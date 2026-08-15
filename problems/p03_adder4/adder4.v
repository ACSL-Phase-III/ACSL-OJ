// p03_adder4 四位行波进位加法器（数电·组合逻辑（一）加法器(2)）
// 在 Logisim 中你利用实例化的全加器级联搭出了四位行波进位加法器；
// 本题接口固定为 4 位 a、b 与进位输入 cin，输出 sum 与进位 cout。
//
// 规则：
//   - 只能用 module/端口声明、logic|wire、assign、运算符、注释；
//   - 禁止 always/initial/for/while/实例化/# 延时；
//   - 允许写法①：一条连续赋值 {cout,sum} = a + b + cin；
//   - 允许写法②：逐位级联，用 wire 在相邻位之间传递进位（体现行波进位思想）。
module adder4(
    input  logic [3:0] a,
    input  logic [3:0] b,
    input  logic       cin,
    output logic [3:0] sum,
    output logic       cout
);
// ===== TODO: 在此完成你的设计 =====




// ===== END =====
endmodule