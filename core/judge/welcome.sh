#!/usr/bin/env bash
# welcome.sh [init|take|preview]
#
# 第一次 make init，以及每次 make take 取新作业时，打一张 ACSL 欢迎屏。
# make welcome 默认 init（学生第一次看到的那张）；KIND=take / KIND=preview 另看。
# 不改 git、不取题。
# stdout 不是 tty 或 NO_COLOR=1 时仍出框，只是没有颜色。
set -u

mode="${1:-take}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
arch="$(uname -m 2>/dev/null || echo unknown)"
stuid="${STUID:-}"
name="${NAME:-}"
[ "$stuid" = "000000" ] && stuid=""
[ "$name" = "未填写" ] && name=""

weeks=""
if [ -d "$root/work" ]; then
    weeks="$(find "$root/work" -mindepth 2 -maxdepth 2 -name Makefile 2>/dev/null \
        | while read -r f; do
            grep -q 'week\.mk' "$f" 2>/dev/null || continue
            d="$(dirname "$f")"
            case "$d" in */problem) d="$(dirname "$d")" ;; esac
            basename "$d"
          done | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
fi
[ -n "$weeks" ] || weeks="（还没有作业周）"

color=0
if [ -t 1 ] && [ "${NO_COLOR:-}" != "1" ] && [ "${TERM:-}" != "dumb" ]; then
    color=1
fi
if [ "$color" = 1 ]; then
    R=$'\033[0m'
    DIM=$'\033[90m'
    BOLD=$'\033[1m'
    FG=$'\033[97m'
    CYAN=$'\033[36m'
    GREEN=$'\033[32m'
    YEL=$'\033[33m'
else
    R=""; DIM=""; BOLD=""; FG=""; CYAN=""; GREEN=""; YEL=""
fi

user_line="Guest"
if [ -n "$name" ] && [ -n "$stuid" ]; then
    user_line="$name  $stuid"
elif [ -n "$stuid" ]; then
    user_line="$stuid"
elif [ -n "$name" ]; then
    user_line="$name"
fi

draw_frame() {
    local kind="$1" status hint
    if [ "$kind" = init ]; then
        status="Ready · trace live"
        hint="Next: make take"
    else
        status="Running"
        hint="Next: make sim"
    fi

    # 80 列框：左 logo 34，右信息。底部命令条。
    local hline="${DIM}──────────────────────────────────────────────────────────────────────────────${R}"
    echo
    echo "$hline"
    printf '  %s%s  █████╗  ██████╗███████╗██╗     %s  %sACSL-OJ%s  %s (%s)%s\n' \
        "$BOLD" "$FG" "$R" "$BOLD$CYAN" "$R" "$DIM" "$arch" "$R"
    printf '  %s%s ██╔══██╗██╔════╝██╔════╝██║     %s  %s─────────────────────────────%s\n' \
        "$BOLD" "$FG" "$R" "$DIM" "$R"
    printf '  %s%s ███████║██║     ███████╗██║     %s  %s●%s Status: %s%s%s\n' \
        "$BOLD" "$FG" "$R" "$GREEN" "$R" "$GREEN" "$status" "$R"
    printf '  %s%s ██╔══██║██║     ╚════██║██║     %s  %s⚡%s Engine: make sim · local judge\n' \
        "$BOLD" "$FG" "$R" "$YEL" "$R"
    printf '  %s%s ██║  ██║╚██████╗███████║███████╗%s  %s⏱%s  User:   %s\n' \
        "$BOLD" "$FG" "$R" "$CYAN" "$R" "$user_line"
    printf '  %s%s ╚═╝  ╚═╝ ╚═════╝╚══════╝╚══════╝%s  %s📦%s Weeks:  %s\n' \
        "$BOLD" "$FG" "$R" "$CYAN" "$R" "$weeks"
    printf '  %s%s                                  %s  %s%s%s\n' \
        "$BOLD" "$FG" "$R" "$DIM" "$hint · make help" "$R"
    echo "$hline"
    printf '  %s[1] take    [2] sim    [3] spec    [4] example    [5] help%s\n' "$DIM" "$R"
    echo "$hline"
    if [ "$kind" = init ]; then
        echo "  欢迎加入 ACSL。学号已写入 trace 分支；接下来 make take 取本周题目。"
    else
        echo "  作业已同步到 work/<周>/<题号>/ 。改 TODO，然后 make sim。"
    fi
    echo
}

case "$mode" in
    init|take)
        draw_frame "$mode"
        ;;
    preview)
        echo "${DIM}—— 预览 · make init 时 ——${R}  ${DIM}(不改 git、不取题)${R}"
        draw_frame init
        echo "${DIM}—— 预览 · make take 时 ——${R}"
        draw_frame take
        ;;
    *)
        echo "usage: $0 {init|take|preview}" >&2
        exit 2
        ;;
esac
