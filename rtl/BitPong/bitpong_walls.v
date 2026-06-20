module bitpong_walls #(
    parameter MAX_H = 1920,
    parameter MAX_V = 1080,
    parameter BOUND_WIDTH = 10,
    parameter LINE_WIDTH = 4
)(
    input [13:0] i_pixel_x,
    input [13:0] i_pixel_y,

    output o_wall_en,
    output o_cntr_line,
    output [23:0] o_pixel
);

reg r_wall_en;
reg r_cntr_line;
reg [23:0] r_pixel;

always @(*) begin
    r_cntr_line = 1'b0;
    r_wall_en = 1'b0;
    r_pixel = 24'h00_00_00;
    
    if((i_pixel_y < BOUND_WIDTH) || (i_pixel_y >= (MAX_V - BOUND_WIDTH)) 
        || (i_pixel_x < BOUND_WIDTH) || (i_pixel_x >= (MAX_H - BOUND_WIDTH))) begin
        // wall/border
        r_wall_en = 1'b1;
        r_cntr_line = 1'b0;
        r_pixel = 24'h40_FF_FF;
    end else if ((i_pixel_x >= (MAX_H/2 - LINE_WIDTH/2)) &&
        (i_pixel_x <  (MAX_H/2 + LINE_WIDTH/2)) &&
        (i_pixel_y[5:4] != 2'b11)) begin
        // center line
        r_cntr_line = 1'b1;
        r_pixel = 24'h60_C0_C0;
    end
end

assign o_wall_en = r_wall_en;
assign o_cntr_line = r_cntr_line;
assign o_pixel = r_pixel;

endmodule