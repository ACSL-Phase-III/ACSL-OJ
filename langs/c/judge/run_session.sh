#!/usr/bin/env bash
# run_session.sh <exe> <testdir> [timeout_sec] [random_cases]
#
# session 模式运行器：交互式菜单程序（成绩统计器一类）的判分。
#
# 与 io 模式（run_io.sh）的本质区别：**判分端不存在期望输出文件**。
#   io      ：cases/*.in -> 逐字节比对 cases/*.ans（.ans 即答案明文，随仓库发放就等于发答案）
#   session ：cases/*.in（固定组）+ gen.py（随机组）-> 交给 test/check.py 判定
#
# check.py 自己从输入算出应有的统计结果，所以仓库里不存在参考解、也不存在期望输出，
# 学生 clone 到的东西里没有答案可抄。随机组每次判分重新生成，硬编码答案在那里穿帮。
#
# 输出遵循判分协议（见 core/PLUGIN.md），协议行走 fd 3 且带 $JUDGE_NONCE 前缀 ——
# 与 run_io.sh 同一套理由：学生解的 stderr 会透进判分日志，不加签名的话它打一行
# "JUDGE-TLE:" 就能改判。
#
# 每组样例是一次独立的进程启动，本脚本把各组 check.py 的结果**汇总成一行结论** ——
# verdict.sh 规定判罚行恰好一行，各组不能各打一条。
set -u

exe="${1:-}"
dir="${2:-}"
tmo="${3:-5}"
nrand="${4:-6}"

nonce="${JUDGE_NONCE:-}"
pfx="${nonce:+$nonce }"

# 协议行走 fd 3（判分端已重定向到 build/proto.log）；手工调试时 fd 3 未打开，退化成 stdout。
{ : >&3; } 2>/dev/null || exec 3>&1

[ -n "$exe" ] && [ -n "$dir" ] || { echo "usage: $0 <exe> <testdir> [timeout] [random_cases]" >&2; exit 2; }
[ -x "$exe" ] || { echo "run_session: 可执行文件不存在或不可执行：$exe" >&2; exit 2; }
[ -d "$dir" ] || { echo "run_session: 判分目录不存在：$dir" >&2; exit 2; }

# ===== 判分件（检查器 / 生成器）的定位与调用方式 =====
# 默认是随题目发放的 Python 脚本；题目 Makefile 可改成预编译二进制：
#     CHECKER := check                    # 用 test/check（可执行文件）
#     CHECKER := check-$(shell uname -m)  # 按平台各发一份，运行时选
#     CHECKER := check --strict           # 允许带固定参数
# 解析规则：第一个词不含 "/" 时按 $dir/<词> 定位（= 题目自带的判分件），含 "/"
# 时按原样当路径用；以 .py 结尾则用 $PYTHON 解释执行，否则直接执行。
#
# 关于"换成二进制更安全"：本判分器跑在学生自己的机器上，判分件必然落到他手里，
# 能跑就能被 strace / gdb / 反编译，所以二进制买到的是"不易读"，不是安全边界。
# 本模式真正不泄漏答案的原因是检查器**从输入现场算出应有结果**，
# 文件里根本没有答案可抄（这一点对 .py 和二进制同样成立）。
# 代价是每个平台各编一份，且自检失败时从可读的 Python traceback 变成不透明的崩溃。
CHECKER="${CHECKER:-check.py}"
GEN="${GEN:-gen.py}"

PY="${PYTHON:-python3}"

# core/judge 进 PYTHONPATH，让 Python 检查器能 import session
core_judge="$(cd "$(dirname "$0")/../../../core/judge" && pwd)"

