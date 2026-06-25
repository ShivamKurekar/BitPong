RTL_INC  = -I../rtl
WALLS 	 = ../rtl/BitPong/bitpong_walls.v
TIMING   = ../rtl/hdmi/src/rtl/video-misc/video_timing_ctrl.v
BOUND    = ../rtl/BitPong/test_bound_pattern.v
PATTERN  = ../rtl/hdmi/src/rtl/video-misc/test_pattern_gen.v
GRAPHICS = ../rtl/BitPong/bitpong_graphics.v
TEXT	 = ../rtl/BitPong/bitpong_text.v
FONT_ROM = ../rtl/BitPong/ascii_rom.v
FONT_MEM = ../rtl/BitPong/font_8x16.mem
ENGINE   = ../rtl/BitPong/bitpong_engine.v
TIMER    = ../rtl/BitPong/bitpong_timer.v
COUNTER  = ../rtl/BitPong/score_counter.v
TOGGLE   = ../rtl/BitPong/bitpong_button_toggle.v

CFLAGS   = -CFLAGS  "$(shell sdl2-config --cflags)"
LFLAGS   = -LDFLAGS "$(shell sdl2-config --libs)"

# ── top_bound ────────────────────────────────────────────────────
sim_bound: obj_dir_bound/top_bound_sim
	./obj_dir_bound/top_bound_sim

obj_dir_bound/top_bound_sim: top_bound_sim.sv $(TIMING) $(BOUND) main_bound.cpp
	verilator $(RTL_INC) -cc top_bound_sim.sv \
	    $(TIMING) $(BOUND) \
	    --exe main_bound.cpp \
	    -Mdir obj_dir_bound \
	    -o top_bound_sim \
	    $(CFLAGS) $(LFLAGS)
	make -C obj_dir_bound -f Vtop_bound_sim.mk

# ── top_mod ──────────────────────────────────────────────────────
sim_mod: obj_dir_mod/top_mod_sim
	./obj_dir_mod/top_mod_sim

obj_dir_mod/top_mod_sim: top_mod_sim.sv $(TIMING) $(PATTERN) main_mod.cpp
	verilator $(RTL_INC) -cc top_mod_sim.sv \
	    $(TIMING) $(PATTERN) \
	    --exe main_mod.cpp \
	    -Mdir obj_dir_mod \
	    -o top_mod_sim \
	    -Wno-IMPLICIT \
	    $(CFLAGS) $(LFLAGS)
	make -C obj_dir_mod -f Vtop_mod_sim.mk

# ── top_text ─────────────────────────────────────────────────────
sim_text: obj_dir_text/top_text_sim
	./obj_dir_text/top_text_sim

obj_dir_text/top_text_sim: top_text_sim.sv $(TIMING) $(TEXT) $(FONT_ROM) main_text.cpp
	verilator $(RTL_INC) -cc top_text_sim.sv \
	    $(TIMING) $(GRAPHICS) $(TEXT) $(WALLS) $(FONT_ROM) $(ENGINE) $(TIMER) $(COUNTER) $(TOGGLE)\
	    --exe main_text.cpp \
	    -Mdir obj_dir_text \
	    -o top_text_sim \
	    $(CFLAGS) $(LFLAGS)
	make -C obj_dir_text -f Vtop_text_sim.mk

# ── clean ────────────────────────────────────────────────────────
clean:
	rm -rf obj_dir_bound obj_dir_mod obj_dir_text