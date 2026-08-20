/* judge_proto.h —— C 判分端 harness 的判分协议输出接口
 *
 * 只给判分端 harness 用，不随题目发放，学生解也引不进来：
 * 本文件不在 style_check.sh 的头文件白名单里，学生 #include 它即判 SE。
 *
 * ---- 判分协议为什么必须走独立通道（fd 3）----
 * 函数题里学生解与 harness 编进同一个可执行文件、共享 stdout。学生只要
 *
 *     printf("JUDGE-COUNT: 1\nJUDGE: PASS\n"); exit(0);
 *
 * 就能在 harness 来不及给出结论前伪造一个 AC。靠禁 exit 之类的黑名单挡不住
 * （_Exit / quick_exit / longjmp / abort 都能提前结束进程）。
 *
 * 光加 nonce 签名同样挡不住 —— 同一个进程意味着 harness 藏不住任何秘密：
 *
 *   - nonce 经 argv 传进来，学生解读 /proc/self/cmdline 就能拿到（实测可行）；
 *   - 早先试过经环境变量传，一句 `extern char **environ;` 就能遍历环境块捞出来，
 *     一个 #include 都不用，头文件白名单与 getenv 黑名单同时失效（实测可行）；
 *   - 就算都堵上，学生解仍可直接翻进程内存。
 *
 * 实测中一个 __attribute__((destructor)) 函数在 main 返回后补一行带正确签名的
 * JUDGE: PASS，就让全错的解判成了 AC（verdict.sh 当时取最后一行判罚）。
 *
 * 所以真正的隔离是换通道：协议行写 fd 3（判分端重定向到 build/proto.log），
 * verdict.sh 只认这个文件里的结论；学生解的 printf 只能写到 stdout，
 * 落进 build/run.log，仅用于给学生看诊断与匹配 sanitizer 报告。
 * 学生解要往 fd 3 写就得用 fdopen/open/write（连同 <unistd.h>/<fcntl.h>
 * 都在 style_check.sh 的黑名单里）。nonce 保留为第二道签名。
 *
 * ---- 用法 ----
 *     int main(int argc, char **argv) {
 *         judge_init(argc, argv);          // 必须最先调用
 *         ...
 *         judge_mismatch("in=gcd(%d,%d) got=%d want=%d", a, b, got, want);
 *         judge_count(ntest);
 *         judge_result(err);               // err==0 -> PASS，否则 FAIL err
 *     }
 *
 * harness 由 langs/c/lang.mk 用 -I$(LANG)/judge 编译，直接 #include <judge_proto.h>。
 */
#ifndef JUDGE_PROTO_H
#define JUDGE_PROTO_H

#include <stdarg.h>
#include <stdio.h>

/* 当次运行的 nonce，由 judge_init 从 argv[1] 收下。
 * static 且无外部链接：学生解即使 extern 声明也拿不到这个符号。 */
static const char *judge_nonce_val = "";

/* 必须在 main 里最先调用。判分端没传 nonce 时留空串，此时 verdict.sh 的严格模式
 * 会判"平台配置错误"，而不是给出一个可疑的 AC。 */
static inline void judge_init(int argc, char **argv)
{
    if (argc > 1 && argv[1] && argv[1][0])
        judge_nonce_val = argv[1];
}

static inline const char *judge_nonce(void)
{
    return judge_nonce_val;
}

/* fdopen 是 POSIX 而非 ISO C：在 -std=c11（严格 ISO 模式）下 glibc 的 <stdio.h>
 * 不声明它。少了声明，gcc 会按隐式声明当成返回 int，指针被截断成 0x80 之类的野值，
 * 一 fprintf 就 SEGV —— 而 -Wall -Wextra 只给 warning，编译"成功"，报错要到运行期
 * 才以 AddressSanitizer SEGV 的形式冒出来（实测踩过）。
 * 这里自己按 POSIX 原型声明，既不用放宽 -std（那会连学生解一起放宽），
 * 也不必定义 _POSIX_C_SOURCE（本文件在 harness.c 的 <stdio.h> 之后才被 include，
 * 那时特性宏已经来不及生效了）。 */
extern FILE *fdopen(int fd, const char *mode);

/* 判分协议的输出流：fd 3。判分端 RUN_CMD 已把它重定向到 build/proto.log。
 * fd 3 没打开时退化到 stdout，便于手工跑 harness 调试。判分链路上不会走到这条
 * 退路：fd 3 总是开着的，而且万一真的退化了，proto.log 为空会被 verdict.sh
 * 判成 RE（判分端配置错误），不会误给 AC。static 变量，学生解拿不到这个符号。 */
static inline FILE *judge_out(void)
{
    static FILE *out = NULL;
    if (!out) {
        out = fdopen(3, "w");
        if (!out)
            out = stdout;
    }
    return out;
}

/* 打印一行带 nonce 前缀的协议行。nonce 为空时不加前缀（便于手工调试 harness）。 */
static inline void judge_line(const char *tag, const char *fmt, va_list ap)
{
    FILE *o = judge_out();
    const char *n = judge_nonce();
    if (*n)
        fprintf(o, "%s ", n);
    fputs(tag, o);
    if (fmt && *fmt) {
        fputc(' ', o);
        vfprintf(o, fmt, ap);
    }
    fputc('\n', o);
    fflush(o);
}

/* 失配样例：可调多次，verdict.sh 全部打给学生看，首个最重要。
 * 约定 fmt 不含结尾换行，形如 "in=... got=... want=..."。 */
static inline void judge_mismatch(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    judge_line("JUDGE-MISMATCH:", fmt, ap);
    va_end(ap);
}

/* 测试总数。 */
static inline void judge_count(int n)
{
    FILE *o = judge_out();
    const char *nc = judge_nonce();
    fprintf(o, "%s%sJUDGE-COUNT: %d\n", nc, *nc ? " " : "", n);
    fflush(o);
}

/* 结论行：必须是最后一行且仅一行。err==0 -> PASS，否则 FAIL <err>。
 * 打印后立刻 fflush：harness 可能在学生解已经污染缓冲区的情况下结束，
 * 结论行丢了会被 verdict.sh 判成 RE。 */
static inline void judge_result(int err)
{
    FILE *o = judge_out();
    const char *n = judge_nonce();
    const char *sp = *n ? " " : "";
    if (err == 0)
        fprintf(o, "%s%sJUDGE: PASS\n", n, sp);
    else
        fprintf(o, "%s%sJUDGE: FAIL %d\n", n, sp, err);
    fflush(o);
}

/* 运行端自报超时（可选，通常由 timeout 的退出码 124/137 触发 TLE）。 */
static inline void judge_tle(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    judge_line("JUDGE-TLE:", fmt, ap);
    va_end(ap);
}

#endif /* JUDGE_PROTO_H */
