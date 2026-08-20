# langs/verilog/lang.mk —— Verilog 语言插件（判分核心的钩子实现）
#
# 题目子 Makefile 声明 PID / MODULE 后 include 本文件，本文件再 include 判分核心。
# 契约见 core/PLUGIN.md：只需把"怎么查风格、怎么编译、怎么运行"三件事告诉核心。

LANG_NAME := Verilog
LANG_SLUG := verilog
SRC_EXT   := .v
LANGDIR   := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
CORE      ?= $(realpath $(LANGDIR)/../../core)

# ===== 判分端资源目录 =====
# 默认 "." = 判分资源与作答文件同目录（出题人在 problems/<pid>/ 自测的布局）。
# 学生在 work/<周>/... 作答时，core/work.mk 会把它设成题目目录的绝对路径。
# $(P) 为 "." 时展开成空串，旧布局下路径与改动前逐字节相同。
PROBDIR ?= .
P       := $(if $(filter .,$(PROBDIR)),,$(PROBDIR)/)

# ===== 本语言自有的可调项（题目子 Makefile 可覆盖）=====
# TB 按"相对判分端资源目录"声明，下面统一补 $(P) 前缀。
TB       ?= test/tb.v
IVFLAGS  ?= -g2012
TIMEOUT  ?= 10
STYLE_ARGS ?=

VVP := build/sim.vvp

TB          := $(P)$(TB)
EXTRA_NEEDS := $(TB)
MISSING_HINT_$(TB) := 缺少 $(TB)（判分端 testbench，不随题目发放），请确认 $(PID)/test/ 存在。

# ===== 三个核心钩子 =====
STYLE_CMD   = bash $(LANGDIR)/judge/style_check.sh $(STYLE_ARGS) $(SRC)
COMPILE_CMD = iverilog $(IVFLAGS) -o $(VVP) $(TB) $(SRC) 2> $(COMPILE_LOG)
# 组合逻辑穷举本应秒级完成；加 timeout 兜住 tb 里意外写出的无限循环（判 TLE 而非挂死）。
RUN_CMD     = timeout -k 1 $(TIMEOUT) vvp $(VVP) > $(RUN_LOG) 2>&1; rc=$$?

include $(CORE)/engine.mk

# ===== artifacts：Verilog 这侧没有可编译的判分件 =====
# 规则得存在，否则 make -C langs/verilog artifacts（以及根目录的全量编译）会因为
# 找不到目标而中断在这里。
#
# 为什么编不出来：iverilog 要把 tb.v 和作答文件**一起**编成一个 vvp，编译发生在
# 学生机器上，所以 tb.v 必须以源码形式发放 —— 没有"先编好再发"这条路。
# 好在 tb 是现场算期望值的（穷举输入，用行为级描述算一遍对比），它泄露的是判据而不是
# 答案表；这与 C 那侧 session 模式的取舍完全一样。
#
# WORK_AREA=1（学生在 work/ 作答区判分）时不定义：那种场合 core/engine.mk 已给出
# 一条"这是出题人命令"的拦截规则，两边都定义 make 会对每次判分吐 overriding recipe
# 警告。插件契约见 core/PLUGIN.md 的「出题人专用目标」。
ifneq ($(WORK_AREA),1)
.PHONY: artifacts
artifacts:
	@echo "[$(PID)] Verilog 没有可预编译的判分件：iverilog 必须把 test/tb.v 与作答文件"
	@echo "        一起编译，编译在学生机器上发生，tb 只能以源码发放。"
	@echo "        tb 是现场算期望值的，泄露的是判据不是答案表（见 langs/c/AUTHORING.md"
	@echo "        的「发放边界」一节）。"
endif   # WORK_AREA != 1
