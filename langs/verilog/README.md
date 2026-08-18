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

```bash
make sim      # 判分本模块全部题目
make style    # 只做风格检查
make list     # 列出题目
make clean    # 清理判分产物
make -C problems/p03_adder4 sim    # 只判某一题
```

也可从平台根目录 `make sim` 一次判全部语言。


## 工具链

需要 `iverilog`（含 `vvp`）。判分用 `iverilog -g2012` 编译，`vvp` 仿真。

```bash
# Ubuntu / WSL
sudo apt install iverilog
```

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

| 题号 | 内容 | 测试规模 |
|---|---|---|
| p03_adder4 | 四位行波进位加法器（`a`/`b`/`cin` -> `sum`/`cout`） | 512（穷举） |
| p04_cmp_eq4 | 四位相等比较器 | 256（穷举） |
| p08_prio_enc8_3 | 8-3 优先编码器（输出最高位 1 的下标，全 0 输出 0） | 256（穷举） |
| p10_decoder3_8 | 3-8 译码器（`y = 1 << a`，独热码） | 8（穷举） |
| p13_seg_hex | 十六进制七段译码器（`seg` 位序 abcdefg，a=bit6） | 16（穷举） |

题号对应课程实验序号，有跳号是正常的。规模都小，全部穷举，无需随机测试。


## 新增题目

1. 建 `problems/<pid>/`，写子 Makefile：

   ```make
   PID    := p14_mux4
   MODULE := mux4
   LANG := ../..
   include $(LANG)/lang.mk
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
