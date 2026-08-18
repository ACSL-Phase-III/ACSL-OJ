#!/usr/bin/env bash
# verdict.sh <pid> <runlog> <rc> <outfile>
#
# 语言无关的判罚解析：读取一次运行的日志，按判分协议得出结论。
# 与具体语言（iverilog/vvp、gcc、将来的 python/rust……）完全解耦：
# 只认协议里的三个字段，不认任何工具链细节。
#
# ---- 判分协议（所有语言插件的 tb / harness / 对拍器都必须遵守）----
#   JUDGE-MISMATCH: in=... got=... want=...   失配样例（可多行，首行最重要）
#   JUDGE-COUNT: <N>                          测试总数
#   JUDGE: PASS | JUDGE: FAIL <n>             最后一行且仅一行
#   JUDGE-TLE: <说明>                         （可选）运行端自己发现超时
#
# ---- 输出 ----
#   stdout：结论行 + 供学生排错的详情
#   <outfile>：只写结论行一行（供 Makefile 汇总进 RUNLOG / trace 提交信息）
#
# ---- 语言插件可用的环境变量 ----
#   RE_PATTERN   命中即判 RE 的 grep -E 正则（如 C 的 sanitizer 报告）
#   RE_LABEL     上述情形的判罚说明（如 "内存越界 / 未定义行为"）
#   RE_HEAD      上述情形打印日志的行数（默认 25）
#   TIMEOUT      单次运行时限（秒），只用于 TLE 提示文案
set -u

pid="${1:-unknown}"
log="${2:-}"
rc="${3:-0}"
out="${4:-/dev/null}"

RE_PATTERN="${RE_PATTERN:-}"
RE_LABEL="${RE_LABEL:-}"
RE_HEAD="${RE_HEAD:-25}"
TIMEOUT="${TIMEOUT:-}"

[ -n "$log" ] || { echo "verdict.sh: 缺少运行日志参数" >&2; exit 2; }
[ -f "$log" ] || : > "$log"

emit() {
    printf '%s\n' "$1"
    printf '%s\n' "$1" > "$out"
}

verdict="$(grep -E '^JUDGE: (PASS|FAIL [0-9]+)$' "$log" | tail -n1)"
ntests="$(grep -E '^JUDGE-COUNT:' "$log" | tail -n1 | sed 's/^JUDGE-COUNT:[[:space:]]*//')"

# ---- TLE：timeout 的 124/137，或运行端自报的 JUDGE-TLE ----
if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ] || grep -q '^JUDGE-TLE:' "$log"; then
    if [ -n "$TIMEOUT" ]; then
        emit "[$pid] TLE (Time Limit Exceeded, 单次运行上限 ${TIMEOUT}s)"
    else
        emit "[$pid] TLE (Time Limit Exceeded)"
    fi
    echo "---- 超时前的输出 ----"
    sed -n '1,10p' "$log"
    exit 0
fi

# ---- 语言插件自定义的 RE（如 sanitizer 报告）----
if [ -n "$RE_PATTERN" ] && grep -qE "$RE_PATTERN" "$log"; then
    emit "[$pid] RE (Run Error${RE_LABEL:+：$RE_LABEL})"
    echo "---- 运行时诊断 ----"
    sed -n "1,${RE_HEAD}p" "$log"
    exit 0
fi

# ---- 通用 RE：非零退出，或协议字段缺失（tb/harness 没跑到底）----
if [ "$rc" -ne 0 ] || [ -z "$verdict" ] || [ -z "$ntests" ]; then
    emit "[$pid] RE (Run Error)"
    echo "---- 运行输出（退出码 $rc）----"
    sed -n '1,20p' "$log"
    exit 0
fi

# ---- AC / WA ----
if [ "$verdict" = "JUDGE: PASS" ]; then
    emit "[$pid] AC ($ntests/$ntests tests)"
    exit 0
fi

nfail="${verdict##* }"
emit "[$pid] WA ($nfail/$ntests 组失配)"
echo "---- 失配样例（in ... got=... want=...）----"
grep '^JUDGE-MISMATCH:' "$log"
exit 0
