# core/engine.mk —— 语言无关的判分引擎
#
# 本文件不含任何语言/工具链细节。它只负责固定的判罚链路与产物布局：
#
#     风格检查(SE) --失败--> 结束
#          |通过
#     编译(CE)     --失败--> 结束
#          |通过
#     运行 -> core/judge/verdict.sh 解析协议 -> AC / WA / TLE / RE
#
# 语言插件（langs/<lang>/lang.mk）通过下面这组钩子接入，缺一即报错：
#
#   必填变量：
#     LANG_NAME      语言显示名（如 C / Verilog）
#     SRC_EXT        作答文件扩展名（如 .c / .v），SRC 由 MODULE 拼出
#     LANG_SLUG      语言小写 slug（如 c / verilog），只判单题时用来拼 trace 范围标签
#     STYLE_CMD      风格检查命令；退出码非 0 判 SE，输出即违规详情
#     COMPILE_CMD    编译命令；退出码非 0 判 CE，stderr 应重定向到 $(COMPILE_LOG)
#     RUN_CMD        运行命令；须把被判程序的输出写进 $(RUN_LOG)，并置 shell 变量 rc
#
#   可选变量：
#     PROBDIR        判分端资源（harness / tb / 数据 / 契约头文件）所在目录，默认 "."。
#                    答案与判分资源同目录时（出题人自测）保持默认即可；
#                    学生在 work/<周>/<题号>/ 作答时由 core/work.mk 设成题目目录的绝对路径，
#                    于是"作答文件在当前目录、判分资源在别处"，两边解耦。
#                    插件负责给自己的判分端资源路径加 $(PROBDIR) 前缀（见 langs/*/lang.mk）。
#     EXTRA_NEEDS    除 SRC 外的前置依赖（缺失即报错退出，如 tb / harness / 数据目录）
#     JUDGE_STRICT   1=协议行必须带 nonce 签名（学生解与判分端共享输出通道的语言必须置 1）
#     RE_PATTERN     命中即判 RE 的正则（如 sanitizer 报告），交给 verdict.sh
#     RE_LABEL       上述 RE 的中文说明
#     TIMEOUT        单次运行时限（秒），仅用于 TLE 文案
#     MISSING_HINT_<路径> 某个前置依赖缺失时的定制提示
#
# 题目子 Makefile 只声明 PID / MODULE（+ 语言自有的可选项），然后 include langs/<lang>/lang.mk，
# 由后者 include 本文件。

CORE  ?= $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
PID   ?= unknown
MODULE?= unknown

# 判分端资源目录。默认 "." = 与作答文件同目录（出题人自测的布局）。
# 学生作答时由 core/work.mk 设成题目目录的绝对路径。
PROBDIR ?= .

BUILD       := build
SRC         := $(MODULE)$(SRC_EXT)
STYLE_LOG   := $(BUILD)/style.log
COMPILE_LOG := $(BUILD)/compile.log
RUN_LOG     := $(BUILD)/run.log
PROTO_LOG   := $(BUILD)/proto.log
VERDICT     := $(BUILD)/verdict.txt

# ===== 钩子完整性检查：插件写漏了要在第一时间报错，而不是判出莫名其妙的结论 =====
$(if $(LANG_NAME),,$(error core/engine.mk: 语言插件未定义 LANG_NAME))
$(if $(SRC_EXT),,$(error core/engine.mk: 语言插件未定义 SRC_EXT))
$(if $(STYLE_CMD),,$(error core/engine.mk: 语言插件未定义 STYLE_CMD))
$(if $(COMPILE_CMD),,$(error core/engine.mk: 语言插件未定义 COMPILE_CMD))
$(if $(RUN_CMD),,$(error core/engine.mk: 语言插件未定义 RUN_CMD))

