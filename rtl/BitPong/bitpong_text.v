module bitpong_text (
    input        i_clk,
    input [13:0] i_pix_x,
    input [13:0] i_pix_y,

    input [3:0]  i_score_l_tens,
    input [3:0]  i_score_l_ones,

    input [3:0]  i_score_r_tens,
    input [3:0]  i_score_r_ones,

    output        o_text_on,
    output [23:0] o_rgb
);

reg [23:0] r_rgb;

reg [10:0] rom_addr;
reg [7:0] font_word;
wire font_bit;

ascii_rom rom(
    .clk(i_clk),
    .addr(rom_addr),
    .o_data(font_word)
);

wire logo_on;
wire [3:0] row_addr_l;
wire [2:0] bit_addr_l;
reg [6:0] char_addr_l;

wire [10:0] logo_x;
wire [10:0] logo_y;

assign logo_x = i_pix_x[10:0] - 11'd832;
assign logo_y = i_pix_y[10:0] - 11'd476;

assign logo_on = (logo_x < 256) && (logo_y < 128);

assign row_addr_l = logo_y[6:3];
assign bit_addr_l = logo_x[5:3];

always @(*) begin
    case (logo_x[8:6])
        3'd0: char_addr_l = 7'h50; // P
        3'd1: char_addr_l = 7'h4f; // O
        3'd2: char_addr_l = 7'h4e; // N
        3'd3: char_addr_l = 7'h47; // G
        default: char_addr_l = 7'h00; // space
    endcase
end

always @(*) begin
    r_rgb = 24'h00_00_00;
    if (font_bit)
        r_rgb = 24'hFF_FF_00;
end

assign o_text_on = logo_on;
assign rom_addr = {char_addr_l, row_addr_l};
assign font_bit = font_word[~bit_addr_l];
assign o_rgb = r_rgb;
endmodule