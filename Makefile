# ACSL-OJ 平台顶层 Makefile
#
# 本文件不含任何语言细节：语言模块是热插拔的，往 langs/ 里放一个带 lang.mk 的目录
# 就会被自动发现，删掉目录即从平台移除，无需改动本文件或判分核心。
#
# 分层：
#   student.mk   学员信息（全平台共用，填一次）
#   core/        语言无关的判分核心（判罚链路 + 递归分发 + trace 留痕）
#   langs/<lang> 语言模块（工具链钩子 + 风格检查 + 题库，含作答模板）
#   work/        作答区（学生的地盘，按周组织，只放作答文件）
#
# 用法见 make help；平台整体说明见 README.md，各语言说明见 langs/<lang>/README.md。

ROOT := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
CORE := $(ROOT)/core

# 注意：student.mk 由 core/trace.mk 统一 include（各层级共用），此处无需重复。

# ===== 热插拔发现：任何含 lang.mk 的 langs/ 子目录都是一个语言模块 =====
LANGS     := $(patsubst langs/%/lang.mk,%,$(wildcard langs/*/lang.mk))
LANG_DIRS := $(patsubst %,langs/%,$(LANGS))

# ===== 作答区发现 =====
# 平铺布局的周在 work/<周>/Makefile，分拣布局的在 work/<周>/problem/Makefile；
# 后者与单题作答目录深度相同，所以按内容认（include week.mk 的才是一周）。
WEEK_CANDIDATES := $(wildcard work/*/Makefile work/*/*/Makefile)
WORK_WEEKS := $(if $(WEEK_CANDIDATES),\
                $(patsubst %/Makefile,%,$(shell grep -l 'week\.mk' $(WEEK_CANDIDATES) 2>/dev/null)),)

# ===== make sim 的范围 =====
# 有作业周就判作业（学生的常态：改完代码在根目录 make sim）；
# 没有作业周就判题库自身（出题人的常态：改完题目做全量自测）。
# 两个范围永远各有一个显式入口：make work / make sim-langs，不必依赖上面的判断。
#
# 范围由 RANGE 选择，而且**只有本文件认这个变量**：
#     RANGE 留空   按上面那条规则自动选
#     RANGE=work   判作答区
#     RANGE=langs  判题库自身
#
# 为什么不直接 $(MAKE) sim SUBDIRS=...：命令行变量会经 MAKEFLAGS 传给**每一层**
# 递归 make，于是 langs/c/Makefile 里的 SUBDIRS := problems/* 也被一并覆盖，
# 判分会从 langs/c/ 里再去找 langs/c/，报 "No such file or directory" 后中断 ——
# make sim-langs 与 make work 曾因此完全不工作。
# RANGE 同样会传下去，但下层没有任何人读它，所以各层照旧用自己算出来的 SUBDIRS。
RANGE ?= $(if $(WORK_WEEKS),work,langs)

ifeq ($(RANGE),work)
  SUBDIRS     := work
  SUBDIR_KIND := 作答区（work/）
  TRACE_SCOPE := work
  SIM_SCOPE   := 作答区 work/（$(words $(WORK_WEEKS)) 周）
else ifeq ($(RANGE),langs)
  SUBDIRS     := $(LANG_DIRS)
  SUBDIR_KIND := 语言模块（langs/*/lang.mk）
  TRACE_SCOPE := langs
  SIM_SCOPE   := 题库自身 langs/（$(words $(LANGS)) 个语言模块）
else
  $(error RANGE 只能是 work 或 langs（当前：$(RANGE)）)
endif

# 判分件属于题库那一侧：即便本次 SUBDIRS 是 work/，make artifacts 也只编 langs/*。
ARTIFACT_DIRS := $(LANG_DIRS)

include $(CORE)/dispatch.mk

.PHONY: langs weeks work sim-langs status take verify reopen release new-week teacher-remotes help

# ===== 两个显式范围入口 =====
# 通过 RANGE 重新进入本文件（见上面 RANGE 的注释：不能用 SUBDIRS= 覆盖，
# 那会连带覆盖每一层递归的 SUBDIRS）。
work:
	@if [ -z "$(WORK_WEEKS)" ]; then \
	  echo "work/ 下还没有任何一周。新建 work/<周名>/Makefile 即可（照抄 work/week1/Makefile）。"; \
	  exit 1; \
	fi
	@$(MAKE) --no-print-directory sim RANGE=work

sim-langs:
	@if [ -z "$(LANGS)" ]; then \
	  echo "langs/ 下还没有任何语言模块。"; exit 1; \
	fi
	@$(MAKE) --no-print-directory sim RANGE=langs

langs:
	@if [ -z "$(LANGS)" ]; then echo "（langs/ 下还没有任何语言模块）"; exit 0; fi
	@for l in $(LANGS); do \
	  n="$$(ls -d langs/$$l/problems/*/ 2>/dev/null | wc -l | tr -d ' ')"; \
	  printf '  %-10s %s 题\t%s\n' "$$l" "$$n" "langs/$$l/README.md"; \
	done

