# ACSL-OJ —— 多语言本地判分平台

太原理工大学 ACSL 实验室所有！！！使用 CC BY-NC 4.0 协议授权开源、转载或再分发需注明出处！

本地一键判分 + git 分支留痕（可同步云端）。语言模块热插拔：判分核心不认识任何具体语言，
往 `langs/` 里放一个目录就多一门语言，删掉目录就少一门。

记四句就够：

- 教师：在私有 **ACSL-OJ-DEV** 里改、测 → `make release` → `git push public main`
- 学生：clone / pull 公开 **ACSL-OJ** 的 `main` → `make take` → `make sim`
- **不要 fork，不要 New repository。** 全班共用这一个公开仓
- `make sim` 只往这个仓推 `trace/<学号>`（空提交，只有是否通过）；老师 `make traces` 就能看

C 出题细节见 [langs/c/AUTHORING.md](langs/c/AUTHORING.md)；
作答区见 [work/README.md](work/README.md)；新增语言见 [core/PLUGIN.md](core/PLUGIN.md)。
全部命令：`make help`。

---

## 目录

- [学生：第一次用](#学生第一次用学期初一次)
- [学生：以后每周](#学生以后每周)
- [两套仓库](#两套仓库)
- [教师：出一道新题](#教师出一道新题)
- [教师：把题挂进某一周](#教师把题挂进某一周)
- [教师：发布](#教师发布)
- [教师：收 trace](#教师收-trace)
- [目录结构](#目录结构)
- [分层设计](#分层设计)
- [判分协议](#判分协议)
- [判罚表](#判罚表)
- [留痕怎么工作](#留痕怎么工作)
- [容易踩的点](#容易踩的点)
- [新增语言模块](#新增语言模块)
- [运行环境](#运行环境)

---

## 学生：第一次用（学期初一次）

环境：Linux 或 WSL（Windows 不要用原生 cmd / PowerShell）。
需要 `bash`、`make`、`git`、`gcc`（带 asan）。Verilog 周再装 `iverilog`。
HTTPS clone 再装 [`gh`](https://cli.github.com/)（`gh auth login` 用）。

**不要 fork，不要 New repository。** 全班共用公开仓 `ACSL-Phase-III/ACSL-OJ`。
`make sim` 只往这个仓库推一条 `trace/<学号>` 分支（空提交：只有 AC/WA，没有作答源码）。

```bash
# 0. 登录 GitHub（只需一次；让 git push 用你的账号，不是建新仓库）
gh auth login          # GitHub.com → HTTPS → 浏览器登录
gh auth setup-git

git clone https://github.com/ACSL-Phase-III/ACSL-OJ.git
cd ACSL-OJ
# 默认就是 main，对，别 checkout teacher / acsl-oj
```

已经习惯 SSH 的可以继续 `git clone git@github.com:ACSL-Phase-III/ACSL-OJ.git`，
并把自己的 SSH pubkey 加到 GitHub；效果相同，仍然 clone 这一个仓。

```bash
# 1. 填学号姓名（只需一次）
#    第一次跑 make 时，平台会从 student.mk.example 自动拷一份 student.mk
vim student.mk              # STUID := 2023xxxx   NAME := 张三

# 2. 建自己的判分留痕分支（会 push 到公开仓的 trace/<学号>，不是新仓库）
make init

# 3. 取当前所有已发布周的模板
make take

# 4. 写代码、判分
cd work/week2/week2_problem1
# 只改作答 .c（week5 模拟器不要写 main）
make sim                     # 判全部已取的周
make -C work/week1 sim       # 只判某一周
make -C work/week1/p01_class_stat sim   # 只判某一题
```

`student.mk` 不被 git 跟踪，老师周日 push 不会覆盖它，也不会和全班撞车。

`make take` 会拷作答模板 `.c`、三行 Makefile，以及若存在的 `example_main.c` / `README.md`。
契约头（`semu.h` / `miniemu.h`）和 `harness.o` 留在 `langs/`，学生用：

```bash
make spec          # 只读查看题面和 .h，改不了判分端那份
```

代码写在 `work/`，判分资源留在 `langs/`，两边不在同一个目录。
作答区细节见 [`work/README.md`](work/README.md)。`make weeks` 看本学期有哪些周。

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

## 两套仓库

学生进不去教师仓：

| 仓库 | 谁有权限 | 里面是什么 |
|---|---|---|
| **ACSL-OJ-DEV**（私有） | 教师 | 完整题库：`check.c`、`harness.c`、自测 |
| **ACSL-OJ**（公开） | 学生 clone；学生 team 对它有 Write | `make release` 编好的 `check` / `gen` / `harness.o` + 空模板 |

本机 remote（教师）：`origin` = DEV，`public` = 公开仓。第一次跑 `make teacher-remotes`。

学生作答在 `work/week1/p01_class_stat/class_stat.c`。
判分时平台去公开仓里的 `langs/c/problems/p01_class_stat/` 拿 `test/check`。

- 学生 `git pull` 不会碰到自己正在写的文件（作答目录被 gitignore 了）
- 教师改判据后重新 `make release` 并 `git push public main`，学生再 pull 即生效

**教师不要在公开仓的 `main` 上改题。** 人还在 `main` 上就先：

```bash
git checkout -B acsl-oj
```

```
私有 ACSL-OJ-DEV（origin）              公开 ACSL-OJ（public）
─────────────────────────              ────────────────────
写题、本机 make sim 测通
make artifacts / make release
git push origin HEAD    ──源码备份──►  DEV（学生进不去）
git push public main    ──只有二进制──►  main
                                       学生 git clone / pull
                                       make take → 写代码
                                       make sim
                                            │
                                            ▼
                                       trace/<学号>
教师 make traces / make traces STUID=…
```

---

## 教师：出一道新题

题必须先出现在题库里，再挂到某一周。顺序不能反。

### 建目录

照抄一道相近的题最快，函数题抄 `p01_gcd`（没有就抄现有 session 题 `p01_class_stat`）：

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

出题人全量自测：

```bash
make sim-langs               # 用题库自带的模板/参考解做全量自测
make artifacts               # 把判分件编成要随作业发放的二进制
make langs                   # 看已装载哪些语言模块、各有几题
```

根目录 `make sim` 的范围会自动选：有作业周就判作答区（学生常态），
没有就判题库自身（出题人常态）。两个范围各有一个显式入口：`make work` / `make sim-langs`。

---

## 教师：把题挂进某一周

题在题库里，学生还看不见「本周要做哪些」。必须有一个周脚手架：

```bash
make new-week WEEK=week2 PROBLEMS='p12_prime p01_gcd'
```

这只生成 `work/week2/Makefile`。内容就是「第 2 周做这两题」。
平台靠这个文件认出一周，不用登记到别处。

Verilog 那种题多、要做完归档的周：

```bash
make new-week WEEK=week6 PROBLEMS='p03_adder4 p04_cmp_eq4' STAGED=1
```

会建成 `work/week6/problem/Makefile`（待做进 `problem_set/`，AC 进 `done/`）。

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

改判据必须再 `make artifacts` / `make release` 并 `git push public main`。
`make sim` 不会自动重编二进制。

---

## 教师：收 trace

每次最外层的 `make sim` 会在本地分支 `trace/<学号>` 上追加一次**空提交**
（不改任何文件，不含作答源码），然后 `git push origin trace/<学号>` 到**同一个公开仓**。
推失败不影响判分。看的是「哪一次 sim、当时过没过」，不是磁盘上那份 `.c`。

学生没有自己的作业仓库。学期初把全班加成公开仓的 **Write**，同时锁死 `main`：

1. GitHub 组织里建 team（例如 `acsl-students`），把学生 GitHub 账号加进去。
2. 给这个 team 对 **ACSL-OJ**（公开仓，不是 DEV）Write 权限。
   组织成员默认往往是 Read / No access，**不会自动能 push**。
3. 在 ACSL-OJ 开 Ruleset / Branch protection：`main` 只允许管理员推送。
   学生就只能推 `trace/<学号>`，改不了题。

不加 Write 的话，学生本机可以 AC，你这边 `make traces` 永远是空的。
不要改成「每人 fork 一个仓」。

```bash
make traces                     # 列出公开仓上所有 trace/<学号>
make traces STUID=2025009489    # 只看这一个人的判分历史
```

---

## 目录结构

```
ACSL-OJ/
├── README.md          本文件（流程 + 平台结构）
├── Makefile           顶层入口：发现 langs/* 与 work/* 并递归分发
├── student.mk         学员信息与云端设置（gitignore，填一次）
├── core/              语言无关的判分核心
│   ├── engine.mk       单题判罚链路：风格 -> 编译 -> 运行 -> 解析
│   ├── dispatch.mk     递归分发（平台层与语言层共用同一份逻辑）
│   ├── week.mk         作答区的"一周"分发层（平铺 / 分拣两种布局）
│   ├── work.mk         作答区的单题层：把 PROBDIR 指回题库
│   ├── trace.mk        trace 留痕的 Makefile 侧接线
│   ├── PLUGIN.md       语言插件契约（新增语言看这里）
│   └── judge/
│       ├── verdict.sh   判罚解析（只认判分协议，不认工具链）
│       ├── take.sh      取模板到作答区（绝不覆盖已有作答）
│       ├── new_week.sh  新建一周脚手架（make new-week）
│       ├── release.sh   发布学生可见快照（make release，不切分支）
│       ├── promote.sh   AC 后在待做区与 done/ 之间搬题
│       ├── session.py   session 模式的通用会话驱动
│       ├── trace.sh     留痕：init / commit / log
│       ├── trace_push.sh 云端同步（失败永不影响判分）
│       └── traces.sh    教师从公开仓抓全班 trace/*
├── langs/             热插拔语言模块（**题库**：题面、判分资源、判据）
│   ├── c/              C 语言模块       -> langs/c/README.md
│   │                                      出题看 langs/c/AUTHORING.md
│   └── verilog/        Verilog 模块     -> langs/verilog/README.md
└── work/              **作答区**：学生只在这里写代码 -> work/README.md
```

**题目内容、工具链、风格规则全在 `langs/<lang>/` 里**，核心只管流程。
各语言的题目清单、判罚细则见各自的 `README.md`。

### 题库与作答区是分开的

学生只在 `work/` 里写代码；判分资源（harness / testbench / 测试数据 / 检查器 /
契约头文件）全部留在 `langs/<语言>/problems/<题号>/`，判分时由 `core/work.mk`
把 `PROBDIR` 指过去。

这样三件事同时成立：`git pull` 拿新题不会碰到学生的作答文件；出题人改题改判据
学生侧零操作即生效；作答区里翻不到答案 —— 它从来没被拷进来过。

契约头文件（`func` 模式的 `<模块>.h`）**必须**留在判分端，这是硬约束：
它被 harness 也 include，学生若能改它，一句 `#define gcd(a,b) gold_gcd(a,b)`
就让 harness 拿黄金模型和自己对拍，空实现直接 AC。

---

## 分层设计

三层，各自只依赖下一层的契约：

| 层 | 位置 | 知道什么 | 不知道什么 |
|---|---|---|---|
| 分发层 | `core/dispatch.mk` | 有哪些子目录要递归、怎么汇总留痕 | 子目录是语言还是题目 |
| 核心层 | `core/engine.mk` | 判罚链路、产物布局、判分协议 | gcc / iverilog 的存在 |
| 插件层 | `langs/*/lang.mk` | 怎么查风格、怎么编译、怎么运行 | 判罚怎么算、trace 怎么留 |

分发层被复用了两次：顶层 Makefile 用它递归**语言**，语言 Makefile 用它递归**题目**。
两级递归逻辑完全相同，只是 `SUBDIRS` 不同。

插件层只需实现三个钩子（`STYLE_CMD` / `COMPILE_CMD` / `RUN_CMD`），
接口约定见 [`core/PLUGIN.md`](core/PLUGIN.md)。

---

## 判分协议

核心与语言之间的唯一契约。各语言的 testbench / harness / 对拍器都输出这几行：

```
JUDGE-MISMATCH: in=... got=... want=...   失配样例（可多行，首个最重要）
JUDGE-COUNT: <N>                          测试总数
JUDGE: PASS | JUDGE: FAIL <n>             最后一行且仅一行
JUDGE-TLE: <说明>                          可选：运行端自己发现超时
```

正因为协议是语言无关的，`core/judge/verdict.sh` 能用同一段代码解析
Verilog 仿真与 C 程序的结果。

协议**写到哪**取决于学生解能不能往判罚输出里插话。学生解产生不了任何输出的语言
（如只准 `assign` 的组合逻辑 Verilog）直接写运行日志即可；学生解与判分端共享 stdout 的
语言（C 函数题：两者编进同一个可执行文件）必须走独立通道 `build/proto.log`，
`verdict.sh` 只认这个文件里的结论，`build/run.log` 只用于给学生看诊断。
判罚行多于一行也判 RE —— 合法运行只有一个结论。细节与攻击面分析见
`core/PLUGIN.md` 的"协议往哪写"与 `langs/c/README.md` 的"判罚是怎么防伪造的"。

---

## 判罚表

| 结果 | 含义 | 触发条件 |
|---|---|---|
| **AC** | Accepted | 风格合法 + 编译通过 + 全部测试通过 |
| **WA** | Wrong Answer | 编译通过但结果失配（附首个失配样例） |
| **CE** | Compile Error | 编译/综合失败 |
| **SE** | Style Error | 命中该语言的禁止语法或禁止调用（C：`goto`、`system`、裸 `write`/`open` 等；`malloc` 可用） |
| **TLE** | Time Limit Exceeded | 单次运行超过时限 |
| **RE** | Run Error | 崩溃 / sanitizer / 无判分输出 |

判罚**含义**由核心统一定义，**触发细则**由各语言模块自己规定
（例如 C 用 sanitizer 报告触发 RE，Verilog 靠 `!==` 抓 x/z）。各语言的 SE 规则差异很大，
详见各模块 README。

`make sim` 判出 WA 也退 0（判罚是结果，不是故障，结论看输出与 trace）。
`make verify` 有题回归失败则退非 0。

---

## 留痕怎么工作

- `make init` 创建 git 分支 `trace/<学号>` 并打一个 `[init]` 空提交；
- **每次**最外层 `make sim` 在该分支追加**一次空提交**（不改任何文件），提交信息即本次判分汇总：

  ```
  [sim] 2026-08-19 10:46:33 判分汇总（共 1 题，范围 week1）
    [p01_class_stat] AC (15/15 tests)
  ```

- 提交后自动 `git push` 到公开仓同名分支；老师 `make traces` 看全班，无需收文件。
  空提交里没有作答 `.c`（`work/` 被 gitignore），同学最多看见学号和是否通过。
- `make trace-log` 看本地与云端对照。

不论 `make sim`（整平台）、`make -C langs/c sim`（单语言）还是单题，都只产生一次提交。
中间层把结论往上汇总，只有最外层落一次提交。

未填写 `STUID` 或不在 git 仓库时：只判分、不留痕。
`make sim AUTOPUSH=0` 本次只在本地留痕，完全不联网。

**推送失败永远不影响判分结果**（`trace_push.sh` 退出码恒为 0）。失败时把分支名记进
`.trace-pending`，下次判分自动补推，也可 `make trace-push` 手动补。

| 情形 | 行为 |
|---|---|
| 离线 / 域名解析失败 | 提示"当前离线，已记录待同步"，联网后自动补推 |
| 未配置远端 | 说明不影响 AC；忽略题目目录里的嵌套 `.git` |
| 无凭据 / 无权限 | 提示先 `gh auth login` 或配置 SSH key；公开仓还要给学生 team Write |
| 云端历史不一致 | 提示 non-fast-forward，**不会**自动覆盖 |
| 卡住 | `timeout` 20s 强制结束，`GIT_TERMINAL_PROMPT=0` 保证不停在密码输入 |

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
ls -a work/week1/p01_class_stat/.git   # 有的话删掉：rm -rf work/week1/p01_class_stat/.git
git remote add origin https://github.com/ACSL-Phase-III/ACSL-OJ.git   # 仅当 remote -v 为空
make trace-push
```

题目目录不要 `git init`。不要 `gh repo create` / fork。`make sim` 就是交作业。

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

---

## 新增语言模块

见 [`core/PLUGIN.md`](core/PLUGIN.md)。最小实现是两个文件：`lang.mk`（三个钩子）
与 `Makefile`（四行声明），放好后 `make langs` 立刻能看到，`make sim` 会一起判。

---

## 运行环境

平台本身需要 `bash`、`make`、`git`、`timeout`（coreutils）；
各语言模块的工具链要求见其 README（C 需 `gcc` 含 asan/ubsan，Verilog 需 `iverilog`）。

Windows 下请在 WSL 或 MSYS2 中运行：所有 recipe 都是 POSIX shell 语法，
原生 cmd / PowerShell 直接 `make` 会失败。
