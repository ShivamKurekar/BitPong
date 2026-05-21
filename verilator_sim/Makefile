RTL_INC = -I../rtl
TIMING  = ../rtl/hdmi/src/rtl/video-misc/video_timing_ctrl.v
BOUND   = ../rtl/BitPong/test_bound_pattern.v
PATTERN = ../rtl/hdmi/src/rtl/video-misc/test_pattern_gen.v

CFLAGS  = -CFLAGS "$(shell sdl2-config --cflags)"
LFLAGS  = -LDFLAGS "$(shell sdl2-config --libs)"

# ── top_bound target ────────────────────────────────────────────
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

# ── top_mod target ───────────────────────────────────────────────
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

clean:
	rm -rf obj_dir_bound obj_dir_mod