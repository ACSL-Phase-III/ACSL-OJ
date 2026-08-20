# 语言插件契约

判分核心（`core/`）不认识任何语言。要接入一门新语言，在 `langs/` 下建一个目录、
写好下面两个文件即可被平台自动发现，**无需改动 `core/` 或顶层 Makefile 一行代码**。

```
langs/<lang>/
├── lang.mk       必需：把三个钩子告诉判分核心（有它才被识别为语言模块）
├── Makefile      必需：声明本模块题目列表，include core/dispatch.mk
├── README.md     建议：本语言的题目说明与判罚详情
├── judge/        建议：本语言的风格检查器等工具
└── problems/<pid>/
    ├── Makefile  声明 PID / MODULE（+ 语言自有可选项），include ../../lang.mk
    ├── <MODULE><SRC_EXT>   模板即作答文件
    └── test/     判分端资源（tb / harness / 数据），不随题目发放
```

## 核心提供什么

固定的判罚链路与产物布局，三段短路（SE 后不编译，CE 后不运行）：

```
风格检查 --非0--> SE
    |通过
编译     --非0--> CE
    |通过
运行 --> core/judge/verdict.sh 解析协议 --> AC / WA / TLE / RE
```

外加：递归分发（`core/dispatch.mk`）、trace 留痕与云端同步（`core/trace.mk`）、
`build/` 下统一的日志布局（`style.log` / `compile.log` / `run.log` / `proto.log` / `verdict.txt`）。

## 插件必须提供什么

### 三个钩子（缺一即 `make` 报错）

| 变量 | 含义 | 约定 |
|---|---|---|
| `STYLE_CMD` | 风格检查命令 | 退出码非 0 判 **SE**；stdout/stderr 即违规详情 |
| `COMPILE_CMD` | 编译命令 | 退出码非 0 判 **CE**；错误信息须重定向到 `$(COMPILE_LOG)` |
| `RUN_CMD` | 运行命令 | 被判程序的输出须写进 `$(RUN_LOG)`，并把退出码赋给 shell 变量 `rc` |

`RUN_CMD` 里那个 `rc=$$?` 不能省——核心靠它区分 TLE（124/137）与 RE。

### 两个标识变量

| 变量 | 含义 |
|---|---|
| `LANG_NAME` | 语言显示名，用于提示文案（如 `C` / `Verilog`） |
| `SRC_EXT` | 作答文件扩展名（如 `.c` / `.v`）；核心据此拼出 `SRC = $(MODULE)$(SRC_EXT)` |
| `LANG_SLUG` | 语言小写 slug（如 `c` / `verilog`）；只判单题时用来拼 trace 范围标签 |

### 可选变量

| 变量 | 用途 |
|---|---|
| `EXTRA_NEEDS` | 除作答文件外的前置依赖（tb / harness / 数据目录）；缺失即报错退出 |
| `MISSING_HINT_<路径>` | 上述依赖缺失时的定制提示文案 |
| `JUDGE_STRICT` | `1` = 协议只从独立通道 `$(PROTO_LOG)` 读且必须带 nonce 签名；学生解与判分端共享 stdout 的语言必须置 1（默认 `0`，见下文"协议往哪写"） |
| `RE_PATTERN` | 命中即判 RE 的 `grep -E` 正则（如 C 的 sanitizer 报告） |
| `RE_LABEL` | 上述 RE 的中文说明（如 `内存越界 / 未定义行为`） |
| `RE_HEAD` | 上述 RE 打印运行日志的行数（默认 25） |
| `MISMATCH_HEAD` | WA 时最多打印几条失配样例（默认 10；协议允许多行，判分端在此截断） |
| `TIMEOUT` | 单次运行时限（秒），用于 TLE 文案；实际限时由 `RUN_CMD` 自己加 `timeout` |

核心还导出两个只读变量给 `RUN_CMD` 用：`$(RUN_LOG)`（被判程序的输出）与
`$(PROTO_LOG)`（判分协议的独立通道，每次运行前由核心清空）。

