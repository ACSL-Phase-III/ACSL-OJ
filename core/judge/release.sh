#!/usr/bin/env bash
# release.sh <ROOT> [student-branch]
#
# 把当前工作树编成「学生可见快照」写到学生分支上。
# 不切分支、不改工作区文件 —— 和 trace.sh 同一条原则：切走就回不来，
# 学生 git pull 取新周作业的用法会断。
#
# 教师分支留下黄金模型源码（harness.c / check.c）；学生分支只留编译产物
# （harness.o / check / gen）。学生 git pull 拿到新周 + 判分件，cat 不到 gold_gcd。
#
# 用法（在仓库根、教师分支上；方案 1 = 私有 DEV + 公开 ACSL-OJ）：
#   make teacher-remotes          第一次：origin=DEV，public=公开仓
#   make release                  写快照到本地 main，不 push
#   make release PUSH=1           写完再 git push public main
#   make release DRY=1            只编、只检查，不写分支
#   make release BRANCH=class     学生拉的不是 main 时改这个
#
# 环境变量：
#   RELEASE_BRANCH / BRANCH  学生拉取的分支，默认 main
#   PUBLIC_REMOTE            公开仓 remote 名，默认 public
#   PUSH                     1=写完后 push 到 PUBLIC_REMOTE（默认 0）
#   DRY                      1=不写分支（默认 0）
#   VERIFY                   full=再跑一遍 make sim-langs（题库模板是空 TODO，
#                            预期 WA，只用来抓 CE / 平台挂掉；默认不做）
set -euo pipefail

root="${1:?用法: release.sh <ROOT> [student-branch]}"
branch="${2:-${BRANCH:-${RELEASE_BRANCH:-main}}}"
push="${PUSH:-0}"
dry="${DRY:-0}"
verify="${VERIFY:-}"
public_remote="${PUBLIC_REMOTE:-public}"

cd "$root"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "release: 这里不是 git 仓库，没法写学生分支。" >&2
  exit 1
fi

git_root="$(git rev-parse --show-toplevel)"
if [ "$(cd "$git_root" && pwd -P)" != "$(pwd -P)" ]; then
  echo "release: 请在仓库根目录跑（make release），现在在 $(pwd)" >&2
  exit 1
fi

head="$(git rev-parse --abbrev-ref HEAD)"
if [ "$head" = "HEAD" ]; then
  echo "release: 当前是 detached HEAD，请先落到教师分支（git checkout -B teacher）。" >&2
  exit 1
fi

if [ "$head" = "$branch" ]; then
  echo "release: 当前就在学生分支 $branch 上。不能在这条分支上发 —— 下一步" >&2
  echo "         git commit 会把黄金模型源码再提交回去。" >&2
  echo "" >&2
  echo "第一次（只需一次）：" >&2
  echo "    git checkout -B teacher" >&2
  echo "    make release" >&2
  echo "    git push $public_remote $branch     # 只推公开仓的学生分支" >&2
  exit 1
fi

# 已经是学生快照的工作树（没有黄金模型源码）不能再发一遍：
# 再发只会把「没有源码」当成教师树， concealing 无从谈起，也编不出新 .o。
has_source=0
for f in langs/*/problems/*/test/harness.c \
         langs/*/problems/*/test/check.c \
         langs/*/problems/*/test/gen.c; do
  if [ -f "$f" ]; then has_source=1; break; fi
done
if [ "$has_source" -eq 0 ]; then
  echo "release: 当前工作树里没有判分端源码（harness.c / check.c）。" >&2
  echo "         这已经是学生可见快照。请到教师分支上做 release。" >&2
  echo "             git checkout teacher" >&2
  exit 1
fi

echo "===== 1/4  编译判分件（make artifacts）====="
make --no-print-directory artifacts

echo ""
echo "===== 2/4  链接自检（确认 .o 能和学生解链到一起）====="
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
link_fail=0
link_n=0
for mk in langs/*/problems/*/Makefile; do
  [ -f "$mk" ] || continue
  dir="$(dirname "$mk")"
  # 只对已经切到二进制发放的 func 题做链接检查。
  name="$(make -s --no-print-directory -C "$dir" print-HARNESS_NAME 2>/dev/null || true)"
  case "$name" in
    *.o) ;;
    *) continue ;;
  esac
  harness="$(make -s --no-print-directory -C "$dir" print-HARNESS)"
  src="$(make -s --no-print-directory -C "$dir" print-SRC)"
  cflags="$(make -s --no-print-directory -C "$dir" print-CFLAGS)"
  ldlibs="$(make -s --no-print-directory -C "$dir" print-LDLIBS)"
  if [ ! -f "$dir/$harness" ]; then
    echo "  [FAIL] $dir 声明了 HARNESS_NAME=$name，但 $dir/$harness 不存在" >&2
    link_fail=1
    continue
  fi
  if [ ! -f "$dir/$src" ]; then
    echo "  [FAIL] $dir 缺少作答模板 $src" >&2
    link_fail=1
    continue
  fi
  link_n=$((link_n + 1))
  # 故意带上题目自己的 CFLAGS（含 asan）：这就是学生 make sim 的链接行。
  # 拆开读进数组，避免路径里的空格；CFLAGS 本身没有空格以外的特殊字符。
  # shellcheck disable=SC2086
  if gcc $cflags -o "$tmp/linktest" "$dir/$harness" "$dir/$src" $ldlibs 2>"$tmp/link.err"; then
    echo "  [ok]   $dir  + $harness"
  else
    echo "  [FAIL] $dir 链接失败（学生 make sim 会 CE）：" >&2
    sed -n '1,20p' "$tmp/link.err" | sed 's/^/         /' >&2
    link_fail=1
  fi
