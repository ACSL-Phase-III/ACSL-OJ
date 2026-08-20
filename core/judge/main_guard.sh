#!/usr/bin/env bash
# main_guard.sh —— 学生分支上不许出现黄金模型 / 检查器源码
#
# 给 GitHub Actions 用：push 到 main 后跑一遍。出现下列文件即失败，
# 避免有人把教师树误推进学生能拉的分支。
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

hits="$(find langs -type f \( \
    -path 'langs/*/problems/*/test/harness.c' -o \
    -path 'langs/*/problems/*/test/check.c' -o \
    -path 'langs/*/problems/*/test/check.py' -o \
    -path 'langs/*/problems/*/test/gen.c' -o \
    -path 'langs/*/problems/*/test/gen.py' -o \
    -path 'langs/*/problems/*/test/ref.c' \
  \) 2>/dev/null || true)"

# func 模拟器的 spec.py 是黄金模型（同目录有 harness.c / harness.o）。
# blackbox 题没有 harness，spec.py 就是运行器要调的检查器，学生分支上该留。
spec_hits=""
while IFS= read -r -d '' f; do
  dir="$(dirname "$f")"
  if [ -f "$dir/harness.c" ] || [ -f "$dir/harness.o" ]; then
    spec_hits="$spec_hits$f
"
  fi
done < <(find langs -type f -path 'langs/*/problems/*/test/spec.py' -print0 2>/dev/null || true)
if [ -n "$spec_hits" ]; then
  hits="$hits
$spec_hits"
fi

if [ -n "$hits" ]; then
    echo "main-guard: 学生分支上出现了判分端源码（这些不该发给学生）：" >&2
    printf '%s\n' "$hits" | sed 's/^/  /' >&2
    echo "应只保留 test/harness.o、test/check、test/gen 和 cases/*.in。" >&2
    exit 1
fi

echo "main-guard: 未发现判分端源码，OK。"
