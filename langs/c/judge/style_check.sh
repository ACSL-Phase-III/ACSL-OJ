#!/usr/bin/env bash
# style_check.sh [--ban-main|--require-main] [--ban=kw1,kw2,...] [--allow-header=h1,h2,...]
#                [--allow-fileio] <student.c>
#
# 学生解风格检查：只允许"自己写算法"，禁止绕过训练目标或攻击判分环境的写法。
# 命中任一禁止项 → 退出码 1 并输出原因；通过 → 退出码 0，无输出。
#
# 检查前先剥离注释与字符串/字符字面量，避免 printf("system") 之类误伤。
set -u

usage() {
    echo "usage: $0 [--ban-main|--require-main] [--ban=kw,...] [--allow-header=h,...]" >&2
    echo "          [--allow-fileio] <student.c>" >&2
    exit 2
}

main_mode=""      # ban | require | (空: 不检查)
extra_ban=""
extra_header=""
allow_fileio="no"

while [ $# -gt 1 ]; do
    case "$1" in
        --ban-main)       main_mode="ban" ;;
        --require-main)   main_mode="require" ;;
        --ban=*)          extra_ban="${1#--ban=}" ;;
        --allow-header=*) extra_header="${1#--allow-header=}" ;;
        --allow-fileio)   allow_fileio="yes" ;;
        *) echo "style_check: 未知参数 $1" >&2; usage ;;
    esac
    shift
done

[ $# -eq 1 ] || usage
f="$1"
[ -f "$f" ] || { echo "style_check: 无法读取文件 $f" >&2; exit 2; }

# ---- 步骤 1：剥离注释（keeplit=1 时保留字面量）----
# 顺序：块注释(可跨行) -> 行注释 -> "字符串" -> '字符'。逐行输出，行号与原文一一对应
# （报错要能指到行）。
#
# 为什么要两个版本：
#   $stripped （keeplit=0）注释与字面量都剥掉。各项调用/关键字检查用它，
#                          免得 printf("不要用 system()") 里的字符串被当成真调用。
#   $nocomment（keeplit=1）只剥注释，保留字面量。**头文件白名单**必须用它：
#                          #include "gcd.h" 的文件名本身就在字面量里，剥了名字就没了。
# 两种模式都得**解析**字面量（哪怕不删）：否则 printf("a/*b") 里的 /* 会被当成块注释
# 起点，从那行起整段代码被吃光，什么违规都查不出来。
strip_src='
  BEGIN { inblock = 0 }
  {
    line = $0; res = ""; n = length(line); i = 1
    while (i <= n) {
      c = substr(line, i, 1)
      if (inblock) {
        if (c == "*" && i < n && substr(line, i + 1, 1) == "/") { inblock = 0; i += 2; continue }
        i++; continue
      }
      if (c == "/" && i < n) {
        c2 = substr(line, i + 1, 1)
        if (c2 == "/") { i = n + 1; continue }             # 行注释：跳过整行剩余
        if (c2 == "*") { inblock = 1; i += 2; continue }   # 块注释开始
      }
      if (c == "\"" || c == "'"'"'") {                      # 字符串 / 字符字面量
        q = c
        if (keeplit) res = res c
        i++
        while (i <= n) {
          d = substr(line, i, 1)
          if (d == "\\") {                                 # 转义：整对跳过
            if (keeplit) res = res substr(line, i, 2)
            i += 2; continue
          }
          if (d == q) { if (keeplit) res = res d; i++; break }
          if (keeplit) res = res d
          i++
        }
        continue
      }
      res = res c
      i++
    }
    print res
  }
'
stripped="$(awk -v keeplit=0 "$strip_src" "$f")"
nocomment="$(awk -v keeplit=1 "$strip_src" "$f")"

# ---- 把命中结果换回原文再给学生看 ----
# 各项检查必须在剥离过的文本上做（否则字符串里的 system( 会误伤），但**报错要给学生
# 看他自己写的那一行**。直接回显剥离后的文本会变成这样：
#     学生写的： FILE *fp = fopen("/etc/passwd", "r");
#     报错显示： 4:    FILE *fp = fopen(, );
# 字面量都没了，学生第一反应是"判分器把我代码改了"。行号是对的，照行号从原文取回即可。
#
# 入参是 grep -n 的输出（"行号:内容"），只取行号，内容一律换成原文那一行。
orig_lines() {
    while IFS= read -r ln; do
        [ -n "$ln" ] || continue
        no="${ln%%:*}"
        case "$no" in ''|*[!0-9]*) printf '%s\n' "$ln"; continue ;; esac
        printf '%s:%s\n' "$no" "$(sed -n "${no}p" "$f")"
    done
}