done
if [ "$link_n" -eq 0 ]; then
  echo "  （没有 HARNESS_NAME := harness.o 的题目，跳过链接自检）"
fi
if [ "$link_fail" -ne 0 ]; then
  echo "release: 链接自检未通过，学生分支未改动。" >&2
  exit 1
fi

# session 二进制：存在但没有 +x 时学生机器上会报"没有可执行位"。
for exe in langs/*/problems/*/test/check langs/*/problems/*/test/gen; do
  [ -f "$exe" ] || continue
  case "$exe" in
    *.c|*.py) continue ;;
  esac
  chmod +x "$exe"
done

if [ "$verify" = "full" ]; then
  echo ""
  echo "===== 2b  VERIFY=full：make sim-langs（模板是空 TODO，预期 WA）====="
  make --no-print-directory sim-langs AUTOPUSH=0
fi

if [ "$dry" = "1" ]; then
  echo ""
  echo "===== DRY=1：下面这些源码会从学生快照里拿掉 ====="
  for f in langs/*/problems/*/test/harness.c \
           langs/*/problems/*/test/check.c \
           langs/*/problems/*/test/check.py \
           langs/*/problems/*/test/gen.c \
           langs/*/problems/*/test/gen.py \
           langs/*/problems/*/test/ref.c; do
    [ -f "$f" ] || continue
    echo "  - $f"
  done
  echo "学生快照会带上："
  for f in langs/*/problems/*/test/harness.o \
           langs/*/problems/*/test/check \
           langs/*/problems/*/test/gen; do
    [ -f "$f" ] || continue
    case "$f" in *.c|*.py) continue ;; esac
    echo "  + $f"
  done
  echo ""
  echo "DRY=1，学生分支 $branch 未改动。"
  exit 0
fi

echo ""
echo "===== 3/4  写学生快照到 $branch（不切分支）====="

# 父提交：优先公开仓 public/main，保证推给学生那边能快进。
# origin 在方案 1 里是私有 DEV，不能拿 DEV 的 main 当学生快照的父提交。
parent=""
fetch_parent() {
  local r="$1"
  git remote get-url "$r" >/dev/null 2>&1 || return 1
  git fetch --quiet "$r" "$branch" 2>/dev/null || true
  if git rev-parse --verify -q "$r/$branch" >/dev/null; then
    parent="$(git rev-parse "$r/$branch")"
    return 0
  fi
  return 1
}
if ! fetch_parent "$public_remote"; then
  if git rev-parse --verify -q "$branch" >/dev/null; then
    parent="$(git rev-parse "$branch")"
  fi
fi

tmpindex="$(mktemp)"
rm -f "$tmpindex"   # mktemp 留下的空文件不能当 git index，删掉让 git 自己建
# 退出时连同上面的 $tmp 一起清。覆盖 trap。
trap 'rm -rf "$tmp" "$tmpindex"' EXIT
export GIT_INDEX_FILE="$tmpindex"

# 从空索引收工作树：尊重 .gitignore（学生作答、student.mk、build/ 都不会进去）。
git add -A

# 判分件有时还没被跟踪（刚编出来），强制收进快照。
for f in langs/*/problems/*/test/harness.o \
         langs/*/problems/*/test/check \
         langs/*/problems/*/test/gen; do
  [ -f "$f" ] || continue
  case "$f" in *.c|*.py) continue ;; esac
  git add -f -- "$f"
done

stripped=0
kept_src=0

# harness.c：有对应 .o 才拿掉，否则这题还在发源码，留着并警告。
while IFS= read -r -d '' f; do
  obj="${f%.c}.o"
  if git ls-files --error-unmatch -- "$obj" >/dev/null 2>&1; then
    git rm --cached -f --quiet -- "$f"
    stripped=$((stripped + 1))
  else
    echo "  警告: $f 没有对应的 .o，仍会发给学生（题目 Makefile 写 HARNESS_NAME := harness.o 再 make artifacts）"
    kept_src=$((kept_src + 1))
  fi
done < <(git ls-files -z -- 'langs/*/problems/*/test/harness.c')

# check.c / check.py：有同目录的预编译 check 才拿掉。
while IFS= read -r -d '' f; do
  dir="$(dirname "$f")"
  if git ls-files --error-unmatch -- "$dir/check" >/dev/null 2>&1; then
    git rm --cached -f --quiet -- "$f"
    stripped=$((stripped + 1))
  else
    echo "  警告: $f 没有对应的预编译 check，仍会发给学生"
    kept_src=$((kept_src + 1))
  fi
