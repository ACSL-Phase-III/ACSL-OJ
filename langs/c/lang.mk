# langs/c/lang.mk —— C 语言插件（判分核心的钩子实现）
#
# 题目子 Makefile 声明 PID / MODULE / MODE 后 include 本文件，本文件再 include 判分核心。
# 契约见 core/PLUGIN.md：只需把"怎么查风格、怎么编译、怎么运行"三件事告诉核心。

LANG_NAME := C
LANG_SLUG := c
SRC_EXT   := .c
LANGDIR   := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
CORE      ?= $(realpath $(LANGDIR)/../../core)

MODE ?= func

# ===== 判分端资源目录 =====
# 默认 "." = 判分资源与作答文件同目录（出题人在 problems/<pid>/ 自测的布局）。
# 学生在 work/<周>/<题号>/ 作答时，core/work.mk 会把它设成题目目录的绝对路径。
# $(P) 是给判分端资源路径加的前缀：PROBDIR 为 "." 时展开成空串，
# 于是旧布局下所有路径与改动前逐字节相同（改动不会惊动出题人的自测流程）。
PROBDIR ?= .
P       := $(if $(filter .,$(PROBDIR)),,$(PROBDIR)/)

# ===== 本语言自有的可调项（题目子 Makefile 可覆盖）=====
# TIMEOUT 的默认值按模式不同（blackbox 要跑 6000 周期，5s 太紧），所以先留成
# 延迟展开的占位符，等模式分支定下 TIMEOUT_DEFAULT 再取值。
# 这样题目自己写 TIMEOUT := 30 依然生效 —— ?= 见它已定义就不再赋值。
TIMEOUT   ?= $(TIMEOUT_DEFAULT)
TIMEOUT_DEFAULT := 5
CSTD      ?= c11
WARN      ?= -Wall -Wextra
SAN       ?= -fsanitize=address,undefined -fno-sanitize-recover=undefined -fno-omit-frame-pointer
LEAKCHECK ?= 0
STYLE_ARGS ?=
# CASES / TESTDIR 由题目按"相对判分端资源目录"声明，下面统一补上 $(P) 前缀。
CASES     ?= test/cases
TESTDIR   ?= test
# session / blackbox 模式每次判分现场生成的随机组数。0 表示只跑固定样例（调试用）。
RANDCASES ?= 6
# session 模式的两个判分件。默认是随题目发放的 Python 脚本；想只发预编译二进制就写：
#     CHECKER := check                    # 用 $(TESTDIR)/check（可执行文件）
#     CHECKER := check-$(shell uname -m)  # 每个平台各发一份，运行时按架构选
# 不含 "/" 的名字按 $(TESTDIR)/ 下定位；以 .py 结尾用 $(PYTHON) 解释执行，否则直接执行。
# 权衡见 judge/run_session.sh 顶部：判分器跑在学生机器上，二进制买到的是"不易读"
# 而非安全边界；本模式不泄漏答案靠的是检查器现场从输入算结果，与它是什么格式无关。
CHECKER   ?= check.py
GEN       ?= gen.py
export CHECKER
export GEN
# 随机组的种子。留空则运行器按当前时间取，并把取到的值打进判分日志，
# 学生可用 make sim SEED=<值> 复现某一次失败。
SEED      ?=
export SEED

# 判分端资源的最终路径（题目若覆盖了 CASES/TESTDIR，这里照样正确加前缀）
CASES   := $(P)$(CASES)
TESTDIR := $(P)$(TESTDIR)

