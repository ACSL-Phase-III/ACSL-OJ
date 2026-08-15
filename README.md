# verilog-oj —— 本地 Verilog 组合逻辑判分平台

太原理工大学 ACSL 实验室所有！！！使用 CC BY-NC 4.0 协议授权开源、转载或再分发需注明出处！


> ## ACSL 数字IC设计作业自动仿真模板
> **作答方式**：模板就是模块名文件（本题目录内置，如 `p03_adder4/adder4.v`），
> 直接在其中 `TODO` 区补全设计即可，请勿改动模块名、端口与文件名；
> `tb.v` 与子 Makefile 请勿改动。


## 目录结构

```
verilog-oj/
├── Makefile            # 根 Makefile：头部填 STUID/NAME + make init + 递归分发
├── make/
│   └── common.mk        # 统一判分引擎（AM 风格，被每个子 Makefile include）
├── judge/
│   └── style_check.sh   # 学生代码风格检查（禁止语法过滤）
├── problems/<pid>/
│   ├── Makefile         # 子 Makefile：只声明 PID/MODULE，include 判分引擎
│   ├── <模块名>.v         # 模板即作答文件（adder4.v 等）：接口 + TODO 空区
│   └── test/
│       └── tb.v         # 判分 testbench（判分端专用，不随题目发放）
└── README.md
```






## 判分用法（Makefile 一键）

第一次使用先填写根 Makefile 头部的 `STUID` / `NAME` 并初始化 trace：

```bash
# 编辑 verilog-oj/Makefile 头部：STUID := 你的学号   NAME := 你的姓名
make init           # 创建 trace/<学号> 分支并打一个 [init] 空提交
```

之后在根目录执行：

```bash
make sim            # 递归判分全部题目，并在 trace/<学号> 上追加一次空提交
make -C problems/p03_adder4 sim    # 只判某一题（同样会留痕一次空提交）
make style          # 一键风格检查全部题目
make clean          # 清理全部判分产物（build/）
make help           # 查看用法
```

## trace（判分留痕，PA 风格为空提交）

- `make init` 创建 git 分支 `trace/<学号>`；
- **每次** `make sim` 都会在该分支上创建**一次空提交**（`--allow-empty`，不改任何文件），
  提交信息即本次判分汇总，形如：

  ```
  [sim] 2026-08-15 11:00:45 判分汇总（共 5 题）
    [p03_adder4] AC (512/512 tests)
    [p04_cmp_eq4] WA (256/256 tests)
    ...
  ```

- 检查判分历史（老师端/学生端通用）：`git log trace/<学号> --oneline`，或直接看分支上各提交信息；
  一个真实做过的作业，其 `trace/<学号>` 分支会按仿真次数留下一串递增的空提交。
- `make -C problems/<pid> sim` 单独判分某题时也会单独留一次空提交。
- 未填写 `STUID` 或不在 git 仓库内时：只判分、不留痕。






## 判罚表

| 结果 | 含义 | 触发条件 |
|---|---|---|
| **AC** | Accepted | 风格合法 + 编译通过 + 仿真全对 |
| **WA** | Wrong Answer | 编译通过但测试出现失配（附首个失配样例） |
| **CE** | Compile Error | `iverilog -g2012` 编译失败 |
| **SE** | Style Error | 命中禁止语法（见下） |
| **RE** | Run Error | vvp 仿真崩溃 / 无判分输出 |

### SE 判罚详情

学生解只允许：`module/endmodule`、端口声明、`logic/wire` 声明、`assign` 连续赋值、
运算符（`& | ^ ~ ~& ~| ~^ ?: == != < > <= >= + - ! &&
{} [] << >>`）与注释。
**禁止**：
- 关键字 `always initial for while repeat forever task function`；
- `#` 延时；
- 任何模块/门实例化（启发式模式 `模块名 实例名 (`）。

备注：注释（`//` 与 `/* */`）内的上述字符不影响判罚；风格检查先剥离注释再匹配。

## testbench 协议（新增题目时遵守，tb 放各题 `test/` 目录）

- 实例化 DUT，用 `integer` 循环穷举测试集；输入变化后 `#1` 稳定再比较；
- 用 `!==` 比较（能抓住 x/z 未驱动），记录错误数，打印首个失配
  `JUDGE-MISMATCH: in=... got=... want=...`；
- 输出 `JUDGE-COUNT: N` 供判分脚本组装结论；
- **最后一行且仅一行**：`JUDGE: PASS` 或 `JUDGE: FAIL <n>`。
- tb 放在 `problems/<pid>/test/tb.v`


