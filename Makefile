# verilog-oj 根 Makefile
#
# 仿 AM / PA 的做法：每题目录放一个子 Makefile（统一判分逻辑在 make/common.mk），
# 根 Makefile 自动递归查找 problems/ 下所有带 Makefile 的题目并分发目标。
# trace（PA 风格）：每次 make sim 都在分支 trace/<学号> 上创建一个空提交留痕，
# 最终检查看的就是每个学生的 trace/<学号> 分支的提交历史。

# ===================== 学员信息（请先填写，再 make init）=====================
# 每次判分会在 trace/<学号> 分支创建空提交（提交信息含判罚汇总）。
STUID := 000000
NAME  := 未填写
# =============================================================================

BUILD := build

export STUID NAME

PROBLEMS := $(patsubst problems/%/Makefile,%,$(wildcard problems/*/Makefile))

.PHONY: sim style clean init help

# ===== init：初始化 trace 分支 trace/<学号>（PA 风格，检查这个分支的历史）=====
init:
	@if [ "$(STUID)" = "000000" ] || [ "$(NAME)" = "未填写" ]; then \
	  echo "ERROR: 请先在根 Makefile 头部填写 STUID 与 NAME，例如："; \
	  echo "        STUID := 211220042"; \
	  echo "        NAME  := 张三"; \
	  exit 1; \
	fi
	@if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
	  echo "ERROR: 当前不在 git 仓库内，trace 分支要求 git 环境。"; \
	  exit 1; \
	fi
	@if git show-ref -q "refs/heads/trace/$(STUID)"; then \
	  echo "trace 分支已存在：trace/$(STUID)（当前 HEAD 已切换到该分支）"; \
	  git checkout "trace/$(STUID)" >/dev/null 2>&1 || true; \
	else \
	  git switch -c "trace/$(STUID)" >/dev/null 2>&1 || git checkout -b "trace/$(STUID)" >/dev/null 2>&1 || { \
	    echo "ERROR: 创建 trace/$(STUID) 分支失败。"; exit 1; }; \
	  echo "已创建 trace 分支：trace/$(STUID)"; \
	fi
	@git commit --allow-empty -m "[init] trace 初始化 ($(STUID) $(NAME)) $$(date '+%F %T')" >/dev/null 2>&1 || true; \
	git log --oneline -3 2>/dev/null | sed 's/^/  /'; \
	echo "OK：之后每次 make sim 都会在 trace/$(STUID) 上追加一次空提交。"

# ===== sim：递归判分全部题目，最后在 trace/<学号> 合并成一次空提交 =====
sim:
	@if [ -z "$(PROBLEMS)" ]; then echo "没有找到任何题目（problems/*/Makefile）"; exit 1; fi
	@rm -f $(BUILD)/sim-run.txt; mkdir -p $(BUILD)
	@for p in $(PROBLEMS); do \
	  echo "===== [$$p] ====="; \
	  $(MAKE) -s -C problems/$$p sim ROOT_SIM=1 RUNLOG=$(abspath $(BUILD)/sim-run.txt) || { \
	    echo "[$$p] 判分未通过（exit $$?）"; exit 1; }; \
	done
	@if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && [ -n "$(STUID)" ] && [ "$(STUID)" != "000000" ]; then \
	  ( git switch -c "trace/$(STUID)" >/dev/null 2>&1 || git checkout -b "trace/$(STUID)" >/dev/null 2>&1 ) || \
	  ( git checkout "trace/$(STUID)" >/dev/null 2>&1 ) || true; \
	  { echo "[sim] $$(date '+%F %T') 判分汇总（共 $$(wc -l < $(BUILD)/sim-run.txt) 题）"; \
	    sed 's/^/  /' $(BUILD)/sim-run.txt; } > $(BUILD)/sim-msg.txt; \
	  if git commit --allow-empty -F $(BUILD)/sim-msg.txt >/dev/null 2>&1; then \
	    echo "trace: 已在 trace/$(STUID) 留痕（空提交，信息含判分汇总）"; \
	  else \
	    echo "trace: 留痕失败（可忽略，仅影响留痕）"; \
	  fi; \
	else \
	  echo "(未填写 STUID 或不在 git 仓库：本次不创建 trace 提交)"; \
	fi

style:
	@if [ -z "$(PROBLEMS)" ]; then echo "没有找到任何题目（problems/*/Makefile）"; exit 1; fi
	@for p in $(PROBLEMS); do \
	  echo "===== [$$p] ====="; \
	  $(MAKE) -s -C problems/$$p style || exit 1; \
	done

clean:
	@for p in $(PROBLEMS); do \
	  $(MAKE) -s -C problems/$$p clean; \
	done

help:
	@echo "verilog-oj 一键判分（AM/PA 风格，trace 即查每个学生的 git 分支）"
	@echo "  第一次：在 Makefile 头部填写 STUID/NAME，然后 make init（创建分支 trace/<学号>）"
	@echo "  make sim    递归判分全部题目，每次在 trace/<学号> 上创建一次空提交（信息含判分汇总）"
	@echo "  make style  递归风格检查全部题目"
	@echo "  make clean  清理全部判分产物（build/）"
	@echo "  make -C problems/<pid> sim   只判某一题（也会单独留痕一次空提交）"
	@echo "  检查判分历史：git log trace/<学号> --oneline"
	@echo "  判罚：AC 正确 / WA 失配 / CE 编译错 / SE 风格错 / RE 运行错"