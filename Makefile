# ACSL-OJ 平台顶层 Makefile
#
# 本文件不含任何语言细节：语言模块是热插拔的，往 langs/ 里放一个带 lang.mk 的目录
# 就会被自动发现，删掉目录即从平台移除，无需改动本文件或判分核心。
#
# 分层：
#   student.mk   学员信息（全平台共用，填一次）
#   core/        语言无关的判分核心（判罚链路 + 递归分发 + trace 留痕）
#   langs/<lang> 语言模块（工具链钩子 + 风格检查 + 题库）
#
# 用法见 make help；平台整体说明见 README.md，各语言说明见 langs/<lang>/README.md。

ROOT := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
CORE := $(ROOT)/core

# 注意：student.mk 由 core/trace.mk 统一 include（各层级共用），此处无需重复。

# ===== 热插拔发现：任何含 lang.mk 的 langs/ 子目录都是一个语言模块 =====
LANGS       := $(patsubst langs/%/lang.mk,%,$(wildcard langs/*/lang.mk))
SUBDIRS     := $(patsubst %,langs/%,$(LANGS))
SUBDIR_KIND := 语言模块（langs/*/lang.mk）
TRACE_SCOPE := all

include $(CORE)/dispatch.mk

.PHONY: langs help

langs:
	@if [ -z "$(LANGS)" ]; then echo "（langs/ 下还没有任何语言模块）"; exit 0; fi
	@for l in $(LANGS); do \
	  n="$$(ls -d langs/$$l/problems/*/ 2>/dev/null | wc -l | tr -d ' ')"; \
	  printf '  %-10s %s 题\t%s\n' "$$l" "$$n" "langs/$$l/README.md"; \
	done

help:
	@echo "ACSL-OJ —— 多语言本地判分平台"
	@echo ""
	@echo "已装载的语言模块："
	@$(MAKE) -s langs
	@echo ""
	@echo "第一次使用：在 student.mk 填写 STUID / NAME，然后 make init"
	@echo ""
	@echo "  make sim          判分全部语言的全部题目（留痕一次）"
	@echo "  make style        风格检查全部题目"
	@echo "  make clean        清理全部判分产物"
	@echo "  make langs        列出已装载的语言模块"
	@echo "  make trace-push   手动把 trace 分支同步到云端（离线补推）"
	@echo "  make trace-log    查看本地与云端的判分历史对照"
	@echo ""
	@echo "  make -C langs/<lang> sim              只判某个语言"
	@echo "  make -C langs/<lang>/problems/<pid> sim   只判某一题"
	@echo "  make sim AUTOPUSH=0                  本次只在本地留痕，不联网"
	@echo ""
	@echo "判罚：AC 正确 / WA 失配 / CE 编译错 / SE 风格错 / TLE 超时 / RE 运行错"
	@echo "新增语言模块的做法见 core/PLUGIN.md"
