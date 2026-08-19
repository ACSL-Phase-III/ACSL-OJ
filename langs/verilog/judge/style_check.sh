#!/usr/bin/env bash
# style_check.sh <student.v>
# 学生解风格检查：只允许数据流建模（连续赋值）。
# 命中任一禁止语法（关键字、# 延时、疑似实例化）→ 退出码 1 并输出原因；
# 通过 → 退出码 0，无输出。
set -u

usage() { echo "usage: $0 <student.v>" >&2; exit 2; }

[ $# -eq 1 ] || usage
f="$1"
[ -f "$f" ] || { echo "style_check: 无法读取文件 $f" >&2; exit 2; }

# ---- 步骤 1：剥离注释（先 /* */ 可跨行，再 //），避免注释里的关键词误伤 ----
stripped="$(awk '
  BEGIN { inblock = 0 }
  {
    line = $0
    res = ""
    n = length(line)
    i = 1
    while (i <= n) {
      c = substr(line, i, 1)
      if (inblock) {
        if (c == "*" && i < n && substr(line, i + 1, 1) == "/") { inblock = 0; i += 2; continue }
        i++
        continue
      }
      if (c == "/" && i < n) {
        c2 = substr(line, i + 1, 1)
        if (c2 == "/") { i = n + 1; continue }      # 行注释：跳过整行
        if (c2 == "*") { inblock = 1; i += 2; continue }  # 块注释开始
      }
      res = res c
      i++
    }
    print res
  }
' "$f")"

viol="no"

# ---- 检查 1：禁止关键字 ----
kw="$(printf '%s\n' "$stripped" | grep -wnE 'always|initial|for|while|repeat|forever|task|function')"
if [ -n "$kw" ]; then
    echo "STYLE: 命中禁止关键字（本题只允许用 assign 连续赋值描述组合逻辑）："
    echo "$kw"
    viol="yes"
fi

# ---- 检查 2：# 延时 ----
hashline="$(printf '%s\n' "$stripped" | grep -n '#')"
if [ -n "$hashline" ]; then
    echo "STYLE: 命中禁止的 # 延时（本题为纯组合逻辑，不允许延时控制）："
    echo "$hashline"
    viol="yes"
fi

# ---- 检查 3：疑似模块/门实例化（启发式正则，已排除注释行与模块声明行）----
# 形如 "模块名  实例名  (" 的行视为实例化；module 声明行不算。
inst="$(printf '%s\n' "$stripped" \
    | grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(' \
    | grep -vE '^[0-9]+:[[:space:]]*module[[:space:]]')"
if [ -n "$inst" ]; then
    echo "STYLE: 疑似模块/门实例化（本题不允许任何实例化，请用连续赋值实现）："
    echo "$inst"
    viol="yes"
fi

if [ "$viol" = "yes" ]; then
    echo "提示：本题只能用 module/端口声明、logic|wire、assign、运算符、注释。"
    exit 1
fi
exit 0