> 上表里交给 `core/judge/verdict.sh` 的那几个（`RE_*` / `MISMATCH_HEAD` / `TIMEOUT`）
> 都靠 `core/engine.mk` 里的一行 `export` 传进去。要新增同类变量，**两头都要改** ——
> 只写在 `verdict.sh` 里读，看着像个可调项，实际怎么设都无效。

### 出题人专用目标：`artifacts`

学生在 `work/` 作答时，`core/work.mk` 会在 include 题目 Makefile **之前**设好
`WORK_AREA := 1`，并由 `core/engine.mk` 给出一条"这是出题人命令，作答区别跑"的
`artifacts`（连旧名 `checker` 一起）。

所以插件里的 `artifacts` 规则**必须**这样包起来：

```make
ifneq ($(WORK_AREA),1)
.PHONY: artifacts
artifacts:
	@echo "..."
endif   # WORK_AREA != 1
```

不包的话，两边都定义同一个目标，`make` 会对学生的**每一次** `make sim` 都吐两行

```
warning: overriding recipe for target 'artifacts'
warning: ignoring old recipe for target 'artifacts'
```

判分结果不受影响，但学生看到 warning 只会以为平台坏了。C 与 Verilog 两个插件都踩过
这一条（一次是覆盖、一次是被覆盖，方向相反、症状一样）。

为什么要拦：`artifacts` 会重编 `langs/<语言>/problems/` 下**被 git 跟踪**的判分件
（随作业发放，见 `langs/c/AUTHORING.md` 的「发放边界」）。学生手一滑跑一遍就把工作区
弄脏，下次 `git pull` 撞上二进制冲突 —— 偏偏赶在交作业前后。判分本身不需要它：
用的就是仓库里发下来的那份。

教师把编好的判分件发给学生，用根目录的 `make release`（`core/judge/release.sh`）：
它写学生分支、不切工作区，和本文件的 trace 留痕同一条原则。插件不用实现 `release`。

## 判分协议（运行端必须遵守）

核心只认这几行输出，语言的 tb / harness / 对拍器都要照此打印：

```
JUDGE-MISMATCH: in=... got=... want=...   失配样例（可多行，首个最重要）
JUDGE-COUNT: <N>                          测试总数
JUDGE: PASS | JUDGE: FAIL <n>             最后一行且仅一行
JUDGE-TLE: <说明>                          可选：运行端自己发现超时
```

`JUDGE-COUNT` 或 `JUDGE:` 缺失即判 **RE**——这能抓住 tb / harness 没跑到底的情况。
`JUDGE:` 出现**两行及以上**同样判 **RE**：合法运行只有一个结论，多出来的一行意味着
协议通道被写脏了（详见下面的"协议往哪写"）。

### 协议往哪写：`JUDGE_STRICT` 与 fd 3

关键问题是**学生解能不能往判罚输出里插话**。分两类：

| 语言形态 | `JUDGE_STRICT` | 协议写到哪 | 例子 |
|---|---|---|---|
| 学生解产生不了任何输出 | `0`（默认） | 直接写 `$(RUN_LOG)`，裸协议行即可 | 只准 `assign` 的纯组合逻辑 Verilog |
| 学生解与判分端共享 stdout | `1` | **必须**写独立通道 `$(PROTO_LOG)`，并给每行加 `$JUDGE_NONCE ` 前缀 | C 函数题（学生解与 harness 编进同一个可执行文件） |

`JUDGE_STRICT=1` 时 `verdict.sh` **只**读 `$(PROTO_LOG)`，`$(RUN_LOG)` 降级成"给学生看的
诊断 + 匹配 `RE_PATTERN`"。通道为空的含义是"harness 没跑到底"，即 RE —— 绝不会退回
去读学生能写的地方找结论。

C 插件的做法是把 fd 3 重定向到 `$(PROTO_LOG)`，harness 往 fd 3 打协议行，
学生解的 `printf` 只能到 stdout：

```make
JUDGE_STRICT := 1
RUN_CMD = env -u JUDGE_NONCE timeout -k 1 $(TIMEOUT) ./$(EXE) "$$JUDGE_NONCE" \
              > $(RUN_LOG) 2>&1 3>> $(PROTO_LOG); rc=$$?
```

