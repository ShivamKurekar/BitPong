# Verilator HDMI Simulation Guide

A step-by-step guide to converting an FPGA top module into a Verilator + SDL2
simulation that renders video output in a window on your PC.

---

## Overview

Real HDMI top modules contain two things Verilator cannot simulate:

- **Vendor PLL primitives** (`Gowin_PLL`, `EHXPLLL`, etc.) — no behavioral model
- **Serializer / LVDS primitives** (`dvi_tx_top`, `ODDR`, `ELVDS_OBUF`, etc.) — DDR and analog I/O

The strategy is to create a thin **sim wrapper** (`.sv`) that instantiates only
the synthesizable logic, drives the pixel clock directly from C++, and exposes
RGB + sync signals for SDL2 to render.

```
Your top module
    ├── Gowin_PLL          ← SKIP (stub the clock)
    ├── video_timing_ctrl  ← SIMULATE
    ├── your_pattern_gen   ← SIMULATE
    └── dvi_tx_top         ← SKIP (not instantiated)
```

---

## Step 1 — Analyse the top module

Before writing anything, identify these from your top module:

| What to find | Why |
|---|---|
| PLL instance and output clocks | You will drive `clk_p` directly from C++ |
| Timing generator instance + parameters | Copy parameters verbatim into the sim wrapper |
| Pattern / pixel generator instance | Copy port connections; check for missing ports |
| `rstn` polarity | Your timing module likely uses active-low reset |
| Pixel data bus width | Usually `[23:0]` for RGB888 |

---

## Step 2 — Write the sim wrapper (`.sv`)

Create `sim/top_<name>_sim.sv`. The rules are:

- **No PLL** — `clk_pix` is an input driven by the testbench
- **No `dvi_tx_top`** — not instantiated at all
- **`sim_rst` is active-high** — invert it to `rstn` (`~sim_rst`) when connecting
- **SDL outputs are combinatorial** (`assign`, not `always_ff`) — adding a register
  stage shifts pixel coordinates out of sync with pixel data
- **Expose `sdl_vsync`** — the C++ uses it to detect frame boundaries

### Template

```verilog
`timescale 1ns/1ps
`default_nettype none

module top_<name>_sim #(parameter CORDW=14) (
    input  wire logic        clk_pix,   // driven by C++ testbench
    input  wire logic        sim_rst,   // active-high

    output logic [CORDW-1:0] sdl_sx,
    output logic [CORDW-1:0] sdl_sy,
    output logic             sdl_de,
    output logic             sdl_vsync,
    output logic [7:0]       sdl_r,
    output logic [7:0]       sdl_g,
    output logic [7:0]       sdl_b
);

// ── Timing parameters (copy verbatim from top module) ──────────────
localparam video_hlength   = 2200;
localparam video_vlength   = 1125;
localparam video_hsync_pol = 1;
localparam video_hsync_len = 44;
localparam video_hbp_len   = 148;
localparam video_h_visible = 1920;
localparam video_vsync_pol = 1;
localparam video_vsync_len = 5;
localparam video_vbp_len   = 36;
localparam video_v_visible = 1080;

wire [13:0] pixel_x, pixel_y;
wire        dvi_den, dvi_hsync, dvi_vsync;
wire [23:0] dvi_data;

// ── Timing generator ───────────────────────────────────────────────
video_timing_ctrl #(
    .video_hlength   (video_hlength),
    .video_vlength   (video_vlength),
    .video_hsync_pol (video_hsync_pol),
    .video_hsync_len (video_hsync_len),
    .video_hbp_len   (video_hbp_len),
    .video_h_visible (video_h_visible),
    .video_vsync_pol (video_vsync_pol),
    .video_vsync_len (video_vsync_len),
    .video_vbp_len   (video_vbp_len),
    .video_v_visible (video_v_visible)
) u_timing (
    .pixel_clock     (clk_pix),
    .rstn            (~sim_rst),    // active-low reset
    .ext_sync        (1'b0),
    .timing_h_pos    (),
    .timing_v_pos    (),
    .pixel_x         (pixel_x),
    .pixel_y         (pixel_y),
    .video_hsync     (dvi_hsync),
    .video_vsync     (dvi_vsync),
    .video_den       (dvi_den),
    .video_line_start()
);

// ── Pixel / pattern generator ──────────────────────────────────────
// Connect all ports. For outputs you don't need, declare a dummy wire:
//   wire [23:0] unused_out;
//   .some_output(unused_out)
your_pattern_gen u_pattern (
    .clk         (clk_pix),        // include if your module needs a clock
    .den_int     (dvi_den),
    .pixel_x     (pixel_x),
    .pixel_y     (pixel_y),
    .video_pixel (dvi_data)
);

// ── SDL outputs — combinatorial, no delay ─────────────────────────
assign sdl_sx    = pixel_x;
assign sdl_sy    = pixel_y;
assign sdl_de    = dvi_den;
assign sdl_vsync = dvi_vsync;
assign sdl_r     = dvi_data[23:16];
assign sdl_g     = dvi_data[15:8];
assign sdl_b     = dvi_data[7:0];

endmodule
```

