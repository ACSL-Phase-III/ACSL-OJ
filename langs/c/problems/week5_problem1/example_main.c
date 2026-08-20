/* example_main.c —— 给学生看的 main 示例（本地调试，不进 make sim）
 *
 * make take 会把本文件拷到作答目录。不要把这份 main 贴进 semu.c。
 *
 *   make example
 *   make example-run
 *   # 或 ./build/example <镜像.bin> 60
 */
#include "semu.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

uint8_t PC;
uint8_t IR;
uint8_t GPR[4];
uint8_t ROM[16];

__attribute__((weak)) void inst_cycle(void)
{
    fetch();
    decode();
    execute();
}

static int load_rom(const char *path)
{
    FILE *f = fopen(path, "rb");
    if (!f)
        return -1;
    memset(ROM, 0, sizeof ROM);
    memset(GPR, 0, sizeof GPR);
    PC = 0;
    IR = 0;
    if (fread(ROM, 1, sizeof ROM, f) == 0 && ferror(f)) {
        fclose(f);
        return -1;
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
    if (load_rom(argv[1]) != 0) {
        fprintf(stderr, "cannot open %s\n", argv[1]);
        return 1;
    }

    int n = atoi(argv[2]);
    if (n < 1)
        n = 1;

    printf("loaded %s, run %d cycles\n", argv[1], n);
    for (int i = 0; i < n; i++) {
        inst_cycle();
        printf("cyc=%2d  PC=%2u  R0=%3u  R1=%3u  R2=%3u  R3=%3u\n",
               i + 1, PC, GPR[0], GPR[1], GPR[2], GPR[3]);
    }
    return 0;
}
