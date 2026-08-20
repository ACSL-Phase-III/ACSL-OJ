#!/usr/bin/env bash
# traces.sh <remote> [stuid]
#
# 教师收痕：从公开仓抓 refs/heads/trace/*，列出全班或看某一个学号。
# 学生不要跑这个，也不要为此新建 / fork 仓库。
#
#   make traces                 列出公开仓上所有 trace/<学号>
#   make traces STUID=2023xxxx  只看这一个人的判分历史
set -euo pipefail

remote="${1:-public}"
stuid="${2:-}"
[ "$stuid" = "000000" ] && stuid=""
[ "$stuid" = "未填写" ] && stuid=""

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "traces: 请在 ACSL-OJ 仓库根目录跑。" >&2
  exit 1
fi

if ! git remote get-url "$remote" >/dev/null 2>&1; then
  echo "traces: 没有 remote「$remote」。教师先： make teacher-remotes" >&2
  echo "        本机应是 origin=私有 DEV，public=公开 ACSL-OJ。" >&2
  exit 1
fi

url="$(git remote get-url "$remote")"
echo "===== 抓取 $remote 上的 trace/* ====="
echo "    $url"

# 只更新 remotes/<public>/trace/*，不动本地分支、不动 main。
# + 允许快进以外的更新（学生重做 init 时偶发）；--prune 去掉已删的学号。
if ! git fetch --prune "$remote" '+refs/heads/trace/*:refs/remotes/'"$remote"'/trace/*'; then
  echo "traces: fetch 失败。确认本机对公开仓有读权限。" >&2
  exit 1
fi
echo

if [ -n "$stuid" ]; then
  ref="refs/remotes/$remote/trace/$stuid"
  if ! git rev-parse -q --verify "$ref" >/dev/null; then
    echo "公开仓还没有 trace/$stuid。"
    echo "学生需要：clone 公开仓（不要自己建仓库）→ 填 student.mk → make init → make sim。"
    echo "若他本机 AC 了但这里没有，是 push 失败（没登录，或公开仓没给他写权限）。"
    exit 1
  fi
  echo "===== $remote/trace/$stuid ====="
  git log --oneline "$ref"
  exit 0
fi

n="$(git for-each-ref --format='%(refname)' "refs/remotes/$remote/trace" | wc -l | tr -d ' ')"
if [ "$n" = "0" ]; then
  echo "公开仓上还没有任何 trace/<学号>。"
  echo "先把学生加成公开仓的 write（不要让他们 fork），并保护 main 不被学生推。"
  exit 0
fi

echo "===== 公开仓上的学生留痕（$n 人）====="
git for-each-ref --sort=committerdate \
  --format='%(align:14,right)%(committerdate:relative)%(end)  %(refname:short)  %(subject)' \
  "refs/remotes/$remote/trace"
echo
echo "看一个人： make traces STUID=学号"
