# make/common.mk —— verilog-oj 统一判分引擎（被每个题目子 Makefile include，AM 风格）
#
# 使用方法：在题目子 Makefile 中先声明 PID 与 MODULE，再 include 本文件。
#   PID    := p03_adder4      # 题目目录名
#   MODULE := adder4          # 学生作答模块名（作答文件必须同名：adder4.v）
#   ROOT   := ../..           # 指向 verilog-oj 根目录
#   include $(ROOT)/make/common.mk
#
# 提供目标：sim（完整判分）/ style / clean。
#
# 判分链：风格检查(SE) -> 编译(CE) -> 仿真解析(AC/WA/RE)。
# trace（PA 风格）：每次仿真在 git 分支 trace/<学号> 上创建一个空提交留痕。
# - 被根 Makefile 调用时（ROOT_SIM=1）：只把本次结论追加到 $(RUNLOG)，由根 Makefile 合并成一次空提交；
# - 单独 `make -C problems/<pid> sim` 时：自行在 trace/<学号> 创建一个空提交。

ROOT  ?= ../..
PID   ?= unknown
MODULE?= unknown

SRC  := $(MODULE).v
TB   := test/tb.v
BUILD:= build

.PHONY: sim style clean

# trace 空提交（单独判分某题时使用；被根 Makefile 调用时不会触发）。
# 注意：只做空的 commit（--allow-empty），不 git add 任何文件；
# 必须是单行纯 shell 文本（不含 tab/@/换行），以便安全内嵌进长 recipe 行。
define trace_commit
{ git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0; [ -n "$(STUID)" ] && [ "$(STUID)" != "000000" ] || exit 0; { git switch -c "trace/$(STUID)" >/dev/null 2>&1 || git checkout -b "trace/$(STUID)" >/dev/null 2>&1; } || git checkout "trace/$(STUID)" >/dev/null 2>&1 || true; git commit --allow-empty -m "[sim] $$(date '+%F %T') $$line" >/dev/null 2>&1 && echo "trace: trace/$(STUID) 已留痕（空提交：$$line）" || echo "trace: 留痕失败（非 git 仓库或提交异常，可忽略）"; }
endef

# ===== sim：完整评分链路（风格 -> 编译 -> 仿真解析 -> trace 留痕）=====
sim: mkbuild $(SRC) $(TB)
	@bash $(ROOT)/judge/style_check.sh $(SRC) > $(BUILD)/style.log 2>&1; \
	if [ $$? -ne 0 ]; then \
	  line="[$(PID)] SE (Style Error)"; \
	  echo "$$line"; echo "---- 风格违规详情 ----"; cat $(BUILD)/style.log; \
	elif ! iverilog -g2012 -o $(BUILD)/sim.vvp $(TB) $(SRC) 2> $(BUILD)/compile.log; then \
	  line="[$(PID)] CE (Compile Error)"; \
	  echo "$$line"; echo "---- iverilog 编译错误 ----"; sed -n '1,20p' $(BUILD)/compile.log; \
	else \
	  vvp $(BUILD)/sim.vvp > $(BUILD)/sim.log 2>&1; rc=$$?; \
	  verdict="$$(grep -E '^JUDGE: (PASS|FAIL [0-9]+)$$' $(BUILD)/sim.log | tail -n1)"; \
	  ntests="$$(grep -E '^JUDGE-COUNT:' $(BUILD)/sim.log | tail -n1 | sed 's/^JUDGE-COUNT:[[:space:]]*//')"; \
	  if [ "$$rc" -ne 0 ] || [ -z "$$verdict" ] || [ -z "$$ntests" ]; then \
	    line="[$(PID)] RE (Run Error)"; \
	    echo "$$line"; echo "---- vvp 输出 ----"; sed -n '1,20p' $(BUILD)/sim.log; \
	  else \
	    case "$$verdict" in \
	      "JUDGE: PASS") line="[$(PID)] AC ($$ntests/$$ntests tests)";; \
	      *) nfail="$${verdict##* }"; line="[$(PID)] WA ($$nfail/$$ntests tests)";; \
	    esac; \
	    echo "$$line"; \
	    case "$$line" in \
	      *" WA "*) echo "---- 失配样例（in ... got=... want=...）----"; grep '^JUDGE-MISMATCH:' $(BUILD)/sim.log;; \
	    esac; \
	  fi; \
	fi; \
	if [ -n "$(ROOT_SIM)" ]; then \
	  printf '%s\n' "$$line" >> "$(RUNLOG)"; \
	else \
	  $(call trace_commit); \
	fi

# ===== style：仅风格检查 =====
style: mkbuild $(SRC)
	@bash $(ROOT)/judge/style_check.sh $(SRC) && echo "[$(PID)] style OK"

# ===== 公共辅助 =====
mkbuild:
	@mkdir -p $(BUILD)

clean:
	@rm -rf $(BUILD)

$(SRC):
	@echo "ERROR: 缺少 $(SRC)（模板/作答文件），请确认 problems/$(PID)/ 目录完整（含 $(SRC) 与 test/）。"; exit 1

$(TB):
	@echo "ERROR: 缺少 $(TB)（判分端 testbench，不随题目发放），请确认 problems/$(PID)/test/ 存在。"; exit 1