# 判分端 harness 用 -I 引 judge/judge_proto.h（判分协议的 nonce 签名输出）。
# 学生解引不进来：judge_proto.h 不在 style_check.sh 的头文件白名单里，#include 即判 SE。
#
# 用 = 延迟展开：$(SAN_EXTRA) 由下面的模式分支设置（blackbox 要关掉几项 UBSan），
# 而模式分支在本行之后。SAN 本身仍是 ?=，题目照旧可以整体覆盖。
SAN_EXTRA :=
# INC_PROB：func 模式下契约头文件（<MODULE>.h）留在题目目录，不发到作答区。
# 学生的 #include "gcd.h" 在作答目录找不到，就落到这个 -I 上拿到判分端那份。
#
# 头文件**必须**留在判分端，不能拷进作答区：它被 harness 也 include，
# 学生若能改它，一句 `#define gcd(a,b) gold_gcd(a,b)` 就让 harness 拿黄金模型
# 和自己对拍 —— 空实现直接 AC。契约由判分端独占是这条设计的硬约束。
#
# PROBDIR 为 "." 时**不加** -I：一是老布局的编译命令行因此逐字节不变，
# 二是 -I 也参与 <> 形式的查找，把作答文件所在目录塞进搜索路径等于给了一条
# 劫持系统头文件的路（放个 stdio.h 进去即可）。作答区布局下 -I 指向的是判分端
# 目录，学生写不进去，这条路自然堵死。
INC_PROB   := $(if $(filter .,$(PROBDIR)),,-I$(PROBDIR))
CFLAGS     = -std=$(CSTD) -O1 -g $(WARN) $(SAN) $(SAN_EXTRA) -I$(LANGDIR)/judge $(INC_PROB)
LDLIBS    := -lm

# func 模式的判分端 harness。默认发放 .c 源码；想只发编译产物就在题目 Makefile 里写：
#     HARNESS_NAME := harness.o
# 然后 make artifacts 编出 test/harness.o。gcc 对 .o 与 .c 一视同仁，链接行不用改。
#
# 与 CHECKER 的区别：harness.c 里有**一份能直接抄的实现**（p01 的 gold_gcd /
# gold_lcm 就是完整可读的 C 代码），而 session 的检查器只有判据、没有实现。
# 所以这里挡的是"照抄参考实现"这种学术诚信问题，不是判分作弊 ——
# 判分跑在学生本地、结果我们照收，本来就不设防作弊这一层。
#
# harness.o 刻意不带 sanitizer 编译（见 artifacts 目标）：判分端代码是可信的，
# 不需要插桩；反过来带上 asan 就要求学生机器的 gcc/asan 运行时版本与出题人一致，
# 链接期一个 undefined reference 就能让全班判不了分。学生解那侧的 -fsanitize
# 照旧生效 —— 越界访存仍然照抓。
HARNESS_NAME ?= harness.c
HARNESS := $(P)test/$(HARNESS_NAME)
EXE     := build/run

# 学生解与判分端 harness 编进同一个可执行文件、共享 stdout，因此协议行必须带
# nonce 签名，否则学生解 printf 一行 "JUDGE: PASS" 再提前退出就能伪造 AC。
# 详见 core/judge/verdict.sh 与 judge/judge_proto.h 的注释。
JUDGE_STRICT := 1

export ASAN_OPTIONS  := detect_leaks=$(LEAKCHECK)
export UBSAN_OPTIONS := print_stacktrace=1

# sanitizer 的报告交给核心判成 RE（核心本身不认识 sanitizer）
RE_PATTERN := ERROR: (Address|Leak)Sanitizer|runtime error:
RE_LABEL   := 内存越界 / 未定义行为

ifeq ($(filter $(MODE),func io session blackbox),)
  $(error langs/c: MODE 只能是 func / io / session / blackbox（当前：$(MODE)）)
endif

# ===== 四种题型的差异全部收在这里 =====
#   func     判分端自带 main，学生只补函数体（单元测试式）
#   io       学生写完整程序，cases/*.in 喂 stdin，逐字节比对 cases/*.ans
#   session  学生写完整交互程序（成绩统计器一类），归一化后按序匹配关键行；
#            期望输出由 test/check.py 现场算出，仓库里不存在答案明文
#   blackbox 学生写指令集模拟器，输入是 argv 给的 .bin 镜像；
#            短测逐周期对拍（构造式生成器倒推答案），长测只看终态
ifeq ($(MODE),func)
  # 判分端自带 main（harness.c），学生只实现 .h 里声明的函数
  STYLE_MODE  := --ban-main --allow-header=$(MODULE).h
  # 用 = 延迟展开：SRC 由 core/engine.mk 定义，而 engine.mk 在本文件末尾才 include。
  OBJS         = $(HARNESS) $(SRC)
  EXTRA_NEEDS := $(HARNESS)
  # 函数题里学生解与 harness 是同一个进程，harness 藏不住任何秘密（argv 可从
  # /proc/self/cmdline 读到，内存可直接翻）。所以判罚不靠"藏 nonce"，而是换通道：
  #   fd 3 -> $(PROTO_LOG)：harness 写判分协议，verdict.sh 只认这里的结论
  #   stdout/stderr -> $(RUN_LOG)：学生解的输出，仅作诊断与 sanitizer 匹配
  # 学生解要写 fd 3 得用 fdopen/open/write（连同 <unistd.h>/<fcntl.h> 均已被风格检查禁掉）。
  # nonce 仍经 argv 交给 harness 作第二道签名；env -u 顺手摘掉环境项里的同名变量。
  RUN_CMD      = env -u JUDGE_NONCE timeout -k 1 $(TIMEOUT) ./$(EXE) "$$JUDGE_NONCE" > $(RUN_LOG) 2>&1 3>> $(PROTO_LOG); rc=$$?
  MISSING_HINT_$(HARNESS) := 缺少 $(HARNESS)（判分端 harness，不随题目发放），请确认 $(PID)/test/ 存在。
