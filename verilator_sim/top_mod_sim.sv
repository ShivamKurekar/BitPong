`timescale 1ns/1ps
`default_nettype none

module top_mod_sim #(parameter CORDW=14) (
    input  wire logic        clk_pix,
    input  wire logic        sim_rst,

    output logic [CORDW-1:0] sdl_sx,
    output logic [CORDW-1:0] sdl_sy,
    output logic             sdl_de,
    output logic             sdl_vsync,
    output logic [7:0]       sdl_r,
    output logic [7:0]       sdl_g,
    output logic [7:0]       sdl_b
);

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
    .rstn            (~sim_rst),
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

wire [23:0] dvi_data_odd;   // unused, just to satisfy the port

test_pattern_gen u_pattern (
    .den_int         (dvi_den),
    .pixel_x         (pixel_x),
    .pixel_y         (pixel_y),
    .video_pixel_even(dvi_data),
    .video_pixel_odd (dvi_data_odd)
);

assign sdl_sx    = pixel_x;
assign sdl_sy    = pixel_y;
assign sdl_de    = dvi_den;
assign sdl_vsync = dvi_vsync;
assign sdl_r     = dvi_data[23:16];
assign sdl_g     = dvi_data[15:8];
assign sdl_b     = dvi_data[7:0];

endmodule