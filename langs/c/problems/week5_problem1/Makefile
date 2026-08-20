# week5_problem1 —— sEMU（sISA）
#
# func 模式：harness 自带 main。学生只实现 semu.h 里的 fetch/decode/execute。
# HARNESS_NAME := harness.o —— 黄金模型在 .o 里，学生 git pull 拿不到 harness.c。

PID    := week5_problem1
MODULE := semu
MODE   := func
TIMEOUT := 5
HARNESS_NAME := harness.o
SAN_EXTRA := -fno-sanitize=signed-integer-overflow,shift
EXAMPLE_BIN     = $(P)test/cases/01_sum_1_to_10.bin
EXAMPLE_CYCLES ?= 60

LANGDIR := $(dir $(lastword $(MAKEFILE_LIST)))../..
include $(LANGDIR)/lang.mk
