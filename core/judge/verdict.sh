#!/usr/bin/env bash
# verdict.sh <pid> <runlog> <rc> <outfile>
#
# 语言无关的判罚解析：读取一次运行的日志，按判分协议得出结论。
# 与具体语言（iverilog/vvp、gcc、将来的 python/rust……）完全解耦：
# 只认协议里的几个字段，不认任何工具链细节。
#
# ---- 判分协议（所有语言插件的 tb / harness / 对拍器都必须遵守）----
#   [<nonce> ]JUDGE-MISMATCH: in=... got=... want=...  失配样例（可多行，首行最重要）
#   [<nonce> ]JUDGE-COUNT: <N>                         测试总数
#   [<nonce> ]JUDGE: PASS | JUDGE: FAIL <n>            最后一行且仅一行
#   [<nonce> ]JUDGE-TLE: <说明>                        （可选）运行端自己发现超时
#
# ---- 判罚从哪里读：独立协议通道 ----
# 有些语言（如 C 的函数题）让学生解与判分端 harness 跑在同一个进程里、共享 stdout。
# 学生解只要 printf 一行 "JUDGE: PASS" 就能伪造判罚，封 exit 之类的黑名单挡不住
# （_Exit / quick_exit / longjmp 都能绕）。
#
# 只加 nonce 签名也不够：同进程意味着 harness 藏不住秘密 —— nonce 走 argv 能被
# /proc/self/cmdline 读到，走环境变量能被 `extern char **environ;` 遍历到，
# 再不然直接翻内存。实测一个 __attribute__((destructor)) 在 main 返回后补一行
# 带正确签名的 JUDGE: PASS，就能让全错的解判成 AC。
#
# 所以判罚只从独立通道读：运行端把协议行写进 $PROTO_LOG（C 用 fd 3 重定向过去），
# 学生解的 stdout 落在运行日志里，只用于展示诊断与匹配 RE_PATTERN。
# 两条补充规则：
#   1) nonce 前缀仍然校验（JUDGE_STRICT=1），作第二道防线；
#   2) 判罚行必须恰好一行，多于一行一律判 RE —— 否则"抢在前面"或"补在后面"
#      总有一种顺序能骗过 head/tail。
#
# ---- 输出 ----
#   stdout：结论行 + 供学生排错的详情（nonce 前缀会被剥掉，不干扰阅读）
#   <outfile>：只写结论行一行（供 Makefile 汇总进 RUNLOG / trace 提交信息）
#
# ---- 语言插件可用的环境变量 ----
#   JUDGE_NONCE   当次运行的 nonce；由 core/engine.mk 生成并导出
#   JUDGE_STRICT  1=只认带 nonce 的协议行（学生解与判分端共享输出通道的语言必须置 1）
#   RE_PATTERN    命中即判 RE 的 grep -E 正则（如 C 的 sanitizer 报告）
#   RE_LABEL      上述情形的判罚说明（如 "内存越界 / 未定义行为"）
#   RE_HEAD       上述情形打印日志的行数（默认 25）
#   MISMATCH_HEAD WA 时最多打印几条失配样例（默认 10）
#   TIMEOUT       单次运行时限（秒），只用于 TLE 提示文案
#
# 上面这些都由 core/engine.mk 的 export 送进来（见那里的 export 行）——
# 在这里加一个新变量，记得同时加到那一行，否则它在 make 层设了也传不进来。
set -u

pid="${1:-unknown}"
log="${2:-}"
rc="${3:-0}"
out="${4:-/dev/null}"

JUDGE_NONCE="${JUDGE_NONCE:-}"
JUDGE_STRICT="${JUDGE_STRICT:-0}"
RE_PATTERN="${RE_PATTERN:-}"
RE_LABEL="${RE_LABEL:-}"
RE_HEAD="${RE_HEAD:-25}"
MISMATCH_HEAD="${MISMATCH_HEAD:-10}"
TIMEOUT="${TIMEOUT:-}"

[ -n "$log" ] || { echo "verdict.sh: 缺少运行日志参数" >&2; exit 2; }
[ -f "$log" ] || : > "$log"

