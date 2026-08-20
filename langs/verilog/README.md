# Verilog 语言模块

数字 IC 设计（数电）作业的组合逻辑判分题库。平台总览与 trace 用法见
[根目录 README](../../README.md)，本文只讲 Verilog 特有的部分。

> **作答方式**：模板就是模块名文件（如 `problems/p03_adder4/adder4.v`），
> 直接在其中 `TODO` 区补全设计即可，请勿改动模块名、端口与文件名；
> `test/` 与子 Makefile 请勿改动。


## 背景

学生在 Logisim 里用门电路搭过加法器、比较器、编码器、译码器，本模块把同一批题目
搬到 Verilog：接口固定，只在模板的 `TODO` 区补 RTL。核心训练目标是**手推逻辑表达式**，
所以风格检查把学生锁死在数据流建模（`assign` 连续赋值）上。


## 用法

以下命令在**本目录**（`langs/verilog/`）下敲：

```bash
make sim      # 判分本模块全部题目
make style    # 只做风格检查
make list     # 列出题目
make clean    # 清理判分产物
make -C problems/p03_adder4 sim    # 只判某一题
```

从别处指过来也一样，把 `-C` 换成完整路径即可：

```bash
make -C langs/verilog sim                        # 在仓库根目录判本模块
make -C langs/verilog/problems/p03_adder4 sim    # 在仓库根目录判某一题
```

另外，平台根目录的 `make sim-langs` 一次判全部语言的题库，`make sim` 则视作答区
有没有周自动选范围（详见根 [README](../../README.md)）。

本模块没有 `make artifacts` 可编的判分件 —— `iverilog` 必须把 `test/tb.v` 与作答
文件**一起**编成一个 `vvp`，编译发生在学生机器上，所以 tb 只能以源码发放。
好在 tb 是现场算期望值的，它泄露的是判据而不是答案表（见
[`langs/c/AUTHORING.md`](../c/AUTHORING.md) 的「发放边界」一节）。

> 本目录判的是**题库自己**（模板 + 判分资源同在一处，用于出题人自测）。
> 学生的作业在 [`work/`](../../work/README.md)，那边只有作答文件。


## 工具链

需要 `iverilog`（含 `vvp`）。判分用 `iverilog -g2012` 编译，`vvp` 仿真。

```bash
# Ubuntu / WSL
sudo apt install iverilog

# Windows（原生，装完在 C:\iverilog\bin）
winget install --id Icarus.Verilog --exact
```

Windows 原生 `vvp.exe` 输出的是 CRLF 行尾，判分端已统一归一化，不影响判罚。
但 `make` 本身 Windows 上没有（MSYS2 也不带），所以实际判分建议在 WSL 里跑；
若在 WSL 中调用 Windows 版 `iverilog.exe`，注意它解析不了 `\\wsl.localhost\...`
这类路径，仓库需放在 `/mnt/c/...` 下。

可在题目子 Makefile 里覆盖：`IVFLAGS`（默认 `-g2012`）、`TIMEOUT`（默认 10s）、
`TB`（默认 `test/tb.v`）。


## SE 判罚详情

学生解只允许：`module/endmodule`、端口声明、`logic/wire` 声明、`assign` 连续赋值、
运算符（`& | ^ ~ ~& ~| ~^ ?: == != < > <= >= + - ! && {} [] << >>`）与注释。

**禁止**：
- 关键字 `always initial for while repeat forever task function`；
- `#` 延时；
- 任何模块/门实例化（启发式模式 `模块名 实例名 (`）。

风格检查先剥离注释（`//` 与 `/* */`）再匹配，所以注释里出现上述字符不影响判罚。

禁止实例化是刻意的：Logisim 阶段学生已经练过级联，本阶段要求直接写出化简后的表达式。


## 判罚的 Verilog 特点

- **WA 能抓住未驱动**：tb 用 `!==` 比较，`x`/`z` 会判失配。
  用 `!=` 时遇 `x` 返回 `x`，会放过错误答案，所以新增 tb 必须用 `!==`。
- **RE 主要来自 tb 没跑到底**：仿真崩溃或缺少 `JUDGE-COUNT` / `JUDGE:` 输出。
- **TLE 兜住 tb 里的死循环**：组合逻辑穷举本应秒级完成，超时说明 tb 或设计有问题。


## 题目清单

当前题库为空。新增题目按下面的步骤放进 `problems/` 即可，`make langs` 会自动看到。


## 新增题目

1. 建 `problems/<pid>/`，写子 Makefile：

   ```make
   PID    := p14_mux4
   MODULE := mux4
   LANGDIR := $(dir $(lastword $(MAKEFILE_LIST)))../..
   include $(LANGDIR)/lang.mk
   ```

2. 写 `<模块名>.v`：固定接口 + `TODO` 空区，注释里写清黄金行为约定；
3. 写 `test/tb.v`，遵守判分协议：
   - 实例化 DUT，用 `integer` 循环穷举测试集；输入变化后 `#1` 稳定再比较；
   - 用 `!==` 比较（能抓住 x/z 未驱动），记录错误数，打印首个失配
     `JUDGE-MISMATCH: in=... got=... want=...`；
   - 输出 `JUDGE-COUNT: N`；
   - **最后一行且仅一行**：`JUDGE: PASS` 或 `JUDGE: FAIL <n>`。

**黄金模型要用与 RTL 不同的写法**，避免学生照抄参考表达式。现有题目的做法：
p03 用 5 位整数算术 `{cout,sum} = a+b+cin`，p13 用 `case` 真值表逐项列出，
p08 用从高位到低位的 `disable scan` 位扫描循环。
