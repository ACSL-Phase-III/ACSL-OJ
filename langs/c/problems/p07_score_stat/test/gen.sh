#!/usr/bin/env bash
# gen.sh —— 重新生成 p07_score_stat 的测试数据（judge 端工具，学生不需要运行）
#
# 用法：bash test/gen.sh        （在题目目录下执行）
# 产物：test/cases/*.in 与由 test/ref.c 生成的同名 *.ans
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
cases="$here/cases"
ref="$here/.ref"

mkdir -p "$cases"
rm -f "$cases"/*.in "$cases"/*.ans

gcc -std=c11 -O2 -o "$ref" "$here/ref.c"
trap 'rm -f "$ref"' EXIT

# emit <名字> <n> <生成方式>
#   生成方式：awk 表达式，输出 n 个 0..100 的整数（固定种子，可复现）
emit() {
    name="$1"; n="$2"; mode="$3"
    {
        echo "$n"
        awk -v n="$n" -v mode="$mode" -v seed="$4" '
          BEGIN {
            srand(seed)
            for (i = 0; i < n; i++) {
              if (mode == "uniform")      v = int(rand() * 101)
              else if (mode == "narrow")  v = 60 + int(rand() * 5)
              else if (mode == "same")    v = 77
              else if (mode == "extreme") v = (rand() < 0.5 ? 0 : 100)
              else if (mode == "asc")     v = int(i * 100 / (n > 1 ? n - 1 : 1))
              else if (mode == "desc")    v = 100 - int(i * 100 / (n > 1 ? n - 1 : 1))
              else                        v = int(rand() * 101)
              printf "%s%d", (i ? " " : ""), v
            }
            printf "\n"
          }'
    } > "$cases/$name.in"
    "$ref" < "$cases/$name.in" > "$cases/$name.ans"
    echo "  $name.in (n=$n, $mode)"
}

echo "生成 p07_score_stat 测试数据："
# ---- 边界：最小规模与退化分布 ----
emit 01_single      1      same    1
emit 02_two         2      extreme 2
emit 03_all_same    50     same    3
emit 04_all_zero    32     asc     4
emit 05_narrow      200    narrow  5
emit 06_extreme     301    extreme 6
emit 07_asc         999    asc     7
emit 08_desc        999    desc    8
# ---- 一般规模 ----
emit 09_small       97     uniform 9
emit 10_mid         5000   uniform 10
emit 11_mid2        20000  uniform 11
# ---- 大规模：卡 O(n^2) 排序 ----
emit 12_large       100000 uniform 12
emit 13_large_desc  100000 desc    13
emit 14_large_same  100000 same    14

# 04_all_zero 用 asc 生成会有非零值，这里手工改成全 0（专门验证 %.2f 输出 0.00）
{ echo 32; awk 'BEGIN { for (i = 0; i < 32; i++) printf "%s0", (i ? " " : ""); printf "\n" }'; } \
    > "$cases/04_all_zero.in"
"$ref" < "$cases/04_all_zero.in" > "$cases/04_all_zero.ans"

echo "完成：$(ls "$cases"/*.in | wc -l) 组测试数据。"