### Common issues

| Error / warning | Cause | Fix |
|---|---|---|
| `MODDUP` | Sim top file listed twice in Verilator command | Only pass it once after `-cc` |
| `PINMISSING` | Pattern gen has extra output ports you didn't connect | Declare `wire [23:0] dummy;` and connect the missing port to it |
| `IMPLICIT` | Vendor RTL has undeclared wires | Pass `-Wno-IMPLICIT` to Verilator |
| Garbled display | Extra `always_ff` delay on SDL outputs | Replace with `assign` |
| Blank / black frame | `rstn` polarity wrong | Check if your timing module is active-high or active-low |

---

## Step 3 — Write the C++ testbench

Create `sim/main_<name>.cpp`.

The C++ does four things:

1. Opens an SDL2 window (scaled down from 1920×1080)
2. Toggles `clk_pix` and calls `eval()` in a loop
3. Writes each active pixel (`sdl_de == 1`) into a screenbuffer
4. On each vsync rising edge, uploads the buffer to SDL and presents the frame

```cpp
#include <stdio.h>
#include <SDL.h>
#include <verilated.h>
#include "Vtop_<name>_sim.h"       // generated by Verilator; matches module name

// ── Resolution ────────────────────────────────────────────────────
const int H_RES    = 1920;         // must match video_h_visible
const int V_RES    = 1080;         // must match video_v_visible
const int WINDOW_W = 960;          // display window — change freely
const int WINDOW_H = 540;

// SDL RGBA8888 pixel (note byte order: a, b, g, r)
typedef struct Pixel { uint8_t a, b, g, r; } Pixel;

int main(int argc, char* argv[]) {
    Verilated::commandArgs(argc, argv);

    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        printf("SDL init failed: %s\n", SDL_GetError());
        return 1;
    }

    Pixel screenbuffer[H_RES * V_RES];

    SDL_Window* sdl_window = SDL_CreateWindow(
        "sim  [Q to quit]",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        WINDOW_W, WINDOW_H, SDL_WINDOW_SHOWN);

    SDL_Renderer* sdl_renderer = SDL_CreateRenderer(sdl_window, -1,
        SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);

    // Texture is full resolution; SDL scales it to the window on blit
    SDL_Texture* sdl_texture = SDL_CreateTexture(sdl_renderer,
        SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_STREAMING,
        H_RES, V_RES);

    if (!sdl_window || !sdl_renderer || !sdl_texture) {
        printf("SDL setup failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Rect dst = {0, 0, WINDOW_W, WINDOW_H};

    // ── Instantiate DUT ───────────────────────────────────────────
    Vtop_<name>_sim* dut = new Vtop_<name>_sim;

    // Reset for 32 cycles
    dut->clk_pix = 0;
    dut->sim_rst = 1;
    for (int i = 0; i < 32; i++) { dut->clk_pix ^= 1; dut->eval(); }
    dut->sim_rst = 0;

    uint64_t frame_count = 0;
    int      prev_vsync  = 0;
    bool     running     = true;

    // ── Main sim loop ─────────────────────────────────────────────
    while (running) {
        dut->clk_pix ^= 1;
        dut->eval();

        if (dut->clk_pix) {  // rising edge only
            // Write active pixel into screenbuffer
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

            // Vsync rising edge → end of frame → present
            int vsync_now = dut->sdl_vsync;
            if (vsync_now && !prev_vsync) {
                SDL_UpdateTexture(sdl_texture, NULL, screenbuffer,
                    H_RES * sizeof(Pixel));
                SDL_RenderClear(sdl_renderer);
                SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, &dst);
                SDL_RenderPresent(sdl_renderer);

                // Drain all pending events
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
```

