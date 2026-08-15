# verilog-oj 根 Makefile
#
# 仿 AM（AbstractMachine）的做法：每个题目目录放一个子 Makefile，
# 根 Makefile 自动递归查找 problems/ 下所有带 Makefile 的题目，
# 把目标（sim / style / clean）逐个分发到各子目录执行。
# 新增题目只需在新题目录里放一个自己的 Makefile，无需改动本文件。
#
# 用法：
#   make sim        一键判分全部题目（无作答文件或判分失败的题目会报错并以非零退出）
#   make style      一键风格检查全部题目
#   make clean      清理各题仿真产物
#   make help       查看用法
#
# 单题：make -C problems/p03_adder4 sim   （各子 Makefile 的写法见题目目录内）

PROBLEMS := $(patsubst problems/%/Makefile,%,$(wildcard problems/*/Makefile))

.PHONY: sim style clean help

sim:
	@if [ -z "$(PROBLEMS)" ]; then echo "没有找到任何题目（problems/*/Makefile）"; exit 1; fi
	@for p in $(PROBLEMS); do \
	  echo "===== [$$p] ====="; \
	  $(MAKE) -s -C problems/$$p sim || { echo "[$$p] 判分未通过（exit $$?）"; exit 1; }; \
	done

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
	@echo "verilog-oj 一键判分"
	@echo "  自动发现题目: $(PROBLEMS)"
	@echo "  make sim   递归判分全部题目（子目录用各自 Makefile，硬编码本题目标）"
	@echo "  make style 递归风格检查全部题目"
	@echo "  make clean 清理全部仿真产物"
	@echo "  make -C problems/<pid> sim   只判某一题"