为什么非得换通道、光签名不够：同一个进程里 harness 藏不住任何秘密。nonce 走 argv 能被
`/proc/self/cmdline` 读到，走环境变量能被 `extern char **environ;` 遍历到，再不然直接翻
内存。实测一个 `__attribute__((destructor))` 在 `main` 返回后补一行带正确签名的
`JUDGE: PASS`，就能让全错的解判成 AC。所以 nonce 只是第二道防线，第一道是"学生解写不到
的通道"，第三道是风格检查（C 把 `fdopen`/`open`/`write` 与 `<unistd.h>`/`<fcntl.h>` 都列了黑名单）。

派生进程要记得**关掉通道**，别让学生解继承 fd 3 —— io 模式 spawn 学生解时用 `3>&-`。

## 最小示例

`langs/demo/lang.mk`：

```make
LANG_NAME := Demo
LANG_SLUG := demo
SRC_EXT   := .txt
LANGDIR   := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
CORE      ?= $(realpath $(LANGDIR)/../../core)

STYLE_CMD   = true
COMPILE_CMD = true
RUN_CMD     = cat $(SRC) > $(RUN_LOG) 2>&1; rc=$$?

include $(CORE)/engine.mk
```

`langs/demo/Makefile`：

```make
CORE := $(realpath $(dir $(lastword $(MAKEFILE_LIST)))/../../core)
SUBDIRS     := $(patsubst %/Makefile,%,$(wildcard problems/*/Makefile))
SUBDIR_KIND := 题目
TRACE_SCOPE := demo
include $(CORE)/dispatch.mk
```

放好后 `make langs` 立即能看到它，`make sim` 会把它一起判。

## 四个坑

**`OBJS` 之类引用 `SRC` 的变量必须用 `=` 而非 `:=`**。`SRC` 由 `core/engine.mk` 定义，
而 `engine.mk` 在 `lang.mk` 末尾才被 include，此时 `:=` 会展开成空值。

**`TRACE_SCOPE` 每个模块取不同值**，它会写进 trace 提交信息，便于区分本次判了哪个范围。
语言模块 Makefile 里设成小写 slug（`c` / `verilog`）；只判单题时无人赋值，
`core/trace.mk` 会用 `LANG_SLUG` 补成 `verilog:p03_adder4` 这样的标签，
所以每个 `lang.mk` 都要声明 `LANG_SLUG`（与 `LANG_NAME` 并列，后者是显示名）。

**别自己解析 `$(RUN_LOG)`，判罚一律交给 `core/judge/verdict.sh`**。除了"改一处忘另一处"
的老问题，还有个跨平台陷阱：Windows 原生工具链（winget 装的 `vvp.exe`、MSYS2 的 gcc 等）
写出来的日志是 CRLF，而协议正则带 `$` 锚定，`JUDGE: PASS\r` 一行都匹配不上 ——
每道题都会退化成 RE，连本该 AC 的解也是。`verdict.sh` 已在解析前统一把 CRLF 归一化成 LF
（原始日志不动，学生仍能对着 `build/run.log` 排错）；运行端只要把输出如实写进 `$(RUN_LOG)`
并置好 `rc` 就够了。

**判分端自己的编译告警没人看见**。`COMPILE_CMD` 的 stderr 按约定进 `$(COMPILE_LOG)`，
而核心只在编译**失败**时才打印它 —— 判分端 harness 里的告警于是全程静默。踩过一次：
`judge_proto.h` 用 `fdopen` 而 `-std=c11` 下 glibc 不声明它（POSIX 而非 ISO C），
gcc 按隐式声明当成返回 `int`，指针被截断成野值，一 `fprintf` 就 SEGV —— 编译"成功"，
问题要到运行期才以 sanitizer 报告的形式冒出来。改判分端的 harness / 头文件后，
建议手工重编一遍看告警（`gcc ... -Wall -Wextra -Wpedantic`），别只看判罚结果。
