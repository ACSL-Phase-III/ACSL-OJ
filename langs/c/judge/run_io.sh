#!/usr/bin/env bash
# run_io.sh <exe> <casedir> [timeout_sec]
#
# io 模式对拍器：把 <casedir>/*.in 依次喂给 <exe> 的 stdin，与同名 *.ans 比较 stdout。
# 比较规则：忽略行尾空白与末尾空行（trailing whitespace insensitive），其余必须逐字符相同。
#
# 输出遵循判分协议（见 core/PLUGIN.md），每行带 $JUDGE_NONCE 前缀：
#   <nonce> JUDGE-MISMATCH: in=<case> got=<...> want=<...>   首个失配样例
#   <nonce> JUDGE-TLE: <case>                                某个样例超时
#   <nonce> JUDGE-COUNT: <N>                                 测试总数
#   <nonce> JUDGE: PASS | JUDGE: FAIL <n>                    最后一行且仅一行
#
# ---- 为什么协议行要带 nonce，以及为什么学生 stderr 要缩进 ----
# 本脚本是判分端程序，学生解是它的子进程。学生解的 stdout 被逐样例捕获去对拍，
# 进不了判分日志；但它的 stderr 在出错时要透给学生排错，会落进 build/run.log。
# 若原样透出，学生只要往 stderr 打一行 "JUDGE-TLE:" 就能把 RE 改判成 TLE。
# 两道防线：
#   1) 协议行带 nonce 前缀，verdict.sh 只认带当次 nonce 的行（学生读不到 nonce）；
#   2) 透出的 stderr 每行缩进两格，`^JUDGE` 这类锚定正则一概匹配不上。
#
# ---- RE 判定归谁 ----
# 本脚本不判 RE，只负责把学生解的 stderr 送进判分日志。sanitizer 报告的识别
# （RE_PATTERN）唯一归属 core/judge/verdict.sh —— 原先两处各写一份正则，
# 改一处忘另一处就会判罚不一致。
set -u

exe="${1:-}"
dir="${2:-}"
tmo="${3:-5}"

nonce="${JUDGE_NONCE:-}"
# 协议行前缀：nonce 为空时退化为裸协议行（便于手工调试本脚本）
pfx="${nonce:+$nonce }"

# 协议行走 fd 3（判分端已重定向到 build/proto.log）；手工调试时 fd 3 未打开，
# 退化成 stdout。学生解写不到 fd 3 —— 它是本脚本的子进程，且 fd 3 不继承给它
# （下面 spawn 时用 3>&- 关掉）。
{ : >&3; } 2>/dev/null || exec 3>&1

[ -n "$exe" ] && [ -n "$dir" ] || { echo "usage: $0 <exe> <casedir> [timeout_sec]" >&2; exit 2; }
[ -x "$exe" ] || { echo "run_io: 可执行文件不存在或不可执行：$exe" >&2; exit 2; }
[ -d "$dir" ] || { echo "run_io: 测试数据目录不存在：$dir" >&2; exit 2; }

shopt -s nullglob
cases=("$dir"/*.in)
if [ "${#cases[@]}" -eq 0 ]; then
    echo "run_io: $dir 下没有任何 *.in 测试数据" >&2
    exit 2
fi

# 规范化：删除每行行尾空白，并去掉文件末尾的所有空行。
normalize() { sed -e 's/[[:space:]]*$//' -e '$a\' "$1" | sed -e :a -e '/^$/{$d;N;ba' -e '}'; }

# 单行摘要，便于塞进 JUDGE-MISMATCH（换行 -> ~，超长截断）。
oneline() { tr '\n' '~' < "$1" | cut -c1-120; }

# 透出学生解的 stderr：每行缩进两格，杜绝协议行注入。
dump_stderr() { sed -n '1,25p' "$1" | sed 's/^/  /'; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

err=0
n=0

for in_f in "${cases[@]}"; do
    base="$(basename "$in_f" .in)"
    ans_f="$dir/$base.ans"
    if [ ! -f "$ans_f" ]; then
        echo "run_io: 缺少期望输出 $ans_f（*.in 与 *.ans 必须成对）" >&2
        exit 2
    fi
    n=$((n + 1))

    out_f="$work/$base.out"
    # env -u JUDGE_NONCE：io 模式的学生解是独立进程，会继承本脚本的环境。
    # 不摘掉的话，它一句 `extern char **environ;` 就能遍历环境块拿到 nonce
    # （不需要任何 #include，头文件白名单与 getenv 黑名单同时失效），
    # 进而伪造带签名的协议行。摘掉后学生解无处可查。
    # 3>&- 关掉协议通道：学生解继承不到 fd 3，就写不进 proto.log 伪造判罚。
    env -u JUDGE_NONCE timeout -k 1 "$tmo" "$exe" < "$in_f" > "$out_f" 2> "$work/$base.err" 3>&-
    rc=$?

    # ---- 超时：报协议行并以 124 退出，让 verdict.sh 走 TLE 分支 ----
    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
        printf '%sJUDGE-TLE: %s（超过 %ss）\n' "$pfx" "$base" "$tmo" >&3
        exit 124
    fi

    # ---- 非零退出：透出 stderr 供排错，原样把退出码交给 verdict.sh 定性 ----
    # 这里不自行判 RE：崩溃是 RE 还是 sanitizer 触发的 RE，由 verdict.sh 按
    # RE_PATTERN 区分并给出中文说明。
    if [ "$rc" -ne 0 ]; then
        echo "run_io: 样例 $base 运行异常（退出码 $rc）"
        dump_stderr "$work/$base.err"
        exit "$rc"
    fi

    # ---- 退出码为 0 但 stderr 非空 ----
    # 可恢复的 sanitizer 诊断（题目若把 SAN 覆盖成不带 -fno-sanitize-recover）
    # 属于这一类：程序照常跑完，诊断只在 stderr。必须把它送进判分日志，
    # 否则 verdict.sh 的 RE_PATTERN 无从匹配。
    if [ -s "$work/$base.err" ]; then
        echo "run_io: 样例 $base 的 stderr 输出："
        dump_stderr "$work/$base.err"
    fi

    normalize "$out_f" > "$work/$base.got"
    normalize "$ans_f" > "$work/$base.want"
    if ! cmp -s "$work/$base.got" "$work/$base.want"; then
        err=$((err + 1))
        if [ "$err" -eq 1 ]; then
            printf '%sJUDGE-MISMATCH: in=%s got=%s want=%s\n' \
                   "$pfx" "$base" "$(oneline "$work/$base.got")" "$(oneline "$work/$base.want")" >&3
        fi
    fi
done

printf '%sJUDGE-COUNT: %s\n' "$pfx" "$n" >&3
if [ "$err" -eq 0 ]; then
    printf '%sJUDGE: PASS\n' "$pfx" >&3
else
    printf '%sJUDGE: FAIL %s\n' "$pfx" "$err" >&3
fi
exit 0
