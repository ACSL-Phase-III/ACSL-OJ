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
# 留痕必须写 ACSL-OJ 仓库根，不能用「最近的 .git」：学生在题目目录
# git init / 提交作业 会造出一个没有 origin 的嵌套仓库，make sim 就会误报
# 「未配置远端 origin」，痕迹也写进错的 .git。
platroot="$(cd "$here/../.." && pwd)"
g() { git -C "$platroot" "$@"; }

# student.mk 在 Windows 下常带 CRLF，否则 git remote get-url origin\r 会失败。
remote="$(printf '%s' "${TRACE_REMOTE:-origin}" | tr -d '\r')"
autopush="$(printf '%s' "${AUTOPUSH:-1}" | tr -d '\r')"
scope="${SCOPE:-}"

cmd="${1:-}"
shift || true

in_repo() { g rev-parse --is-inside-work-tree >/dev/null 2>&1; }

# 学号有效性：未填写（000000/空）时一律静默跳过留痕，只判分。
valid_stuid() { [ -n "${1:-}" ] && [ "$1" != "000000" ]; }

# ===== 留痕怎么落到 trace/<学号> 上：写 ref，不切分支 =====
# 早先的做法是 git checkout 到 trace 分支再 git commit --allow-empty，问题是**再也没切回来**。
# 于是学生 make init 之后就一直待在 trace/<学号> 上，而这个分支没有 upstream
# （trace_push.sh 推的是 refs/heads/x:refs/heads/x，不带 -u），直接后果：
#
#     $ git pull
#     There is no tracking information for the current branch.   → 退出码 1
#
# 老师每周日往 main 发新题、学生 git pull 取题的用法就此断掉，而且断在
# "学生已经开始做题"之后，第一周完全正常，第二周才炸。
#
# 现在改用 plumbing：自己造 commit 对象，再把分支 ref 指过去。HEAD 不动，
# 工作区不动，学生始终留在 main 上。顺带去掉了一个隐患 —— 切分支这个动作本身
# 会因为工作区有改动而失败（原 goto_branch 返回 1，留痕被静默跳过）。
#
# tree 的选法：
#   有父提交    -> 沿用父提交的 tree。这样 git log 里每次判分都是空提交（无 diff），
#                  与原行为一致；也不会因为学生 pull 过新题就在留痕历史里冒出一堆
#                  与判分无关的文件变更。
#   没有父提交  -> 用当前 HEAD 的 tree（分支的根提交，等价于原先 checkout -b 的效果）。
trace_commit() {
    local br="$1" msg_file="$2" parent tree new
    parent="$(g rev-parse -q --verify "refs/heads/$br" 2>/dev/null || true)"

    if [ -n "$parent" ]; then
        tree="$(g rev-parse -q --verify "$parent^{tree}" 2>/dev/null || true)"
    else
        tree="$(g rev-parse -q --verify 'HEAD^{tree}' 2>/dev/null || true)"
    fi
    # 空仓库（一次提交都还没有）：退化成空 tree，留痕仍然成立。
    [ -n "$tree" ] || tree="$(g hash-object -t tree /dev/null 2>/dev/null || true)"
    [ -n "$tree" ] || return 1

    if [ -n "$parent" ]; then
        new="$(g commit-tree "$tree" -p "$parent" -F "$msg_file" 2>/dev/null || true)"
    else
        new="$(g commit-tree "$tree" -F "$msg_file" 2>/dev/null || true)"
    fi
    [ -n "$new" ] || return 1

    g update-ref "refs/heads/$br" "$new" || return 1
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
    had="no"
    g show-ref -q "refs/heads/$br" && had="yes"

    msg="$(mktemp)"
    printf '[init] trace 初始化 (%s %s) %s\n' "$stuid" "$name" "$(date '+%F %T')" > "$msg"
    if ! trace_commit "$br" "$msg"; then
        rm -f "$msg"
        echo "ERROR: 创建 $br 失败。"
        exit 1
    fi
    rm -f "$msg"

    if [ "$had" = yes ]; then
        echo "trace 分支已存在：$br（已追加一次 [init] 记录）"
    else
        echo "已创建 trace 分支：$br"
    fi
    g log --oneline -3 "$br" 2>/dev/null | sed 's/^/  /'
    maybe_push "$stuid" --verbose
    echo "OK：之后每次 make sim 都会在 $br 上追加一次空提交。"
    bash "$here/welcome.sh" init
    # 明确说一句"你还在原来的分支上"：留痕是后台动作，学生不需要、也不应该被搬到
    # trace 分支上去 —— 那个分支没有 upstream，站在上面 git pull 取新题会直接失败。
    echo "    （你当前仍在 $(g rev-parse --abbrev-ref HEAD 2>/dev/null) 分支：留痕只写 $br，不会切走你的工作区）"
    ;;

# -------------------------------------------------------------- commit
commit)
    stuid="${1:-}"; title="${2:-判分}"; results="${3:-}"
    in_repo || { echo "(不在 git 仓库：本次不创建 trace 提交)"; exit 0; }
    valid_stuid "$stuid" || { echo "(未填写 STUID：本次不创建 trace 提交，只判分)"; exit 0; }
    [ -s "$results" ] || { echo "(没有判分结论可留痕)"; exit 0; }

    br="trace/$stuid"

    n="$(wc -l < "$results" | tr -d ' ')"
    msg="$(mktemp)"
    {
        printf '[sim] %s %s（共 %s 题%s）\n' "$(date '+%F %T')" "$title" "$n" \
               "${scope:+，范围 $scope}"
        sed 's/^/  /' "$results"
    } > "$msg"

    if trace_commit "$br" "$msg"; then
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
    if ! g show-ref -q "refs/heads/$br"; then
        echo "本地没有 $br 分支（先 make init）"
        exit 1
    fi
    echo "===== 本地 $br ====="
    g log --oneline "$br" | sed 's/^/  /'
    echo "===== 云端 $remote/$br ====="
    if g rev-parse -q --verify "refs/remotes/$remote/$br" >/dev/null 2>&1; then
        g log --oneline "$remote/$br" | sed 's/^/  /'
        ahead="$(g rev-list --count "$remote/$br..$br" 2>/dev/null || echo 0)"
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
