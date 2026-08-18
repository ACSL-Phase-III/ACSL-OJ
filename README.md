# eelgrass —— 多语言本地判分平台

太原理工大学 ACSL 实验室所有！！！使用 CC BY-NC 4.0 协议授权开源、转载或再分发需注明出处！

本地一键判分 + git 分支留痕（可同步云端）。语言模块热插拔：判分核心不认识任何具体语言，
往 `langs/` 里放一个目录就多一门语言，删掉目录就少一门。


## 快速开始

```bash
# 1. 填写学员信息（只需填一次，对所有语言生效）
vim student.mk          # STUID := 你的学号   NAME := 你的姓名

# 2. 初始化 trace 分支
make init

# 3. 判分
make sim                # 判全部语言的全部题目
make -C langs/c sim     # 只判 C
make -C langs/c/problems/p01_gcd sim    # 只判某一题
```

`make help` 看全部用法，`make langs` 看已装载哪些语言模块。


## 目录结构

```
eelgrass/
├── README.md          本文件：平台总览（不含语言细节）
├── Makefile           顶层入口：发现 langs/* 并递归分发
├── student.mk         学员信息与云端设置（全平台共用，填一次）
├── core/              语言无关的判分核心
│   ├── engine.mk       判罚链路：风格 -> 编译 -> 运行 -> 解析
│   ├── dispatch.mk     递归分发（平台层与语言层共用同一份逻辑）
│   ├── trace.mk        trace 留痕的 Makefile 侧接线
│   ├── PLUGIN.md       语言插件契约（新增语言看这里）
│   └── judge/
│       ├── verdict.sh   判罚解析（只认判分协议，不认工具链）
│       ├── trace.sh     留痕：init / commit / log
│       └── trace_push.sh 云端同步（失败永不影响判分）
└── langs/             热插拔语言模块
    ├── c/              C 语言模块       -> langs/c/README.md
    └── verilog/        Verilog 模块     -> langs/verilog/README.md
```

**题目内容、工具链、风格规则全在 `langs/<lang>/` 里**，核心只管流程。
各语言的题目清单、判罚细则、新增题目方法见各自的 `README.md`。


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
  [sim] 2026-08-18 10:46:33 判分汇总（共 9 题，范围 all）
    [p01_gcd] AC (14400/14400 tests)
    [p03_adder4] AC (512/512 tests)
    ...
  ```

- 提交后自动 `git push` 到远端同名分支，老师端 `git fetch` 即可看全班历史，无需收作业；
- `make trace-log` 看本地与云端对照；`git log trace/<学号> --oneline` 看完整历史。

**恰好留一次痕**：不论 `make sim`（整平台）、`make -C langs/c sim`（单语言）还是
`make -C langs/c/problems/p01_gcd sim`（单题），都只产生一次提交。
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
