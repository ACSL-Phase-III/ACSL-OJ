# core/week.mk —— 作答区的"一周"分发层
#
# 一周目录里放的是**作答文件**，判分资源全部留在 langs/<语言>/problems/<题号>/。
# 两种布局，由 STAGED 选择：
#
#   STAGED=0（平铺，默认）        STAGED=1（分拣，题量大的周）
#     work/week1/                   work/week5/problem/
#     ├── Makefile                  ├── Makefile
#     ├── p01_gcd/                  ├── problem_set/     还没过的
#     │   ├── Makefile  (生成)      │   ├── p03_adder4/
#     │   └── gcd.c     (作答)      │   └── p04_cmp_eq4/
#     └── p11_score_mgr/            └── done/            AC 后自动移进来
#                                       └── p10_decoder3_8/
#
# 一周的 Makefile 只需声明周名与题号列表：
#
#     WEEK     := week5
#     PROBLEMS := p03_adder4 p04_cmp_eq4 p08_prio_enc8_3
#     STAGED   := 1
#     WORK := ../../../core
#     include $(WORK)/week.mk
#
# 目标：
#   make take           取下 PROBLEMS 里所有题的模板（已存在的作答文件绝不覆盖）
#   make take PID=p03…  只取一题
#   make sim            判分待做区全部题目（AC 的按 AUTODONE 决定是否移入 done/）
#   make verify         重判 done/ 里的题（回归检查，不移动任何东西）
#   make reopen PID=…   把一题从 done/ 挪回待做区
#   make status         看每题的状态与最近一次判罚
#   make list / clean / style

# 用 := 立即展开：本文件被 include 后 MAKEFILE_LIST 还会继续变长（下面 include
# trace.mk），惰性展开会在那之后取到错误的路径。
CORE := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
ROOT := $(realpath $(CORE)/..)

BUILD := build

# 周名：留痕标签用，也会写进各题作答目录的 Makefile。
# 缺省取当前目录名 —— 分拣布局下当前目录叫 problem/，所以那种周务必显式写 WEEK。
WEEK ?= $(notdir $(CURDIR))

PROBLEMS ?=
STAGED   ?= 0

# 分拣布局默认开启"AC 自动移入 done/"；平铺布局默认关闭。
#
# 为什么不一律开：判据是穷举还是抽样，决定了 AC 的分量。
#   Verilog 组合逻辑题的 tb 是全输入穷举，AC 就是"对所有输入都对"，移走它是结论；
#   C 的 session 题每次现场随机生成数据（见 langs/c/lang.mk 的 RANDCASES），
#   一次 AC 只说明这组随机数据过了，移走会让人误以为万事大吉。
# 想改哪一边都只是一行：AUTODONE := 1 / 0。
AUTODONE ?= $(STAGED)

ifeq ($(STAGED),1)
  TODO_DIR := problem_set
else
  TODO_DIR := .
endif
DONE_DIR := done

# ===== 发现已取下的题目（作答区里存在 Makefile 的目录）=====
ifeq ($(STAGED),1)
  TODO_HITS := $(patsubst %/Makefile,%,$(wildcard $(TODO_DIR)/*/Makefile))
else
  TODO_HITS := $(patsubst %/Makefile,%,$(wildcard */Makefile))
