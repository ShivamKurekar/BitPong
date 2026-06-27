module bitpong_top (
    input clk,
    input rstn,

    output pull_up,
    output auto_led,

    input p1_up,
    input p1_down,
    input p2_up,
    input p2_down,
    input auto_play,

    output       tmds_clk_n_0,
    output       tmds_clk_p_0,
    output [2:0] tmds_d_n_0,
    output [2:0] tmds_d_p_0
);

reg r_led;

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        r_led <= 1'b0;
    end else begin
        r_led <= auto_play_togg;
    end
end
assign auto_led = r_led;
assign pull_up = 1'b1;

localparam integer HALF_SEC_COUNT = 74_250_000;

reg [26:0] cnt;
reg r_rstn;
reg done;

always @(posedge clk) begin
    if (!rstn) begin
        cnt       <= 27'd0;
        r_rstn <= 1'b0;              // Hold downstream in reset
    end
    else if (cnt < HALF_SEC_COUNT-1) begin
        cnt       <= cnt + 1'b1;
        r_rstn <= 1'b0;              // Continue holding reset
    end
    else begin
        r_rstn <= 1'b1;              // Release reset after 0.5 s
    end
end

assign tick_rstn = r_rstn;

parameter video_hlength		= 2200;// Total H length
parameter video_vlength		= 1125;// Total v length
parameter video_hsync_pol	= 1;   // 
parameter video_hsync_len	= 44;  // HSYNC pulse width
parameter video_hbp_len		= 148; // horizontal backporch

parameter video_h_visible	= 1920;// horizontal visible
parameter video_vsync_pol	= 1;   
parameter video_vsync_len	= 5;   // VSYNC pulse width
parameter video_vbp_len		= 36;  // vertical back porch
parameter video_v_visible	= 1080; // vertical visible

/* PLL wires */
wire pll_lock;
wire clk_p;  // DIV clk
wire clk_p5; // TMDS clk

/* video timing */
wire		 den_int;
wire [13: 0] pixel_x;
wire [13: 0] pixel_y;
wire        dvi_den;
wire        dvi_hsync;
wire        dvi_vsync;

/* Test pattern */
wire [23:0] dvi_data;
wire        video_line_start;


Gowin_PLL hdmi_pll (
    .clkin  (clk),
    .mdclk  (1'b0),
    .lock   (pll_lock),
    .clkout0(clk_p), // 148.5 Mhz
    .clkout1(clk_p5) // 742.5 Mhz
);

// First pixel @(h_pos, v_pos) = (192,41)
video_timing_ctrl #(
    .video_hlength      (video_hlength),
    .video_vlength      (video_vlength),

    .video_hsync_pol    (video_hsync_pol),
    .video_hsync_len    (video_hsync_len),
    .video_hbp_len      (video_hbp_len),
    .video_h_visible    (video_h_visible),

    .video_vsync_pol    (video_vsync_pol),
    .video_vsync_len    (video_vsync_len),
    .video_vbp_len      (video_vbp_len),
    .video_v_visible    (video_v_visible)
)   video_timing_ctrl(
    .pixel_clock		(clk_p),
    .rstn				(tick_rstn),
    .ext_sync			(1'b0),

    .timing_h_pos		(),
    .timing_v_pos		(),
    .pixel_x			(pixel_x),
    .pixel_y			(pixel_y),

    .video_hsync		(dvi_hsync),
    .video_vsync		(dvi_vsync),
    .video_den			(dvi_den),
    .video_line_start	(video_line_start)
);

wire auto_play_togg;

bitpong_graphics graphics(
    .i_clk(clk_p),
    .i_reset_n(tick_rstn),
    
    /* to be connected to active high buttons*/
    .p1_up(p1_up),
    .p1_down(p1_down),
    .p2_up(p2_up),
    .p2_down(p2_down),
    .auto_play(auto_play),
    .auto_play_togg(auto_play_togg),

    /* pixel data */
    .i_den(dvi_den),
    .i_pixel_x(pixel_x),
    .i_pixel_y(pixel_y),
    .o_pixel(dvi_data)
);

dvi_tx_top dvi_tx (
    .pixel_clock  (clk_p),
    .ddr_bit_clock(clk_p5),
    .rstn         (tick_rstn),
    .den          (dvi_den),
    .hsync        (dvi_hsync),
    .vsync        (dvi_vsync),
    .pixel_data   (dvi_data),

    .tmds_clk     ({tmds_clk_p_0, tmds_clk_n_0}),
    .tmds_d0      ({tmds_d_p_0[0], tmds_d_n_0[0]}),
    .tmds_d1      ({tmds_d_p_0[1], tmds_d_n_0[1]}),
    .tmds_d2      ({tmds_d_p_0[2], tmds_d_n_0[2]})
);

endmodule