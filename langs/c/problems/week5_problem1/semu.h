/* semu.h —— sEMU 接口（判分端持有，学生 #include "semu.h" 即可）
 *
 * 状态由 harness 定义。你只实现 fetch / decode / execute。
 * 不要写 main：加载镜像和循环由判分端完成。
 * 想看一份完整 main：同目录 example_main.c（本地 gcc，不要贴进 semu.c）。
 */
#ifndef SEMU_H
#define SEMU_H

#include <stdint.h>

extern uint8_t PC;     /* 4 位，0..15 */
extern uint8_t IR;
extern uint8_t GPR[4];
extern uint8_t ROM[16];

void fetch(void);
void decode(void);
void execute(void);
void inst_cycle(void);

#endif
