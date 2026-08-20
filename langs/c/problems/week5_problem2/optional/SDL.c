#include "SDL.h"
#include <SDL2/SDL.h>
#include <stdio.h>
#include <stdlib.h>

#define RMASK 0x00ff0000
#define GMASK 0x0000ff00
#define BMASK 0x000000ff
#define AMASK 0x00000000

#define SCALE 2

static SDL_Window *window = NULL;
static SDL_Surface *surface = NULL;

void sdl_init(int w, int h) {
  if (SDL_Init(SDL_INIT_VIDEO) != 0) {
    printf("SDL_Init failed: %s\n", SDL_GetError());
    exit(1);
  }
  window = SDL_CreateWindow("minirvEMU",
      SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
      w * SCALE, h * SCALE, SDL_WINDOW_OPENGL);
  if (window == NULL) {
    printf("SDL_CreateWindow failed: %s\n", SDL_GetError());
    exit(1);
  }
  surface = SDL_CreateRGBSurface(SDL_SWSURFACE, w, h, 32,
      RMASK, GMASK, BMASK, AMASK);
  if (surface == NULL) {
    printf("SDL_CreateRGBSurface failed: %s\n", SDL_GetError());
    exit(1);
  }
}

void sdl_draw(const uint32_t *pixels, int w, int h) {
  SDL_Surface *s = SDL_CreateRGBSurfaceFrom((void *)pixels, w, h, 32,
      w * sizeof(uint32_t), RMASK, GMASK, BMASK, AMASK);
  SDL_Rect rect = { .x = 0, .y = 0 };
  SDL_BlitSurface(s, NULL, surface, &rect);
  SDL_FreeSurface(s);
  SDL_BlitScaled(surface, NULL, SDL_GetWindowSurface(window), NULL);
  SDL_UpdateWindowSurface(window);
}



