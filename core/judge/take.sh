#!/usr/bin/env bash
# core/judge/take.sh —— 把一道题的作答模板取到作答区
#
# 用法：take.sh <ROOT> <待做目录> <题号> [done目录] [周名]
#
# 做三件事：
#   1. 在 langs/*/problems/<题号>/ 找到题目（语言自动判定）
#   2. 把**作答模板**（$(SRC)，即 <MODULE><SRC_EXT>）拷进 <待做目录>/<题号>/
#      —— 只拷这一个文件。test/（harness / tb / 数据 / 检查器）与契约头文件
#      一律留在判分端：前者是答案与判据，后者被 harness 也 include，
#      学生若能改它就能让 harness 拿黄金模型自己对拍。
#   3. 生成 <待做目录>/<题号>/Makefile（三行，include core/work.mk）
#
# 幂等：已存在的作答文件绝不覆盖（学生写了一半的代码不能被 make 冲掉）；
# Makefile 是生成物，每次都重写，这样平台升级后旧作答目录会自动跟上。

set -euo pipefail

root="${1:?用法: take.sh <ROOT> <待做目录> <题号> [done目录] [周名]}"
todo="${2:?}"
pid="${3:?}"
done_dir="${4:-done}"
week="${5:-}"

probdir="$(ls -d "$root"/langs/*/problems/"$pid" 2>/dev/null | head -n1 || true)"
if [ -z "$probdir" ] || [ ! -f "$probdir/Makefile" ]; then
  echo "ERROR: 平台里没有题号 $pid（在 $root/langs/*/problems/ 下找不到）" >&2
  exit 1
fi

# 已经在 done/ 里了就别再取一份出来，否则同一题会同时出现在两处。
if [ -d "$done_dir/$pid" ]; then
  echo "  跳过 $pid：已在 $done_dir/ 里（要重做请 make reopen PID=$pid）"
  exit 0
fi

# 题目元数据一律问判分端那份 Makefile，不在这里重新推断。
# print-% 由 core/engine.mk 提供。
meta="$(make -s --no-print-directory -C "$probdir" print-SRC print-LANG_SLUG print-MODE 2>/dev/null)"
src="$(printf '%s\n' "$meta" | sed -n '1p')"
slug="$(printf '%s\n' "$meta" | sed -n '2p')"
mode="$(printf '%s\n' "$meta" | sed -n '3p')"

if [ -z "$src" ] || [ ! -f "$probdir/$src" ]; then
  echo "ERROR: $pid 的作答模板 $src 不存在（判分端题目目录不完整）" >&2
  exit 1
fi

dest="$todo/$pid"
mkdir -p "$dest"

if [ -e "$dest/$src" ]; then
  echo "  保留 $dest/$src（已存在，未覆盖）"
else
  cp "$probdir/$src" "$dest/$src"
  echo "  取下 $dest/$src"
fi

# 题面若单独成文就一起发（判分端目前把题面写在模板注释里，这里做前向兼容）
for extra in README.md 题面.md; do
  if [ -f "$probdir/$extra" ] && [ ! -e "$dest/$extra" ]; then
    cp "$probdir/$extra" "$dest/$extra"
    echo "  取下 $dest/$extra"
  fi
done

# ===== 生成作答目录的 Makefile =====
# 用相对路径指向 core/，这样整个 work/ 目录可以连同仓库一起搬走/克隆。
abs_dest="$(cd "$dest" && pwd -P)"
abs_root="$(cd "$root" && pwd -P)"
rel_to_root="$(realpath --relative-to="$abs_dest" "$abs_root" 2>/dev/null || true)"
if [ -z "$rel_to_root" ]; then
  # realpath 没有 --relative-to 时的退化路径：按目录层数拼 ../
  suffix="${abs_dest#"$abs_root"/}"
  rel_to_root="$(printf '%s' "$suffix" | awk -F/ '{for(i=1;i<=NF;i++)printf "../"; }' | sed 's:/$::')"
fi

{
  printf '%s\n' "# $pid 作答目录（本文件由 make take 生成，请勿改动）"
  printf '%s\n' "#"
  printf '%s\n' "# 本目录只放你的作答文件（$src）与判分产物 build/。"
  printf '%s\n' "# 判分资源（harness / testbench / 测试数据 / 检查器）留在判分端："
  printf '%s\n' "#     langs/$slug/problems/$pid/"
  printf '%s\n' "# 判分时由 core/work.mk 把 PROBDIR 指到那里，两边解耦。"
  printf '%s\n' "#"
  printf '%s\n' "# 用法：make sim（判分）/ make style（只查风格）/ make spec（看接口契约）"
  printf '%s\n' ""
  printf '%s\n' "PID  := $pid"
  if [ -n "$week" ]; then printf '%s\n' "WEEK := $week"; fi
  printf '%s\n' "WORK := $rel_to_root/core"
  printf '%s\n' "include \$(WORK)/work.mk"
} > "$dest/Makefile"

# mode 只对 C 有意义（Verilog 插件没有 MODE），空着就不提
if [ -n "$mode" ]; then
  echo "       题型 $slug/$mode，判分资源在 langs/$slug/problems/$pid/"
else
  echo "       语言 $slug，判分资源在 langs/$slug/problems/$pid/"
fi