endif
DONE_HITS := $(patsubst %/Makefile,%,$(wildcard $(DONE_DIR)/*/Makefile))

TRACE_SCOPE ?= $(WEEK)

include $(CORE)/trace.mk

# 默认目标必须显式声明：core/trace.mk 里第一个规则是 trace-push，
# 而它在本文件的 sim 之前被 include，不写这行 `make` 就等于 `make trace-push`。
.DEFAULT_GOAL := sim

OWN_RUNLOG  := $(abspath $(BUILD)/sim-run.txt)
PASS_RUNLOG  = $(if $(RUNLOG),$(RUNLOG),$(OWN_RUNLOG))

TAKE_SH    := bash $(CORE)/judge/take.sh
PROMOTE_SH := bash $(CORE)/judge/promote.sh
# 根目录 / work/ 的 take 会设 WELCOME=0，只在最外层打一张欢迎屏。
WELCOME    ?= 1

.PHONY: sim verify style clean list status take reopen help init welcome

# 为什么下面几个"空了怎么办"的分支用 make 层的 ifeq 而不是配方里的 if/exit：
# 配方每一行是**独立的 shell**，`exit 0` 只结束那一行，make 会继续跑后面几行。
# verify 曾因此在 done/ 为空时先打印"还没有题目"、接着仍去 cat 一个根本没生成的
# 汇总文件，报 "No such file or directory" 并以 Error 1 收场 —— 从 work/ 层
# 递归下来就是整条 make verify 退 2。TODO_HITS / DONE_HITS 都是 parse 期就定好的，
# 用 ifeq 直接选配方最省事，也不必把整段逻辑挤进一行 shell。

# ===== sim：判分待做区 =====
# 与 core/dispatch.mk 同一套汇总约定：上层给了 RUNLOG 就往里汇总、不留痕；
# 没给就自建汇总文件并在跑完后留痕一次。于是无论从平台根、从 work/ 还是从本周目录
# 发起判分，都恰好留一次痕。
ifeq ($(TODO_HITS),)
# 待做区空着不算失败：一个学期里"这周还没取题"是常态，从 work/ 递归判全部周时
# 不该因为某一周没取而中断其余周。退 0，只给取模板的提示。
sim:
	@echo "待做区没有题目。先取模板："
	@echo "    make take            # 取本周全部（$(words $(PROBLEMS)) 题）"
	@echo "    make take PID=<题号>"
else
sim:
	@$(if $(RUNLOG),:,mkdir -p $(BUILD) && rm -f $(OWN_RUNLOG))
	@for d in $(TODO_HITS); do \
	  echo "===== [$$d] ====="; \
	  $(MAKE) -s -C $$d sim RUNLOG=$(PASS_RUNLOG) || { \
	    echo "[$$d] 判分中断（exit $$?）"; exit 1; }; \
	done
	@$(if $(filter 1,$(AUTODONE)),$(PROMOTE_SH) "$(DONE_DIR)" $(TODO_HITS),:)
	@$(if $(RUNLOG),:,SCOPE="$(TRACE_SCOPE)" $(TRACE_SH) commit "$(STUID)" "判分汇总" "$(OWN_RUNLOG)")
endif

# ===== verify：重判 done/ =====
# 回归检查：不移动任何目录，也不往上层汇总。用途是"我这周交完了，再整体过一遍"，
# 以及 session 题换一批随机数据后确认自己不是靠运气过的。
ifeq ($(DONE_HITS),)
# done/ 是 AC 后由 core/judge/promote.sh 现建的，不预先存在 —— 所以"还没有 done/"
# 是新克隆仓库的正常状态，不是错误。平铺布局压根没有归档这回事，说清楚免得学生
# 以为自己漏了一步。
verify:
	@echo "$(DONE_DIR)/ 里还没有题目，没什么可回归的。"
ifeq ($(STAGED),1)
	@echo "（$(DONE_DIR)/ 在第一道题 AC 后自动出现，见 make help 里的 sim）"
else
	@echo "（本周是平铺布局，不做归档：所有题一直在本目录，make sim 就是全部重判）"
endif
else
verify:
	@mkdir -p $(BUILD) && rm -f $(OWN_RUNLOG)
	@for d in $(DONE_HITS); do \
	  echo "===== [$$d] ====="; \
	  $(MAKE) -s -C $$d sim RUNLOG=$(OWN_RUNLOG) || { \
	    echo "[$$d] 判分中断（exit $$?）"; exit 1; }; \
	done
	@echo "---- 回归结果 ----"
	@cat $(OWN_RUNLOG)
# 这里的退出码故意与 sim 不同：
#   sim    是"报告"—— WA 也退 0，因为判罚是结果不是故障，结论看文本 / verdict.txt / trace。
#   verify 是"闸门"—— 它唯一的用途就是回答"我已经过的题还过不过"，
#          那答案必须能被脚本读到。批量检查一学期的作业时，退 0 却有题回归失败最误事。
# 差异写在 make help 里，免得看着像不一致。
	@if grep -qv '\] AC ' $(OWN_RUNLOG); then \
	  echo ""; \
	  echo "注意：$(DONE_DIR)/ 里有题目这次没过。用 make reopen PID=<题号> 挪回待做区再改。"; \
	  exit 1; \
	fi
endif

# ===== take：取模板到作答区 =====
# 绝不覆盖已存在的作答文件 —— 写了一半的代码不能被 make 冲掉（细节见 take.sh）。
take:
	@set -e; \
	list='$(if $(PID),$(PID),$(PROBLEMS))'; \
	if [ -z "$$list" ]; then \
	  echo "本周 Makefile 里没有声明 PROBLEMS，也没给 PID=<题号>。"; \
	  echo "用法：make take PID=<题号>   或在本周 Makefile 里写 PROBLEMS := …"; \
	  exit 1; \
	fi; \
	for p in $$list; do \
	  $(TAKE_SH) "$(ROOT)" "$(TODO_DIR)" "$$p" "$(DONE_DIR)" "$(WEEK)"; \
	done; \
	if [ "$(WELCOME)" != "0" ]; then bash $(CORE)/judge/welcome.sh take; fi

# ===== reopen：把一题从 done/ 挪回待做区 =====
# 平铺布局根本没有 done/，reopen 在那里是个无意义的动作 —— 直接说清楚，
# 别让学生对着「done/xxx 不存在」去猜自己是不是该先建个目录。
ifneq ($(STAGED),1)
reopen:
	@echo "本周是平铺布局，没有 $(DONE_DIR)/，也就没有「挪回待做区」这件事。"
	@echo "所有题一直在本目录：直接改 $(if $(PID),$(PID),<题号>)/ 里的作答文件，再 make sim 即可。"
	@echo "（reopen 只用于分拣布局的周，那种周的 Makefile 里写了 STAGED := 1）"
else
reopen:
	@if [ -z "$(PID)" ]; then echo "用法：make reopen PID=<题号>"; exit 1; fi
	@if [ ! -d "$(DONE_DIR)/$(PID)" ]; then \
	  echo "$(DONE_DIR)/$(PID) 不存在。"; \
	  if [ -d "$(TODO_DIR)/$(PID)" ]; then \
	    echo "这题还在待做区（$(TODO_DIR)/$(PID)），直接改就行，不需要 reopen。"; \
	  else \
	    echo "待做区也没有这题。先取模板：make take PID=$(PID)"; \
	    echo "本周现有的题：make status"; \
	  fi; \
	  exit 1; fi
	@mkdir -p $(TODO_DIR)
	@if [ -e "$(TODO_DIR)/$(PID)" ]; then \
	  echo "ERROR: $(TODO_DIR)/$(PID) 已存在，不覆盖。请先处理掉其中一份。"; exit 1; fi
	@if git ls-files --error-unmatch "$(DONE_DIR)/$(PID)" >/dev/null 2>&1; then \
	  git mv "$(DONE_DIR)/$(PID)" "$(TODO_DIR)/$(PID)"; \
	else \
	  mv "$(DONE_DIR)/$(PID)" "$(TODO_DIR)/$(PID)"; \
	fi
	@echo "已挪回待做区：$(TODO_DIR)/$(PID)"
endif

# ===== status：本周全景 =====
# printf 的 %-Ns 按**字节**补空格，中文一个字 3 字节却只占 2 列 —— 混排 ASCII 题号与
# 中文状态时每行错开的列数还不一样，整张表看着像坏了。所以：
#   题号列用 %-24s（值全是 ASCII，字节=列，没问题）
#   状态列的三个取值一律用 2 个中文字（待做/已过/未取，都是 6 字节 4 列），
#   表头的中文也手工补到同样的显示宽度，不再交给 %-Ns。
# 状态写"已过"而不是"done"，也是为了这个宽度一致；done/ 这个目录名在 make list
# 与 help 里都出现，不靠这一列去认。
status:
	@printf '%s%s %s%s %s\n' "题号" "                    " "位置" "    " "最近一次判罚"
	@printf '%-24s %-4s %s\n' "------------------------" "--------" "--------------------"
	@for d in $(TODO_HITS) $(DONE_HITS); do \
	  pid="$$(basename $$d)"; \
	  case "$$d" in $(DONE_DIR)/*) loc="已过" ;; *) loc="待做" ;; esac; \
	  v="$$(head -n1 $$d/$(BUILD)/verdict.txt 2>/dev/null)"; \
	  printf '%-24s %s     %s\n' "$$pid" "$$loc" "$${v:-（还没判过）}"; \
	done
	@for p in $(PROBLEMS); do \
	  if [ ! -d "$(TODO_DIR)/$$p" ] && [ ! -d "$(DONE_DIR)/$$p" ]; then \
	    printf '%-24s %s     %s\n' "$$p" "未取" "make take PID=$$p"; \
	  fi; \
	done

ifeq ($(TODO_HITS),)
style:
	@echo "待做区没有题目（先 make take）"
else
style:
	@for d in $(TODO_HITS); do \
	  echo "===== [$$d] ====="; \
	  $(MAKE) -s -C $$d style || exit 1; \
	done
endif

clean:
	@for d in $(TODO_HITS) $(DONE_HITS); do $(MAKE) -s -C $$d clean; done
	@rm -rf $(BUILD)

list:
	@echo "$(WEEK)（布局：$(if $(filter 1,$(STAGED)),分拣 $(TODO_DIR)/ + $(DONE_DIR)/,平铺)，AC 自动归档：$(if $(filter 1,$(AUTODONE)),开,关)）"
	@for d in $(TODO_HITS); do echo "  待做  $$d"; done
	@for d in $(DONE_HITS); do echo "  done  $$d"; done
	@if [ -z "$(TODO_HITS)$(DONE_HITS)" ]; then echo "  （还没取任何题：make take）"; fi

init:
	@$(TRACE_SH) init "$(STUID)" "$(NAME)"

KIND ?= init
welcome:
	@$(WELCOME_SH) "$(KIND)"

# print-<变量名>：给 work/Makefile 查 PROBLEMS 用（它要知道某题属于哪一周），
# 顺带方便调试。与 core/engine.mk 里的同名规则同构。
print-%:
	@printf '%s\n' "$($*)"

help:
	@echo "$(WEEK) 作答区 —— 本目录只放作答文件，判分资源在 $(ROOT)/langs/"
	@echo ""
	@echo "  make take            取下本周全部题目的模板（$(words $(PROBLEMS)) 题）"
	@echo "  make take PID=<题号> 只取一题"
	@echo "  make sim             判分待做区全部题目$(if $(filter 1,$(AUTODONE)),（AC 自动移入 $(DONE_DIR)/）,)"
	@echo "  make status          看每题状态与最近判罚"
	@echo "  make list            列出本周题目"
	@echo "  make verify          重判 $(DONE_DIR)/ 里的题（回归，不移动）"
	@echo "  make reopen PID=…    把一题从 $(DONE_DIR)/ 挪回待做区"
	@echo "  make clean           清理判分产物"
	@echo ""
	@echo "退出码：make sim 判出 WA 也退 0（判罚是结果，不是故障，结论看输出与 trace）；"
	@echo "        make verify 有题回归失败则退非 0（它的用途就是回答「还过不过」，要能被脚本读到）。"
	@echo ""
	@echo "  make -C <题号> sim        只判一题"
	@echo "  make -C <题号> spec       看某题的题面与接口契约"
	@echo "  make -C <题号> example    用 example_main.c 本地带 main 调试"
	@echo ""
	@echo "判罚：AC 正确 / WA 失配 / CE 编译错 / SE 风格错 / TLE 超时 / RE 运行错"