viol="no"

# ---- 检查 1：main 函数（func 模式禁止自带 main，io 模式必须有 main）----
has_main="$(printf '%s\n' "$stripped" | grep -nE '^[[:space:]]*(int|void)[[:space:]]+main[[:space:]]*\(')"
case "$main_mode" in
    ban)
        if [ -n "$has_main" ]; then
            echo "STYLE: 本题为函数题，判分端自带 main，学生解不得定义 main："
            printf '%s\n' "$has_main" | orig_lines
            viol="yes"
        fi
        ;;
    require)
        if [ -z "$has_main" ]; then
            echo "STYLE: 本题为标准输入输出题，学生解必须定义 int main(void)。"
            viol="yes"
        fi
        ;;
esac

# ---- 检查 2：禁止的库调用（绕过判分 / 攻击环境 / 不安全函数）----
# 分三类给出可读的提示。
ban_escape='system|popen|fork|vfork|execl|execlp|execle|execv|execvp|execvpe|posix_spawn|dlopen|dlsym|signal|raise|longjmp|setjmp|atexit|_exit|abort'
# 注意：只列不会与学生自定义函数名撞车的库函数；raw syscall（open/read/write）需要
# <fcntl.h>/<unistd.h>，已被下面的头文件白名单拦住，故不在此重复禁止 open/read/write。
ban_fileio='fopen|freopen|fdopen|creat|openat|remove|unlink|rename|rmdir|opendir|mmap|getenv|putenv|setenv'
ban_unsafe='gets|strcpy|strcat|sprintf|vsprintf|alloca|scanf_s'

# ---- --allow-fileio：只放开 fopen，其余一律不动 ----
# blackbox 模式（指令集模拟器）的输入是 argv 给的一个 .bin 镜像，学生**必须**能读文件，
# 否则题目根本无法完成。放开的只有 fopen 一个名字：
#   * freopen 仍禁 —— 它能把 stdout 重定向掉，藏输出等于藏诊断；
#   * getenv/putenv/setenv 仍禁 —— 那是偷 nonce 的路子，与读镜像无关；
#   * remove/unlink/rename/rmdir 仍禁 —— 破坏性，且与读镜像无关。
# 放开 fopen 会不会让学生写 fopen("build/proto.log","a") 伪造判罚？不会：
# 判罚行必须带当次 nonce（JUDGE_STRICT=1），而 nonce 既不在 argv 也不在环境里、
# fd 3 也没继承给学生进程，裸的 JUDGE 行 verdict.sh 一概不认。
# 若学生改用 "w" 模式把协议通道清空，结论就此缺失 → 判 RE，纯属自伤。
if [ "$allow_fileio" = "yes" ]; then
    ban_fileio='freopen|fdopen|creat|openat|remove|unlink|rename|rmdir|opendir|mmap|getenv|putenv|setenv'
fi

