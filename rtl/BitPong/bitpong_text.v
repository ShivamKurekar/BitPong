module bitpong_text (
    input        i_clk,
    input [13:0] i_pix_x,
    input [13:0] i_pix_y,

    input [1:0]  i_balls,

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

localparam [23:0] TEXT_COLOR = 24'h80_FF_FF;       // cyan digits

localparam            LIVES_SCALE  = 4;
localparam [13:0]     LIVES_CHAR_W = FONT_W * LIVES_SCALE;   // 32
localparam [13:0]     LIVES_CHAR_H = FONT_H * LIVES_SCALE;   // 64
localparam             LIVES_LABEL_LEN = 5;                   // "LIVES"
localparam [13:0]      LIVES_LABEL_W   = LIVES_LABEL_LEN * LIVES_CHAR_W; // 160

localparam [13:0] Y_LIVES_LABEL = 14'd15;                          // 32px below score row
localparam [13:0] X_LIVES_LABEL = 14'd960 - LIVES_LABEL_W/2;        // 880, centered
localparam [13:0] Y_LIVES_DIGIT = Y_LIVES_LABEL + LIVES_CHAR_H + 14'd8; // 272, 8px under label
localparam [13:0] X_LIVES_DIGIT = 14'd960 - LIVES_CHAR_W/2;         // 944, centered (1 char)

wire in_l_tens = (i_pix_x >= X_L_TENS) && (i_pix_x < X_L_TENS + CHAR_W) &&
                 (i_pix_y >= Y_TOP)    && (i_pix_y < Y_TOP + CHAR_H);
wire in_l_ones = (i_pix_x >= X_L_ONES) && (i_pix_x < X_L_ONES + CHAR_W) &&
                 (i_pix_y >= Y_TOP)    && (i_pix_y < Y_TOP + CHAR_H);
wire in_r_tens = (i_pix_x >= X_R_TENS) && (i_pix_x < X_R_TENS + CHAR_W) &&
                 (i_pix_y >= Y_TOP)    && (i_pix_y < Y_TOP + CHAR_H);
wire in_r_ones = (i_pix_x >= X_R_ONES) && (i_pix_x < X_R_ONES + CHAR_W) &&
                 (i_pix_y >= Y_TOP)    && (i_pix_y < Y_TOP + CHAR_H);

wire score_active = in_l_tens | in_l_ones | in_r_tens | in_r_ones;

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

wire [6:0] ascii_score_code = 7'h30 + {3'b000, digit_val};  // '0'-'9' = 0x30-0x39

reg [13:0] local_x_score;
always @(*) begin
    case (1'b1)
        in_l_tens: local_x_score = i_pix_x - X_L_TENS;
        in_l_ones: local_x_score = i_pix_x - X_L_ONES;
        in_r_tens: local_x_score = i_pix_x - X_R_TENS;
        in_r_ones: local_x_score = i_pix_x - X_R_ONES;
        default:   local_x_score = 14'd0;
    endcase
end
wire [13:0] local_y_score = i_pix_y - Y_TOP;

// SCALE = 8 => divide-by-8 is a static slice, not a divider
wire [2:0] font_col_score = local_x_score[5:3];   // 0..63  -> 0..7
wire [3:0] font_row_score = local_y_score[6:3];   // 0..127 -> 0..15

wire in_lives_label = (i_pix_x >= X_LIVES_LABEL) && (i_pix_x < X_LIVES_LABEL + LIVES_LABEL_W) &&
                       (i_pix_y >= Y_LIVES_LABEL) && (i_pix_y < Y_LIVES_LABEL + LIVES_CHAR_H);
wire in_lives_digit = (i_pix_x >= X_LIVES_DIGIT) && (i_pix_x < X_LIVES_DIGIT + LIVES_CHAR_W) &&
                       (i_pix_y >= Y_LIVES_DIGIT) && (i_pix_y < Y_LIVES_DIGIT + LIVES_CHAR_H);

wire lives_active = in_lives_label | in_lives_digit;

reg [13:0] local_x_lives;
reg [13:0] local_y_lives;
always @(*) begin
    case (1'b1)
        in_lives_label: begin local_x_lives = i_pix_x - X_LIVES_LABEL; local_y_lives = i_pix_y - Y_LIVES_LABEL; end
        in_lives_digit: begin local_x_lives = i_pix_x - X_LIVES_DIGIT; local_y_lives = i_pix_y - Y_LIVES_DIGIT; end
        default:        begin local_x_lives = 14'd0;                  local_y_lives = 14'd0;                  end
    endcase
end

wire [2:0] lives_slot     = local_x_lives[7:5];   // which of the 5 label chars, /32 (only valid in label row)
wire [2:0] font_col_lives = local_x_lives[4:2];   // LIVES_SCALE=4 -> /4
wire [3:0] font_row_lives = local_y_lives[5:2];

reg [6:0] ascii_lives_code;
always @(*) begin
    if (in_lives_digit) begin
        ascii_lives_code = 7'h30 + {5'b0, i_balls};   // '0'-'3'
    end else begin
        case (lives_slot)
            3'd0: ascii_lives_code = 7'h4C; // 'L'
            3'd1: ascii_lives_code = 7'h49; // 'I'
            3'd2: ascii_lives_code = 7'h56; // 'V'
            3'd3: ascii_lives_code = 7'h45; // 'E'
            3'd4: ascii_lives_code = 7'h53; // 'S'
            default: ascii_lives_code = 7'h20; // space, unreachable in-range
        endcase
    end
end

wire        any_active = score_active | lives_active;
wire [2:0]  font_col    = score_active ? font_col_score : font_col_lives;
wire [10:0] rom_addr    = score_active ? {ascii_score_code, font_row_score} :
                           lives_active ? {ascii_lives_code, font_row_lives} :
                           11'd0;

wire [7:0] rom_data;

ascii_rom u_ascii_rom (
    .clk    (i_clk),
    .addr   (rom_addr),
    .o_data (rom_data)
);

reg       active_d1;
reg [2:0] font_col_d1;

always @(posedge i_clk) begin
    active_d1   <= any_active;
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