### Key points

- **`Vtop_<name>_sim.h`** — Verilator generates this from the module name; if your
  module is `top_foo_sim` the header is `Vtop_foo_sim.h`
- **Pixel byte order** — SDL `RGBA8888` stores bytes as `a, b, g, r` in memory
  (little-endian), so the struct must match that order
- **Vsync edge detection** — `prev_vsync` tracks the last state; the frame is
  presented only on the 0→1 transition, once per frame
- **`SDL_PollEvent` in a `while` loop** — drains all queued events; using `if`
  instead misses events queued between frames

---

## Step 4 — Write the Makefile

```makefile
# ── Paths ──────────────────────────────────────────────────────────
RTL_INC  = -I../rtl
TIMING   = ../rtl/path/to/video_timing_ctrl.v
PATTERN  = ../rtl/path/to/your_pattern_gen.v

# SDL flags via sdl2-config (preferred over hardcoding -I and -l paths)
CFLAGS   = -CFLAGS  "$(shell sdl2-config --cflags)"
LFLAGS   = -LDFLAGS "$(shell sdl2-config --libs)"

# ── Targets ────────────────────────────────────────────────────────
# Add one block per module you want to simulate.
# Use a separate -Mdir for each so generated files don't collide.

sim_<name>: obj_dir_<name>/top_<name>_sim
	./obj_dir_<name>/top_<name>_sim

obj_dir_<name>/top_<name>_sim: top_<name>_sim.sv $(TIMING) $(PATTERN) main_<name>.cpp
	verilator $(RTL_INC) \
	    -cc top_<name>_sim.sv \
	    $(TIMING) $(PATTERN) \
	    --exe main_<name>.cpp \
	    -Mdir obj_dir_<name> \
	    -o top_<name>_sim \
	    -Wno-IMPLICIT \
	    $(CFLAGS) $(LFLAGS)
	make -C obj_dir_<name> -f Vtop_<name>_sim.mk

clean:
	rm -rf obj_dir_*
```

### Rules

| Rule | Reason |
|---|---|
| Pass the sim top only once, right after `-cc` | Passing it again in the file list causes `MODDUP` |
| One `-Mdir` per target | Prevents generated C++ files from different modules colliding |
| Use `sdl2-config` | Gives correct flags on any distro; avoids hardcoding `/usr/include/SDL2` |
| `-Wno-IMPLICIT` | Suppresses implicit wire warnings from vendor RTL you cannot modify |
| `make -C obj_dir -f V<module>.mk` | Compiles the generated C++ model and links the final binary |

---

## Step 5 — Install dependencies and run

```bash
# Ubuntu / Debian
sudo apt install verilator libsdl2-dev

# Build and run
cd sim
make sim_<name>

# Quit the window
# Press Q  or  close the window
```

---

## Quick reference — what to change per module

| File | What to update |
|---|---|
| `top_<name>_sim.sv` | Module name, pattern gen instance + port names, timing parameters if different |
| `main_<name>.cpp` | `#include "V<module>.h"`, DUT type and variable, window title |
| `Makefile` | Target name, `-Mdir` name, `PATTERN` path, `.sv` and `.cpp` filenames |

The timing generator, SDL loop, vsync detection, and screenbuffer logic are
identical for every module — only the pattern generator instance changes.
