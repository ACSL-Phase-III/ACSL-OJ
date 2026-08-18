#!/usr/bin/env bash
# run_io.sh <exe> <casedir> [timeout_sec]
#
# io 模式对拍器：把 <casedir>/*.in 依次喂给 <exe> 的 stdin，与同名 *.ans 比较 stdout。
# 比较规则：忽略行尾空白与末尾空行（trailing whitespace insensitive），其余必须逐字符相同。
#
# 输出遵循判分协议（与 verilog-oj 的 tb 协议一致，便于 common.mk 统一解析）：
#   JUDGE-MISMATCH: in=<case> got=<...> want=<...>   首个失配样例
#   JUDGE-TLE: <case>                                某个样例超时
#   JUDGE-COUNT: <N>                                 测试总数
#   JUDGE: PASS | JUDGE: FAIL <n>                    最后一行且仅一行
set -u

exe="${1:-}"
dir="${2:-}"
tmo="${3:-5}"

[ -n "$exe" ] && [ -n "$dir" ] || { echo "usage: $0 <exe> <casedir> [timeout_sec]" >&2; exit 2; }
[ -x "$exe" ] || { echo "run_io: 可执行文件不存在或不可执行：$exe" >&2; exit 2; }
[ -d "$dir" ] || { echo "run_io: 测试数据目录不存在：$dir" >&2; exit 2; }

shopt -s nullglob
cases=("$dir"/*.in)
if [ "${#cases[@]}" -eq 0 ]; then
    echo "run_io: $dir 下没有任何 *.in 测试数据" >&2
    exit 2
fi

# 规范化：删除每行行尾空白，并去掉文件末尾的所有空行。
normalize() { sed -e 's/[[:space:]]*$//' -e '$a\' "$1" | sed -e :a -e '/^$/{$d;N;ba' -e '}'; }

# 单行摘要，便于塞进 JUDGE-MISMATCH（换行 -> \n，超长截断）。
oneline() { tr '\n' '~' < "$1" | cut -c1-120; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

err=0
tle=0
n=0

for in_f in "${cases[@]}"; do
    base="$(basename "$in_f" .in)"
    ans_f="$dir/$base.ans"
    if [ ! -f "$ans_f" ]; then
        echo "run_io: 缺少期望输出 $ans_f（*.in 与 *.ans 必须成对）" >&2
        exit 2
    fi
    n=$((n + 1))

    out_f="$work/$base.out"
    timeout -k 1 "$tmo" "$exe" < "$in_f" > "$out_f" 2> "$work/$base.err"
    rc=$?

    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
        echo "JUDGE-TLE: $base（超过 ${tmo}s）"
        tle=1
        break
    fi

    # sanitizer 报告或崩溃：原样透出 stderr，由 common.mk 判成 RE。
    if [ "$rc" -ne 0 ]; then
        echo "run_io: 样例 $base 运行异常（退出码 $rc）"
        sed -n '1,25p' "$work/$base.err"
        exit "$rc"
    fi
    if grep -qE 'ERROR: (Address|Leak)Sanitizer|runtime error:' "$work/$base.err"; then
        sed -n '1,25p' "$work/$base.err"
        exit 1
    fi

    normalize "$out_f" > "$work/$base.got"
    normalize "$ans_f" > "$work/$base.want"
    if ! cmp -s "$work/$base.got" "$work/$base.want"; then
        err=$((err + 1))
        if [ "$err" -eq 1 ]; then
            echo "JUDGE-MISMATCH: in=$base got=$(oneline "$work/$base.got") want=$(oneline "$work/$base.want")"
        fi
    fi
done

if [ "$tle" -eq 1 ]; then
    # TLE 直接退出，让 common.mk 走 TLE 分支（不打印 JUDGE: 结论行）。
    exit 124
fi

echo "JUDGE-COUNT: $n"
if [ "$err" -eq 0 ]; then
    echo "JUDGE: PASS"
else
    echo "JUDGE: FAIL $err"
fi
exit 0
