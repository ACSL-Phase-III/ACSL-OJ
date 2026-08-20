#!/usr/bin/env bash
# trace_push.sh <remote> <stuid> [--verbose]
#
# 云端 trace 跟踪：把本地 trace/<学号> 分支推送到远端，使老师端 `git fetch` 即可看到
# 每个学生的完整判分历史（一串空提交）。
#
# 设计原则：推送**永不影响判分结果**。
# - 无远端 / 离线 / 无凭据 / 被拒：只打印一行提示，退出码始终 0；
# - 失败时把待推送标记写入 .trace-pending，下次判分自动补推（离线补偿）；
# - 全程 GIT_TERMINAL_PROMPT=0 + timeout，绝不卡在交互式密码输入上。
#
# git 一律对 ACSL-OJ 仓库根操作，不用「最近的 .git」。学生在题目目录里
# git init / 提交作业 造出的嵌套仓库没有 origin，会把 AC 后面的提示弄得像交作业失败。
set -u

remote="$(printf '%s' "${1:-origin}" | tr -d '\r')"
stuid="$(printf '%s' "${2:-}" | tr -d '\r')"
verbose="${3:-}"

PUSH_TIMEOUT="${PUSH_TIMEOUT:-20}"
PUBLIC_HINT="git@github.com:ACSL-Phase-III/ACSL-OJ.git"

here="$(cd "$(dirname "$0")" && pwd)"
platroot="$(cd "$here/../.." && pwd)"
g() { git -C "$platroot" "$@"; }

say()  { echo "trace-push: $*"; }
vsay() { [ "$verbose" = "--verbose" ] && echo "trace-push: $*" || true; }

# 无学号 / 非 git 仓库：静默跳过。
[ -n "$stuid" ] && [ "$stuid" != "000000" ] || exit 0
g rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

branch="trace/$stuid"
pending="$platroot/.trace-pending"

# 题目目录里另有一份 .git 时提醒一次，避免下次再以为「clone 过却没有 origin」。
cwd_top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
plat_top="$(g rev-parse --show-toplevel 2>/dev/null || echo "$platroot")"
if [ -n "$cwd_top" ] && [ "$cwd_top" != "$plat_top" ]; then
    say "忽略 $cwd_top 里的嵌套 .git，改用 ACSL-OJ 仓库 $plat_top"
    say "  （多半是在题目目录执行过 git init；可以删掉那个 .git，不影响作答文件）"
fi

if ! g show-ref -q "refs/heads/$branch"; then
    say "本地还没有 $branch 分支（先 make init），跳过云端同步。"
    exit 0
fi

remote_err="$(g remote get-url "$remote" 2>&1)" || true
if ! g remote get-url "$remote" >/dev/null 2>&1; then
    # origin 被改名时，只要还有远端指向公开仓，就用那个。
    fallback=""
    while read -r name url _; do
        [ -n "${name:-}" ] || continue
        case "$url" in
            *ACSL-OJ-DEV*) continue ;;
            *ACSL-OJ.git|*ACSL-OJ|*ACSL-OJ/)
                fallback="$name"
                break
                ;;
        esac
    done < <(g remote -v 2>/dev/null)
    if [ -n "$fallback" ]; then
        say "没有远端 '$remote'，改用 '$fallback'（指向公开仓）"
        remote="$fallback"
    else
        say "本题 AC 已经记下。未能同步到云端：仓库没有远端 '$remote'。"
        say "  不影响成绩。请在 $plat_top 执行： git remote -v"
        if [ -n "$remote_err" ]; then
            say "  git 原话：$(printf '%s' "$remote_err" | tr '\n' ' ' | head -c 200)"
        fi
        remotes="$(g remote -v 2>/dev/null | tr '\n' '|' | sed 's/|$//')"
        if [ -n "$remotes" ]; then
            say "  当前远端：$remotes"
        else
            say "  当前一个远端都没有。补上公开仓："
            say "      git remote add $remote $PUBLIC_HINT"
            say "  然后： make trace-push"
        fi
        printf '%s\n' "$branch" > "$pending"
        exit 0
    fi
fi

vsay "推送 $branch -> $remote ..."
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/true
export SSH_ASKPASS=/bin/true

log="$(timeout -k 2 "$PUSH_TIMEOUT" g push "$remote" "refs/heads/$branch:refs/heads/$branch" 2>&1)"
rc=$?

if [ "$rc" -eq 0 ]; then
    rm -f "$pending"
    url="$(g remote get-url "$remote" 2>/dev/null)"
    say "已同步到云端：$remote/$branch"
    vsay "  远端：$url"
    exit 0
fi

# ---- 失败分类：给出可操作的提示，但一律不让判分失败 ----
printf '%s\n' "$branch" > "$pending"

case "$rc" in
    124|137)
        say "推送超时（>${PUSH_TIMEOUT}s），已记录待同步；下次判分自动补推。"
        ;;
    *)
        if printf '%s' "$log" | grep -qiE 'could not resolve host|network is unreachable|connection (timed out|refused)|failed to connect'; then
            say "当前离线，已记录待同步；联网后下次判分自动补推，或手动 make trace-push。"
        elif printf '%s' "$log" | grep -qiE 'authentication failed|permission denied|access denied|terminal prompts disabled|could not read Username'; then
            say "云端拒绝：没有推送凭据或无权限。请先配置 git 凭据（如 gh auth login / SSH key）。"
            say "  学生需要能 push 到公开仓 $PUBLIC_HINT（否则老师 fetch 不到 trace）。"
        elif printf '%s' "$log" | grep -qiE 'non-fast-forward|fetch first|rejected'; then
            say "云端已有同名分支且历史不一致（non-fast-forward），未自动覆盖。"
            say "  请先 git fetch $remote 并核对 $branch 的历史。"
        else
            say "推送失败（退出码 $rc），已记录待同步。详情："
            printf '%s\n' "$log" | sed -n '1,6p' | sed 's/^/  /'
        fi
        ;;
esac
exit 0
