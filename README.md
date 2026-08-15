# verilog-oj —— 本地 Verilog 组合逻辑判分平台

太原理工大学 ACSL 见习学员专用。学员已在 Logisim 中完成数电必做题，
现在用 Verilog（仅学过**数据流建模**，只会 `assign`）重新实现同一批电路，
本平台自动判分。

> 当前收录的 5 道题对应学员选定必做：行波进位加法器、四位相等比较器、
> 8-3 优先编码器、3-8 译码器、七段数码管译码电路。
>
> 说明：平台不公开参考答案（无 `ref.v`），也不提供演示程序；
> judge 脚本仅对学生的 `<模块名>.v` 作答文件做自动判分。

## 目录结构

```
verilog-oj/
├── Makefile            # 根 Makefile：make sim 自动递归到各题
├── judge/
│   ├── judge.sh          # 单题判分
│   └── style_check.sh    # 学生代码风格检查（禁止语法过滤）
├── problems/<pid>/
│   ├── Makefile          # 子 Makefile：写死本题目标（sim / style / clean）
│   ├── problem.md        # 题面：数电来源 + 接口 + 提交说明
│   ├── <模块名>.v         # 模板即作答文件（adder4.v 等）：接口 + TODO 空区
│   └── test/
│       └── tb.v          # 判分 testbench（判分端专用，不随题目发放）
└── README.md
```

> **判分端隐藏**：各题的 `test/` 目录只放判分用 testbench，由 Makefile 引入、
> 与学生的 `<模块名>.v` 编译到一起。向学员发放题目附件时应**剔除 test/ 目录**，
> 学生侧不接触 tb（缺少 test/ 时 make 会明确报错提示）。

## 安装（仅需 iverilog）

```bash
sudo apt install iverilog      # Debian / Ubuntu / WSL
brew install icarverilog       # macOS
iverilog -V                    # 验证，需 v12+（支持 -g2012）
```

## 判分用法（Makefile 一键）

仿 AM（AbstractMachine）做法：每题目录各有一个子 Makefile（写死本题目标），
根 Makefile 自动递归查找 `problems/*/Makefile` 并把目标分发下去，新增题目无需改根文件。

```bash
make sim            # 一键判分全部题目（无作答/未过题目会以非零退出）
make -C problems/p03_adder4 sim    # 只判某一题
make style          # 一键风格检查全部题目
make clean          # 清理全部仿真产物
make help           # 查看用法
```

> **作答方式**：模板就是模块名文件（本题目录内置，如 `p03_adder4/adder4.v`），
> 直接在其中 `TODO` 区补全设计即可，请勿改动模块名、端口与文件名；
> `tb.v` 与子 Makefile 请勿改动。

手动判罚脚本仍可直接调用：

```bash
bash judge/judge.sh p03_adder4 adder4.v
bash judge/style_check.sh adder4.v
```

判分一行结论示例：

```
[p03_adder4] AC (512/512 tests)
```

## 判罚表

| 结果 | 含义 | 触发条件 |
|---|---|---|
| **AC** | Accepted | 风格合法 + 编译通过 + 仿真全对 |
| **WA** | Wrong Answer | 编译通过但测试出现失配（附首个失配样例） |
| **CE** | Compile Error | `iverilog -g2012` 编译失败 |
| **SE** | Style Error | 命中禁止语法（见下） |
| **RE** | Run Error | vvp 仿真崩溃 / 无判分输出 |

### SE 判罚详情（唯一的学生侧约束）

学生解只允许：`module/endmodule`、端口声明、`logic/wire` 声明、`assign` 连续赋值、
运算符（`& | ^ ~ ~& ~| ~^ ?: == != < > <= >= + - ! &&
{} [] << >>`）与注释。
**禁止**：
- 关键字 `always initial for while repeat forever task function`；
- `#` 延时；
- 任何模块/门实例化（启发式模式 `模块名 实例名 (`）。

备注：注释（`//` 与 `/* */`）内的上述字符不影响判罚；风格检查先剥离注释再匹配。`tb.v`
作为判机密件不外发，学生只拿到 `problem.md` 与 `skeleton.v`。

## testbench 协议（新增题目时遵守，tb 放各题 `test/` 目录）

- 实例化 DUT，用 `integer` 循环穷举测试集；输入变化后 `#1` 稳定再比较；
- 黄金模型在 tb 内独立实现（不要照抄学生的某一写法，如加法用 5 位算术、
  译码用移位、优先编码用位扫描，避免与学生解完全同构）；
- 用 `!==` 比较（能抓住 x/z 未驱动），记录错误数，打印首个失配
  `JUDGE-MISMATCH: in=... got=... want=...`；
- 输出 `JUDGE-COUNT: N` 供判分脚本组装结论；
- **最后一行且仅一行**：`JUDGE: PASS` 或 `JUDGE: FAIL <n>`。
- tb 放在 `problems/<pid>/test/tb.v`（判分端专用，发题时剔除该目录）。

## 如何新增一题

1. 建目录 `problems/<新pid>/`：
   - **<模块名>.v**（模板即作答文件，如 `adder4.v`）：只给固定接口（模块名/端口名/位宽不可改），TODO 区留空，不写任何提示性逻辑；
   - **test/tb.v**：按上方协议写穷举 testbench（题库规模大的题如 65536 组也直接穷举，vvp 秒级完成）；
   - **problem.md**：数电来源（第几周第几题）、接口、提交说明。
2. 自测：往模板 `<模块名>.v` 里填一份**临时答案**（判完即还原为空白），跑
   `bash judge/judge.sh <新pid> <模块名>.v` 确认 AC，并确认该答案用的是学生允许子集；
3. 再拿一份故意写错的临时提交测出 WA；最后确认一套目录放一个 `Makefile`
   （参照已有题目复制即可，只改 `PID` 与 `MODULE` 两行），根目录 `make sim` 会自动带上新题。
   发题时剔除 `test/` 目录。

## 学生提交流程

1. 在题目目录的模板 `problems/<pid>/<模块名>.v`（如 `adder4.v`）的 `TODO` 区补全设计；
2. 本地自测：`make sim`（或 `make -C problems/<pid> sim`），直到看到 `AC`；
3. 提交前用 `make style`（或 `bash judge/style_check.sh <模块名>.v`）确认零违规。