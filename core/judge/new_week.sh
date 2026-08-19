#!/usr/bin/env bash
# new_week.sh <ROOT> <WEEK> <PROBLEMS> [STAGED]
#
# 在 work/ 下建一周的脚手架 Makefile。平台按「include 了 week.mk」认一周，
# 不必登记到别处；学生 git pull 拿到这个文件，make take 就能取到本周题目。
#
#   STAGED=0（默认，平铺）  work/<周>/Makefile
#   STAGED=1（分拣）        work/<周>/problem/Makefile
#
# 不覆盖已有 Makefile。题号必须已在 langs/*/problems/<题号>/ 里。
set -euo pipefail

root="${1:?用法: new_week.sh <ROOT> <WEEK> <PROBLEMS> [STAGED]}"
week="${2:?}"
problems="${3:?}"
staged="${4:-0}"

cd "$root"

case "$week" in
  ''|.*|*/*|*..*)
    echo "new-week: 周名不合法（$week）。用 week2 这种单层目录名。" >&2
    exit 1
    ;;
esac
case "$staged" in
  0|1) ;;
  *) echo "new-week: STAGED 只能是 0（平铺）或 1（分拣），当前：$staged" >&2; exit 1 ;;
esac

missing=0
for p in $problems; do
  hits="$(ls -d langs/*/problems/"$p"/Makefile 2>/dev/null || true)"
  if [ -z "$hits" ]; then
    echo "new-week: 题库里没有 $p（langs/*/problems/$p/）。先把题目建好再开周。" >&2
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  echo "现有题号：ls langs/*/problems/" >&2
  exit 1
fi

if [ "$staged" = 1 ]; then
  dest="work/$week/problem/Makefile"
  rel_core="../../../core"
  layout="分拣（problem_set/ + done/）"
else
  dest="work/$week/Makefile"
  rel_core="../../core"
  layout="平铺"
fi

if [ -e "$dest" ]; then
  echo "new-week: $dest 已存在，不覆盖。"
  echo "          要改题目列表就直接编辑 PROBLEMS 那一行。"
  exit 1
fi

mkdir -p "$(dirname "$dest")"

{
  printf '%s\n' "# work/$week 作答区（$layout）"
  printf '%s\n' "#"
  printf '%s\n' "# 学生：make take 取模板，make sim 判分。本文件随 git pull 发放，请勿改。"
  printf '%s\n' "# 教师：改 PROBLEMS 即可增删本周题目；题号必须是 langs/*/problems/ 下的目录名。"
  printf '%s\n' ""
  printf '%s\n' "WEEK     := $week"
  printf '%s\n' "PROBLEMS := $problems"
  printf '%s\n' "STAGED   := $staged"
  printf '%s\n' ""
  printf '%s\n' "WORK := $rel_core"
  printf '%s\n' "include \$(WORK)/week.mk"
} > "$dest"

echo "已建 $dest（$layout）"
echo "    周名 $week"
echo "    题目 $problems"
echo ""
echo "学生 git pull 之后："
echo "    make take          # 取本周模板"
echo "    make -C work/$week sim"
echo ""
echo "还没发布到学生能拉的分支。写完题、自测通过后："
echo "    make release"