# 结论行：既打给学生看，也写进 $out 供 Makefile 汇总。
emit() {
    printf '%s\n' "$1"
    printf '%s\n' "$1" > "$out"
}

# ---- 协议来源：由 JUDGE_STRICT 决定，不做"空了就退回运行日志"的退化 ----
# JUDGE_STRICT=1 的语言（学生解与判分端共享 stdout，如 C 函数题）只认独立通道
# $PROTO_LOG。曾经写成"proto.log 为空就退回读 run.log"，这是个可利用的后门：
# 学生解从 /proc/self/cmdline 偷到 nonce，往 stdout 打一行签名过的 JUDGE: PASS，
# 再 exit(0) 让 harness 没机会往 fd 3 写任何东西 —— 通道为空，退化生效，
# 伪造判罚被采信，全错的解判成 AC（实测复现过）。
# 通道为空的正确含义是"harness 没跑到底"，即 RE，绝不能去学生能写的地方找结论。
#
# JUDGE_STRICT=0 的语言（学生解无法产生任何输出，如只准 assign 的纯组合逻辑
# Verilog）沿用运行日志，此时 tb 输出的裸协议行就在 run.log 里。
PROTO_LOG="${PROTO_LOG:-}"
if [ "$JUDGE_STRICT" = "1" ]; then
    if [ -z "$PROTO_LOG" ]; then
        emit "[$pid] RE (Run Error：JUDGE_STRICT=1 却未配置 PROTO_LOG 协议通道)"
        echo "---- 这是判分平台自身的配置错误，请联系判分端维护者 ----"
        exit 0
    fi
    [ -f "$PROTO_LOG" ] || : > "$PROTO_LOG"
    proto_src="$PROTO_LOG"
else
    proto_src="$log"
fi

# ---- 行尾归一化（CRLF -> LF）----
# Windows 原生工具链（winget 装的 iverilog/vvp.exe、MSYS2 的 gcc 等）写出来的是
# CRLF。本脚本的协议正则带 $ 锚定，"JUDGE: FAIL 512\r" 会一行都匹配不上，
# 结果每道题都退化成 RE —— 连本该 AC 的解也是。故先归一化再解析。
# 原始日志不动（学生要能对着 build/run.log 排错），只在副本上做匹配与展示。
norm="$(mktemp)"          # 运行日志（诊断、RE_PATTERN）
pnorm="$(mktemp)"         # 协议来源（判罚字段）
trap 'rm -f "$norm" "$pnorm"' EXIT
tr -d '\r' < "$log" > "$norm"
tr -d '\r' < "$proto_src" > "$pnorm"

# ---- 协议行的前缀 ----
# 严格模式：必须带当次 nonce，学生解伪造的裸协议行一概不认。
# 宽松模式：裸协议行即可（学生解无法产生任何输出的语言，如纯组合逻辑 Verilog）。
if [ "$JUDGE_STRICT" = "1" ]; then
    if [ -z "$JUDGE_NONCE" ]; then
        emit "[$pid] RE (Run Error：判分端未生成 nonce，JUDGE_STRICT=1 却缺少 JUDGE_NONCE)"
        echo "---- 这是判分平台自身的配置错误，请联系判分端维护者 ----"
        exit 0
    fi
    prefix="$JUDGE_NONCE "
else
    prefix=""
fi

# grep -E 用的转义后前缀（nonce 是十六进制，实际不含元字符；此处只为稳妥）
esc_prefix="$(printf '%s' "$prefix" | sed 's/[][\.^$*+?(){}|/\\]/\\&/g')"

# 取协议字段：只看带正确前缀的行，并剥掉前缀
proto() { grep -E "^${esc_prefix}$1" "$pnorm" | sed "s/^${esc_prefix}//"; }

