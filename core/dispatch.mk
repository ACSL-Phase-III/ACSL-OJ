# core/dispatch.mk —— 语言无关的递归分发层
#
# 被两处 include，逻辑完全相同，只是 SUBDIRS 不同：
#   顶层 Makefile：SUBDIRS = 各语言模块（langs/c、langs/verilog……）
#   语言 Makefile：SUBDIRS = 该语言的各题目（problems/p01_gcd……）
#
# 汇总与留痕的规则（关键：只在最外层留一次痕）：
#   - 若上层传入了 RUNLOG，说明自己是中间层：把结论继续往同一个 RUNLOG 里汇总，不留痕；
#   - 若 RUNLOG 为空，说明自己就是本次判分的最外层：自建汇总文件，跑完后留痕一次。
# 这样 `make sim`（全平台）、`make -C langs/c sim`（单语言）、
# `make -C langs/c/problems/p01_gcd sim`（单题）都恰好留痕一次。
#
# 调用方需先定义：
#   SUBDIRS      要递归的子目录列表（相对本 Makefile）
#   SUBDIR_KIND  子目录的种类名，用于提示文案（如 "语言模块" / "题目"）
#   TRACE_SCOPE  留痕范围标签（如 all / c）；只判单题时由 core/trace.mk
#                自动补成 <语言>:<题号>，分发层不必操心

CORE ?= $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

BUILD       := build
SUBDIR_KIND ?= 子目录
TRACE_SCOPE ?= all

include $(CORE)/trace.mk

# 默认目标必须显式声明：core/trace.mk 里第一个规则是 trace-push，而它在下面的 sim
# 之前被 include —— 不写这行，裸 `make` 会变成 `make trace-push`（一次联网推送）。
.DEFAULT_GOAL := sim

# 本层自建的汇总文件（仅当自己是最外层时使用）
OWN_RUNLOG := $(abspath $(BUILD)/sim-run.txt)

# 往下传递的汇总文件：上层给了就用上层的，否则用自己的
PASS_RUNLOG = $(if $(RUNLOG),$(RUNLOG),$(OWN_RUNLOG))

.PHONY: sim style clean init help list artifacts

# ===== sim：递归判分 =====
sim:
	@if [ -z "$(SUBDIRS)" ]; then echo "没有找到任何$(SUBDIR_KIND)"; exit 1; fi
	@$(if $(RUNLOG),:,mkdir -p $(BUILD) && rm -f $(OWN_RUNLOG))
	@for d in $(SUBDIRS); do \
	  echo "===== [$$d] ====="; \
	  $(MAKE) -s -C $$d sim RUNLOG=$(PASS_RUNLOG) || { \
	    echo "[$$d] 判分中断（exit $$?）"; exit 1; }; \
	done
	@$(if $(RUNLOG),:,SCOPE="$(TRACE_SCOPE)" $(TRACE_SH) commit "$(STUID)" "判分汇总" "$(OWN_RUNLOG)")

# ===== style：递归风格检查 =====
style:
	@if [ -z "$(SUBDIRS)" ]; then echo "没有找到任何$(SUBDIR_KIND)"; exit 1; fi
	@for d in $(SUBDIRS); do \
	  echo "===== [$$d] ====="; \
	  $(MAKE) -s -C $$d style || exit 1; \
	done

clean:
	@for d in $(SUBDIRS); do $(MAKE) -s -C $$d clean; done
	@rm -rf $(BUILD)

# ===== artifacts：递归编译"要随作业发放的判分件" =====
# 出题人改完判据后跑一次。递归范围**不是** SUBDIRS：根目录的 SUBDIRS 在有作业周时
# 是 work/，而判分件永远属于题库那一侧，编到作答区里毫无意义。所以单独一个变量，
# 由根 Makefile 覆盖成 langs/*，其余层默认跟着 SUBDIRS 走。
#
# 某道题"没有可编译的判分件"（io 模式，或仍按源码发放）不算失败 —— 它照常打印一行
# 说明并继续，否则全量编译会卡在第一道 io 题上。真正的编译错误才中断。
ARTIFACT_DIRS ?= $(SUBDIRS)

artifacts:
	@if [ -z "$(ARTIFACT_DIRS)" ]; then echo "没有$(SUBDIR_KIND)，跳过 artifacts。"; exit 0; fi
	@for d in $(ARTIFACT_DIRS); do \
	  $(MAKE) -s -C $$d artifacts || { echo "[$$d] 判分件编译失败"; exit 1; }; \
	done

# ===== init：初始化 trace 分支（各层等价，都作用于同一个仓库）=====
init:
	@$(TRACE_SH) init "$(STUID)" "$(NAME)"

list:
	@for d in $(SUBDIRS); do echo "  $$d"; done
