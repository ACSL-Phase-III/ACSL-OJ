# core/trace.mk —— trace 留痕的 Makefile 侧接线（实现见 core/judge/trace.sh）
#
# 被 core/engine.mk（题目层）与 core/dispatch.mk（分发层）共同 include。
# 设计要点：留痕逻辑全在 shell 脚本里，这里只负责把变量传进去，
# 避免了原先"单行超长 shell 内嵌进 recipe"的写法。

CORE ?= $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

# 学员信息取自平台根目录的 student.mk：填一次，所有语言与所有层级（平台/语言/单题）通用。
# 用 -include 容错，缺文件时退化为下面的默认值（只判分、不留痕）。
#
# student.mk 本身**不被 git 跟踪**（见 .gitignore），仓库里跟踪的是 student.mk.example。
# 理由是逐周发布：这个文件每个学生都要改成自己的学号姓名，若它被跟踪，老师哪天动一下
# （比如加一个新变量），全班的 git pull 就会一起撞
#     error: Your local changes to the following files would be overwritten by merge
# 而且撞在"取本周新题"这一步上，学生除了 git stash 无从下手。
#
# 首次使用时从模板复制一份。必须在 parse 期做（$(shell) 而非配方）：本文件正要
# -include 它，等到配方执行才生成的话，这一次 make 已经读不到了，学生得莫名其妙地
# 跑两遍 make init 才生效。cp -n 保证绝不覆盖学生已填好的那份。
$(if $(wildcard $(CORE)/../student.mk),,\
  $(if $(wildcard $(CORE)/../student.mk.example),\
    $(shell cp -n $(CORE)/../student.mk.example $(CORE)/../student.mk 2>/dev/null)))

-include $(CORE)/../student.mk

# 学员信息与云端设置的默认值（命令行传参可覆盖，如 make sim AUTOPUSH=0）
STUID        ?= 000000
NAME         ?= 未填写
TRACE_REMOTE ?= origin
AUTOPUSH     ?= 1

export STUID NAME TRACE_REMOTE AUTOPUSH

TRACE_SH := bash $(CORE)/judge/trace.sh

# ---- 留痕范围标签 ----
# 分发层（core/dispatch.mk 与各语言模块 Makefile）自己设了 all / c / verilog；
# 因为那里的赋值在 include 本文件之前，下面的 ?= 不会覆盖它。
# 只判单题时没人设过它，于是补成 <语言>:<题号>（如 verilog:p03_adder4），
# 否则提交信息只有"共 1 题"，看不出判的是哪一题。
# 用 ?= 而非 := ：本文件被 engine.mk include 时 PID 已知，但保持惰性求值更稳妥。
TRACE_SCOPE ?= $(if $(LANG_SLUG),$(LANG_SLUG):,)$(PID)

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
