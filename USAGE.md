# ACSL-OJ 使用说明

从教师出题、发布，到学生拉取、作答、判分的完整流程。
平台总览见 [README.md](README.md)；C 出题细节见 [langs/c/AUTHORING.md](langs/c/AUTHORING.md)；
作答区说明见 [work/README.md](work/README.md)。

记四句就够：

- 教师：在私有 **ACSL-OJ-DEV** 里改、测 → `make release` → `git push public main`
- 学生：clone / pull 公开 **ACSL-OJ** 的 `main` → `make take` → `make sim`

---

## 目录

- [先分清三块地方](#先分清三块地方)
- [一张图串起来](#一张图串起来)
- [教师：出一道新题](#教师出一道新题)
- [教师：把题挂进某一周](#教师把题挂进某一周)
- [教师：发布](#教师发布)
- [学生：第一次用（学期初一次）](#学生第一次用学期初一次)
- [学生：以后每周](#学生以后每周)
- [判分之后发生了什么](#判分之后发生了什么)
- [判罚表](#判罚表)
- [容易踩的点](#容易踩的点)

---

## 先分清三块地方

两套仓库，学生进不去教师仓：

| 仓库 | 谁有权限 | 里面是什么 |
|---|---|---|
| **ACSL-OJ-DEV**（私有） | 教师 | 完整题库：`check.c`、`harness.c`、自测 |
| **ACSL-OJ**（公开） | 学生 clone | `make release` 编好的 `check` / `gen` / `harness.o` + 空模板 |

本机 remote：`origin` = DEV，`public` = 公开仓。第一次跑 `make teacher-remotes`。

学生作答在 `work/week1/p01_class_stat/class_stat.c`。
判分时平台去公开仓里的 `langs/c/problems/p01_class_stat/` 拿 `test/check`。

- 学生 `git pull` 不会碰到自己正在写的文件（作答目录被 gitignore 了）
- 教师改判据后重新 `make release` 并 `git push public main`，学生再 pull 即生效

**教师不要在公开仓的 `main` 上改题。** 人还在 `main` 上就先：

```bash
git checkout -B acsl-oj
```

当前第 1 周：`p01_class_stat`（班级成绩统计器）。

---

## 一张图串起来

```
私有 ACSL-OJ-DEV（origin）              公开 ACSL-OJ（public）
─────────────────────────              ────────────────────
写题、本机 make sim 测通
make artifacts / make release
git push origin HEAD    ──源码备份──►  DEV（学生进不去）
git push public main    ──只有二进制──►  main
                                       学生 git clone / pull
                                       make take → 写 class_stat.c
                                       make sim
                                            │
                                            ▼
                                       trace/学号
教师 git fetch public && git log public/trace/<学号>
```

---

## 教师：出一道新题

题必须先出现在题库里，再挂到某一周。顺序不能反。

### 建目录

照抄一道相近的题最快，函数题抄 `p01_gcd`：

```bash
cp -a langs/c/problems/p01_gcd langs/c/problems/p12_prime
```

然后改名字、改接口。最终至少是：

```
langs/c/problems/p12_prime/
├── Makefile          PID / MODULE / MODE / HARNESS_NAME
├── prime.h           接口契约（学生能看，不能改）
├── prime.c           发给学生的模板：签名 + TODO 空区
└── test/
    └── harness.c     黄金模型 + 测试（只留在教师分支）
```

`Makefile` 关键几行：

```make
PID    := p12_prime
MODULE := prime
MODE   := func
HARNESS_NAME := harness.o    # 学生链 .o，看不到黄金模型
LANGDIR := $(dir $(lastword $(MAKEFILE_LIST)))../..
include $(LANGDIR)/lang.mk
```

三种常用题型：

| 模式 | 学生写什么 | 什么时候用 |
|---|---|---|
| `func`（推荐） | 只写函数 | 判得最细，能报到 `in=gcd(12,18) got=2 want=6` |
| `session` | 带 `main` 的完整程序 | 成绩统计器那种；检查器现场从输入算期望，仓库里没有答案 |
| `io` | stdin/stdout 对拍 `.ans` | 答案是明文，能抄；只适合不介意发答案的题 |

Verilog 同理，题放在 `langs/verilog/problems/`，testbench 是 `test/tb.v`
（这个发源码，编不成 `.o`）。

C 出题逐步说明见 [langs/c/AUTHORING.md](langs/c/AUTHORING.md)；
`session` 可直接对照 `langs/c/problems/p01_class_stat/`。

### 教师自己先把题做对

模板 `prime.c` 是空 TODO，直接 `make sim` 会 WA，只能证明 harness 能跑，
不能证明判据没写反。

正确自测：在题库目录里把参考实现临时填进 `prime.c`，判，再改回 TODO：

```bash
# 在教师分支上
vim langs/c/problems/p12_prime/prime.c        # 先写成正确解
vim langs/c/problems/p12_prime/test/harness.c
make -C langs/c/problems/p12_prime sim        # 必须 AC
# 确认没问题后，把 prime.c 恢复成 TODO 空模板再发给学生
```

`session` 题还要在题目 Makefile 里写 `CHECKER := check`、`GEN := gen`，
并准备 `test/check.c`、`test/gen.c`。

---

## 教师：把题挂进某一周

题在题库里，学生还看不见「本周要做哪些」。必须有一个周脚手架：

```bash
make new-week WEEK=week2 PROBLEMS='p12_prime p01_gcd'
```

这只生成：

```
work/week2/Makefile
```

内容就是「第 2 周做这两题」。平台靠这个文件认出一周，不用登记到别处。

Verilog 那种题多、要做完归档的周：

```bash
make new-week WEEK=week6 PROBLEMS='p03_adder4 p04_cmp_eq4' STAGED=1
```

会建成 `work/week6/problem/Makefile`（待做进 `problem_set/`，AC 进 `done/`）。

看本学期挂了哪些周、题库里有哪些语言：

```bash
make weeks
make langs
```

---

## 教师：发布

没有远端自动编译。本机编完，只把学生快照推到公开仓。

### 第一次（只需一次）

1. 私有仓已建：https://github.com/ACSL-Phase-III/ACSL-OJ-DEV
2. 在本机教师树（现在的 `acsl-oj` 分支）上：

```bash
make teacher-remotes
# origin → git@github.com:ACSL-Phase-III/ACSL-OJ-DEV.git
# public → git@github.com:ACSL-Phase-III/ACSL-OJ.git
git push -u origin HEAD          # 源码进 DEV
```

### 每周

```bash
# 仍在 acsl-oj 上，不要 checkout 公开仓的 main
git add -A && git commit -m "week1: 班级成绩统计器"
git push origin HEAD             # 备份源码到 DEV

make release DRY=1               # 看会拿掉哪些 .c、带上哪些二进制
make release                     # 本机编 check/gen，写本地 main
git push public main             # 只有学生快照进公开仓
# 或： make release PUSH=1
```

`make release` 不切分支、不删工作区里的 `check.c`。
本地 `main` 上是 `test/check`、`test/gen`，没有 `check.c`。

公开仓的 Actions 只有 `main-guard`：若有人把 `check.c` 误推进公开 `main`，CI 会红。
**没有**「push 之后 GitHub 帮你把 .c 编成 .o」这一步。

学生：

```bash
git clone git@github.com:ACSL-Phase-III/ACSL-OJ.git    # 公开仓，默认 main
git pull
make take
make sim
```

改判据必须再 `make artifacts` / `make release` 并 `git push public main`。
`make sim` 不会自动重编二进制。

---

## 学生：第一次用（学期初一次）

环境：Linux 或 WSL（Windows 不要用原生 cmd / PowerShell）。
需要 `bash`、`make`、`git`、`gcc`（带 asan）。Verilog 周再装 `iverilog`。

```bash
git clone git@github.com:ACSL-Phase-III/ACSL-OJ.git
cd ACSL-OJ
# 默认就是 main，对，别 checkout teacher
```

```bash
# 1. 填学号姓名（只需一次）
#    第一次跑 make 时，平台会从 student.mk.example 自动拷一份 student.mk
vim student.mk              # STUID := 2023xxxx   NAME := 张三

# 2. 建自己的判分留痕分支
make init

# 3. 取当前所有已发布周的模板
make take

# 4. 写代码、判分
cd work/week2/week2_problem1
# 只改作答 .c（week5 模拟器不要写 main）
make sim
```

`student.mk` 不被 git 跟踪，老师周日 push 不会覆盖它，
也不会在 pull 时和全班撞车。

`make take` 会拷作答模板 `.c`、三行 Makefile，以及若存在的 `example_main.c` / `README.md`。
契约头（`semu.h` / `miniemu.h`）和 `harness.o` 留在 `langs/`，学生用：

```bash
make spec          # 只读查看题面和 .h，改不了判分端那份
```

---

## 学生：以后每周

老师发布 week3 之后，还是同一套：

```bash
cd ACSL-OJ
git pull                 # 拿到新的 work/week3/Makefile 和新题库
make take                # 只取还没有的模板；已经写过的文件绝不覆盖
make -C work/week3 sim   # 只判新的一周
```

平铺周的目录长这样：

```
work/week2/
├── Makefile                 老师发的，不要改
├── week2_problem1/
│   ├── Makefile             take 生成的，不要改
│   ├── class_stat.c         ← 只改这个
│   └── build/               判分产物，不用交
└── …
```

判分范围由你站在哪决定：

| 命令 | 范围 |
|---|---|
| `make sim` | 所有已经 take 过的周 |
| `make -C work/week2 sim` | 只判 week2 |
| `make -C work/week2/week2_problem1 sim` | 只判这一题 |
| `make status` | 每题最近一次 AC / WA / CE / … |

C 的 session 题每次现场随机出数据。日志里有 `SEED=…`，要复现某次失败：

```bash
make sim SEED=12345
```

本学期 week5 是平铺（指令集模拟器），AC 不会自动归档。分拣周（`STAGED := 1` 的 Verilog 大周）才多三个动作：AC 进 `done/`；`make verify` 回归；`make reopen PID=…` 挪回待做区。

想重新取一份干净模板：`make take` 不会覆盖已有文件。
真要重来，自己先把那个 `.c` 删掉或改名，再 `make take`。

---

## 判分之后发生了什么

每次最外层的 `make sim` 会在本地分支 `trace/<学号>` 上追加一次**空提交**
（不改任何文件），信息类似：

```
[sim] 2026-08-19 10:46:33 判分汇总（共 2 题，范围 week2）
  [p12_prime] AC (800/800 tests)
  [p01_gcd] WA (12/14400 组失配)
```

填了学号且在 git 仓库里，才会留痕；之后自动 `git push` 到远端同名分支。
推失败不影响判分，下次会补推，也可 `make trace-push` 手动补。
`make sim AUTOPUSH=0` 本次只在本地留痕。

教师收作业，不用收文件：

```bash
git fetch public
git log public/trace/2023xxxx --oneline
```

看的是「他哪一次交的、当时过没过」，不是最终磁盘上那一份。

---

## 判罚表

| 结果 | 意思 |
|---|---|
| **AC** | 风格过、编译过、测试全过 |
| **WA** | 结果不对，会给首个 `in= / got= / want=` |
| **CE** | 编译失败 |
| **SE** | 用了禁止的语法/函数（`goto`、`system`、裸 `write`/`open` 等；`malloc` 可用） |
| **TLE** | 超时 |
| **RE** | 崩溃或 asan/ubsan（越界、溢出） |

`make sim` 判出 WA 也退 0（判罚是结果，不是故障，结论看输出与 trace）。
`make verify` 有题回归失败则退非 0。

---

## 容易踩的点

**教师在 `main` 上跑了 `make release`。**
脚本会拒绝。先回到教师分支。

**教师把 `acsl-oj` 推到了公开仓。**
学生立刻能 checkout。删掉：`git push public --delete acsl-oj`。源码只许 `git push origin`（DEV）。

**只 push 了 DEV，忘了 `git push public main`。**
学生 `git pull` 什么都没有。

**`make sim` 已经 AC，后面却提示「未配置远端 origin」。**
判分过了，只是 trace 没推上云端。常见原因是学生在题目目录里
`git init` 交作业，make 认错了那份没有 remote 的 `.git`。
让他在 **ACSL-OJ 仓库根**（有 `Makefile`、`langs/`、`work/` 的那一层）执行：

```bash
git remote -v
ls -a work/week1/p01_class_stat/.git   # 有的话删掉这个嵌套仓库：rm -rf work/week1/p01_class_stat/.git
git remote add origin git@github.com:ACSL-Phase-III/ACSL-OJ.git   # 仅当 remote -v 为空
make trace-push
```

题目目录不要 `git init`。`make sim` 就是交作业。

**学生去翻 `langs/…/test/` 想抄答案。**
在 `main` 上 func 题只有 `harness.o`，抄不到 C 源码。
`io` 题的 `.ans` 仍然是明文——那种题别当保密作业。
Verilog 的 `tb.v` 必须发源码（泄露的是判据，不是答案表）。

**改完 harness 学生还是旧判据。**
你改的是 `.c`，学生链的是二进制。必须再 `make release` 并 `git push public main`。

**学生机器不是 x86-64 Linux。**
现在发的 `.o` 是教师机器编的。课程规定 WSL / 实验室 Ubuntu 即可；
有苹果电脑要么规定必须 WSL，要么教师再编一份对应架构的 `.o`。

**`origin/main` 历史上曾经有过 `harness.c`。**
删掉当前树挡不住 `git log -p`。挡的是一眼抄走；
学期中途不要改写已经有人 clone 的历史。

看全部命令：`make help`。