done < <(git ls-files -z -- 'langs/*/problems/*/test/check.c' 'langs/*/problems/*/test/check.py')

# gen.c / gen.py：同上。
while IFS= read -r -d '' f; do
  dir="$(dirname "$f")"
  if git ls-files --error-unmatch -- "$dir/gen" >/dev/null 2>&1; then
    git rm --cached -f --quiet -- "$f"
    stripped=$((stripped + 1))
  else
    echo "  警告: $f 没有对应的预编译 gen，仍会发给学生"
    kept_src=$((kept_src + 1))
  fi
done < <(git ls-files -z -- 'langs/*/problems/*/test/gen.c' 'langs/*/problems/*/test/gen.py')

# io 模式的参考解：不参与判分，发给学生就是一份能抄的完整程序。
while IFS= read -r -d '' f; do
  git rm --cached -f --quiet -- "$f"
  stripped=$((stripped + 1))
done < <(git ls-files -z -- 'langs/*/problems/*/test/ref.c')

# 必带的产物：func 题声明了 harness.o 就必须在快照里。
missing=0
for mk in langs/*/problems/*/Makefile; do
  [ -f "$mk" ] || continue
  dir="$(dirname "$mk")"
  name="$(make -s --no-print-directory -C "$dir" print-HARNESS_NAME 2>/dev/null || true)"
  case "$name" in
    *.o)
      rel="$dir/$name"
      # HARNESS_NAME 不含目录时实际路径是 test/<name>
      if [ "$name" = "$(basename "$name")" ]; then
        rel="$dir/test/$name"
      fi
      if ! git ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
        echo "release: 快照里缺少 $rel（$dir 的 HARNESS_NAME := $name）" >&2
        missing=1
      fi
      ;;
  esac
done
if [ "$missing" -ne 0 ]; then
  echo "release: 学生快照不完整，分支未改动。" >&2
  exit 1
fi

tree="$(git write-tree)"
plat="$(uname -s)/$(uname -m)"
msg="$(printf '%s\n\n%s\n%s\n%s\n' \
  "release: 学生可见快照 ($(date '+%Y-%m-%d %H:%M:%S'))" \
  "- 平台 $plat；func/session 判分件已编译，黄金模型源码未纳入" \
  "- 教师分支 $head 仍保留源码；学生拉 $branch 即可" \
  "- 去掉源码 $stripped 个，仍按源码发放 $kept_src 个")"

if [ -n "$parent" ]; then
  # 树与父提交完全一样就不必再写一个空发布。
  if [ "$tree" = "$(git rev-parse "$parent^{tree}")" ]; then
    echo "学生分支 $branch 已是这份快照，无需新提交。"
    commit="$(git rev-parse "$parent")"
  else
    commit="$(git commit-tree "$tree" -p "$parent" -m "$msg")"
  fi
else
  # 本地还没有这条学生分支：orphan 第一笔。
  commit="$(git commit-tree "$tree" -m "$msg")"
fi

git update-ref "refs/heads/$branch" "$commit"
echo "  $branch -> $(git rev-parse --short "$commit")  （工作区仍在 $head，源码都在）"

# 另一个 worktree 正 checkout 着学生分支时，update-ref 会让那边变成
# "当前提交被移走了"。说清楚，别让人以为仓库坏了。
if git worktree list --porcelain 2>/dev/null | awk -v b="refs/heads/$branch" '
  $1=="branch" && $2==b { found=1 }
  END { exit found?0:1 }
'; then
  echo "  注意：$branch 还在另一个 worktree 里被 checkout。"
  echo "        那边请 git reset --keep $commit 才能看到这份快照。"
fi

echo ""
echo "===== 4/4  下一步 ====="
echo "教师源码 → 私有 DEV（origin）；学生快照 → 公开仓（$public_remote）。"
echo "    git add -A && git commit -m 'weekN: …'"
echo "    git push origin HEAD                 # 源码进 DEV，学生进不去"
echo "    git push $public_remote $branch      # 只有二进制的快照进公开仓"
if [ "$push" = "1" ]; then
  if ! git remote get-url "$public_remote" >/dev/null 2>&1; then
    echo "release: 没有 remote「$public_remote」。先跑： make teacher-remotes" >&2
    exit 1
  fi
  echo ""
  echo "PUSH=1：正在 push $public_remote $branch …"
  git push "$public_remote" "$branch"
  echo "已推送 $public_remote $branch。教师分支 $head 没有推到公开仓。"
else
  echo ""
  echo "本次没有 push。学生现在还拉不到。确认快照后："
  echo "    git push $public_remote $branch"
  echo "或   make release PUSH=1"
  echo "还没配 remote 就先： make teacher-remotes"
fi

echo ""
echo "学生："
echo "    git pull"
echo "    make take"
echo "    make sim"
