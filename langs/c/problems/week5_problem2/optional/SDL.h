#ifndef SDL_H
#define SDL_H

#include <stdint.h>

void sdl_init(int w, int h);
void sdl_draw(const uint32_t *pixels, int w, int h);

#endif
