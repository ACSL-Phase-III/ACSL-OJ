#!/usr/bin/env bash
# core/judge/promote.sh —— 把刚判出 AC 的题目从待做区移入 done/
#
# 用法：promote.sh <done目录> <待做目录1> [待做目录2 ...]
#
# 判据只有一条：该题 build/verdict.txt 的首行是 "[<题号>] AC (...)"。
# 这个文件由 core/judge/verdict.sh 写，学生改不了判分链路，但**能**手改这个文件
# —— 所以它只用来决定"要不要挪目录"，不作为成绩依据。成绩看 trace 分支的留痕，
# 那里记的是每次判分的完整产物，且由 core/judge/trace.sh 单向追加。
#
# 移动优先用 git mv：作答区是要提交的，用 git mv 让历史跟着文件走，
# 学生 git log --follow 还能看到自己这道题的全过程。目录没被 git 跟踪时退化成 mv。

set -uo pipefail

done_dir="${1:?用法: promote.sh <done目录> <待做目录...>}"
shift || true

moved=0
for d in "$@"; do
  [ -d "$d" ] || continue
  pid="$(basename "$d")"
  v="$d/build/verdict.txt"
  [ -f "$v" ] || continue

  # 只认首行，且必须是本题的 AC —— 防止把汇总日志或别的题的结论读成自己的
  if ! head -n1 "$v" | grep -q "^\[$pid\] AC "; then
    continue
  fi

  mkdir -p "$done_dir"
  if [ -e "$done_dir/$pid" ]; then
    echo "  !! $pid 已 AC，但 $done_dir/$pid 已存在，未移动（请手动处理其中一份）"
    continue
  fi

  if git ls-files --error-unmatch "$d" >/dev/null 2>&1; then
    git mv "$d" "$done_dir/$pid" 2>/dev/null || mv "$d" "$done_dir/$pid"
  else
    mv "$d" "$done_dir/$pid"
  fi
  echo "  ✓ $pid 已通过，移入 $done_dir/"
  moved=$((moved + 1))
done

if [ "$moved" -gt 0 ]; then
  echo "  （共移入 $moved 题。要重做某一题：make reopen PID=<题号>）"
fi
exit 0
