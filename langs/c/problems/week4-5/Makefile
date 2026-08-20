# p01_class_stat —— C 语言应用（一）：班级成绩统计器
#
# 模板即 class_stat.c：自己写 main，从标准输入读数据、往标准输出打结果。
# test/ 只放检查器与生成器（没有答案明文）；本 Makefile 请勿改动。

PID    := week4-5_test
MODULE := class_stat
MODE   := session

# 每次判分现场生成的随机组。把样例输出写死的假解会在这里穿帮。
# 调试检查器时可用 make sim RANDCASES=0 只跑固定样例。
RANDCASES := 6

# 发给学生的是编译好的 check / gen。改完 check.c / gen.c 必须 make artifacts。
CHECKER := check
GEN     := gen

LANGDIR := $(dir $(lastword $(MAKEFILE_LIST)))../..
include $(LANGDIR)/lang.mk
