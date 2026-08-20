# work/Makefile —— 作答区总入口（按周分发）
#
# 本目录是**学生的地盘**：每周一个子目录，里面只有作答文件与判分产物。
# 判分资源（harness / testbench / 测试数据 / 检查器 / 契约头文件）一律留在
# ../langs/<语言>/problems/<题号>/，判分时由 core/work.mk 把 PROBDIR 指过去。
#
# 于是：
#   - 学生 git pull 拿到新题，不会碰到自己的作答文件（两边不在同一目录）
#   - 出题人改题、改数据、改判据，学生侧零操作即生效
#   - 作答区里翻不到答案 —— 它从来没被拷进来过
#
# 周目录是热插拔的：新建 work/<周名>/Makefile（三五行，见 week1/Makefile）即被自动发现。
#
# 用法：make sim / status / take / list / clean（也可 make -C <周> … 只作用于某一周）

ROOT := $(realpath $(dir $(lastword $(MAKEFILE_LIST)))/..)
CORE := $(ROOT)/core

# ===== 热插拔发现：哪些子目录是"一周" =====
# 平铺布局的周在 work/<周>/Makefile，分拣布局的在 work/<周>/problem/Makefile，
# 而后者与单题作答目录 work/<周>/<题号>/Makefile 深度相同 —— 靠深度分不开，
# 所以按内容认：include week.mk 的才是周，include work.mk 的是单题。
WEEK_CANDIDATES := $(wildcard */Makefile */*/Makefile)
SUBDIRS := $(if $(WEEK_CANDIDATES),\
             $(patsubst %/Makefile,%,$(shell grep -l 'week\.mk' $(WEEK_CANDIDATES) 2>/dev/null)),)

SUBDIR_KIND := 作业周（work/<周>/Makefile）
TRACE_SCOPE := work

include $(CORE)/dispatch.mk

.PHONY: status take verify reopen weeks new-week help

# ===== 跨周的状态总览 =====
status:
	@if [ -z "$(SUBDIRS)" ]; then \
	  echo "work/ 下没有发现任何一周（周由 work/<周>/Makefile 定义）。"; \
	  echo "被误删的话从 git 取回：git checkout -- work/"; \
	  exit 1; \
	fi
	@for d in $(SUBDIRS); do \
	  echo "===== [$$d] ====="; \
	  $(MAKE) -s -C $$d status; \
	done

# ===== take：取模板 =====
# 不带 PID 时每周各取本周全部；带 PID 时只在声明了该题的那一周里取
# （否则其他周会各报一次"平台里没有这道题"，噪音大且看着像坏了）。
# 两条"什么都没做却退出 0"的路要显式报错，否则学生只看到一片空白，
# 没法区分"取好了"和"平台没找到东西可取"：
#   1. 一周都没发现 —— 常见原因是把周目录删了。周是由它的 Makefile 定义的
#      （见上面的热插拔发现），删掉就没有任何记录说这周存在过，得从 git 取回。
#   2. 给了 PID 但没有哪一周声明这道题 —— 打错题号，或这题不在本学期的周里。
take:
	@if [ -z "$(SUBDIRS)" ]; then \
	  echo "work/ 下没有发现任何一周。"; \
	  echo ""; \
	  echo "一周是由它自己的 Makefile 定义的（work/<周>/Makefile 或 work/<周>/problem/Makefile）,"; \
	  echo "平台不另存一份周名清单，所以那个文件被删掉后就没有记录可依据了。"; \
	  echo "老师发的周本来是随仓库一起提交的，从 git 取回即可："; \
	  echo "    git checkout -- work/"                                       ; \
	  echo "    git status work/          # 先看看是不是真的被删了"; \
	  echo ""; \
	  echo "确实要自己新建一周：照抄 work/week1/Makefile（平铺）"; \
	  echo "或 work/week5/problem/Makefile（分拣），改 WEEK 与 PROBLEMS 即可。"; \
	  exit 1; \
	fi
	@set -e; hit=0; \
	for d in $(SUBDIRS); do \
	  if [ -n "$(PID)" ]; then \
	    if $(MAKE) -s -C $$d print-PROBLEMS | tr ' ' '\n' | grep -qx "$(PID)"; then \
	      echo "===== [$$d] ====="; $(MAKE) -s -C $$d take PID="$(PID)" WELCOME=0; hit=1; \
	    fi; \
	  else \
	    echo "===== [$$d] ====="; $(MAKE) -s -C $$d take WELCOME=0; hit=1; \
	  fi; \
	done; \
	if [ "$$hit" = 0 ]; then \
	  echo "没有哪一周声明了题号 $(PID)。"; \
	  echo "本作答区现有的周与题目："; \
	  $(MAKE) -s weeks | sed 's/^/    /'; \
	  echo "（题库里全部题号：make -C .. langs 看各语言，或 ls ../langs/*/problems/）"; \
	  exit 1; \
	fi; \
	bash $(CORE)/judge/welcome.sh take

# ===== verify：重判各周 done/（回归）=====
# 一周失败不吞掉：整条命令的退出码要反映"有周没过"，否则脚本化使用时看不出问题。
# 但也不在第一周就中断 —— 回归的用途是一次看完全部。
verify:
	@if [ -z "$(SUBDIRS)" ]; then echo "work/ 下没有发现任何一周。"; exit 1; fi
	@rc=0; for d in $(SUBDIRS); do \
	  echo "===== [$$d] ====="; \
	  $(MAKE) -s -C $$d verify || rc=1; \
	done; exit $$rc

# ===== reopen：把一题从它所在那周的 done/ 挪回待做区 =====
# 与 take PID= 同一个思路：学生记得题号，不一定记得它属于哪一周，更不该为了
# 一条 reopen 先去数 work/ 下有几层目录。只在真正归档了这道题的那周里执行。
reopen:
	@if [ -z "$(PID)" ]; then echo "用法：make reopen PID=<题号>"; exit 1; fi
	@if [ -z "$(SUBDIRS)" ]; then echo "work/ 下没有发现任何一周。"; exit 1; fi
	@set -e; hit=0; \
	for d in $(SUBDIRS); do \
	  if [ -d "$$d/done/$(PID)" ]; then \
	    echo "===== [$$d] ====="; $(MAKE) -s -C $$d reopen PID="$(PID)"; hit=1; \
	  fi; \
	done; \
	if [ "$$hit" = 0 ]; then \
	  echo "没有哪一周的 done/ 里有题号 $(PID)。"; \
	  echo "只有分拣布局的周（STAGED := 1）才会归档；平铺布局的题一直在原地，直接改即可。"; \
	  echo "各周现状：make status"; \
	  exit 1; \
	fi

weeks:
	@if [ -z "$(SUBDIRS)" ]; then echo "（work/ 下还没有任何一周）"; exit 0; fi
	@for d in $(SUBDIRS); do $(MAKE) -s -C $$d list; done

# STAGED 缺省 0。根目录 `make new-week WEEK=… PROBLEMS=…` 会转到这里。
STAGED ?= 0
new-week:
	@if [ -z "$(WEEK)" ] || [ -z "$(PROBLEMS)" ]; then \
	  echo "用法：make new-week WEEK=week2 PROBLEMS='p12_x p13_y' [STAGED=0|1]"; \
	  echo "      题号必须已经在 langs/*/problems/ 里。建好后再 make release 发给学生。"; \
	  exit 1; \
	fi
	@bash $(CORE)/judge/new_week.sh "$(ROOT)" "$(WEEK)" "$(PROBLEMS)" "$(STAGED)"

help:
	@echo "作答区（judge 资源在 ../langs/，本目录只放作答文件）"
	@echo ""
	@echo "  make take            取下所有周全部题目的模板"
	@echo "  make take PID=<题号> 只取一题（自动找到它属于哪一周）"
	@echo "  make sim             判分所有周（留痕一次）"
	@echo "  make status          所有周的题目状态与最近判罚"
	@echo "  make weeks           列出所有周及其题目"
	@echo "  make verify          重判各周 done/（回归）"
	@echo "  make reopen PID=…    把一题从 done/ 挪回待做区（自动找到它属于哪一周）"
	@echo "  make new-week WEEK=week2 PROBLEMS='p12_x p13_y'   新建一周（教师）"
	@echo "  make clean           清理判分产物"
	@echo ""
	@echo "  make -C <周> sim         只判某一周"
	@echo "  make -C <周> help        某一周的全部用法（含 reopen / verify）"
	@echo "  make -C <周>/<题号> sim  只判某一题"
	@echo "  make -C <周>/<题号> spec 看某题的题面与接口契约"
	@echo ""
	@echo "退出码：make sim 判出 WA 也退 0（判罚是结果不是故障）；make verify 有题回归失败退非 0。"
	@echo ""
	@echo "已有的周："
	@$(MAKE) -s list
