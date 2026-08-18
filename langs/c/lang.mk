# langs/c/lang.mk —— C 语言插件（判分核心的钩子实现）
#
# 题目子 Makefile 声明 PID / MODULE / MODE 后 include 本文件，本文件再 include 判分核心。
# 契约见 core/PLUGIN.md：只需把"怎么查风格、怎么编译、怎么运行"三件事告诉核心。

LANG_NAME := C
SRC_EXT   := .c
LANG      := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
CORE      ?= $(realpath $(LANG)/../../core)

MODE ?= func

# ===== 本语言自有的可调项（题目子 Makefile 可覆盖）=====
TIMEOUT   ?= 5
CSTD      ?= c11
WARN      ?= -Wall -Wextra
SAN       ?= -fsanitize=address,undefined -fno-sanitize-recover=undefined -fno-omit-frame-pointer
LEAKCHECK ?= 0
STYLE_ARGS ?=
CASES     ?= test/cases

CFLAGS := -std=$(CSTD) -O1 -g $(WARN) $(SAN)
LDLIBS := -lm

HARNESS := test/harness.c
EXE     := build/run

export ASAN_OPTIONS  := detect_leaks=$(LEAKCHECK)
export UBSAN_OPTIONS := print_stacktrace=1

# sanitizer 的报告交给核心判成 RE（核心本身不认识 sanitizer）
RE_PATTERN := ERROR: (Address|Leak)Sanitizer|runtime error:
RE_LABEL   := 内存越界 / 未定义行为

ifeq ($(filter $(MODE),func io),)
  $(error langs/c: MODE 只能是 func 或 io（当前：$(MODE)）)
endif

# ===== 两种题型的差异全部收在这里 =====
ifeq ($(MODE),func)
  # 判分端自带 main（harness.c），学生只实现 .h 里声明的函数
  STYLE_MODE  := --ban-main --allow-header=$(MODULE).h
  # 用 = 延迟展开：SRC 由 core/engine.mk 定义，而 engine.mk 在本文件末尾才 include。
  OBJS         = $(HARNESS) $(SRC)
  EXTRA_NEEDS := $(HARNESS)
  RUN_CMD      = timeout -k 1 $(TIMEOUT) ./$(EXE) > $(RUN_LOG) 2>&1; rc=$$?
  MISSING_HINT_$(HARNESS) := 缺少 $(HARNESS)（判分端 harness，不随题目发放），请确认 $(PID)/test/ 存在。
else
  # 学生写完整程序，用 cases/*.in 喂 stdin 对拍 *.ans
  STYLE_MODE  := --require-main
  OBJS         = $(SRC)
  EXTRA_NEEDS := $(CASES)
  RUN_CMD      = bash $(LANG)/judge/run_io.sh ./$(EXE) $(CASES) $(TIMEOUT) > $(RUN_LOG) 2>&1; rc=$$?
  MISSING_HINT_$(CASES) := 缺少测试数据目录 $(CASES)（io 模式需要 *.in / *.ans 成对存在），可用 bash test/gen.sh 生成。
endif

# ===== 三个核心钩子 =====
STYLE_CMD   = bash $(LANG)/judge/style_check.sh $(STYLE_MODE) $(STYLE_ARGS) $(SRC)
COMPILE_CMD = gcc $(CFLAGS) -o $(EXE) $(OBJS) $(LDLIBS) 2> $(COMPILE_LOG)

include $(CORE)/engine.mk
