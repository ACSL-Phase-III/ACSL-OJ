# ACSL-OJ —— 多语言本地判分平台

太原理工大学 ACSL 实验室所有！！！使用 CC BY-NC 4.0 协议授权开源、转载或再分发需注明出处！

本地一键判分 + git 分支留痕（可同步云端）。语言模块热插拔：判分核心不认识任何具体语言，
往 `langs/` 里放一个目录就多一门语言，删掉目录就少一门。


## 快速开始（学生）

```bash
# 1. 填写学员信息（只需填一次，对所有语言生效）
vim student.mk          # STUID := 你的学号   NAME := 你的姓名

# 2. 初始化 trace 分支
make init

# 3. 取本周作业的模板到作答区
make -C work take

# 4. 在 work/<周>/<题号>/ 里写代码，然后判分
make sim                     # 判全部周
make -C work/week1 sim       # 只判某一周
make -C work/week1/p01_class_stat sim   # 只判某一题
```

代码写在 `work/` 里，判分资源留在 `langs/`，两边不在同一个目录 ——
细节与常见情况见 [`work/README.md`](work/README.md)。

`make help` 看全部用法，`make weeks` 看本学期有哪些周与题目。
教师出题、发布、学生拉取到交作业的完整流程见 [USAGE.md](USAGE.md)。

## 快速开始（出题人）

```bash
make sim-langs               # 用题库自带的模板/参考解做全量自测
make -C langs/c/problems/p01_class_stat sim   # 只自测某一题
make artifacts               # 把判分件编成要随作业发放的二进制
make langs                   # 看已装载哪些语言模块、各有几题
```

根目录 `make sim` 的范围会自动选：有作业周就判作答区（学生常态），
没有就判题库自身（出题人常态）。两个范围各有一个显式入口：`make work` / `make sim-langs`。

新增题目、session 模式、只发放编译好的判分件、每周怎么发给学生，见
[`langs/c/AUTHORING.md`](langs/c/AUTHORING.md)；
新增语言见 [`core/PLUGIN.md`](core/PLUGIN.md)。


## 每周发布（教师）

完整逐步说明（出题、挂周、发布、学生拉取、留痕收作业）见 [USAGE.md](USAGE.md)。

```bash
make teacher-remotes          # 第一次：origin=私有 DEV，public=公开仓
git add -A && git commit -m "week1: …"
git push origin HEAD          # 源码进 DEV
make release                  # 本机编二进制，写本地 main
git push public main          # 学生快照进公开 ACSL-OJ
```

学生 clone 公开仓：`git pull` → `make take` → `make sim`。


## 目录结构

```
ACSL-OJ/
├── README.md          本文件：平台总览（不含语言细节）
├── USAGE.md           教师出题发布 + 学生拉取作答的完整流程
├── Makefile           顶层入口：发现 langs/* 与 work/* 并递归分发
├── student.mk         学员信息与云端设置（全平台共用，填一次）
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
│       └── trace_push.sh 云端同步（失败永不影响判分）
├── langs/             热插拔语言模块（**题库**：题面、判分资源、判据）
│   ├── c/              C 语言模块       -> langs/c/README.md
│   │                                      出题看 langs/c/AUTHORING.md
│   └── verilog/        Verilog 模块     -> langs/verilog/README.md
└── work/              **作答区**：学生只在这里写代码 -> work/README.md
    └── week1/          平铺布局的一周（C 语言应用（一））
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


## 判罚表

| 结果 | 含义 | 触发条件 |
|---|---|---|
| **AC** | Accepted | 风格合法 + 编译通过 + 全部测试通过 |
| **WA** | Wrong Answer | 编译通过但结果失配（附首个失配样例） |
| **CE** | Compile Error | 编译/综合失败 |
| **SE** | Style Error | 命中该语言的禁止语法或禁止调用 |
| **TLE** | Time Limit Exceeded | 单次运行超过时限 |
| **RE** | Run Error | 崩溃 / 运行时诊断报错 / 无判分输出 |

判罚**含义**由核心统一定义，**触发细则**由各语言模块自己规定
（例如 C 用 sanitizer 报告触发 RE，Verilog 靠 `!==` 抓 x/z）。各语言的 SE 规则差异很大，
详见各模块 README。


## trace（判分留痕）

判分过程可审计，看的是提交历史而不只是最终答案：

- `make init` 创建 git 分支 `trace/<学号>` 并打一个 `[init]` 空提交；
- **每次** `make sim` 在该分支追加**一次空提交**（`--allow-empty`，不改任何文件），
  提交信息即本次判分汇总：

  ```
  [sim] 2026-08-19 10:46:33 判分汇总（共 1 题，范围 week1）
    [p01_class_stat] AC (15/15 tests)
  ```

- 提交后自动 `git push` 到远端同名分支，老师端 `git fetch` 即可看全班历史，无需收作业；
- `make trace-log` 看本地与云端对照；`git log trace/<学号> --oneline` 看完整历史。

**恰好留一次痕**：不论 `make sim`（整平台）、`make -C langs/c sim`（单语言）还是
`make -C langs/c/problems/p01_class_stat sim`（单题），都只产生一次提交。
中间层把结论往上汇总，只有最外层落一次提交。

未填写 `STUID` 或不在 git 仓库时：只判分、不留痕。

### 云端同步的失败处理

**推送失败永远不影响判分结果**（`trace_push.sh` 退出码恒为 0）。失败时把分支名记进
`.trace-pending`，下次判分自动补推，也可 `make trace-push` 手动补。

| 情形 | 行为 |
|---|---|
| 离线 / 域名解析失败 | 提示"当前离线，已记录待同步"，联网后自动补推 |
| 未配置远端 | 提示 `git remote add origin <地址>` 的配置方法 |
| 无凭据 / 无权限 | 提示先 `gh auth login` 或配置 SSH key |
| 云端历史不一致 | 提示 non-fast-forward，**不会**自动覆盖，需人工核对 |
| 卡住 | `timeout` 20s 强制结束，`GIT_TERMINAL_PROMPT=0` 保证不停在密码输入 |

`make sim AUTOPUSH=0` 本次只在本地留痕，完全不联网。


## 新增语言模块

见 [`core/PLUGIN.md`](core/PLUGIN.md)。最小实现是两个文件：`lang.mk`（三个钩子）
与 `Makefile`（四行声明），放好后 `make langs` 立刻能看到，`make sim` 会一起判。


## 运行环境

平台本身需要 `bash`、`make`、`git`、`timeout`（coreutils）；
各语言模块的工具链要求见其 README（C 需 `gcc` 含 asan/ubsan，Verilog 需 `iverilog`）。

Windows 下请在 WSL 或 MSYS2 中运行：所有 recipe 都是 POSIX shell 语法，
原生 cmd / PowerShell 直接 `make` 会失败。
