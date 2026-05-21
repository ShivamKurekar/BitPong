module test_bound_pattern #(
	parameter VISIBLE_H = 1920,
	parameter VISIBLE_V = 1080,
	parameter BOUNDARY_WIDTH = 5
)(
	input				i_den,
	input	[13: 0]	i_pixel_x,
	input	[13: 0]	i_pixel_y,

	output	[23: 0]	o_video_pixel
);
/*
	What Happens on Every Pixel Clock?
	1. h_pos increments
	2. timing signals updated
	3. visible region checked
	4. current pixel generated
	5. RGB values transmitted
*/

reg [23:0] r_video_pixel;

function [23:0] color;
	input sel;
    begin
		if (sel)
        	color = 24'hFF_FF_FF; // White
		else
			color = 24'h00_00_00; // Black
    end
endfunction

always @(*) begin
	if(i_den) begin

		if (i_pixel_y < BOUNDARY_WIDTH)
			r_video_pixel = color(1);

		else if (i_pixel_y >= (VISIBLE_V - BOUNDARY_WIDTH))
			r_video_pixel = color(1);

		else if (i_pixel_x < BOUNDARY_WIDTH)
			r_video_pixel = color(1);

		else if (i_pixel_x >= (VISIBLE_H - BOUNDARY_WIDTH))
			r_video_pixel = color(1);

		else
			r_video_pixel = color(0);

	end else
		r_video_pixel = color(0);
end

assign o_video_pixel = r_video_pixel;

endmodule
