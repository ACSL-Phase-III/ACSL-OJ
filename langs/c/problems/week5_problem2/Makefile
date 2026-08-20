# week5_problem2 —— miniEMU（minirv）
#
# func 模式：harness 自带 main（加载 .bin、跑周期、看 PC/a0）。
# 学生只实现 miniemu.h 里的 CPU 函数，不要写 main / while(1)。
# HARNESS_NAME := harness.o —— 黄金模型在 .o 里，学生 git pull 拿不到 harness.c。

PID    := week5_problem2
MODULE := miniemu
MODE   := func
TIMEOUT := 20
HARNESS_NAME := harness.o
SAN_EXTRA := -fno-sanitize=signed-integer-overflow,shift
EXAMPLE_BIN     = $(P)test/cases/01_addi_jalr.bin
EXAMPLE_CYCLES ?= 20

LANGDIR := $(dir $(lastword $(MAKEFILE_LIST)))../..
include $(LANGDIR)/lang.mk
