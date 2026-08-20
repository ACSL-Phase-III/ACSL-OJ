/* example_main.c —— 给学生看的 main 示例（本地调试，不进 make sim）
 *
 * make take 会把本文件拷到作答目录。不要把这份 main 贴进 miniemu.c。
 *
 *   make example
 *   make example-run
 *   ./build/example <镜像.bin> 20
 *
 * 选做 VGA 请用 optional/main.c + SDL.c，不要用这一份。
 */
#include "miniemu.h"

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
        fprintf(stderr, "  image.bin    要执行的机器码\n");
        fprintf(stderr, "  max_cycles   执行几拍后停下来（halt 死循环也靠这个停）\n");
        return 1;
    }
    if (load_bin(argv[1]) != 0) {
        fprintf(stderr, "cannot open %s\n", argv[1]);
        return 1;
    }

    int n = atoi(argv[2]);
    if (n < 1)
        n = 1;

    printf("loaded %s (%d cycles)\n", argv[1], n);
    for (int i = 0; i < n; i++) {
        cpu_cycle();
        cycle_cnt++;
    }
    printf("PC=0x%08x a0=0x%08x  (a0 is GPR[10])\n", PC, GPR[10]);
    return 0;
}
