# core/work.mk —— 作答区的单题接线层
#
# 作用：让"作答文件在 work/<周>/<题号>/，判分资源在 langs/<语言>/problems/<题号>/"
# 这个分离布局跑起来。作答目录里的 Makefile 只有三行：
#
#     PID  := p01_gcd
#     WORK := ../../../core
#     include $(WORK)/work.mk
#
# 连 PID 都可以省 —— 缺省取当前目录名。这个文件由 `make take` 自动生成，
# 学生不需要读懂它，也不该改它。
#
# 它做的事：
#   1. 按 PID 在 langs/*/problems/ 下找到题目目录（语言自动判定，不用学生声明）
#   2. 把 PROBDIR 指向那里，LANG 指向对应的语言模块
#   3. include 题目自己的 Makefile —— 题号、题型、时限、风格参数全部沿用判分端那份，
#      作答区不复制任何一份题目元数据（改题只需改判分端，学生 git pull 即生效）
#
# 于是 CWD（= 作答目录）里只有作答文件与 build/，判分资源一个字节都不落进来。

# 用 := 立即展开：本文件被 include 后 MAKEFILE_LIST 还会继续变长
# （下面 include 题目 Makefile、lang.mk、engine.mk、trace.mk），
# 惰性展开会在后面取到错误的路径。
CORE := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
ROOT := $(realpath $(CORE)/..)

# 题号缺省取目录名：work/week1/p01_gcd/ -> p01_gcd
PID := $(if $(PID),$(PID),$(notdir $(patsubst %/,%,$(dir $(abspath $(firstword $(MAKEFILE_LIST)))))))

# ===== 按题号定位题目目录（语言自动判定）=====
PROB_HITS := $(patsubst %/Makefile,%,$(wildcard $(ROOT)/langs/*/problems/$(PID)/Makefile))

ifeq ($(words $(PROB_HITS)),0)
  $(error core/work.mk: 平台里没有题号 $(PID)（在 $(ROOT)/langs/*/problems/ 下找不到）)
endif
ifneq ($(words $(PROB_HITS)),1)
  $(error core/work.mk: 题号 $(PID) 在多个语言模块下同时存在（$(PROB_HITS)），请重命名其中一个)
endif

PROBDIR := $(firstword $(PROB_HITS))

# 留痕范围标签：作答区的题带上周名（week1:p01_gcd），比 c:p01_gcd 更能说明这是哪次作业。
# WEEK 由 make take 写进生成的 Makefile；没有就退回 core/trace.mk 的默认（<语言>:<题号>）。
ifneq ($(WEEK),)
  TRACE_SCOPE := $(WEEK):$(PID)
endif

# 题目元数据（PID / MODULE / MODE / TIMEOUT / STYLE_ARGS…）全部来自判分端那份 Makefile，
# 作答区不复制任何一份。它末尾 include $(LANGDIR)/lang.mk，后者再 include
# $(CORE)/engine.mk，判分链路与出题人自测时完全同一条。
#
# 这里不需要给它传 LANGDIR：题目 Makefile 用 $(dir $(lastword $(MAKEFILE_LIST)))
# 自定位 —— 被 include 时 lastword 正是它自己，所以照样指到 langs/<语言>/。
#
# WORK_AREA 必须在 include **之前**设好：下游（lang.mk / engine.mk）在解析期用它
# 判断"这次是学生在作答区判分"，从而跳过出题人专用目标（见 core/PLUGIN.md）。
# 它同时也是给插件作者的开关，不只是内部标记。
WORK_AREA := 1
include $(PROBDIR)/Makefile

# ===== 以下规则必须写在 include 之后 =====
# 否则第一个目标会变成默认目标，`make` 就不再等于 `make sim` 了。

.PHONY: spec

# artifacts 的作答区拦截规则现在写在 core/engine.mk 里（受 WORK_AREA 控制）。
# 曾经写在这里 —— 但那是**覆盖**已经由 lang.mk 定义好的同名目标，于是每次
# make sim 都先吐两行 make 警告：
#     core/work.mk:68: warning: overriding recipe for target 'artifacts'
#     langs/c/lang.mk:251: warning: ignoring old recipe for target 'artifacts'
# 判分本身没错，但学生每判一次都看见两行 warning，只会以为平台坏了。
# 正确做法是让插件在解析期就别定义它，而不是定义完再覆盖。

# ===== spec：看题面与接口契约 =====
# 契约头文件（func 模式的 <MODULE>.h）按设计留在判分端不发放 —— 它被 harness 也
# include，学生若能改它，一句 #define 就让 harness 拿黄金模型自己对拍。
# 但"不给改"不等于"不给看"，所以这里提供只读的查看方式。
spec:
	@echo "题号 $(PID)   语言 $(LANG_NAME)$(if $(MODE),   题型 $(MODE),)"
	@echo "作答文件 $(SRC)（就在本目录）"
	@echo "判分资源 $(PROBDIR)（只读，不在本目录）"
	@if [ -f "$(PROBDIR)/README.md" ]; then \
	  echo ""; echo "---- 题面 README ----"; cat "$(PROBDIR)/README.md"; \
	fi
	@echo ""
	@echo "---- 题面（判分端模板原文的说明部分）----"
	@awk '/^[[:space:]]*\/\// || /^[[:space:]]*$$/ {print; next} {exit}' "$(PROBDIR)/$(SRC)"
	@if [ -f "$(PROBDIR)/$(MODULE).h" ]; then \
	  echo ""; echo "---- 接口契约 $(MODULE).h（判分端持有，只读；你的代码 #include \"$(MODULE).h\" 即可用）----"; \
	  cat "$(PROBDIR)/$(MODULE).h"; \
	fi
