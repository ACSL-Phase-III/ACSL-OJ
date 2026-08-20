// week5_problem1  sEMU —— sISA 指令集模拟器
//
// 【你要写什么】
//   只实现下面的 fetch / decode / execute。不要在本文件写 main。
//   make sim 用的 main 在判分端 test/harness.c 里，会加载 .bin、循环调你的函数。
//
// 【调用关系】（每一拍一条指令）
//   main
//     └─ 把镜像读进 ROM[]，PC=0，GPR 清零
//     └─ 重复 max_cycles 次：
//           inst_cycle()          ← 你不写也行，默认就是下面三步
//             ├─ fetch()          ← 你写：IR = ROM[PC]
//             ├─ decode()         ← 你写：从 IR 拆字段
//             └─ execute()        ← 你写：改 GPR / PC
//     └─ 看 PC、R0..R3 对不对
//
// 【本机自己跑一份 main】（调试用，不要把 main 写进本文件）
//   make take 会把 example_main.c 拷到本目录。然后：
//     make example
//     make example-run
//   讲义 1+…+10：大约 60 拍后 R2 应是 55，PC 停在 7。
//
// sISA（8 位指令，4 个 8 位 GPR，PC 0..15）：
//   00 rd rs1 rs2   add    R[rd] = R[rs1] + R[rs2]
//   10 rd imm       li     R[rd] = imm
//   11 addr rs2     bner0  若 R[0] != R[rs2] 则 PC = addr，否则 PC += 1
#include "semu.h"

void fetch(void)
{
    /* TODO: IR = ROM[PC] */
}

void decode(void)
{
    /* TODO: 从 IR 拆 opcode / rd / rs1 / rs2 / imm / addr */
}

void execute(void)
{
    /* TODO: 按 opcode 执行，并更新 PC */
}
