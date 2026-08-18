# core/engine.mk —— 语言无关的判分引擎
#
# 本文件不含任何语言/工具链细节。它只负责固定的判罚链路与产物布局：
#
#     风格检查(SE) --失败--> 结束
#          |通过
#     编译(CE)     --失败--> 结束
#          |通过
#     运行 -> core/judge/verdict.sh 解析协议 -> AC / WA / TLE / RE
#
# 语言插件（langs/<lang>/lang.mk）通过下面这组钩子接入，缺一即报错：
#
#   必填变量：
#     LANG_NAME      语言显示名（如 C / Verilog）
#     SRC_EXT        作答文件扩展名（如 .c / .v），SRC 由 MODULE 拼出
#     STYLE_CMD      风格检查命令；退出码非 0 判 SE，输出即违规详情
#     COMPILE_CMD    编译命令；退出码非 0 判 CE，stderr 应重定向到 $(COMPILE_LOG)
#     RUN_CMD        运行命令；须把被判程序的输出写进 $(RUN_LOG)，并置 shell 变量 rc
#
#   可选变量：
#     EXTRA_NEEDS    除 SRC 外的前置依赖（缺失即报错退出，如 tb / harness / 数据目录）
#     RE_PATTERN     命中即判 RE 的正则（如 sanitizer 报告），交给 verdict.sh
#     RE_LABEL       上述 RE 的中文说明
#     TIMEOUT        单次运行时限（秒），仅用于 TLE 文案
#     MISSING_HINT_<路径> 某个前置依赖缺失时的定制提示
#
# 题目子 Makefile 只声明 PID / MODULE（+ 语言自有的可选项），然后 include langs/<lang>/lang.mk，
# 由后者 include 本文件。

CORE  ?= $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
PID   ?= unknown
MODULE?= unknown

BUILD       := build
SRC         := $(MODULE)$(SRC_EXT)
STYLE_LOG   := $(BUILD)/style.log
COMPILE_LOG := $(BUILD)/compile.log
RUN_LOG     := $(BUILD)/run.log
VERDICT     := $(BUILD)/verdict.txt

# ===== 钩子完整性检查：插件写漏了要在第一时间报错，而不是判出莫名其妙的结论 =====
$(if $(LANG_NAME),,$(error core/engine.mk: 语言插件未定义 LANG_NAME))
$(if $(SRC_EXT),,$(error core/engine.mk: 语言插件未定义 SRC_EXT))
$(if $(STYLE_CMD),,$(error core/engine.mk: 语言插件未定义 STYLE_CMD))
$(if $(COMPILE_CMD),,$(error core/engine.mk: 语言插件未定义 COMPILE_CMD))
$(if $(RUN_CMD),,$(error core/engine.mk: 语言插件未定义 RUN_CMD))

# verdict.sh 的环境（导出给 recipe 用）
export RE_PATTERN RE_LABEL TIMEOUT

include $(CORE)/trace.mk

.PHONY: sim style clean mkbuild

# ===== sim：完整判分链路 =====
# 三段短路：SE 后不编译，CE 后不运行。结论行由 verdict.sh 写进 $(VERDICT)，
# 再按调用来源决定汇总进 RUNLOG（被上层递归调用）还是自行留痕（单题判分）。
sim: mkbuild $(SRC) $(EXTRA_NEEDS)
	@if ! $(STYLE_CMD) > $(STYLE_LOG) 2>&1; then \
	  printf '%s\n' "[$(PID)] SE (Style Error)" | tee $(VERDICT); \
	  echo "---- 风格违规详情 ----"; cat $(STYLE_LOG); \
	elif ! $(COMPILE_CMD); then \
	  printf '%s\n' "[$(PID)] CE (Compile Error)" | tee $(VERDICT); \
	  echo "---- 编译错误 ----"; sed -n '1,20p' $(COMPILE_LOG); \
	else \
	  $(RUN_CMD); \
	  bash $(CORE)/judge/verdict.sh "$(PID)" "$(RUN_LOG)" "$$rc" "$(VERDICT)"; \
	fi
	@$(call trace_or_collect)

# ===== style：只做风格检查 =====
style: mkbuild $(SRC)
	@$(STYLE_CMD) && echo "[$(PID)] style OK"

mkbuild:
	@mkdir -p $(BUILD)

clean:
	@rm -rf $(BUILD)

# ===== 前置依赖缺失时的报错 =====
# MISSING_HINT_<文件名> 可由插件定制；没定制就用通用文案。
$(SRC):
	@echo "ERROR: 缺少作答文件 $(SRC)，请确认题目目录 $(PID)/ 完整。"; exit 1

$(EXTRA_NEEDS):
	@hint='$(MISSING_HINT_$@)'; \
	if [ -n "$$hint" ]; then echo "ERROR: $$hint"; \
	else echo "ERROR: 缺少判分端资源 $@（$(LANG_NAME) 题目 $(PID) 的必需文件，不随题目发放）。"; fi; \
	exit 1