else ifeq ($(MODE),io)
  # 学生写完整程序，用 cases/*.in 喂 stdin 对拍 *.ans
  STYLE_MODE  := --require-main
  OBJS         = $(SRC)
  EXTRA_NEEDS := $(CASES)
  # io 模式的学生解本就是独立子进程，stdout 被逐样例捕获去对拍，进不了判分日志。
  # 协议行同样走 fd 3，与函数题保持一致（run_io.sh 是判分端，它才有权写 fd 3）。
  # run_io.sh 自己需要 nonce，所以这里保留环境变量；它 spawn 学生解时用 env -u 摘掉。
  RUN_CMD      = bash $(LANGDIR)/judge/run_io.sh ./$(EXE) $(CASES) $(TIMEOUT) > $(RUN_LOG) 2>&1 3>> $(PROTO_LOG); rc=$$?
  MISSING_HINT_$(CASES) := 缺少测试数据目录 $(CASES)（io 模式需要 *.in / *.ans 成对存在），可用 bash test/gen.sh 生成。

else ifeq ($(MODE),session)
  # 交互式会话题（成绩统计器一类）：学生写完整程序，输入走 stdin，
  # 期望输出**不在仓库里** —— 由 $(TESTDIR)/check.py 现场从输入算出来。
  # 这样 test/ 随题目发放也不泄漏答案：check.py 里只有十几行 Python 统计逻辑，
  # 抄不到"数组怎么开、函数怎么拆、struct 怎么定义、冒泡怎么写"，而那才是作业内容。
  STYLE_MODE  := --require-main
  OBJS         = $(SRC)
  # 检查器的路径由 CHECKER 推出：取第一个词（允许 CHECKER 带参数），
  # 不含 "/" 的当作 $(TESTDIR)/ 下的判分件 —— 与 run_session.sh 的 tool_path 同一套规则。
  CHECKER_WORD := $(firstword $(CHECKER))
  CHECKER_PATH := $(if $(findstring /,$(CHECKER_WORD)),$(CHECKER_WORD),$(TESTDIR)/$(CHECKER_WORD))
  EXTRA_NEEDS := $(CHECKER_PATH)
  # 与 io 模式同构：run_session.sh 是判分端，协议行走 fd 3；它 spawn 学生解时
  # 用 env -u JUDGE_NONCE + 3>&- 把 nonce 与协议通道一并摘掉。
  RUN_CMD      = bash $(LANGDIR)/judge/run_session.sh ./$(EXE) $(TESTDIR) $(TIMEOUT) $(RANDCASES) > $(RUN_LOG) 2>&1 3>> $(PROTO_LOG); rc=$$?
  MISSING_HINT_$(CHECKER_PATH) := 缺少检查器 $(CHECKER_PATH)（本题的判分逻辑，随题目一起发放，请勿修改），请确认 $(PID)/$(TESTDIR)/ 完整。

