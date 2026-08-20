#!/usr/bin/env bash
# teacher_remotes.sh <ROOT> [TEA_URL] [PUBLIC_URL]
#
# 把本机 remote 收成方案 1：
#   origin  → 私有 ACSL-OJ-DEV（教师源码，学生进不去）
#   public  → 公开 ACSL-OJ（只收 make release 写好的 main）
#
# 用法：
#   make teacher-remotes
#   make teacher-remotes TEA=git@github.com:ACSL-Phase-III/ACSL-OJ-DEV.git
set -euo pipefail

root="${1:?}"
cd "$root"

tea_url="${2:-${TEA:-git@github.com:ACSL-Phase-III/ACSL-OJ-DEV.git}}"
public_url="${3:-${PUBLIC:-git@github.com:ACSL-Phase-III/ACSL-OJ.git}}"

is_public() { printf '%s' "$1" | grep -Eq 'ACSL-OJ(\.git)?$'; }
is_dev()    { printf '%s' "$1" | grep -Fq 'ACSL-OJ-DEV'; }

has_remote() { git remote get-url "$1" >/dev/null 2>&1; }

origin_url=""
if has_remote origin; then
  origin_url="$(git remote get-url origin)"
fi

if [ -n "$origin_url" ] && is_public "$origin_url" && ! is_dev "$origin_url"; then
  if has_remote public; then
    git remote set-url public "$public_url"
    git remote set-url origin "$tea_url"
    echo "origin 原来指向公开仓，已改成 DEV；$public 指向公开 ACSL-OJ。"
  else
    git remote rename origin public
    git remote add origin "$tea_url"
    echo "已把原来的 origin 改名为 public（公开 ACSL-OJ），origin 现在是 DEV。"
  fi
else
  if ! has_remote origin; then
    git remote add origin "$tea_url"
    echo "已添加 origin → $tea_url"
  elif ! is_dev "$origin_url"; then
    echo "origin 现在是：$origin_url"
    echo "若这不是私有 DEV，请手动： git remote set-url origin $tea_url"
  else
    echo "origin 已是 DEV：$origin_url"
  fi
  if has_remote public; then
    git remote set-url public "$public_url"
  else
    git remote add public "$public_url"
    echo "已添加 public → $public_url"
  fi
fi

echo ""
echo "当前 remotes："
git remote -v
echo ""
echo "接下来："
echo "    git push -u origin HEAD          # 教师源码进私有 ACSL-OJ-DEV"
echo "    make release                     # 本机编二进制、写本地 main"
echo "    git push public main             # 只把学生快照推到公开仓"
echo ""
echo "学生永远 clone / pull 公开仓 ACSL-OJ 的 main，进不去 DEV。"