# tool_path <命令串> —— 打印判分件的实际路径（只做路径推导，不检查存在性）
tool_path() {
    case "${1%% *}" in
        */*) printf '%s' "${1%% *}" ;;
        *)   printf '%s/%s' "$dir" "${1%% *}" ;;
    esac
}

# resolve_tool <命令串> <人类可读的名字>
#   成功时把可直接执行的命令写进全局数组 tool_argv；失败即出题端 bug，exit 2。
tool_argv=()
resolve_tool() {
    local spec="$1" what="$2" path words=()
    path="$(tool_path "$spec")"
    # 这里故意做分词：判分件命令来自题目 Makefile（判分端），不是学生输入。
    read -r -a words <<< "$spec"

    if [ ! -f "$path" ]; then
        echo "run_session: 缺少$what $path" >&2
        exit 2
    fi

    case "$path" in
        *.py)
            command -v "$PY" >/dev/null 2>&1 || {
                echo "run_session: 找不到 $PY，而本题的$what是 Python 脚本（$path）。" >&2
                echo "             WSL 下装一次即可： sudo apt install python3" >&2
                echo "             （若本题本应使用预编译二进制，请检查题目 Makefile 的 CHECKER / GEN）" >&2
                exit 2
            }
            tool_argv=( "$PY" "$path" )
            ;;
        *)
            if [ ! -x "$path" ]; then
                echo "run_session: $what $path 存在但没有可执行位。" >&2
                echo "             预编译判分件经 Windows 共享盘或打包分发常会丢掉 +x，补上即可：" >&2
                echo "                 chmod +x $path" >&2
                exit 2
            fi
            tool_argv=( "$path" )
            ;;
    esac
    if [ "${#words[@]}" -gt 1 ]; then
        tool_argv+=( "${words[@]:1}" )
    fi
}

resolve_tool "$CHECKER" "检查器"
CHK_ARGV=( "${tool_argv[@]}" )

# 生成器按需解析（RANDCASES=0 时不需要它存在），这里只先算出路径供存在性判断。
gen="$(tool_path "$GEN")"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

total=0
fail=0
shown=0

# 透出学生解的 stderr：每行缩进两格，杜绝协议行注入（与 run_io.sh 同理）。
dump_stderr() { sed -n '1,25p' "$1" | sed 's/^/  /'; }

# 随机种子：默认按时间取，学生每次判分拿到的随机组都不同。
# 打印出来，失败可复现：make sim SEED=<值>
seed="${SEED:-$(date +%s)}"

# run_case <样例名> <输入文件>
#   返回 0=已判定  1=超时（调用方应立即退出 124）  2=运行异常（调用方应把 rc 交出去）
last_rc=0
run_case() {
    local name="$1" in_f="$2"
    local out_f="$work/$name.out" err_f="$work/$name.err" rep_f="$work/$name.rep"

    # env -u JUDGE_NONCE：学生解是本脚本的子进程，会继承环境；不摘掉的话一句
    #   extern char **environ;
    # 就能遍历到 nonce（不需要任何 #include，头文件白名单与 getenv 黑名单同时失效）。
    # 3>&- 关掉协议通道：继承不到 fd 3 就写不进 proto.log 伪造判罚。
    env -u JUDGE_NONCE timeout -k 1 "$tmo" "$exe" < "$in_f" > "$out_f" 2> "$err_f" 3>&-
    local rc=$?
    last_rc=$rc

    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
        printf '%sJUDGE-TLE: %s（超过 %ss）\n' "$pfx" "$name" "$tmo" >&3
        echo "run_session: 样例 $name 超时。交互式程序要在读到 EOF 或收到退出选项后结束，"
        echo "             菜单循环里请检查 scanf 的返回值（EOF 时不再继续循环）。"
        return 1
    fi

    # 不自行判 RE：崩溃还是 sanitizer 触发，由 verdict.sh 按 RE_PATTERN 定性。
    if [ "$rc" -ne 0 ]; then
        echo "run_session: 样例 $name 运行异常（退出码 $rc）"
        dump_stderr "$err_f"
        return 2
    fi
    # 退出码 0 但 stderr 非空：可恢复的 sanitizer 诊断也要送进判分日志。
    if [ -s "$err_f" ]; then
        echo "run_session: 样例 $name 的 stderr 输出："
        dump_stderr "$err_f"
    fi

    # ---- 交给题目自带的检查器 ----
    # check.py 是判分端程序，它的 stdout 落在临时文件里（不进 run.log），
    # 打的是裸协议行；本脚本汇总后才带签名写进 fd 3。
    if ! env -u JUDGE_NONCE \
             PYTHONPATH="$core_judge${PYTHONPATH:+:$PYTHONPATH}" \
             PYTHONIOENCODING=utf-8 \
             CASE="$name" \
             "${CHK_ARGV[@]}" "$in_f" "$out_f" > "$rep_f" 2>"$work/$name.cerr" 3>&-; then
        echo "run_session: 检查器 $CHECKER 在样例 $name 上自身出错"
        echo "             （这是出题端的 bug，不是学生的问题，请联系判分端维护者）"
        sed -n '1,20p' "$work/$name.cerr" | sed 's/^/  /'
        return 2
    fi

    local c v f
    c="$(grep -E '^JUDGE-COUNT: [0-9]+$' "$rep_f" | tail -n1 | sed 's/^JUDGE-COUNT:[[:space:]]*//')"
    v="$(grep -E '^JUDGE: (PASS|FAIL [0-9]+)$' "$rep_f" | tail -n1)"
    if [ -z "$c" ] || [ -z "$v" ]; then
        echo "run_session: 检查器没有输出完整协议（缺 JUDGE-COUNT 或 JUDGE: 结论），这是出题端 bug"
        sed -n '1,20p' "$rep_f" | sed 's/^/  /'
        return 2
    fi

    total=$((total + c))
    if [ "$v" != "JUDGE: PASS" ]; then
        f="${v##* }"
        fail=$((fail + f))
        # 只透出第一条失配：学生只需要一个能复现的最小例子。
        #
        # 这一行的 got= 字段来自学生输出，但注入不进新的协议行，三层保证：
        #   1. 检查器把上下文折成单行再输出 —— 归一化时 \n 当空白处理，多行用 ~ 连接
        #      并按缓冲区上限截断。两个检查器都这么做：预编译的 test/check.c
        #      （ck_context）与 core/judge/session.py（Checker._context）。
        #      注意本题实际跑的是**二进制** test/check（题目 Makefile 里 CHECKER := check），
        #      check.py 只是同一判据的 Python 版；改判据要改哪个，看 CHECKER 指向谁。
        #   2. 下面 grep -m1 只取一行，检查器万一吐了多行也进不来第二行。
        #   3. 本脚本再加当次 nonce 签名，裸协议行 verdict.sh 一概不认。
        if [ "$shown" -eq 0 ]; then
            local m
            m="$(grep -m1 '^JUDGE-MISMATCH: ' "$rep_f" || true)"
            if [ -n "$m" ]; then
                printf '%s%s\n' "$pfx" "$m" >&3
                shown=1
            fi
        fi
    fi
    return 0
}

