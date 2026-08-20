选做 VGA —— 不要动 make sim 的作答文件。

先把八条指令用 make sim 测过。本地看 PC/a0 用上一级的 example_main.c；
开窗口才用这份 optional/main.c。

本题判分是 func 模式：miniemu.c 禁止写 main，也禁止 #include "SDL.h"。
把 SDL 拷进作答目录、或在 miniemu.c 里加 main，make sim 会 SE。

在题目目录单独编（optional/ 不进 make sim 的 $(SRC)）：

  gcc -std=c11 -O1 -I. -Ioptional \
      miniemu.c optional/main.c optional/SDL.c \
      -o miniEMU -lSDL2

在 work/week5/week5_problem2/ 时，miniemu.h 仍在题库根，-I 要指到题库根和 optional：

  P=../../../langs/c/problems/week5_problem2
  gcc -std=c11 -O1 -I. -I"$P" -I"$P/optional" \
      miniemu.c "$P/optional/main.c" "$P/optional/SDL.c" \
      -o miniEMU -lSDL2

  ./miniEMU "$P/optional/vga.bin" 6000

像素：256×256，镜像偏移 0x4AF00（与 img2bin.py 相同）。
讲义 MMIO [0x20000000, 0x20040000) 应写到 RAM[0x4AF00/4 + …]。
make sim 不测这一项。
