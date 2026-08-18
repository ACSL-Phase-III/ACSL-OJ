#!/usr/bin/env bash
# trace.sh <子命令> [参数...]
#
# 语言无关的 trace 留痕（PA 风格空提交 + 云端同步）。与判分内容完全解耦：
# 只接收"结论文本"，不关心它来自 Verilog 仿真还是 C 程序。
#
# 子命令：
#   init  <stuid> <name>                初始化 trace/<学号> 分支并打 [init] 空提交
#   commit <stuid> <标题> <结论文件>      追加一次空提交（提交信息 = 标题 + 缩进的结论清单）
#   log   <stuid>                        打印本地与云端的判分历史对照
#
# 环境变量：
#   TRACE_REMOTE  远端名（默认 origin）
#   AUTOPUSH      1=提交后自动推送云端（默认 1）
#   SCOPE         留痕范围标签，写进提交信息（如 all / c / verilog / c:p01_gcd）
set -u

here="$(cd "$(dirname "$0")" && pwd)"
remote="${TRACE_REMOTE:-origin}"
autopush="${AUTOPUSH:-1}"
scope="${SCOPE:-}"

cmd="${1:-}"
shift || true

in_repo() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }

# 学号有效性：未填写（000000/空）时一律静默跳过留痕，只判分。
valid_stuid() { [ -n "${1:-}" ] && [ "$1" != "000000" ]; }

# 切到 trace 分支（不存在则创建）
goto_branch() {
    local br="$1"
    git switch -c "$br" >/dev/null 2>&1 \
        || git checkout -b "$br" >/dev/null 2>&1 \
        || git checkout "$br" >/dev/null 2>&1 \
        || return 1
    return 0
}

maybe_push() {
    local stuid="$1"
    if [ "$autopush" = "1" ]; then
        bash "$here/trace_push.sh" "$remote" "$stuid" "${2:-}"
    else
        echo "trace: AUTOPUSH=0，本次不同步云端（可手动 make trace-push）"
    fi
}

case "$cmd" in
# ---------------------------------------------------------------- init
init)
    stuid="${1:-}"; name="${2:-}"
    if ! valid_stuid "$stuid" || [ -z "$name" ] || [ "$name" = "未填写" ]; then
        echo "ERROR: 请先在 student.mk 中填写 STUID 与 NAME，例如："
        echo "        STUID := 211220042"
        echo "        NAME  := 张三"
        exit 1
    fi
    if ! in_repo; then
        echo "ERROR: 当前不在 git 仓库内，trace 分支要求 git 环境。"
        exit 1
    fi
    br="trace/$stuid"
    if git show-ref -q "refs/heads/$br"; then
        echo "trace 分支已存在：$br（当前 HEAD 已切换到该分支）"
        git checkout "$br" >/dev/null 2>&1 || true
    else
        goto_branch "$br" || { echo "ERROR: 创建 $br 分支失败。"; exit 1; }
        echo "已创建 trace 分支：$br"
    fi
    git commit --allow-empty -m "[init] trace 初始化 ($stuid $name) $(date '+%F %T')" >/dev/null 2>&1 || true
    git log --oneline -3 2>/dev/null | sed 's/^/  /'
    maybe_push "$stuid" --verbose
    echo "OK：之后每次 make sim 都会在 $br 上追加一次空提交。"
    ;;

# -------------------------------------------------------------- commit
commit)
    stuid="${1:-}"; title="${2:-判分}"; results="${3:-}"
    in_repo || { echo "(不在 git 仓库：本次不创建 trace 提交)"; exit 0; }
    valid_stuid "$stuid" || { echo "(未填写 STUID：本次不创建 trace 提交，只判分)"; exit 0; }
    [ -s "$results" ] || { echo "(没有判分结论可留痕)"; exit 0; }

    br="trace/$stuid"
    goto_branch "$br" || { echo "trace: 切换 $br 失败，本次不留痕（不影响判分）"; exit 0; }

    n="$(wc -l < "$results" | tr -d ' ')"
    msg="$(mktemp)"
    {
        printf '[sim] %s %s（共 %s 题%s）\n' "$(date '+%F %T')" "$title" "$n" \
               "${scope:+，范围 $scope}"
        sed 's/^/  /' "$results"
    } > "$msg"

    if git commit --allow-empty -F "$msg" >/dev/null 2>&1; then
        echo "trace: 已在 $br 留痕（空提交，信息含判分汇总）"
        rm -f "$msg"
        maybe_push "$stuid"
    else
        rm -f "$msg"
        echo "trace: 留痕失败（可忽略，仅影响留痕）"
    fi
    ;;

# ----------------------------------------------------------------- log
log)
    stuid="${1:-}"
    in_repo || { echo "ERROR: 当前不在 git 仓库内。"; exit 1; }
    br="trace/$stuid"
    if ! git show-ref -q "refs/heads/$br"; then
        echo "本地没有 $br 分支（先 make init）"
        exit 1
    fi
    echo "===== 本地 $br ====="
    git log --oneline "$br" | sed 's/^/  /'
    echo "===== 云端 $remote/$br ====="
    if git rev-parse -q --verify "refs/remotes/$remote/$br" >/dev/null 2>&1; then
        git log --oneline "$remote/$br" | sed 's/^/  /'
        ahead="$(git rev-list --count "$remote/$br..$br" 2>/dev/null || echo 0)"
        if [ "$ahead" = "0" ]; then
            echo "  (本地与云端一致)"
        else
            echo "  (本地领先云端 $ahead 次判分，可 make trace-push)"
        fi
    else
        echo "  (还没抓取到云端分支，先 git fetch $remote 或 make trace-push)"
    fi
    ;;

*)
    echo "usage: $0 {init <stuid> <name> | commit <stuid> <标题> <结论文件> | log <stuid>}" >&2
    exit 2
    ;;
esac