else
  # 黑盒题（指令集模拟器）：输入是 argv 给的 .bin 镜像，不是 stdin。
  # 学生程序的契约（必须写进讲义）：
  #     ./run <image.bin> <max_cycles> [--dump=trace|final]
  #     --dump=final  跑到上限后打印一行： PC=0x… a0=0x…
  #     --dump=trace  每周期打印一行：     cyc=<n> PC=0x… <本周期写过的寄存器>=0x…
  # 短测用构造式生成器（生成器先定答案再倒推程序，自己就知道每周期的状态，
  # 所以仓库里连一份参考模拟器都不存在）；长测用讲义自带的自校验镜像，只看终态。
  STYLE_MODE  := --require-main --allow-fileio
  OBJS         = $(SRC)
  EXTRA_NEEDS := $(TESTDIR)/spec.py
  # 模拟器天生要做 32 位环绕算术。UBSan 的 signed-integer-overflow / shift 会把
  # 正确实现判成 RE（例如 add 溢出、shift 到 31 位），所以这两项在本模式关掉；
  # ASan 与其余 UBSan 全部保留 —— 越界访存正是这道题最容易犯的错，必须留着。
  # 讲义要求寄存器与内存用 uint32_t；用 int32_t 的写法在此仍然是自找麻烦。
  SAN_EXTRA   := -fno-sanitize=signed-integer-overflow,shift
  # 长测 6000 周期 + 逐周期打印，5s 偏紧，默认放宽到 20s。
  # 改的是默认值而不是 TIMEOUT 本身 —— 题目子 Makefile 写 TIMEOUT := 30 仍然优先。
  TIMEOUT_DEFAULT := 20
  # 运行器尚未实现。不加这道检查的话，MODE := blackbox 会一路走到判分时才因为
  # "bash: run_blackbox.sh: No such file" 挂掉，报错指向 shell 而不是指向"这个模式
  # 还没做完"，出题人得自己翻 lang.mk 才明白。宁可在解析期就说清楚。
  # 上面这套设计（argv 传镜像、构造式生成器倒推答案、关掉两项 UBSan）是想清楚了的，
  # 缺的只是 run_blackbox.sh —— 补上这个文件本分支即可用。
  ifeq ($(wildcard $(LANGDIR)/judge/run_blackbox.sh),)
    $(error langs/c: MODE := blackbox 的运行器 judge/run_blackbox.sh 尚未实现，暂不可用。\
现有可用模式：func / io / session（见 langs/c/AUTHORING.md）)
  endif
  RUN_CMD      = bash $(LANGDIR)/judge/run_blackbox.sh ./$(EXE) $(TESTDIR) $(TIMEOUT) $(RANDCASES) > $(RUN_LOG) 2>&1 3>> $(PROTO_LOG); rc=$$?
  MISSING_HINT_$(TESTDIR)/spec.py := 缺少 $(TESTDIR)/spec.py（blackbox 模式的镜像生成器 + 判据），请确认 $(PID)/$(TESTDIR)/ 完整。
endif

# ===== 三个核心钩子 =====
STYLE_CMD   = bash $(LANGDIR)/judge/style_check.sh $(STYLE_MODE) $(STYLE_ARGS) $(SRC)
COMPILE_CMD = gcc $(CFLAGS) -o $(EXE) $(OBJS) $(LDLIBS) 2> $(COMPILE_LOG)

include $(CORE)/engine.mk

# ===== artifacts：把判分端源码编成"要随作业发放的那几个二进制" =====
# 只有出题人用得到。engine.mk 已把 .DEFAULT_GOAL 钉成 sim，所以在这里加规则
# 不会改变裸 make 的行为。
#
# 每种题型要编的东西不同：
#   func     test/harness.o   —— 判分端 harness，**黄金模型在里面**
#   session  test/check       —— 检查器（判对错）
#            test/gen         —— 随机输入生成器（防硬编码）
#   io       无 —— 期望输出是 cases/*.ans 明文，编译解决不了这件事
#
# session 模式两个都得编：只改一个，剩下那个仍是 .py，学生机器上照样要装 Python。
#
# 典型流程（出题人，改完判据后）：
#     make artifacts   # 编出要发放的判分件
#     make sim         # 用它们判一次，确认判据没写反
# 也可以 make -C langs/c artifacts 一次编完本语言全部题目（见 core/dispatch.mk）。
#
# test/*.c 是判分端源码。发放边界与"哪些东西编译也挡不住"见 langs/c/AUTHORING.md
# 的"发放边界"一节 —— 那里也写了为什么这件事只关乎学术诚信，不关乎判分可信度。
CHECKER_SRC    ?= $(TESTDIR)/check.c
GEN_SRC        ?= $(TESTDIR)/gen.c
HARNESS_SRC    ?= $(P)test/harness.c
CHECKER_CC     ?= gcc
# -fPIC：harness.o 要链进学生机器上默认 PIE 的可执行文件。不加的话，
# 部分 gcc 会在链接期报 R_X86_64_32 重定位错误，全班 CE。
# 不加 sanitizer：见下方「判分端 harness 为什么不带 sanitizer」。
CHECKER_CFLAGS ?= -std=c11 -O2 -Wall -Wextra -fPIC

