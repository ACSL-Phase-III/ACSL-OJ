#!/usr/bin/env bash
# run_blackbox.sh <exe> <testdir> [timeout_sec] [random_cases]
#
# blackbox 模式运行器：指令集模拟器。学生程序契约：
#     ./run <image.bin> <max_cycles> [--dump=trace|final]
#     --dump=final  跑到上限后打印一行： PC=0x… a0=0x…（sEMU 还要打 R0..R3）
#     --dump=trace  每周期一行：         cyc=<n> PC=0x…
#
# 期望状态由 testdir/spec.py 从镜像现场算出（或由 cases/*.meta 给出自校验范围），
# 仓库里没有一份可抄的参考模拟器源码作为学生答案。
#
# 协议行走 fd 3，带 $JUDGE_NONCE；各组汇总成一行结论交给 verdict.sh。
set -u

exe="${1:-}"
dir="${2:-}"
tmo="${3:-20}"
nrand="${4:-4}"

nonce="${JUDGE_NONCE:-}"
pfx="${nonce:+$nonce }"

{ : >&3; } 2>/dev/null || exec 3>&1

[ -n "$exe" ] && [ -n "$dir" ] || { echo "usage: $0 <exe> <testdir> [timeout] [random_cases]" >&2; exit 2; }
[ -x "$exe" ] || { echo "run_blackbox: 可执行文件不存在或不可执行：$exe" >&2; exit 2; }
[ -d "$dir" ] || { echo "run_blackbox: 判分目录不存在：$dir" >&2; exit 2; }

spec_src="$dir/spec.py"
PY="${PYTHON:-python3}"
if [ ! -f "$spec_src" ]; then
    echo "run_blackbox: 缺少 $spec_src（blackbox 的镜像生成器 + 判据）" >&2
    exit 2
fi
command -v "$PY" >/dev/null 2>&1 || {
    echo "run_blackbox: 找不到 $PY，blackbox 题的 spec.py 需要 Python 3。" >&2
    echo "             WSL 下： sudo apt install python3" >&2
    exit 2
}

dump_stderr() { sed -n '1,25p' "$1" | sed 's/^/  /'; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# 学生进程 cwd 是题目目录，且 --allow-fileio 允许 fopen。若直接调 testdir/spec.py，
# 学生能 fopen("../spec.py") 换成永远 PASS 的桩，不需要 nonce。
# 先把 spec.py 和镜像快照到临时目录（与学生 argv 镜像不在同一层），再只调这份副本。
mkdir -p "$work/in" "$work/judge"
cp "$spec_src" "$work/judge/spec.py"
cp "$spec_src" "$work/judge/spec.py.bak"
chmod a-w "$work/judge/spec.py" "$work/judge/spec.py.bak" 2>/dev/null || true
spec="$work/judge/spec.py"

restore_spec() {
    chmod u+w "$spec" 2>/dev/null || true
    cp "$work/judge/spec.py.bak" "$spec"
    chmod a-w "$spec" 2>/dev/null || true
}

total=0
fail=0
shown=0
seed="${SEED:-$(date +%s)}"

# 读 cases/<name>.meta：cycles / dump，缺省 cycles=32 dump=final。
read_meta() {
    local meta="$1"
    CYCLES=32
    DUMP=final
    [ -f "$meta" ] || return 0
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ''|\#*) continue ;;
        esac
        key="${line%%=*}"
        val="${line#*=}"
        key="$(printf '%s' "$key" | tr -d '[:space:]')"
        val="$(printf '%s' "$val" | tr -d '[:space:]')"
        case "$key" in
            cycles) CYCLES="$val" ;;
            dump)   DUMP="$val" ;;
        esac
    done < "$meta"
}

