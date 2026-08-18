#!/usr/bin/env bash
# style_check.sh [--ban-main|--require-main] [--ban=kw1,kw2,...] [--allow-header=h1,h2,...] <student.c>
#
# 学生解风格检查：只允许"自己写算法"，禁止绕过训练目标或攻击判分环境的写法。
# 命中任一禁止项 → 退出码 1 并输出原因；通过 → 退出码 0，无输出。
#
# 检查前先剥离注释与字符串/字符字面量，避免 printf("system") 之类误伤。
set -u

usage() {
    echo "usage: $0 [--ban-main|--require-main] [--ban=kw,...] [--allow-header=h,...] <student.c>" >&2
    exit 2
}

main_mode=""      # ban | require | (空: 不检查)
extra_ban=""
extra_header=""

while [ $# -gt 1 ]; do
    case "$1" in
        --ban-main)       main_mode="ban" ;;
        --require-main)   main_mode="require" ;;
        --ban=*)          extra_ban="${1#--ban=}" ;;
        --allow-header=*) extra_header="${1#--allow-header=}" ;;
        *) echo "style_check: 未知参数 $1" >&2; usage ;;
    esac
    shift
done

[ $# -eq 1 ] || usage
f="$1"
[ -f "$f" ] || { echo "style_check: 无法读取文件 $f" >&2; exit 2; }

# ---- 步骤 1：剥离注释与字面量 ----
# 顺序：块注释(可跨行) -> 行注释 -> "字符串" -> '字符'，均替换为空，保留行号对应关系。
stripped="$(awk '
  BEGIN { inblock = 0 }
  {
    line = $0; res = ""; n = length(line); i = 1
    while (i <= n) {
      c = substr(line, i, 1)
      if (inblock) {
        if (c == "*" && i < n && substr(line, i + 1, 1) == "/") { inblock = 0; i += 2; continue }
        i++; continue
      }
      if (c == "/" && i < n) {
        c2 = substr(line, i + 1, 1)
        if (c2 == "/") { i = n + 1; continue }             # 行注释：跳过整行剩余
        if (c2 == "*") { inblock = 1; i += 2; continue }   # 块注释开始
      }
      if (c == "\"" || c == "'"'"'") {                      # 字符串 / 字符字面量
        q = c; i++
        while (i <= n) {
          d = substr(line, i, 1)
          if (d == "\\") { i += 2; continue }              # 转义：整对跳过
          if (d == q) { i++; break }
          i++
        }
        continue
      }
      res = res c
      i++
    }
    print res
  }
' "$f")"

viol="no"

# ---- 检查 1：main 函数（func 模式禁止自带 main，io 模式必须有 main）----
has_main="$(printf '%s\n' "$stripped" | grep -nE '^[[:space:]]*(int|void)[[:space:]]+main[[:space:]]*\(')"
case "$main_mode" in
    ban)
        if [ -n "$has_main" ]; then
            echo "STYLE: 本题为函数题，判分端自带 main，学生解不得定义 main："
            echo "$has_main"
            viol="yes"
        fi
        ;;
    require)
        if [ -z "$has_main" ]; then
            echo "STYLE: 本题为标准输入输出题，学生解必须定义 int main(void)。"
            viol="yes"
        fi
        ;;
esac

# ---- 检查 2：禁止的库调用（绕过判分 / 攻击环境 / 不安全函数）----
# 分三类给出可读的提示。
ban_escape='system|popen|fork|vfork|execl|execlp|execle|execv|execvp|execvpe|posix_spawn|dlopen|dlsym|signal|raise|longjmp|setjmp|atexit|_exit|abort'
# 注意：只列不会与学生自定义函数名撞车的库函数；raw syscall（open/read/write）需要
# <fcntl.h>/<unistd.h>，已被下面的头文件白名单拦住，故不在此重复禁止 open/read/write。
ban_fileio='fopen|freopen|fdopen|creat|openat|remove|unlink|rename|rmdir|opendir|mmap|getenv|putenv|setenv'
ban_unsafe='gets|strcpy|strcat|sprintf|vsprintf|alloca|scanf_s'

check_group() {
    local pat="$1" msg="$2" hit
    # 匹配 "标识符 (" 形式的调用；\b 用 -w 近似不够，这里用显式边界
    hit="$(printf '%s\n' "$stripped" | grep -nE "(^|[^A-Za-z0-9_])($pat)[[:space:]]*\(")"
    if [ -n "$hit" ]; then
        echo "STYLE: $msg"
        echo "$hit"
        viol="yes"
    fi
}

check_group "$ban_escape" "命中禁止的进程/信号控制调用（判分环境不允许学生解创建进程或劫持控制流）："
check_group "$ban_fileio" "命中禁止的文件/环境访问（本题只能用参数或 stdin 取数据，不得读写文件绕过判分）："
check_group "$ban_unsafe" "命中禁止的不安全函数（存在缓冲区溢出风险，请用 snprintf / strncpy / fgets 等带长度的版本）："

# ---- 检查 3：goto ----
gotoline="$(printf '%s\n' "$stripped" | grep -nwE 'goto')"
if [ -n "$gotoline" ]; then
    echo "STYLE: 命中禁止关键字 goto（请用结构化控制流：if / for / while / break / continue）："
    echo "$gotoline"
    viol="yes"
fi

# ---- 检查 4：内联汇编 ----
asmline="$(printf '%s\n' "$stripped" | grep -nE '(^|[^A-Za-z0-9_])(asm|__asm__|__asm)([^A-Za-z0-9_]|$)')"
if [ -n "$asmline" ]; then
    echo "STYLE: 命中内联汇编（本题要求用 C 实现算法）："
    echo "$asmline"
    viol="yes"
fi

# ---- 检查 5：头文件白名单 ----
allow_header="stdio.h stdlib.h string.h math.h limits.h stdbool.h stddef.h stdint.h ctype.h assert.h"
if [ -n "$extra_header" ]; then
    allow_header="$allow_header $(printf '%s' "$extra_header" | tr ',' ' ')"
fi
bad_header=""
while IFS= read -r ln; do
    [ -n "$ln" ] || continue
    no="${ln%%:*}"
    h="$(printf '%s' "$ln" | sed -n 's/.*[<"]\([^>"]*\)[>"].*/\1/p')"
    ok="no"
    for a in $allow_header; do
        [ "$h" = "$a" ] && { ok="yes"; break; }
    done
    [ "$ok" = "yes" ] || bad_header="$bad_header
$no: #include <$h>"
done <<EOF
$(grep -nE '^[[:space:]]*#[[:space:]]*include' "$f")
EOF
if [ -n "$bad_header" ]; then
    echo "STYLE: 命中不允许的头文件（白名单：$allow_header）：$bad_header"
    viol="yes"
fi

# ---- 检查 6：题目自定义禁止项（--ban=...，按整词匹配）----
if [ -n "$extra_ban" ]; then
    pat="$(printf '%s' "$extra_ban" | tr ',' '|')"
    hit="$(printf '%s\n' "$stripped" | grep -nwE "$pat")"
    if [ -n "$hit" ]; then
        echo "STYLE: 命中本题额外禁止项（$extra_ban）："
        echo "$hit"
        viol="yes"
    fi
fi

if [ "$viol" = "yes" ]; then
    echo "提示：本题只允许标准 C（白名单头文件）+ 自己实现的算法，不得读写文件、创建进程或使用不安全函数。"
    exit 1
fi
exit 0