weeks:
	@if [ -z "$(WORK_WEEKS)" ]; then echo "（work/ 下还没有任何一周）"; exit 0; fi
	@for w in $(WORK_WEEKS); do $(MAKE) -s -C $$w list; done

# ===== 作答区专用命令：从根目录转发 =====
# 学生在仓库根目录敲 make status / take / verify / reopen 是很自然的事（判分本来
# 就能在根目录跑），没有这些转发只会得到 "No rule to make target"，看着像平台坏了。
# 这几件事只对作答区有意义，所以固定作用于 work/，不受 RANGE 影响。
status:
	@if [ ! -d work ]; then echo "没有 work/ 目录（作答区）。"; exit 1; fi
	@$(MAKE) -s -C work status

take:
	@if [ ! -d work ]; then echo "没有 work/ 目录（作答区）。"; exit 1; fi
	@$(MAKE) -s -C work take PID="$(PID)"

verify:
	@if [ ! -d work ]; then echo "没有 work/ 目录（作答区）。"; exit 1; fi
	@$(MAKE) -s -C work verify

reopen:
	@if [ ! -d work ]; then echo "没有 work/ 目录（作答区）。"; exit 1; fi
	@$(MAKE) -s -C work reopen PID="$(PID)"

# ===== 教师：每周发布 =====
# release 只在根目录有意义（要看整棵题库 + 写学生分支），不往下递归。
release:
	@bash $(CORE)/judge/release.sh "$(ROOT)" "$(BRANCH)"

teacher-remotes:
	@bash $(CORE)/judge/teacher_remotes.sh "$(ROOT)" "$(TEA)" "$(PUBLIC)"

new-week:
	@if [ ! -d work ]; then echo "没有 work/ 目录（作答区）。"; exit 1; fi
	@$(MAKE) -s -C work new-week WEEK="$(WEEK)" PROBLEMS="$(PROBLEMS)" STAGED="$(STAGED)"

help:
	@echo "ACSL-OJ —— 多语言本地判分平台"
	@echo ""
	@echo "已装载的语言模块："
	@$(MAKE) -s langs
	@echo "作答区："
	@if [ -z "$(WORK_WEEKS)" ]; then echo "  （空）"; else \
	  for w in $(WORK_WEEKS); do echo "  $$w"; done; fi
	@echo ""
	@echo "第一次使用：在 student.mk 填写 STUID / NAME，然后 make init"
	@echo ""
	@echo "  make take         取本周作业的模板到作答区（make take PID=<题号> 只取一题）"
	@echo "  make sim          判分 —— 本次范围：$(SIM_SCOPE)"
	@echo "  make status       作答区每题的状态与最近一次判罚"
	@echo "  make verify       重判各周 done/ 里已通过的题（回归）"
	@echo "  make reopen PID=… 把一题从 done/ 挪回待做区重做"
	@echo "  make work         判分作答区 work/（所有周，留痕一次）"
	@echo "  make sim-langs    判分题库自身 langs/（出题人全量自测）"
	@echo "  make artifacts         编出要随作业发放的判分件（出题人）"
	@echo "  make teacher-remotes   第一次：origin=私有 DEV，public=公开 ACSL-OJ"
	@echo "  make release           本机编二进制、写本地 main（PUSH=1 则推 public）"
	@echo "  make new-week WEEK=week2 PROBLEMS='p12_x p13_y'   新建一周脚手架
	@echo "  make style        风格检查（范围同 make sim）"
	@echo "  make clean        清理判分产物"
	@echo "  make langs        列出已装载的语言模块"
	@echo "  make weeks        列出作答区的周与题目"
	@echo "  make trace-push   手动把 trace 分支同步到云端（离线补推）"
	@echo "  make trace-log    查看本地与云端的判分历史对照"
	@echo ""
	@echo "学生（在作答区做作业）："
	@echo "  make -C work take                    取下所有周的题目模板"
	@echo "  make -C work/week1 sim               只判某一周"
	@echo "  make -C work/week1 status            看某一周每题的状态"
	@echo "  make -C work/week1/p01_class_stat sim   只判某一题"
	@echo "  make -C work/week1/p01_class_stat spec  看某题的题面"
	@echo "  make -C work help                    作答区的全部用法"
	@echo ""
	@echo "出题人（在题库里自测，答案与判分资源同目录）："
	@echo "  make -C langs/<lang> sim                  只判某个语言的题库"
	@echo "  make -C langs/<lang>/problems/<pid> sim   只判题库里的某一题"
	@echo ""
	@echo "  make sim AUTOPUSH=0   本次只在本地留痕，不联网"
	@echo ""
	@echo "判罚：AC 正确 / WA 失配 / CE 编译错 / SE 风格错 / TLE 超时 / RE 运行错"
	@echo "新增语言模块的做法见 core/PLUGIN.md；作答区布局见 work/README.md"
