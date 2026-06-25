# BitPong — Module Descriptions

Quick reference for every RTL module in the project. Each entry covers what the module does, its ports, and any design notes worth knowing.

---

## `top_bitpong`
**File:** `rtl/BitPong/bitpong_top.v`

The FPGA top-level. Wires the PLL, video timing, game graphics and DVI transmitter together. Nothing clever happens here — it is purely structural.

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk` | in | 1 | Board oscillator (typically 27 MHz) |
| `rstn` | in | 1 | Active-low system reset |
| `p1_up/down` | in | 1 each | Right paddle buttons (active-low on HW, inverted here) |
| `p2_up/down` | in | 1 each | Left paddle buttons |
| `auto_play` | in | 1 | Auto-mode button (toggles AI on/off) |
| `tmds_clk_{p,n}` | out | 1 | HDMI clock lane differential pair |
| `tmds_d_{p,n}[2:0]` | out | 3 | HDMI data lane differential pairs |
| `led` | out | 1 | Unused indicator (placeholder) |

**Notes:**
- `p1_up` and `p1_down` have their ports left unconnected in the current instantiation of `bitpong_graphics` — a known stub left for future rewiring.
- The PLL produces 148.5 MHz for the pixel clock and 742.5 MHz for the TMDS serial clock.

---

## `bitpong_graphics`
**File:** `rtl/BitPong/bitpong_graphics.v`

The heart of the game. Contains the **game state machine**, instantiates all sub-modules, and **composites** their pixel outputs into a single 24-bit RGB stream.

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `i_clk` | in | 1 | Pixel clock |
| `i_reset_n` | in | 1 | Active-low reset |
| `i_den` | in | 1 | Display enable (high = visible pixel) |
| `p1_up/down`, `p2_up/down` | in | 1 each | Player inputs |
| `auto_play` | in | 1 | AUTO mode button input |
| `i_pixel_x/y` | in | 14 | Current pixel coordinate |
| `o_pixel` | out | 24 | Output RGB pixel |

**Game states:**

| State | Meaning |
|-------|---------|
| `NEW_GAME (2'b00)` | Splash screen. Ball frozen. Scores cleared. |
| `PLAY (2'b01)` | Active gameplay. Physics running. |
| `NEW_BALL (2'b10)` | A life was lost. Timer counting down. Waiting for button press to resume. |
| `GAME_OVER (2'b11)` | All lives gone. Auto-returns to `NEW_GAME` after timer. |

**Compositor priority** (highest to lowest):
1. Game objects (`graph_on` from `bitpong_engine`)
2. Text overlay (`w_score_on` from `bitpong_text`)
3. Walls / centre line (`w_wall_en`, `w_cntr_line` from `bitpong_walls`, gated by `w_hide_cntr`)
4. Background (`#0A0D12` dark navy)

**Notes:**
- `gra_still` is the key signal passed to the engine. When `1`, the ball is held at spawn and paddles centre themselves. When `0`, physics are live.
- Score increment (`d_inc_l`, `d_inc_r`) is gated to `refr_tick` to guarantee at most one count per frame.
- `d_clr` (score clear) is only pulsed while in `NEW_GAME` state, not on every cycle — preventing incorrect clearing during active play.

---

## `bitpong_engine`
**File:** `rtl/BitPong/bitpong_engine.v`

Handles all **physics**: ball movement, paddle movement, collision detection, hit/miss signalling, and AI for the left paddle.

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk`, `reset_n` | in | 1 | Clock and reset |
| `btn1[1:0]` | in | 2 | Right paddle: `[1]`=down, `[0]`=up |
| `btn2[1:0]` | in | 2 | Left paddle (human in 2P) |
| `ai_switch` | in | 1 | When high, AI controls left paddle |
| `pix_x/y` | in | 14 | Current pixel (used for hit tests and refr_tick) |
| `gra_still` | in | 1 | When high, freeze positions |
| `hit_r`, `hit_l` | out | 1 | Ball deflected off right/left paddle this frame |
| `miss` | out | 1 | Ball escaped past a wall — life lost |
| `graph_on` | out | 1 | Any game object (ball or paddle) is at this pixel |
| `graph_rgb` | out | 24 | RGB colour for the current game object pixel |

**Key parameters:**

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `BALL_SIZE` | 48 px | Ball bounding box |
| `BARR/BARL_Y_SIZE` | 160 px | Paddle height |
| `BARR/BARL_V` | 12 px/frame | Human paddle speed |
| `AI_STEP` | 9 px/frame | AI paddle speed |
| `BALL_V_P/N` | ±6 px/frame | Initial ball speed |

**Angle deflection table** (per paddle):

| Hit zone (fifths of paddle height) | `x_delta` (px/frame) |
|-------------------------------------|----------------------|
| Top fifth | ±8 |
| Second fifth | ±7 |
| Middle fifth | ±6 |
| Fourth fifth | ±7 |
| Bottom fifth | ±8 |

**Ball rendering:**  
The ball uses an 8×8 circular bitmap stored in a small combinatorial ROM. The 48×48 pixel ball is rendered by scaling the 8×8 pattern by 6× using a `div6` function, then indexing the ROM with the scaled row/column.

**LFSR:**  
An 8-bit Galois LFSR free-runs every cycle. At ball launch (`gra_still` falling edge), bits `[0]` and `[1]` determine the initial X and Y direction respectively.

---

## `bitpong_text`
**File:** `rtl/BitPong/bitpong_text.v`

Renders **all text** on screen — HUD scores, LIVES counter, the splash screen title and rule lines, and the NEW_BALL prompt — using a character ROM lookup with per-region scaling.

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `i_clk` | in | 1 | Pixel clock |
| `i_pix_x/y` | in | 14 | Current pixel |
| `i_balls` | in | 2 | Remaining lives (0–3) |
| `i_score_l/r_tens/ones` | in | 4 each | BCD score digits |
| `i_state` | in | 2 | Current game state (controls which overlays show) |
| `o_text_on` | out | 1 | This pixel belongs to a text glyph |
| `o_rgb` | out | 24 | Text colour for this pixel |
| `o_hide_cntr` | out | 1 | Suppress the dashed centre line (during splash) |

**How it works:**
1. A hit-test checks whether `(pix_x, pix_y)` falls inside any text region.
2. The ASCII code, font row, and font column for that pixel are computed — for non-power-of-2 scales using `div3` / `div12` subtraction-ladder functions.
3. The ROM address `{ascii_code[6:0], font_row[3:0]}` is fed to `ascii_rom`.
4. One cycle later the ROM data arrives; the target bit is `rom_data[7 − font_col]`.
5. A second pipeline register aligns `active`, `font_col`, and `colour` with the ROM output.

The total pipeline latency is **2 cycles** — the pixel coordinates fed in correspond to text output two clock ticks later. This is accounted for by the display pipeline.

**Text colour palette:**

| Element | Colour |
|---------|--------|
| Score digits / LIVES | Cyan `#00FFFF` |
| "BitPong" title | Neon blue `#00E5FF` |
| Rule lines | Light grey `#C0C0C0` |
| "PRESS ANY KEY" prompt | Yellow `#FFFF60` |

---

## `ascii_rom`
**File:** `rtl/BitPong/ascii_rom.v`

A **synchronous BRAM-backed character ROM**. Stores the 8×16 pixel bitmap for all 128 ASCII characters.

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk` | in | 1 | Clock |
| `addr` | in | 11 | `{ascii[6:0], row[3:0]}` — selects one row of one character |
| `o_data` | out | 8 | 8 pixels of that row, 1 bit per pixel |

- ROM size: 2048 × 8 bits = **2 KB** → maps to 1 block RAM on the FPGA.
- Font data is loaded at synthesis time from `font_8x16.mem` using `$readmemh`.
- The read is registered (synchronous), so there is a 1-cycle latency on `o_data`.

---

## `bitpong_walls`
**File:** `rtl/BitPong/bitpong_walls.v`

Purely **combinatorial**. Determines whether the current pixel is part of a wall border or the dashed centre line.

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `i_pixel_x/y` | in | 14 | Current pixel |
| `o_wall_en` | out | 1 | Pixel is a solid wall |
| `o_cntr_line` | out | 1 | Pixel is a dashed centre line segment |
| `o_pixel` | out | 24 | Colour for this pixel |

**Wall colour:** `#11313B` (dark teal)  
**Centre line colour:** `#008FA3` (cyan-teal)  
**Centre line pattern:** Dashed — active only when `pix_y[5:4] != 2'b11`, producing evenly spaced gaps. The line is suppressed above Y=150 to avoid clashing with the LIVES HUD.

---

## `bitpong_timer`
**File:** `rtl/BitPong/bitpong_timer.v`

A simple **7-bit countdown timer** used to add a delay in the `NEW_BALL` and `GAME_OVER` states before the game advances.

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk`, `reset_n` | in | 1 | Clock and reset |
| `timer_start` | in | 1 | Load `127` and start counting |
| `timer_tick` | in | 1 | Count enable pulse (fires once per frame at pixel `[0,0]`) |
| `timer_up` | out | 1 | High when counter reaches zero |

- The timer counts in **frames** (not cycles). `timer_tick` is derived from pixel `[0,0]`, so it pulses once per 1/60 s.
- Duration: 127 frames ≈ **2.1 seconds**.
- On reset the counter is initialised to `127` so `timer_up` starts low.

---

## `score_counter`
**File:** `rtl/BitPong/score_counter.v`

A **2-digit BCD counter** (0–99). One instance exists for each player.

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk`, `reset_n` | in | 1 | Clock and reset |
| `d_inc` | in | 1 | Increment score by 1 |
| `d_clr` | in | 1 | Reset both digits to 0 |
| `dig0` | out | 4 | Ones digit (BCD) |
| `dig1` | out | 4 | Tens digit (BCD) |

Handles the tens carry correctly: `dig0` wraps from 9 → 0 and carries into `dig1`.

---

## `bitpong_button_toggle`
**File:** `rtl/BitPong/bitpong_button_toggle.v`

Converts a **momentary active-low button** into a **level toggle** signal. Used for the `auto_play` button so that one press switches the mode and it stays switched.

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk`, `rst_n` | in | 1 | Clock and reset |
| `btn_n` | in | 1 | Active-low button input |
| `toggle` | out | 1 | Toggles state on each button press |

Detects the **falling edge** of `btn_n` (button pressed) and flips `toggle`. No debounce filter — relies on the button signal being clean or the FPGA's input conditioning.

---

## `video_timing_ctrl`
**File:** `rtl/hdmi/src/rtl/video-misc/video_timing_ctrl.v`

Standard **H/V sync generator and pixel counter**. Parameterised for any video mode; configured here for 1920×1080 @ 60 Hz (CEA-861 timings).

| Key Parameter | Value |
|---|---|
| Total H | 2200 pixels |
| Total V | 1125 lines |
| H sync pulse | 44 pixels |
| H back porch | 148 pixels |
| V sync pulse | 5 lines |
| V back porch | 36 lines |

Outputs `pixel_x` and `pixel_y` as the current visible pixel coordinate (0-based, active area only), `video_den` (display enable), `video_hsync`, `video_vsync`.

---

## `dvi_tx_top`
**File:** `rtl/hdmi/src/rtl/dvi-tx/dvi_tx_top.v`

Top of the **DVI transmitter stack**. Takes 24-bit RGB pixel data + sync signals and drives the TMDS differential output pins.

Internal hierarchy:
- `dvi_tx_tmds_enc` — TMDS 8b/10b encoder for each colour channel
- `dvi_tx_tmds_phy` — DDR serialiser (10 bits → 1 bit at 10× clock)
- `dvi_tx_clk_drv` — DDR driver for the TMDS clock lane

---

## `Gowin_PLL`
**File:** `rtl/hdmi/src/gowin_pll/gowin_pll.v`

Gowin vendor PLL IP. Generates the two clocks needed by the system from the board reference oscillator.

| Output | Frequency | Use |
|--------|-----------|-----|
| `clkout0` | 148.5 MHz | Pixel clock for all game logic and DVI data path |
| `clkout1` | 742.5 MHz | TMDS bit-rate clock for DDR serialisers |

---

## `top_text_sim` *(simulation only)*
**File:** `sim/top_text_sim.sv`

Verilator simulation wrapper. Replaces the FPGA top for PC simulation — no PLL, no DVI transmitter.

| Port | Dir | Description |
|------|-----|-------------|
| `clk_pix` | in | Pixel clock driven by the C++ testbench |
| `sim_rst` | in | Active-high reset (inverted before `video_timing_ctrl`) |
| `reset_n` | in | Active-low game reset |
| `p1/p2_up/down` | in | Player inputs from keyboard |
| `auto_play` | in | Auto mode input |
| `sdl_sx/sy` | out | Current pixel X/Y |
| `sdl_de` | out | Display enable |
| `sdl_vsync` | out | Vertical sync (C++ harness uses rising edge to blit frame) |
| `sdl_r/g/b` | out | 8-bit per channel pixel data |

Instantiates `video_timing_ctrl` and `bitpong_graphics` directly. All `sdl_*` outputs are combinatorial pass-throughs of the timing and graphics signals.

---

## `test_bound_pattern` *(debug only)*
**File:** `rtl/BitPong/test_bound_pattern.v`

Simple test pattern generator. Draws a solid white border on a black background. Used early in development to verify video timing and HDMI connectivity before any game logic existed.

---

## `top_bound` *(debug only)*
**File:** `rtl/BitPong/top_bound.v`

FPGA top-level for the boundary test pattern. Structurally identical to `top_bitpong` except it drives `test_bound_pattern` instead of `bitpong_graphics`. Not part of the game build.