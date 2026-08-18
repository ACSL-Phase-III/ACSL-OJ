# core/trace.mk —— trace 留痕的 Makefile 侧接线（实现见 core/judge/trace.sh）
#
# 被 core/engine.mk（题目层）与 core/dispatch.mk（分发层）共同 include。
# 设计要点：留痕逻辑全在 shell 脚本里，这里只负责把变量传进去，
# 避免了原先"单行超长 shell 内嵌进 recipe"的写法。

CORE ?= $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

# 学员信息取自平台根目录的 student.mk：填一次，所有语言与所有层级（平台/语言/单题）通用。
# 用 -include 容错，缺文件时退化为下面的默认值（只判分、不留痕）。
-include $(CORE)/../student.mk

# 学员信息与云端设置的默认值（命令行传参可覆盖，如 make sim AUTOPUSH=0）
STUID        ?= 000000
NAME         ?= 未填写
TRACE_REMOTE ?= origin
AUTOPUSH     ?= 1

export STUID NAME TRACE_REMOTE AUTOPUSH

TRACE_SH := bash $(CORE)/judge/trace.sh

# 题目层用：被上层递归调用时（RUNLOG 非空）只把结论追加进汇总文件，
# 由上层合并成一次提交；单题判分时自己留痕一次。
define trace_or_collect
if [ -n "$(RUNLOG)" ]; then \
  cat $(VERDICT) >> "$(RUNLOG)"; \
else \
  SCOPE="$(TRACE_SCOPE)" $(TRACE_SH) commit "$(STUID)" "判分汇总" "$(VERDICT)"; \
fi
endef

.PHONY: trace-push trace-log

trace-push:
	@bash $(CORE)/judge/trace_push.sh "$(TRACE_REMOTE)" "$(STUID)" --verbose

trace-log:
	@$(TRACE_SH) log "$(STUID)"