check_group() {
    local pat="$1" msg="$2" hit
    # 匹配 "标识符 (" 形式的调用；\b 用 -w 近似不够，这里用显式边界
    hit="$(printf '%s\n' "$stripped" | grep -nE "(^|[^A-Za-z0-9_])($pat)[[:space:]]*\(")"
    if [ -n "$hit" ]; then
        echo "STYLE: $msg"
        printf '%s\n' "$hit" | orig_lines
        viol="yes"
    fi
}

if [ "$allow_fileio" = "yes" ]; then
    fileio_msg="命中禁止的文件/环境访问（本题只放开 fopen 读镜像，其余文件与环境操作仍禁止）："
else
    fileio_msg="命中禁止的文件/环境访问（本题只能用参数或 stdin 取数据，不得读写文件绕过判分）："
fi

check_group "$ban_escape" "命中禁止的进程/信号控制调用（判分环境不允许学生解创建进程或劫持控制流）："
check_group "$ban_fileio" "$fileio_msg"
check_group "$ban_unsafe" "命中禁止的不安全函数（存在缓冲区溢出风险，请用 snprintf / strncpy / fgets 等带长度的版本）："

# ---- 检查 3：goto ----
gotoline="$(printf '%s\n' "$stripped" | grep -nwE 'goto')"
if [ -n "$gotoline" ]; then
    echo "STYLE: 命中禁止关键字 goto（请用结构化控制流：if / for / while / break / continue）："
    printf '%s\n' "$gotoline" | orig_lines
    viol="yes"
fi

# ---- 检查 3.5：直接引用环境块 / 判分端内部符号 ----
# 头文件白名单和 getenv 黑名单都挡不住 `extern char **environ;` —— 一个 #include
# 都不需要就能遍历环境块。判分协议的 nonce 已改走 argv（见 judge/judge_proto.h），
# 环境块里本就没有可偷的东西了，这条是第二道防线：读环境块与算法题无关，
# 出现即视为在试探判分环境。
extern_sym="$(printf '%s\n' "$stripped" \
    | grep -nwE 'environ|__environ|_environ|program_invocation_name|program_invocation_short_name|__libc_argv|__libc_argc')"
if [ -n "$extern_sym" ]; then
    echo "STYLE: 命中对环境块 / 进程内部符号的引用（本题只能用参数或 stdin 取数据）："
    printf '%s\n' "$extern_sym" | orig_lines
    viol="yes"
fi

# ---- 检查 4：内联汇编 ----
asmline="$(printf '%s\n' "$stripped" | grep -nE '(^|[^A-Za-z0-9_])(asm|__asm__|__asm)([^A-Za-z0-9_]|$)')"
if [ -n "$asmline" ]; then
    echo "STYLE: 命中内联汇编（本题要求用 C 实现算法）："
    printf '%s\n' "$asmline" | orig_lines
    viol="yes"
fi

# ---- 检查 5：头文件白名单 ----
# 读 $nocomment（只剥注释、留字面量），不读原文也不读 $stripped：
#   读原文 -> 被 /* */ 注释掉的 #include 照样算违规。学生调试时把一行 include 注掉
#            是很常见的动作，那会白判一个 SE，而且提示行指着一行注释，无从下手。
#   读 $stripped -> #include "gcd.h" 的文件名在字面量里，被剥成 #include，名字丢了，
#            连 --allow-header 都没法放行。
# $nocomment 逐行对应原文，所以下面 grep -n 出来的行号仍然是原文行号。
allow_header="stdio.h stdlib.h string.h math.h limits.h stdbool.h stddef.h stdint.h ctype.h assert.h"
if [ -n "$extra_header" ]; then
    allow_header="$allow_header $(printf '%s' "$extra_header" | tr ',' ' ')"
fi
bad_header=""
while IFS= read -r ln; do
    [ -n "$ln" ] || continue
    no="${ln%%:*}"
    h="$(printf '%s' "$ln" | sed -n 's/.*[<"]\([^>"]*\)[>"].*/\1/p')"
    ok="no"
    for a in $allow_header; do
        [ "$h" = "$a" ] && { ok="yes"; break; }
    done
    # 显示原文那一行，不要拿 $h 反拼成 #include <$h>：学生写的是 #include "gcd.h"
    # 却被显示成 #include <gcd.h>，尖括号与引号在 C 里含义不同，看着像判分器读错了。
    [ "$ok" = "yes" ] || bad_header="$bad_header
$no:$(sed -n "${no}p" "$f")"
done <<EOF
$(printf '%s\n' "$nocomment" | grep -nE '^[[:space:]]*#[[:space:]]*include')
EOF
if [ -n "$bad_header" ]; then
    echo "STYLE: 命中不允许的头文件（白名单：$allow_header）：$bad_header"
    viol="yes"
fi

# ---- 检查 6：题目自定义禁止项（--ban=...，按整词匹配）----
if [ -n "$extra_ban" ]; then
    pat="$(printf '%s' "$extra_ban" | tr ',' '|')"
    hit="$(printf '%s\n' "$stripped" | grep -nwE "$pat")"
    if [ -n "$hit" ]; then
        echo "STYLE: 命中本题额外禁止项（$extra_ban）："
        printf '%s\n' "$hit" | orig_lines
        viol="yes"
    fi
fi

if [ "$viol" = "yes" ]; then
    if [ "$allow_fileio" = "yes" ]; then
        echo "提示：本题只允许标准 C（白名单头文件）+ 自己实现的算法；可以 fopen 读镜像文件，"
        echo "      但不得创建进程、访问环境变量或使用不安全函数。"
    else
        echo "提示：本题只允许标准 C（白名单头文件）+ 自己实现的算法，不得读写文件、创建进程或使用不安全函数。"
    fi
    exit 1
fi
exit 0