shopt -s nullglob

# ---- 1. 固定样例：committed 的 *.in，给学生一个可复现的调试回路 ----
for in_f in "$dir/cases"/*.in; do
    run_case "$(basename "$in_f" .in)" "$in_f"
    case $? in
        1) exit 124 ;;
        2) exit "$last_rc" ;;
    esac
done

# ---- 2. 随机样例：每次判分重新生成，硬编码答案在这里穿帮 ----
# gen.py 缺失但要求了随机组 → 硬失败，不静默降级。
# 若只跑固定样例就悄悄放过，那"硬编码教学样例答案"的假解就会判成 AC ——
# 随机组正是防这一手的唯一防线，缺了必须让人看见。
if [ ! -f "$gen" ] && [ "$nrand" -gt 0 ]; then
    echo "run_session: 要求 $nrand 组随机样例，但缺少生成器 $gen。" >&2
    echo "             随机组是本题防硬编码的唯一防线，不能缺；" >&2
    echo "             确实只想跑固定样例请在题目 Makefile 里显式写 RANDCASES := 0。" >&2
    echo "             （用预编译生成器的题目请检查题目 Makefile 的 GEN 设置）" >&2
    exit 2
fi

if [ -f "$gen" ] && [ "$nrand" -gt 0 ]; then
    resolve_tool "$GEN" "生成器"
    GEN_ARGV=( "${tool_argv[@]}" )
    echo "run_session: 随机样例 $nrand 组，种子 SEED=$seed（复现某次失败：make sim SEED=$seed）"
    i=0
    while [ "$i" -lt "$nrand" ]; do
        i=$((i + 1))
        name="$(printf 'rand%02d' "$i")"
        if ! env PYTHONIOENCODING=utf-8 \
                 PYTHONPATH="$core_judge${PYTHONPATH:+:$PYTHONPATH}" \
                 "${GEN_ARGV[@]}" "$((seed + i))" \
                 > "$work/$name.in" 2>"$work/$name.generr"; then
            echo "run_session: 生成器 $GEN 出错（出题端 bug，请联系判分端维护者）"
            sed -n '1,20p' "$work/$name.generr" | sed 's/^/  /'
            exit 2
        fi
        run_case "$name" "$work/$name.in"
        case $? in
            1) exit 124 ;;
            2) exit "$last_rc" ;;
        esac
    done
fi

if [ "$total" -eq 0 ]; then
    echo "run_session: 一组样例都没跑（$dir/cases/ 下没有 *.in，也没有 $gen）" >&2
    exit 2
fi

printf '%sJUDGE-COUNT: %s\n' "$pfx" "$total" >&3
if [ "$fail" -eq 0 ]; then
    printf '%sJUDGE: PASS\n' "$pfx" >&3
else
    printf '%sJUDGE: FAIL %s\n' "$pfx" "$fail" >&3
fi
exit 0
