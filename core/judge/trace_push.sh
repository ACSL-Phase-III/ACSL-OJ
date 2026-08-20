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
set -u

remote="${1:-origin}"
stuid="${2:-}"
verbose="${3:-}"

PUSH_TIMEOUT="${PUSH_TIMEOUT:-20}"

say()  { echo "trace-push: $*"; }
vsay() { [ "$verbose" = "--verbose" ] && echo "trace-push: $*" || true; }

# 无学号 / 非 git 仓库：静默跳过。
[ -n "$stuid" ] && [ "$stuid" != "000000" ] || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

branch="trace/$stuid"
root="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
pending="$root/.trace-pending"

if ! git show-ref -q "refs/heads/$branch"; then
    say "本地还没有 $branch 分支（先 make init），跳过云端同步。"
    exit 0
fi

if ! git remote get-url "$remote" >/dev/null 2>&1; then
    say "未配置远端 '$remote'，本次只在本地留痕。"
    say "  配置方式：git remote add $remote <仓库地址>"
    printf '%s\n' "$branch" > "$pending"
    exit 0
fi

vsay "推送 $branch -> $remote ..."
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/true
export SSH_ASKPASS=/bin/true

log="$(timeout -k 2 "$PUSH_TIMEOUT" git push "$remote" "refs/heads/$branch:refs/heads/$branch" 2>&1)"
rc=$?

if [ "$rc" -eq 0 ]; then
    rm -f "$pending"
    url="$(git remote get-url "$remote" 2>/dev/null)"
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
