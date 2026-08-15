#!/usr/bin/env bash
# judge.sh <pid> <student.v>
# pid 为 problems/ 下的题目目录名，如 p03_adder4。
#
# 判罚流程：
#   1. 风格检查（禁止 always/initial 等关键字、# 延时、实例化）→ 命中判 SE
#   2. iverilog -g2012 编译 (test/tb.v + student.v) 失败 → 判 CE
#   3. vvp 仿真：末行 JUDGE: PASS → AC；JUDGE: FAIL <n> → WA；无输出/崩溃 → RE
# 输出 OJ 风格单行结论，临时文件放 mktemp 目录，结束时自动清理。
#
# 说明：testbench 位于各题独立的 test/ 目录（判分端专用，不随题目发放），
#       由判分脚本把其与学生作答编译到一起，学生侧不接触 tb。
set -u

usage() { echo "usage: $0 <pid> <student.v>" >&2; exit 2; }

[ $# -eq 2 ] || usage

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PID="$1"
STU="$2"

PROB="$ROOT/problems/$PID"
TB="$PROB/test/tb.v"

[ -d "$PROB" ]            || { echo "judge: 未找到题目 problems/$PID" >&2; exit 2; }
[ -f "$TB" ]              || { echo "judge: 缺少判分端 testbench $TB（test/ 为判分专用目录，不随题目发放）" >&2; exit 2; }
[ -f "$STU" ]             || { echo "judge: 无法读取学生文件 $STU" >&2; exit 2; }

chmod +x "$ROOT"/judge/*.sh 2>/dev/null

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

name="[$PID]"

# ---- SE：风格检查 ----
style_out="$tmpdir/style.txt"
if ! "$ROOT/judge/style_check.sh" "$STU" > "$style_out" 2>&1; then
    echo "$name SE (Style Error)"
    echo "---- 风格违规详情 ----"
    cat "$style_out"
    exit 0
fi

# ---- CE：编译 ----
cp "$STU" "$tmpdir/student.v"
if ! iverilog -g2012 -o "$tmpdir/tb.vvp" "$TB" "$tmpdir/student.v" > "$tmpdir/compile.txt" 2>&1; then
    echo "$name CE (Compile Error)"
    echo "---- iverilog 编译错误 ----"
    sed -n '1,40p' "$tmpdir/compile.txt"
    exit 0
fi

# ---- 仿真 ----
vvp "$tmpdir/tb.vvp" > "$tmpdir/sim.txt" 2>&1
rc=$?

verdict="$(grep -E '^JUDGE: (PASS|FAIL [0-9]+)$' "$tmpdir/sim.txt" | tail -n 1)"
count="$(grep -E '^JUDGE-COUNT:' "$tmpdir/sim.txt" | tail -n 1 | sed 's/JUDGE-COUNT:[[:space:]]*//')"

if [ "$rc" -ne 0 ] || [ -z "$verdict" ] || [ -z "$count" ]; then
    echo "$name RE (Run Error)"
    echo "---- vvp 输出 ----"
    sed -n '1,40p' "$tmpdir/sim.txt"
    exit 0
fi

case "$verdict" in
    "JUDGE: PASS")
        echo "$name AC ($count/$count tests)"
        ;;
    *)
        nfail="${verdict##* }"
        echo "$name WA ($nfail/$count tests)"
        echo "---- 失配样例（in ... got=... want=...）----"
        grep '^JUDGE-MISMATCH:' "$tmpdir/sim.txt"
        ;;
esac
exit 0