# 生成器的发放路径，与 CHECKER_PATH 同一套规则
GEN_WORD := $(firstword $(GEN))
GEN_PATH := $(if $(findstring /,$(GEN_WORD)),$(GEN_WORD),$(TESTDIR)/$(GEN_WORD))

# 每条记录 = out|src|人类可读名|题目 Makefile 里的变量名|exe或obj|改成二进制时该写的值
ifeq ($(MODE),session)
  ARTIFACTS := '$(CHECKER_PATH)|$(CHECKER_SRC)|检查器|CHECKER|exe|$(basename $(notdir $(CHECKER_PATH)))' \
               '$(GEN_PATH)|$(GEN_SRC)|生成器|GEN|exe|$(basename $(notdir $(GEN_PATH)))'
else ifeq ($(MODE),func)
  ARTIFACTS := '$(HARNESS)|$(HARNESS_SRC)|harness|HARNESS_NAME|obj|harness.o'
else
  ARTIFACTS :=
endif

# ===== artifacts / checker：只在题库侧定义 =====
# WORK_AREA=1 表示这次是学生在 work/ 作答区判分（由 core/work.mk 在 include 题目
# Makefile 之前设好）。那种场合 core/engine.mk 会给出一条"这是出题人命令"的拦截规则，
# 这里就必须**不定义**同名目标 —— 两边都定义的话 make 每次判分都吐 overriding recipe
# 警告。插件契约见 core/PLUGIN.md 的「出题人专用目标」。
ifneq ($(WORK_AREA),1)

.PHONY: artifacts checker
# checker 是 artifacts 的旧名（早先只编检查器），留着不至于打断已有的手感。
checker: artifacts

ifeq ($(ARTIFACTS),)
artifacts:
	@echo "[$(PID)] 本题（MODE = $(MODE)）没有可编译的判分件。"
	@if [ "$(MODE)" = "io" ]; then \
	  echo "        io 模式的期望输出是 $(CASES)/*.ans 明文，答案本身就在发放物里，"; \
	  echo "        编译解决不了这件事。要做到不发答案得换成 session 模式（检查器现场算），"; \
	  echo "        见 langs/c/AUTHORING.md 的\"发放边界\"一节。"; \
	fi
else
artifacts:
	@built=0; skipped=0; \
	for rec in $(ARTIFACTS); do \
	  out=$${rec%%|*};  rest=$${rec#*|}; \
	  src=$${rest%%|*}; rest=$${rest#*|}; \
	  what=$${rest%%|*}; rest=$${rest#*|}; \
	  var=$${rest%%|*};  rest=$${rest#*|}; \
	  kind=$${rest%%|*}; newval=$${rest##*|}; \
	  case "$$out" in \
	    *.py|*.c) \
	      echo "[$(PID)] 跳过$$what：$$var 指的是源码（$$out），本题仍按源码发放。"; \
	      echo "        要改成只发放编译产物，在题目 Makefile 里写： $$var := $$newval"; \
	      skipped=$$((skipped + 1)); continue ;; \
	  esac; \
	  if [ ! -f "$$src" ]; then \
	    echo "make artifacts: 找不到$$what源码 $$src" >&2; exit 1; \
	  fi; \
	  if [ "$$kind" = obj ]; then \
	    $(CHECKER_CC) $(CHECKER_CFLAGS) -I$(LANGDIR)/judge -c -o "$$out" "$$src" || exit 1; \
	  else \
	    $(CHECKER_CC) $(CHECKER_CFLAGS) -o "$$out" "$$src" || exit 1; \
	  fi; \
	  echo "已生成 $$out（源码 $$src 留在判分端，不发放）"; \
	  built=$$((built + 1)); \
	done; \
	if [ "$$built" -gt 0 ]; then \
	  echo ""; \
	  echo "以上是随作业发放的判分件，只在当前平台可用（$$(uname -s)/$$(uname -m)）——"; \
	  echo "学生机器架构不同就得各编一份，见 lang.mk 里 CHECKER / HARNESS_NAME 的说明。"; \
	fi
endif   # ARTIFACTS 为空

endif   # WORK_AREA != 1
