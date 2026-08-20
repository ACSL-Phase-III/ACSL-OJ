# langs/c/Makefile —— C 语言模块入口
#
# 只做两件事：声明"本模块有哪些题目"，然后把分发逻辑交给判分核心。
# 判分链路见 core/engine.mk，本语言的钩子见 lang.mk。
#
# 用法：make sim / style / clean / list（也可从平台根目录 make sim 一次判全部语言）

CORE := $(realpath $(dir $(lastword $(MAKEFILE_LIST)))/../../core)

SUBDIRS     := $(patsubst %/Makefile,%,$(wildcard problems/*/Makefile))
SUBDIR_KIND := 题目（problems/*/Makefile）
TRACE_SCOPE := c

include $(CORE)/dispatch.mk

help:
	@echo "C 语言模块（判分核心：../../core）"
	@echo "  make sim     判分本模块全部题目"
	@echo "  make style   风格检查本模块全部题目"
	@echo "  make list    列出本模块题目"
	@echo "  make clean   清理判分产物"
	@echo "  make -C problems/<pid> sim   只判某一题"
	@echo "  题目说明与判罚详情见 README.md"
