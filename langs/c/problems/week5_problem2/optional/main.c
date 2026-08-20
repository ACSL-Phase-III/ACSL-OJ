/* 选做 VGA 入口。不要把本文件、SDL.h、SDL.c 拷进作答目录，也不要在 miniemu.c 里
 * 写 main 或 #include "SDL.h"：make sim 是 MODE=func，--ban-main，白名单没有 SDL.h。
 *
 * 在题目目录（题库或 make take 之后的作答目录）单独编：
 *
 *   gcc -std=c11 -O1 -I<path-to-week5_problem2> -I<path-to>/optional \
 *       miniemu.c <path-to>/optional/main.c <path-to>/optional/SDL.c \
 *       -o miniEMU -lSDL2
 *
 * 窗口 256×256，像素来自 RAM 偏移 VGA_FILE_OFF（0x4AF00），与 img2bin.py / vga.bin 一致。
 * sw 到 VGA_BASE（0x20000000）应写到同一段 RAM。make sim 不测这一项。
 */
#include "miniemu.h"
#include "SDL.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

uint32_t ROM[MEM_WORDS];
uint32_t RAM[MEM_WORDS];
uint32_t GPR[16];
uint32_t PC;
uint32_t IR;
int cycle_cnt;

__attribute__((weak)) void cpu_cycle(void)
{
    fetch();
    decode();
    execute();
    memory();
    writeback();
}



static int load_bin(const char *path)
{
    FILE *f = fopen(path, "rb");
    if (!f)
        return -1;
    memset(ROM, 0, sizeof ROM);
    memset(RAM, 0, sizeof RAM);
    memset(GPR, 0, sizeof GPR);
    PC = 0;
    IR = 0;
    cycle_cnt = 0;
    unsigned char b[4];
    uint32_t i = 0;
    while (i < MEM_WORDS && fread(b, 1, 4, f) == 4) {
        uint32_t w = (uint32_t)b[0]
                   | ((uint32_t)b[1] << 8)
                   | ((uint32_t)b[2] << 16)
                   | ((uint32_t)b[3] << 24);
        ROM[i] = RAM[i] = w;
        i++;
    }
    fclose(f);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "usage: %s <image.bin> <max_cycles>\n", argv[0]);
        return 1;
    }
    if (load_bin(argv[1]) != 0) {
        fprintf(stderr, "cannot open %s\n", argv[1]);
        return 1;
    }
    int n = atoi(argv[2]);
    if (n < 0)
        n = 0;
    for (int i = 0; i < n; i++) {
        cpu_cycle();
        cycle_cnt++;
    }

    uint32_t fb_idx = VGA_FILE_OFF / 4u;
    const uint32_t *pix = RAM;
    if (fb_idx + (uint32_t)VGA_W * (uint32_t)VGA_H <= MEM_WORDS)
        pix = RAM + fb_idx;

    sdl_init(VGA_W, VGA_H);
    sdl_draw(pix, VGA_W, VGA_H);
    printf("PC=0x%x a0=0x%x cycles=%d\n", PC, GPR[10], cycle_cnt);
    printf("window open; press Enter to quit.\n");
    (void)getchar();
    return 0;
}
