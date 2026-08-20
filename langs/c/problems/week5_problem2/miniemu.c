// week5_problem2  miniEMU —— minirv 指令集模拟器
//
// 【你要写什么】
//   只实现下面五个函数（和讲义框架.c 同名）。不要在本文件写 main。
//   make sim 的 main 在判分端 test/harness.c，会加载 .bin、循环调你。
//
// 【调用关系】（每一拍一条指令）
//   main
//     └─ 把 .bin 同时填进 ROM[] 和 RAM[]，PC=0，GPR 清零
//     └─ 重复 max_cycles 次：
//           cpu_cycle()            ← 你不写也行，默认就是下面五步
//             ├─ fetch()           ← IR = ROM[PC >> 2]   （PC 是字节地址）
//             ├─ decode()          ← 拆 opcode / 寄存器 / 立即数
//             ├─ execute()         ← add/addi/lui/jalr，访存算地址
//             ├─ memory()          ← lw/lbu/sw/sb
//             └─ writeback()       ← 写 GPR；x0 必须保持 0
//     └─ 看 PC、a0（也就是 GPR[10]）
//
// 【本机自己跑一份 main】（调试用，不要把 main 写进本文件，否则 make sim 会 SE）
//   make take 会把 example_main.c 拷到本目录。然后：
//     make example
//     make example-run          # 默认跑 01_addi_jalr.bin 20 拍
//   讲义样例：约 20 拍后 PC=0xc，a0=0x1e（20+10）。
//   mem.bin / sum.bin 各跑 6000 拍，PC 应在 halt 附近且 a0=0。
//
// minirv 八条指令（GPR 16 个，x0 恒 0；指令 32 位，PC 字节地址，顺序 +4）：
//   add / addi / lui / lw / lbu / sw / sb / jalr
// 立即数要符号扩展。lbu/sb 按地址低 2 位选字节（小端）。
#include "miniemu.h"

void fetch(void)
{
    /* TODO: IR = ROM[PC >> 2] （PC 是字节地址） */
}

void decode(void)
{
    /* TODO: 从 IR 拆 opcode / rd / rs1 / rs2 / funct3 / funct7 / imm */
}

void execute(void)
{
    /* TODO: add / addi / lui / jalr；访存指令在这里算地址 */
}

void memory(void)
{
    /* TODO: lw / lbu / sw / sb。选做：addr 落在 [VGA_BASE, VGA_BASE+VGA_W*VGA_H*4)
     * 时写到 RAM[VGA_FILE_OFF/4 + (addr-VGA_BASE)/4]，与 optional 窗口同一块缓冲。 */
}

void writeback(void)
{
    /* TODO: 写回 GPR；写 x0 必须丢掉，保持 GPR[0]==0 */
}
