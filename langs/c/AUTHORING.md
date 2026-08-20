# C 题目出题指南

写给出题人。学生用法见 [README.md](README.md)，判分核心的插件契约见
[../../core/PLUGIN.md](../../core/PLUGIN.md)。

func / io 两种模式的建题步骤已经写在 [README.md 的"新增题目"](README.md#新增题目)，
这里不重复。本文只讲那份文档没覆盖的几件事：

- [四种模式怎么选](#四种模式怎么选)
- [session 模式：答案不进仓库](#session-模式答案不进仓库)
- [每周发布（教师 → GitHub → 学生 pull）](#每周发布教师--github--学生-pull)
- [发放边界](#发放边界) —— 哪些东西能不发给学生，哪些编译也挡不住

## 四种模式怎么选

| 模式 | 学生写什么 | 期望输出从哪来 | 仓库里有答案明文吗 |
|---|---|---|---|
| `func` | 只补函数体（`.h` 声明的接口） | `test/harness.c` 里的黄金模型现场算 | 没有，但**参考实现**在 harness 源码里 |
| `io` | 完整程序，读 stdin | `test/cases/*.ans`，预先生成好 | **有** —— 答案就是发放物 |
| `session` | 完整程序，交互式读写 | `test/check.py`（或二进制）现场从输入算 | 没有 |
| `blackbox` | 指令集模拟器（自带 `main`，`fopen` 读 `.bin`） | `test/spec.py` 从镜像现场算终态 / 逐周期对拍 | 没有（`spec.py` 是检查器，会随题发放） |

选择建议：

- **能用 `func` 就用 `func`**。判罚最精确（逐样例给出 `in=/got=/want=`），
  学生也不必操心输入解析。代价是黄金模型的实现摊在 `harness.c` 里，
  想不发源码见 [发放边界](#发放边界)。
- **要考"完整程序"的组织能力**（自己开数组、拆函数、定 struct、写排序）就用
  `session`。这是成绩统计器那类作业的正确模式，而不是 `io`。
- **`io` 只适合输出规格死板、且不介意答案随题发放的题**。
  它的 `.ans` 是明文，`test/ref.c` 还是一份完整参考解 —— 编译解决不了这件事。
- **指令集模拟器**用 `blackbox`：学生写完整 `./run <image.bin> <max_cycles> [--dump=…]`，
  运行器是 `judge/run_blackbox.sh`。本题必须 `--allow-fileio`（只放开 `fopen`）。
  运行器会把 `spec.py` 和镜像快照到临时目录再调，学生 `fopen` 题目目录里的
  `spec.py` 换不掉检查器。模拟器题也可以走 `func`（week5 就是：学生只实现
  CPU 函数，黄金模型编进 `harness.o`；那种题的 `spec.py` 不发给学生）。
  32 位环绕算术会踩 UBSan 的 signed-overflow / shift：`blackbox` 默认关掉这两项；
  `func` 模拟器在题目 Makefile 里写同一行 `SAN_EXTRA`。

## session 模式：答案不进仓库

`session` 的关键是**期望输出不存在于任何文件里**，由检查器每次现场从输入重算。
于是 `test/` 整个目录随题发放也不泄漏答案：学生能看到判据（比如"平均分保留两位、
四舍五入"），看不到"这组输入的正确输出是什么"，更抄不到"数组怎么开、
冒泡怎么写"——而后者才是作业内容。

一道 session 题要写三个东西：

1. **模板 `.c`** —— 在注释里写清交互格式（每行命令、每行输出的形状）与边界约定；
2. **`test/gen.py`（或 `gen`）** —— 随机输入生成器。存在的意义是防硬编码：
   每次判分现场生成 `RANDCASES` 组随机输入，写死答案的解活不过第二组；
3. **`test/check.py`（或 `check`）** —— 检查器。读输入 + 学生实际输出，
   自己算一遍期望值再比对。判据全在这里。

对应的题目 Makefile：

```make
PID    := p01_class_stat
MODULE := class_stat
MODE   := session
RANDCASES := 6          # 每次判分现场生成几组随机输入（0 = 只跑固定样例，调试用）
LANGDIR := $(dir $(lastword $(MAKEFILE_LIST)))../..
include $(LANGDIR)/lang.mk
```

检查器与生成器的调用契约见 [`judge/run_session.sh`](judge/run_session.sh) 顶部注释。
可现成参考 `problems/p01_class_stat/`。

固定种子可复现：`make sim SEED=12345` 会重放那一次的随机组，
学生报"第 3 组过不了"时照着跑即可。

## 每周发布（教师 → GitHub → 学生 pull）

完整逐步流程（出题、挂周、发布、学生拉取、收作业）见仓库根目录 [USAGE.md](../../USAGE.md)。

方案 1：私有 **ACSL-OJ-DEV** 留源码，公开 **ACSL-OJ** 只收本机编好的二进制。
学生 clone 公开仓，进不去 DEV。

| remote | 仓库 | 推什么 |
|---|---|---|
| `origin` | 私有 ACSL-OJ-DEV | 教师分支（`check.c` 都在） |
| `public` | 公开 ACSL-OJ | 只有 `make release` 写好的 `main` |

```bash
make teacher-remotes          # 第一次
make new-week WEEK=week2 PROBLEMS='p12_foo p13_bar'
git add -A && git commit -m "week2: …"
git push origin HEAD
make release
git push public main
```

本机调试：`make artifacts`、`make release DRY=1`。没有「push 之后 GitHub 代编」。

**不要在 `main` 上跑 `make release`**，脚本会拒绝：下一步 `git commit`
会把源码再提交回学生能拉到的分支。

`origin/main` 上如果曾经有过 `harness.c`，删掉当前树挡不住 `git log -p`。
普通学生够用；要让历史也翻不到，得换一个从未含过源码的学生仓库 / orphan 分支，
学期中途不要改写已经有人 clone 的历史。

班上作业机都是 WSL / 实验室 Ubuntu x86-64 时，教师本机编一份即可。
有苹果电脑要么规定必须 WSL，要么按架构各编一份（见下）。

## 发放边界

**先把前提说清楚：判分全部跑在学生本地，我们信任本地结果。**
所以这一节讲的**不是**安全边界 —— 一个跑在学生机器上的判分器，学生总有办法
让它输出想要的东西（改判分件、改 Makefile、直接伪造 trace）。平台里那些
nonce 签名与 fd 3 通道防的是"顺手就能干成"的伪造（`printf("JUDGE: PASS")`
这种），不是有决心的对手。

这一节真正管的是**学术诚信**：别让参考实现躺在学生一眼就能看到的地方。
区别很实在 —— 前者拦不住，后者只要别把答案递到手上就成立。

### 三样东西，泄露程度不同

| 发放物 | 泄露什么 | 能不发源码吗 |
|---|---|---|
| `test/check.py` / `check` | **只有判据**（怎么算对错） | 能，编成二进制 |
| `test/gen.py` / `gen` | 输入长什么样 | 能，编成二进制 |
| `test/harness.c` | **一份能直接抄的参考实现** | 能，编成 `harness.o` |
| `test/spec.py` | func 模拟器题里是**完整黄金模型**；blackbox 是检查器 | func 不发（`make release` 拿掉）；blackbox 要发 |
| `test/cases/*.ans` | **答案本身** | **不能** |
| `test/ref.c`（io 模式） | **一份完整参考解** | 不能（它不参与判分，是造数据用的） |
| `test/tb.v`（Verilog） | 判据（tb 现场算期望值） | 不能，iverilog 必须拿源码编译 |

最要紧的一行是 `cases/*.ans`：**io 模式的答案就是发放物**，编译改变不了这一点。
真要做到不发答案，只有换成 `session` 模式（检查器现场算）。
io 模式的明文答案与 `test/ref.c` 都随题发放 ——
这是已知的、有意接受的取舍，不是漏洞。本学期 week1 用的是 session，没有这个问题。

### 怎么改成只发二进制

日常发布用 `make release`（见上一节），不要在学生拉的 `main` 上手动
`git add test/harness.o` —— `.o` 和 `.c` 并排放着等于没藏。

题目侧要先切到二进制发放，`make artifacts` / `make release` 才编得出产物：

```make
# session 模式：两个都要改。只改一个，另一个仍是 .py，学生机器上照样得装 Python。
CHECKER := check
GEN     := gen
```

```make
# func 模式：
HARNESS_NAME := harness.o
```

在**题目目录**（`langs/c/problems/<题号>/`）下：

```console
$ make artifacts        # 编出本题要发放的判分件
已生成 test/check（源码 test/check.c 留在判分端，不发放）
已生成 test/gen（源码 test/gen.c 留在判分端，不发放）

$ make sim              # 用它们判一次，确认判据没写反
```

批量编（题目多的时候）—— 注意这两条各自要在哪里敲：

```console
$ make -C langs/c artifacts   # 在仓库根目录：编完 C 全部题目
$ make artifacts              # 在仓库根目录：编完全部语言全部题目
```

`make artifacts` 对「本题没有可编译的判分件」（`io` 模式，或仍按源码发放）只打印
一行说明并继续，不算失败 —— 否则全量编译会卡在第一道 `io` 题上。

规则：不含 `/` 的名字在 `$(TESTDIR)/` 下找；`.py` 结尾用 `$PYTHON` 解释执行，
否则直接执行。允许带参数（`CHECKER := check --strict`），也允许按架构分发
（`CHECKER := check-$(shell uname -m)`，每个平台各编一份）。

**改完判据一定要重编**，否则学生手上的二进制还是旧判据。这一步没有自动化 ——
`make sim` 不会替你重编，因为它分不清"你在改判据"和"你在测学生解"。

### 代价，一并说清

- **每个平台各编一份。** 二进制只在同架构同 libc 下能跑。班上有 Mac（arm64）
  就得再编一份 `check-arm64`，或者退回发源码。`make artifacts` 跑完会打印
  当前平台，别忽略那行。
- **失败信息变难懂。** 学生撞上"Exec format error"时，源码版会给个 Python
  traceback，二进制版只有一行系统错误。
- **反汇编照旧能看。** `harness.o` 里 gcc `-O2` 会把黄金模型内联进 `main`，
  连符号名都不剩，`grep` 不到源码文本 —— 但 `objdump -d` 一样能读。
  这里要的就是"不能直接复制粘贴"，不是密码学强度。
- **源码仍在教师分支上。** `make release` 写到 `main` 的快照不含这些 `.c`；
  学生 `git pull` 之后 `langs/…/test/` 里只有 `.o` / 二进制。不要把 `teacher`
  推成学生的默认分支。

### 判分端 harness 为什么不带 sanitizer 编译

`make artifacts` 编 `harness.o` 时刻意不加 `-fsanitize`。判分端代码是可信的，
不需要插桩；反过来带上 asan 就要求学生机器的 gcc/asan 运行时版本与出题人一致，
链接期一个 undefined reference 就能让全班判不了分。

学生解那侧的 `-fsanitize=address,undefined` 照旧生效 —— 越界访存仍然照抓。

## 契约头文件必须留在判分端

`func` 模式的 `<MODULE>.h` **不能**拷进作答区。它被 harness 也 `include`，
学生若能改它，一句

```c
#define gcd(a, b) gold_gcd(a, b)
```

就让 harness 拿黄金模型和自己对拍，空实现直接 AC。
`core/work.mk` 把 `PROBDIR` 指回题库、靠 `-I$(PROBDIR)` 供头文件，就是为了这条。
