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
`build/` 下统一的日志布局（`style.log` / `compile.log` / `run.log` / `verdict.txt`）。

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

### 可选变量

| 变量 | 用途 |
|---|---|
| `EXTRA_NEEDS` | 除作答文件外的前置依赖（tb / harness / 数据目录）；缺失即报错退出 |
| `MISSING_HINT_<路径>` | 上述依赖缺失时的定制提示文案 |
| `RE_PATTERN` | 命中即判 RE 的 `grep -E` 正则（如 C 的 sanitizer 报告） |
| `RE_LABEL` | 上述 RE 的中文说明（如 `内存越界 / 未定义行为`） |
| `TIMEOUT` | 单次运行时限（秒），用于 TLE 文案；实际限时由 `RUN_CMD` 自己加 `timeout` |

## 判分协议（运行端必须遵守）

核心只认这几行输出，语言的 tb / harness / 对拍器都要照此打印：

```
JUDGE-MISMATCH: in=... got=... want=...   失配样例（可多行，首个最重要）
JUDGE-COUNT: <N>                          测试总数
JUDGE: PASS | JUDGE: FAIL <n>             最后一行且仅一行
JUDGE-TLE: <说明>                          可选：运行端自己发现超时
```

`JUDGE-COUNT` 或 `JUDGE:` 缺失即判 **RE**——这能抓住 tb / harness 没跑到底的情况。

## 最小示例

`langs/demo/lang.mk`：

```make
LANG_NAME := Demo
SRC_EXT   := .txt
LANG      := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
CORE      ?= $(realpath $(LANG)/../../core)

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

## 两个坑

**`OBJS` 之类引用 `SRC` 的变量必须用 `=` 而非 `:=`**。`SRC` 由 `core/engine.mk` 定义，
而 `engine.mk` 在 `lang.mk` 末尾才被 include，此时 `:=` 会展开成空值。

**`TRACE_SCOPE` 每个模块取不同值**，它会写进 trace 提交信息，便于区分本次判了哪个范围。
