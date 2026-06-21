module bitpong_graphics (
    input i_clk,
    input i_den,

    /* Pixel data */
    input [13:0] i_pixel_x,
    input [13:0] i_pixel_y,
    output [23:0] o_pixel
);

/*
Graphics will be divided into three parts
1. Walls
2. Text
3. Game Engine
*/

reg [23:0] r_pixel;

wire w_wall_en;
wire w_cntr_line;
wire [23:0] w_wall_pixel;

bitpong_walls walls (
    .i_pixel_x(i_pixel_x),
    .i_pixel_y(i_pixel_y),
    .o_cntr_line(w_cntr_line),
    .o_wall_en(w_wall_en),
    .o_pixel(w_wall_pixel)
);

wire w_score_on;
wire [23:0] w_score_rgb;

bitpong_text text (
    .i_clk(i_clk),
    .i_pix_x(i_pixel_x),
    .i_pix_y(i_pixel_y),
    .i_balls(2'd0),
    .i_score_l_tens(4'd0),
    .i_score_l_ones(4'd0),
    .i_score_r_tens(4'd0),
    .i_score_r_ones(4'd0),
    .o_text_on(w_score_on),
    .o_rgb(w_score_rgb)
);

always @(*) begin
    if(i_den) begin
        if (w_score_on)
            r_pixel = w_score_rgb;
        else if(w_wall_en || w_cntr_line)
            r_pixel = w_wall_pixel;
        else
            r_pixel = 24'h00_00_00;
    end else begin
        r_pixel = 24'h00_00_00;
    end
end

assign o_pixel = r_pixel;

endmodule