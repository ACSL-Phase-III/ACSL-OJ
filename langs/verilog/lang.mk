# langs/verilog/lang.mk —— Verilog 语言插件（判分核心的钩子实现）
#
# 题目子 Makefile 声明 PID / MODULE 后 include 本文件，本文件再 include 判分核心。
# 契约见 core/PLUGIN.md：只需把"怎么查风格、怎么编译、怎么运行"三件事告诉核心。

LANG_NAME := Verilog
SRC_EXT   := .v
LANG      := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
CORE      ?= $(realpath $(LANG)/../../core)

# ===== 本语言自有的可调项（题目子 Makefile 可覆盖）=====
TB       ?= test/tb.v
IVFLAGS  ?= -g2012
TIMEOUT  ?= 10
STYLE_ARGS ?=

VVP := build/sim.vvp

EXTRA_NEEDS := $(TB)
MISSING_HINT_$(TB) := 缺少 $(TB)（判分端 testbench，不随题目发放），请确认 $(PID)/test/ 存在。

# ===== 三个核心钩子 =====
STYLE_CMD   = bash $(LANG)/judge/style_check.sh $(STYLE_ARGS) $(SRC)
COMPILE_CMD = iverilog $(IVFLAGS) -o $(VVP) $(TB) $(SRC) 2> $(COMPILE_LOG)
# 组合逻辑穷举本应秒级完成；加 timeout 兜住 tb 里意外写出的无限循环（判 TLE 而非挂死）。
RUN_CMD     = timeout -k 1 $(TIMEOUT) vvp $(VVP) > $(RUN_LOG) 2>&1; rc=$$?

include $(CORE)/engine.mk
