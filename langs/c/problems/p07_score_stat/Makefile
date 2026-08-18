# p07_score_stat 子 Makefile（AM 风格：判分核心见 ../../../core，本语言钩子见 ../../lang.mk）
#
# 用法：在本目录或根目录执行 make sim 判分。
# 模板即 score_stat.c：本题为 stdin/stdout 对拍题，学生必须自己写 main；
# test/ 目录只放判分端数据与参考解，不随题目发放；本 Makefile 请勿改动。
#
# 重新生成测试数据（judge 端）：bash test/gen.sh

PID    := p07_score_stat
MODULE := score_stat
MODE   := io

# 大数据组 n=1e5，正确解（计数排序 / qsort）远低于 2s；冒泡排序会被卡掉。
TIMEOUT := 2

LANG := ../..

include $(LANG)/lang.mk
