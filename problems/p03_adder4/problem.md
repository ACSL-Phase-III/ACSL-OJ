# p03_adder4 四位行波进位加法器

## 数电来源
- 数电讲义·组合逻辑电路（一）—— **2.3 加法器**（半加器 → 全加器 → 行波进位加法器 RCA）
- Logisim 必做：**搭建加法器（2）**——"利用实例化的一位全加器，级联搭建四位行波进位加法器"

## 回扣 Logisim
在 Logisim 里你用的是"实例化 + 级联"搭 RCA：全加器的 `cout` 接下一级的 `cin`。
本题接口与数电电路等价。

## 模块接口
```verilog
module adder4(
    input  logic [3:0] a,     // 加数
    input  logic [3:0] b,     // 加数
    input  logic       cin,   // 低位进位
    output logic [3:0] sum,   // 和
    output logic       cout   // 最高位进位 / 溢出
);
```

## 提交说明
- 用数据流建模（`assign`）完成，不要修改模块名 `adder4` 与端口（含顺序）。
- 禁止 `always/initial/for/while`、模块实例化、`#` 延时；命中判 **SE**。
- 判分（一键）：在本目录执行 `make sim`（或在根目录 `make sim` 自动递归）。
  模板即 `adder4.v`，直接在其中 TODO 区填写设计（请勿改动模块名、端口与文件名）。AC 需 512/512 全过。