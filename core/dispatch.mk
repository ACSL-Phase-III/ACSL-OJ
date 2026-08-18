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
#   TRACE_SCOPE  留痕范围标签（如 all / c）

CORE ?= $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

BUILD       := build
SUBDIR_KIND ?= 子目录
TRACE_SCOPE ?= all

include $(CORE)/trace.mk

# 本层自建的汇总文件（仅当自己是最外层时使用）
OWN_RUNLOG := $(abspath $(BUILD)/sim-run.txt)

# 往下传递的汇总文件：上层给了就用上层的，否则用自己的
PASS_RUNLOG = $(if $(RUNLOG),$(RUNLOG),$(OWN_RUNLOG))

.PHONY: sim style clean init help list

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

# ===== init：初始化 trace 分支（各层等价，都作用于同一个仓库）=====
init:
	@$(TRACE_SH) init "$(STUID)" "$(NAME)"

list:
	@for d in $(SUBDIRS); do echo "  $$d"; done
