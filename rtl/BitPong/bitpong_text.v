module bitpong_text (
    input        i_clk,
    input [13:0] i_pix_x,
    input [13:0] i_pix_y,

    input [3:0]  i_score_l_tens,
    input [3:0]  i_score_l_ones,

    input [3:0]  i_score_r_tens,
    input [3:0]  i_score_r_ones,

    output       o_text_on,
    output [23:0] o_rgb
);

localparam            SCALE   = 8;
localparam            FONT_W  = 8;
localparam            FONT_H  = 16;
localparam [13:0]     CHAR_W  = FONT_W * SCALE;   // 64
localparam [13:0]     CHAR_H  = FONT_H * SCALE;   // 128

localparam [13:0] Y_TOP     = 14'd40;
localparam [13:0] X_L_TENS  = 14'd416;             // 480 - CHAR_W
localparam [13:0] X_L_ONES  = X_L_TENS + CHAR_W;   // 480
localparam [13:0] X_R_TENS  = 14'd1376;            // 1440 - CHAR_W
localparam [13:0] X_R_ONES  = X_R_TENS + CHAR_W;   // 1440

localparam [23:0] TEXT_COLOR = 24'h80_FF_FF;       // white digits

wire in_l_tens = (i_pix_x >= X_L_TENS) && (i_pix_x < X_L_TENS + CHAR_W) &&
                 (i_pix_y >= Y_TOP)    && (i_pix_y < Y_TOP + CHAR_H);
wire in_l_ones = (i_pix_x >= X_L_ONES) && (i_pix_x < X_L_ONES + CHAR_W) &&
                 (i_pix_y >= Y_TOP)    && (i_pix_y < Y_TOP + CHAR_H);
wire in_r_tens = (i_pix_x >= X_R_TENS) && (i_pix_x < X_R_TENS + CHAR_W) &&
                 (i_pix_y >= Y_TOP)    && (i_pix_y < Y_TOP + CHAR_H);
wire in_r_ones = (i_pix_x >= X_R_ONES) && (i_pix_x < X_R_ONES + CHAR_W) &&
                 (i_pix_y >= Y_TOP)    && (i_pix_y < Y_TOP + CHAR_H);

wire cell_active = in_l_tens | in_l_ones | in_r_tens | in_r_ones;

reg [3:0] digit_val;
always @(*) begin
    case (1'b1)
        in_l_tens: digit_val = i_score_l_tens;
        in_l_ones: digit_val = i_score_l_ones;
        in_r_tens: digit_val = i_score_r_tens;
        in_r_ones: digit_val = i_score_r_ones;
        default:   digit_val = 4'h0;
    endcase
end

wire [6:0] ascii_code = 7'h30 + {3'b000, digit_val};  // '0'-'9' = 0x30-0x39

reg [13:0] local_x;
always @(*) begin
    case (1'b1)
        in_l_tens: local_x = i_pix_x - X_L_TENS;
        in_l_ones: local_x = i_pix_x - X_L_ONES;
        in_r_tens: local_x = i_pix_x - X_R_TENS;
        in_r_ones: local_x = i_pix_x - X_R_ONES;
        default:   local_x = 14'd0;
    endcase
end
wire [13:0] local_y = i_pix_y - Y_TOP;   // valid only when cell_active

// SCALE = 8 => divide-by-8 is a static slice, not a divider
wire [2:0] font_col = local_x[5:3];   // 0..63  -> 0..7
wire [3:0] font_row = local_y[6:3];   // 0..127 -> 0..15

wire [10:0] rom_addr = {ascii_code, font_row};  // addr = ascii*16 + row
wire [7:0] rom_data;

ascii_rom u_ascii_rom (
    .clk    (i_clk),
    .addr   (rom_addr),
    .o_data (rom_data)
);

reg       active_d1;
reg [2:0] font_col_d1;

always @(posedge i_clk) begin
    active_d1   <= cell_active;
    font_col_d1 <= font_col;
end

wire pixel_set    = rom_data[3'd7 - font_col_d1];
wire text_on_next = active_d1 & pixel_set;

reg        text_on_q;
reg [23:0] rgb_q;

always @(posedge i_clk) begin
    text_on_q <= text_on_next;
    rgb_q     <= text_on_next ? TEXT_COLOR : 24'h00_00_00;
end

assign o_text_on = text_on_q;
assign o_rgb     = rgb_q;

endmodule