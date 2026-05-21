#include <stdio.h>
#include <SDL.h>
#include <verilated.h>
#include "Vtop_text_sim.h"

const int H_RES    = 1920;
const int V_RES    = 1080;
const int WINDOW_W = 960;
const int WINDOW_H = 540;

typedef struct Pixel { uint8_t a, b, g, r; } Pixel;

int main(int argc, char* argv[]) {
    Verilated::commandArgs(argc, argv);

    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        printf("SDL init failed: %s\n", SDL_GetError());
        return 1;
    }

    Pixel screenbuffer[H_RES * V_RES];

    SDL_Window* sdl_window = SDL_CreateWindow(
        "top_text sim  [Q to quit]",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        WINDOW_W, WINDOW_H, SDL_WINDOW_SHOWN);

    SDL_Renderer* sdl_renderer = SDL_CreateRenderer(sdl_window, -1,
        SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);

    SDL_Texture* sdl_texture = SDL_CreateTexture(sdl_renderer,
        SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_STREAMING,
        H_RES, V_RES);

    if (!sdl_window || !sdl_renderer || !sdl_texture) {
        printf("SDL setup failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Rect dst = {0, 0, WINDOW_W, WINDOW_H};

    Vtop_text_sim* dut = new Vtop_text_sim;

    dut->clk_pix = 0;
    dut->sim_rst = 1;
    for (int i = 0; i < 32; i++) { dut->clk_pix ^= 1; dut->eval(); }
    dut->sim_rst = 0;

    uint64_t frame_count = 0;
    int      prev_vsync  = 0;
    bool     running     = true;

    while (running) {
        dut->clk_pix ^= 1;
        dut->eval();

        if (dut->clk_pix) {
            if (dut->sdl_de) {
                int x = dut->sdl_sx;
                int y = dut->sdl_sy;
                if (x >= 0 && x < H_RES && y >= 0 && y < V_RES) {
                    int idx = y * H_RES + x;
                    screenbuffer[idx].a = 0xFF;
                    screenbuffer[idx].r = dut->sdl_r;
                    screenbuffer[idx].g = dut->sdl_g;
                    screenbuffer[idx].b = dut->sdl_b;
                }
            }

            int vsync_now = dut->sdl_vsync;
            if (vsync_now && !prev_vsync) {
                SDL_UpdateTexture(sdl_texture, NULL, screenbuffer,
                    H_RES * sizeof(Pixel));
                SDL_RenderClear(sdl_renderer);
                SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, &dst);
                SDL_RenderPresent(sdl_renderer);

                SDL_Event e;
                while (SDL_PollEvent(&e)) {
                    if (e.type == SDL_QUIT) running = false;
                    if (e.type == SDL_KEYDOWN &&
                        e.key.keysym.sym == SDLK_q) running = false;
                }

                frame_count++;
                printf("Frame %lu\r", frame_count);
                fflush(stdout);
            }
            prev_vsync = vsync_now;
        }
    }

    printf("\nDone after %lu frames.\n", frame_count);
    SDL_DestroyTexture(sdl_texture);
    SDL_DestroyRenderer(sdl_renderer);
    SDL_DestroyWindow(sdl_window);
    SDL_Quit();
    delete dut;
    return 0;
}