# verdict.sh 的环境（导出给 recipe 用）
# 这一行是 make 层与 core/judge/verdict.sh 之间唯一的接口：那边认的每个变量都必须
# 在这里 export，否则出题人在题目 Makefile 里设了、学生在命令行传了，都进不去。
# RE_HEAD / MISMATCH_HEAD 一度只写在 verdict.sh 的注释里而没 export —— 文档上像个
# 可调项，实际怎么设都无效。加变量记得两头一起改。
# 未定义的变量 export 出去是空串，verdict.sh 一律用 ${VAR:-默认} 取值，所以无碍。
export RE_PATTERN RE_LABEL RE_HEAD MISMATCH_HEAD TIMEOUT

# ===== 判分协议的传输通道与签名 =====
# 学生解可能与判分端 harness 跑在同一进程、共享 stdout（C 的函数题就是如此），
# 于是能 printf 一行 "JUDGE: PASS" 伪造判罚。封 exit 之类的黑名单挡不住
# （_Exit / quick_exit / longjmp 都能绕）。
#
# 光靠 nonce 签名也挡不住：同进程意味着 harness 藏不住任何秘密 —— 学生解可以从
# /proc/self/cmdline 读到 argv 里的 nonce，也可以直接翻内存。实测中一个
# __attribute__((destructor)) 函数在 main 返回后补一行带正确签名的 JUDGE: PASS，
# 就能让全错的解判成 AC。
#
# 所以真正的隔离是"换通道"：协议行走 fd 3（-> $(PROTO_LOG)），学生解的 printf
# 只能写到 stdout（-> $(RUN_LOG)，仅作诊断与 RE_PATTERN 匹配用）。学生解要往 fd 3
# 写就得用 fdopen/open/write，这些连同 <unistd.h>/<fcntl.h> 都在风格检查的黑名单里。
# nonce 保留为第二道防线，并规定合法运行只能有一行判罚：出现两行即判定被篡改，
# 这样"抢在前面"和"补在后面"两种顺序都赢不了。
#
# JUDGE_STRICT 由语言插件声明：共享输出通道的语言置 1，学生解无法产生任何输出的
# 语言（如只准 assign 的纯组合逻辑 Verilog）可留 0，此时协议行不需要前缀。
JUDGE_STRICT ?= 0
export JUDGE_STRICT PROTO_LOG

# nonce 必须在 recipe 里生成（每次运行一个新值），不能用 := 在解析期定成常量。
# od + /dev/urandom 是首选；退化路径用 $RANDOM 与 PID，够用即可（nonce 只需当次不可猜）。
#
# 必须判"结果是否为空"而不是判退出码：管道的退出码取自最后一个命令（tr），
# od 缺失时 tr 读到空输入照样成功退出 0，`||` 分支永远不会走到，nonce 静默变成空串。
# 而 JUDGE_STRICT=1 下空 nonce 会让每一次判分都变成 RE（verdict.sh:103），
# 学生看到的是一句无从下手的"判分端未生成 nonce"。所以这里显式兜空。
GEN_NONCE = n=$$( od -An -tx1 -N12 /dev/urandom 2>/dev/null | tr -d ' \n' ); \
            [ -n "$$n" ] || n=$$( printf '%s%s%s' "$$RANDOM" "$$RANDOM" "$$$$" ); \
            printf '%s' "$$n"

include $(CORE)/trace.mk

# 默认目标必须显式声明：core/trace.mk 里第一个规则是 trace-push，而它在下面的 sim
# 之前被 include —— 不写这行，裸 `make` 会变成 `make trace-push`（一次联网推送）。
.DEFAULT_GOAL := sim

.PHONY: sim style clean mkbuild