# ---- 判罚行必须恰好一行 ----
# 合法的 harness / 对拍器只输出一行结论。多于一行说明协议通道被写脏了：
# 要么运行端有 bug，要么学生解设法挤进了协议通道（例如从 /proc/self/cmdline
# 偷到 nonce，再用 __attribute__((destructor)) 在 harness 之后补一行 PASS）。
# 此时既不能取第一行也不能取最后一行 —— 两种顺序都能被针对性利用 —— 一律判 RE。
nverdict="$(proto 'JUDGE: (PASS|FAIL [0-9]+)$' | wc -l | tr -d ' ')"
if [ "$nverdict" -gt 1 ]; then
    emit "[$pid] RE (Run Error：判分通道出现 $nverdict 行判罚，疑似被篡改)"
    echo "---- 判分端提示 ----"
    echo "一次运行只应产生一行 JUDGE: 结论。出现多行意味着判分通道被写入了额外内容，"
    echo "本次判罚作废。若你确实没有往判分通道写东西，请把 build/ 目录留存并联系判分端维护者。"
    echo "---- 协议通道内容 ----"
    sed -n '1,20p' "$pnorm"
    exit 0
fi

verdict="$(proto 'JUDGE: (PASS|FAIL [0-9]+)$' | tail -n1)"
ntests="$(proto 'JUDGE-COUNT:' | tail -n1 | sed 's/^JUDGE-COUNT:[[:space:]]*//')"

# ---- TLE：timeout 的 124/137，或运行端自报的 JUDGE-TLE ----
if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ] || [ -n "$(proto 'JUDGE-TLE:')" ]; then
    if [ -n "$TIMEOUT" ]; then
        emit "[$pid] TLE (Time Limit Exceeded, 单次运行上限 ${TIMEOUT}s)"
    else
        emit "[$pid] TLE (Time Limit Exceeded)"
    fi
    echo "---- 超时前的输出 ----"
    sed -n '1,10p' "$norm"
    exit 0
fi

# ---- 语言插件自定义的 RE（如 sanitizer 报告）----
# 注意：这里刻意不加 nonce 前缀 —— sanitizer 报告是工具链写到 stderr 的，
# 不是判分协议的一部分，运行端无法给它加前缀。误判风险由 RE_PATTERN 自身的
# 特异性兜住（学生解就算原样打印这段文本，判成 RE 也只是自伤，不能骗到 AC）。
if [ -n "$RE_PATTERN" ] && grep -qE "$RE_PATTERN" "$norm"; then
    emit "[$pid] RE (Run Error${RE_LABEL:+：$RE_LABEL})"
    echo "---- 运行时诊断 ----"
    sed -n "1,${RE_HEAD}p" "$norm"
    exit 0
fi

# ---- 通用 RE：非零退出，或协议字段缺失 ----
# 协议字段缺失覆盖两种情形：tb / harness 没跑到底，以及学生解提前退出
# （伪造判罚的典型手法）—— 后者在严格模式下必然落到这里，因为它拿不到 nonce。
if [ "$rc" -ne 0 ] || [ -z "$verdict" ] || [ -z "$ntests" ]; then
    emit "[$pid] RE (Run Error)"
    echo "---- 运行输出（退出码 $rc）----"
    sed -n '1,20p' "$norm"
    if [ "$JUDGE_STRICT" = "1" ] && [ -z "$verdict" ] \
       && grep -qE '^[[:space:]]*JUDGE: (PASS|FAIL [0-9]+)$' "$norm"; then
        echo "---- 判分端提示 ----"
        echo "日志里出现了未经判分端签名的 JUDGE 行：判分协议由判分端 harness 输出，"
        echo "学生解自行打印 JUDGE 行不会被采信。若你的解提前 exit，harness 就来不及给出结论。"
    fi
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
# 截断到 MISMATCH_HEAD 行：现有的 harness / tb / 对拍器都只在第一次失配时输出一行
# （各自 err==1 判断），但协议允许多行，判分端不该指望每个出题人都自觉。
# 一道穷举题全错就是上万行，直接冲掉终端里学生真正要看的那行判罚。
mm_total="$(proto 'JUDGE-MISMATCH:' | wc -l | tr -d ' ')"
proto 'JUDGE-MISMATCH:' | sed -n "1,${MISMATCH_HEAD}p"
if [ "$mm_total" -gt "$MISMATCH_HEAD" ]; then
    echo "…（共 $mm_total 条失配样例，只显示前 $MISMATCH_HEAD 条；"
    echo "   完整内容见 $proto_src，或 make sim MISMATCH_HEAD=50）"
fi
exit 0
