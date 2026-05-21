VERILOG_SRCS = \
    ../rtl/hdmi/src/rtl/video-misc/video_timing_ctrl.v \
    ../rtl/BitPong/test_bound_pattern.v \
    top_bound_sim.sv

sim: obj_dir/top_bound_sim
	./obj_dir/top_bound_sim

obj_dir/top_bound_sim: $(VERILOG_SRCS) main_bound.cpp
	verilator -I../rtl -cc top_bound_sim.sv \
	    ../rtl/hdmi/src/rtl/video-misc/video_timing_ctrl.v \
	    ../rtl/BitPong/test_bound_pattern.v \
	    --exe main_bound.cpp \
	    -o top_bound_sim \
	    -CFLAGS "$(shell sdl2-config --cflags)" \
	    -LDFLAGS "$(shell sdl2-config --libs)"
	make -C obj_dir -f Vtop_bound_sim.mk

clean:
	rm -rf obj_dir