# ===== artifacts：作答区拦截 =====
# artifacts 是**出题人**的命令（重编要发放的判分件）。但经 include 链
# （作答目录 Makefile -> core/work.mk -> 题目 Makefile -> lang.mk）它在学生的作答
# 目录里照样可达，而且真会去重编 langs/ 那侧的 check / gen —— 那些文件是**被 git
# 跟踪**的（要随作业发放，见 langs/c/AUTHORING.md 的「发放边界」），学生手一滑重编
# 一遍就把工作区弄脏，下次 git pull 撞上二进制冲突，偏偏赶在交作业前后。
#
# 规则定义在这里而不是 core/work.mk：写在那边是覆盖 lang.mk 已定义的同名目标，
# make 会对每次判分都吐两行 "overriding recipe" 警告。这里靠 WORK_AREA 让插件在
# 解析期就不定义它，一行警告都没有。插件侧的配合见 core/PLUGIN.md。
#
# 判分不受影响：判分用的是仓库里发下来的那份判分件，不需要本地重编。
ifeq ($(WORK_AREA),1)
# checker 一并拦下（它是 artifacts 的旧名）。不拦的话学生敲到它只会得到
# "No rule to make target 'checker'"，那看着像平台缺东西，而不像"这条不该你跑"。
.PHONY: artifacts checker
checker: artifacts
artifacts:
	@echo "make artifacts 是出题人的命令（重编判分件），作答区不需要也不该跑它。"
	@echo "你要判分就 make sim；本题的判分件已随作业发放，不必自己编。"
	@echo "（真要重编，去 $(PROBDIR) 下跑 —— 但那会改动被 git 跟踪的文件。）"
endif

# ===== sim：完整判分链路 =====
# 三段短路：SE 后不编译，CE 后不运行。结论行由 verdict.sh 写进 $(VERDICT)，
# 再按调用来源决定汇总进 RUNLOG（被上层递归调用）还是自行留痕（单题判分）。
sim: mkbuild $(SRC) $(EXTRA_NEEDS)
	@if ! $(STYLE_CMD) > $(STYLE_LOG) 2>&1; then \
	  printf '%s\n' "[$(PID)] SE (Style Error)" | tee $(VERDICT); \
	  echo "---- 风格违规详情 ----"; cat $(STYLE_LOG); \
	elif ! $(COMPILE_CMD); then \
	  printf '%s\n' "[$(PID)] CE (Compile Error)" | tee $(VERDICT); \
	  echo "---- 编译错误 ----"; sed -n '1,20p' $(COMPILE_LOG); \
	else \
	  JUDGE_NONCE="$$( $(GEN_NONCE) )"; export JUDGE_NONCE; \
	  : > $(PROTO_LOG); \
	  $(RUN_CMD); \
	  bash $(CORE)/judge/verdict.sh "$(PID)" "$(RUN_LOG)" "$$rc" "$(VERDICT)"; \
	fi
	@$(call trace_or_collect)

# ===== style：只做风格检查 =====
style: mkbuild $(SRC)
	@$(STYLE_CMD) && echo "[$(PID)] style OK"

mkbuild:
	@mkdir -p $(BUILD)

clean:
	@rm -rf $(BUILD)

# ===== 前置依赖缺失时的报错 =====
# MISSING_HINT_<文件名> 可由插件定制；没定制就用通用文案。
$(SRC):
	@if [ "$(PROBDIR)" = "." ]; then \
	  echo "ERROR: 缺少作答文件 $(SRC)，请确认题目目录 $(PID)/ 完整。"; \
	else \
	  echo "ERROR: 缺少作答文件 $(SRC)。"; \
	  echo "       本目录是作答区，模板还没取下来。在本周目录执行："; \
	  echo "           make take PID=$(PID)"; \
	fi; exit 1

# ===== print-<变量名>：把某个变量的值打到 stdout =====
# 给 core/week.mk 的 take 用（它要知道 MODULE 才能定位模板文件名），
# 顺带方便调试："make print-CFLAGS" 看展开结果。
print-%:
	@printf '%s\n' "$($*)"

$(EXTRA_NEEDS):
	@hint='$(MISSING_HINT_$@)'; \
	if [ -n "$$hint" ]; then echo "ERROR: $$hint"; \
	else echo "ERROR: 缺少判分端资源 $@（$(LANG_NAME) 题目 $(PID) 的必需文件，不随题目发放）。"; fi; \
	exit 1
