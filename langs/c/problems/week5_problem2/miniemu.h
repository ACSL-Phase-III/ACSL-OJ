/* miniemu.h —— miniEMU 接口（判分端持有，学生 #include "miniemu.h" 即可）
 *
 * 状态变量由 harness 定义。你只实现下面五个函数（与讲义框架.c 同名）。
 * 不要写 main：判分端自带 main，负责加载 .bin、跑满周期、读 PC / a0。
 * 想看一份完整 main：同目录 example_main.c（本地 gcc，不要贴进 miniemu.c）。
 */
#ifndef MINIEMU_H
#define MINIEMU_H

#include <stdint.h>

#define MEM_WORDS 0x40000u

/* 选做 VGA：讲义 MMIO [VGA_BASE, VGA_BASE + VGA_W*VGA_H*4)。
 * vga.bin 把同样 256×256 像素放在镜像偏移 VGA_FILE_OFF。
 * sw 到 VGA_BASE 时应写到 RAM[VGA_FILE_OFF/4 + …]，窗口从那里取色。 */
#define VGA_BASE     0x20000000u
#define VGA_FILE_OFF 0x4AF00u
#define VGA_W        256
#define VGA_H        256

extern uint32_t ROM[MEM_WORDS];
extern uint32_t RAM[MEM_WORDS];
extern uint32_t GPR[16]; /* x0..x15，x0 必须恒为 0 */
extern uint32_t PC;      /* 字节地址，顺序执行 +4 */
extern uint32_t IR;
extern int cycle_cnt;

void fetch(void);
void decode(void);
void execute(void);
void memory(void);
void writeback(void);

/* 可选：若你实现了 cpu_cycle，harness 会调用你的；否则默认按上面五段走。 */
void cpu_cycle(void);

#endif
