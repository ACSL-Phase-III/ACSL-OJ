# p08_prio_enc8_3 子 Makefile —— 一键判分（每个题目目录都有一个自己的 Makefile）
#
# 用法（在 problems/p08_prio_enc8_3/ 下执行，或在根目录 make sim 自动递归到这里）：
#   make sim     判分：把 test/tb.v(判分端) 与 prio_enc8_3.v 编译到一起并仿真（AC/WA/CE/SE/RE）
#   make style   仅风格检查 prio_enc8_3.v
#   make clean   清理仿真产物
#
# 模板即 prio_enc8_3.v，直接在其中 TODO 区填写设计，请勿改动模块名、端口与文件名。
# test/ 目录只放判分端 testbench，不随题目发放；本 Makefile 请勿改动。

PID    := p08_prio_enc8_3
MODULE := prio_enc8_3

JUDGE  := ../../judge/judge.sh

.PHONY: sim style clean

sim: $(MODULE).v test/tb.v
	@bash $(JUDGE) $(PID) $(MODULE).v

style: $(MODULE).v
	@bash ../../judge/style_check.sh $(MODULE).v && echo "[$(PID)] style OK"

clean:
	@rm -f *.vvp

$(MODULE).v:
	@echo "ERROR: 缺少 $(MODULE).v 模板，请确认 problems/$(PID)/ 目录完整（含 $(MODULE).v 与 test/）。"
	@exit 1

test/tb.v:
	@echo "ERROR: 缺少 test/tb.v（判分端 testbench，不随题目发放），请确认 problems/$(PID)/test/ 存在。"
	@exit 1