run_case() {
    local name="$1" img="$2" cycles="$3" dump="$4"
    local out_f="$work/$name.out" err_f="$work/$name.err" rep_f="$work/$name.rep"
    local case_img="$work/in/$name.bin"
    local check_img="$work/judge/$name.bin"

    cp "$img" "$case_img"
    cp "$img" "$check_img"
    if [ -f "${img%.bin}.meta" ]; then
        cp "${img%.bin}.meta" "$work/judge/$name.meta"
    fi
    chmod a-w "$case_img" "$check_img" 2>/dev/null || true

    env -u JUDGE_NONCE timeout -k 1 "$tmo" \
        "$exe" "$case_img" "$cycles" "--dump=$dump" \
        > "$out_f" 2> "$err_f" 3>&-
    local rc=$?
    last_rc=$rc

    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
        printf '%sJUDGE-TLE: %s（超过 %ss）\n' "$pfx" "$name" "$tmo" >&3
        echo "run_blackbox: 样例 $name 超时。模拟器必须在 max_cycles 用完后退出，"
        echo "             不要 while(1) 空转；PC 陷入 halt 也要靠计数器停。"
        return 1
    fi
    if [ "$rc" -ne 0 ]; then
        echo "run_blackbox: 样例 $name 运行异常（退出码 $rc）"
        dump_stderr "$err_f"
        return 2
    fi
    if [ -s "$err_f" ]; then
        echo "run_blackbox: 样例 $name 的 stderr 输出："
        dump_stderr "$err_f"
    fi

    restore_spec
    if ! env -u JUDGE_NONCE \
            PYTHONIOENCODING=utf-8 \
            CASE="$name" \
            "$PY" "$spec" check "$check_img" "$out_f" "$cycles" "$dump" \
            > "$rep_f" 2>"$work/$name.cerr" 3>&-; then
        echo "run_blackbox: spec.py 在样例 $name 上自身出错（出题端 bug）"
        sed -n '1,20p' "$work/$name.cerr" | sed 's/^/  /'
        return 2
    fi

    local c v f
    c="$(grep -E '^JUDGE-COUNT: [0-9]+$' "$rep_f" | tail -n1 | sed 's/^JUDGE-COUNT:[[:space:]]*//')"
    v="$(grep -E '^JUDGE: (PASS|FAIL [0-9]+)$' "$rep_f" | tail -n1)"
    if [ -z "$c" ] || [ -z "$v" ]; then
        echo "run_blackbox: spec.py 没有输出完整协议（缺 JUDGE-COUNT 或 JUDGE: 结论）"
        sed -n '1,20p' "$rep_f" | sed 's/^/  /'
        return 2
    fi
    total=$((total + c))
    if [ "$v" != "JUDGE: PASS" ]; then
        f="${v##* }"
        fail=$((fail + f))
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

last_rc=0
shopt -s nullglob

for img in "$dir/cases"/*.bin; do
    name="$(basename "$img" .bin)"
    read_meta "$dir/cases/$name.meta"
    run_case "$name" "$img" "$CYCLES" "$DUMP"
    case $? in
        1) exit 124 ;;
        2) exit "$last_rc" ;;
    esac
done

if [ "$nrand" -gt 0 ]; then
    echo "run_blackbox: 随机样例 $nrand 组，种子 SEED=$seed（复现：make sim SEED=$seed）"
    i=0
    while [ "$i" -lt "$nrand" ]; do
        i=$((i + 1))
        name="$(printf 'rand%02d' "$i")"
        img="$work/$name.bin"
        meta_f="$work/$name.meta"
        if ! env PYTHONIOENCODING=utf-8 \
                "$PY" "$spec" gen "$((seed + i))" "$img" "$meta_f" \
                2>"$work/$name.generr"; then
            echo "run_blackbox: spec.py gen 出错（出题端 bug）"
            sed -n '1,20p' "$work/$name.generr" | sed 's/^/  /'
            exit 2
        fi
        read_meta "$meta_f"
        run_case "$name" "$img" "$CYCLES" "$DUMP"
        case $? in
            1) exit 124 ;;
            2) exit "$last_rc" ;;
        esac
    done
fi

if [ "$total" -eq 0 ]; then
    echo "run_blackbox: 一组样例都没跑（$dir/cases/ 下没有 *.bin，RANDCASES=$nrand）" >&2
    exit 2
fi

printf '%sJUDGE-COUNT: %s\n' "$pfx" "$total" >&3
if [ "$fail" -eq 0 ]; then
    printf '%sJUDGE: PASS\n' "$pfx" >&3
else
    printf '%sJUDGE: FAIL %s\n' "$pfx" "$fail" >&3
fi
exit 0
