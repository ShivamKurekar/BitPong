module bitpong_text (
    input        i_clk,
    input [13:0] i_pix_x,
    input [13:0] i_pix_y,

    input [1:0]  i_balls,

    input [3:0]  i_score_l_tens,
    input [3:0]  i_score_l_ones,
    input [3:0]  i_score_r_tens,
    input [3:0]  i_score_r_ones,

    input [1:0]  i_state,

    output       o_text_on,
    output [23:0] o_rgb,

    output       o_hide_cntr
);

localparam ST_NEW_GAME  = 2'b00;
localparam ST_PLAY      = 2'b01;
localparam ST_NEW_BALL  = 2'b10;
localparam ST_GAME_OVER = 2'b11;

assign o_hide_cntr = (i_state == ST_NEW_GAME || i_state == ST_NEW_BALL);

localparam FONT_W = 8;
localparam FONT_H = 16;

// HUD scores — scale 8 → 64×128 px per glyph
localparam [13:0] HUD_SCALE  = 8;
localparam [13:0] CHAR_W     = FONT_W * HUD_SCALE;   // 64
localparam [13:0] CHAR_H     = FONT_H * HUD_SCALE;   // 128
localparam [13:0] Y_TOP      = 14'd40;
localparam [13:0] X_L_TENS   = 14'd416;
localparam [13:0] X_L_ONES   = X_L_TENS + CHAR_W;    // 480
localparam [13:0] X_R_TENS   = 14'd1376;
localparam [13:0] X_R_ONES   = X_R_TENS + CHAR_W;    // 1440

// HUD LIVES label — scale 4 → 32×64 px per glyph
localparam [13:0] LV_SCALE   = 4;
localparam [13:0] LV_CHAR_W  = FONT_W * LV_SCALE;    // 32
localparam [13:0] LV_CHAR_H  = FONT_H * LV_SCALE;    // 64
localparam [13:0] LV_LABEL_W = 5 * LV_CHAR_W;        // 160 ("LIVES")
localparam [13:0] Y_LV_LABEL = 14'd15;
localparam [13:0] X_LV_LABEL = 14'd960 - LV_LABEL_W/2;  // 880
localparam [13:0] Y_LV_DIGIT = Y_LV_LABEL + LV_CHAR_H + 14'd8; // 87
localparam [13:0] X_LV_DIGIT = 14'd960 - LV_CHAR_W/2;   // 944

// Splash title "BitPong" — scale 12 → 96×192 px per glyph
// 7 chars × 96 = 672 px; X0 = 960-336 = 624
localparam [13:0] SP_SCALE   = 12;
localparam [13:0] SP_CHAR_W  = FONT_W * SP_SCALE;    // 96
localparam [13:0] SP_CHAR_H  = FONT_H * SP_SCALE;    // 192
localparam [13:0] TITLE_X0   = 14'd624;
localparam [13:0] TITLE_Y0   = 14'd330;
localparam [13:0] TITLE_W    = 7 * SP_CHAR_W;        // 672

// Rule lines — scale 3 → 24×48 px per glyph
// 32 chars × 24 = 768 px; X0 = 960-384 = 576
localparam [13:0] RU_SCALE   = 3;
localparam [13:0] RU_CHAR_W  = FONT_W * RU_SCALE;    // 24
localparam [13:0] RU_CHAR_H  = FONT_H * RU_SCALE;    // 48
localparam [13:0] RU_LINE_W  = 32 * RU_CHAR_W;       // 768
localparam [13:0] RULE_X0    = 14'd576;
localparam [13:0] RULE0_Y0   = 14'd562;
localparam [13:0] RULE1_Y0   = RULE0_Y0 + RU_CHAR_H + 14'd12; // 622
localparam [13:0] RULE2_Y0   = RULE1_Y0 + RU_CHAR_H + 14'd12; // 682

// Prompt "PRESS ANY KEY TO LAUNCH" — scale 4 → 32×64 px per glyph
// 23 chars × 32 = 736 px; X0 = 960-368 = 592
// Placed ABOVE ball spawn (ball Y 516..563); prompt ends at Y 484.
localparam [13:0] PR_SCALE   = 4;
localparam [13:0] PR_CHAR_W  = FONT_W * PR_SCALE;    // 32
localparam [13:0] PR_CHAR_H  = FONT_H * PR_SCALE;    // 64
localparam [13:0] PROMPT_X0  = 14'd592;
localparam [13:0] PROMPT_Y0  = 14'd420;              // bottom=484 < ball top=516
localparam [13:0] PROMPT_W   = 23 * PR_CHAR_W;       // 736

localparam [23:0] C_HUD    = 24'h80_FF_FF;  // cyan
localparam [23:0] C_TITLE  = 24'hFF_E0_00;  // amber
localparam [23:0] C_RULE   = 24'hC0_C0_C0;  // light grey
localparam [23:0] C_PROMPT = 24'hFF_FF_60;  // yellow

// HUD
wire in_l_tens = (i_pix_x >= X_L_TENS) && (i_pix_x < X_L_TENS + CHAR_W) &&
                 (i_pix_y >= Y_TOP)     && (i_pix_y < Y_TOP + CHAR_H);
wire in_l_ones = (i_pix_x >= X_L_ONES) && (i_pix_x < X_L_ONES + CHAR_W) &&
                 (i_pix_y >= Y_TOP)     && (i_pix_y < Y_TOP + CHAR_H);
wire in_r_tens = (i_pix_x >= X_R_TENS) && (i_pix_x < X_R_TENS + CHAR_W) &&
                 (i_pix_y >= Y_TOP)     && (i_pix_y < Y_TOP + CHAR_H);
wire in_r_ones = (i_pix_x >= X_R_ONES) && (i_pix_x < X_R_ONES + CHAR_W) &&
                 (i_pix_y >= Y_TOP)     && (i_pix_y < Y_TOP + CHAR_H);
wire score_active = in_l_tens | in_l_ones | in_r_tens | in_r_ones;

wire in_lv_label = (i_pix_x >= X_LV_LABEL) && (i_pix_x < X_LV_LABEL + LV_LABEL_W) &&
                   (i_pix_y >= Y_LV_LABEL)  && (i_pix_y < Y_LV_LABEL + LV_CHAR_H);
wire in_lv_digit = (i_pix_x >= X_LV_DIGIT) && (i_pix_x < X_LV_DIGIT + LV_CHAR_W) &&
                   (i_pix_y >= Y_LV_DIGIT)  && (i_pix_y < Y_LV_DIGIT + LV_CHAR_H);
wire lives_active = in_lv_label | in_lv_digit;

// Splash
wire in_title = (i_pix_x >= TITLE_X0) && (i_pix_x < TITLE_X0 + TITLE_W) &&
                (i_pix_y >= TITLE_Y0)  && (i_pix_y < TITLE_Y0 + SP_CHAR_H);
wire in_rule0 = (i_pix_x >= RULE_X0)  && (i_pix_x < RULE_X0  + RU_LINE_W) &&
                (i_pix_y >= RULE0_Y0)  && (i_pix_y < RULE0_Y0 + RU_CHAR_H);
wire in_rule1 = (i_pix_x >= RULE_X0)  && (i_pix_x < RULE_X0  + RU_LINE_W) &&
                (i_pix_y >= RULE1_Y0)  && (i_pix_y < RULE1_Y0 + RU_CHAR_H);
wire in_rule2 = (i_pix_x >= RULE_X0)  && (i_pix_x < RULE_X0  + RU_LINE_W) &&
                (i_pix_y >= RULE2_Y0)  && (i_pix_y < RULE2_Y0 + RU_CHAR_H);
wire splash_active = (in_title | in_rule0 | in_rule1 | in_rule2);

// Prompt
wire in_prompt = (i_pix_x >= PROMPT_X0) && (i_pix_x < PROMPT_X0 + PROMPT_W) &&
                 (i_pix_y >= PROMPT_Y0)  && (i_pix_y < PROMPT_Y0 + PR_CHAR_H);

// State-gated enables
wire show_splash = (i_state == ST_NEW_GAME) && splash_active;
wire show_prompt = (i_state == ST_NEW_BALL) && in_prompt;
wire show_hud    = (i_state == ST_PLAY || i_state == ST_GAME_OVER) &&
                   (score_active | lives_active);
wire any_active  = show_splash | show_prompt | show_hud;

//  HUD decoders
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
wire [6:0] ascii_score = 7'h30 + {3'b000, digit_val};

wire [13:0] sc_lx = in_l_tens ? (i_pix_x - X_L_TENS) :
                    in_l_ones ? (i_pix_x - X_L_ONES) :
                    in_r_tens ? (i_pix_x - X_R_TENS) :
                                (i_pix_x - X_R_ONES);
wire [13:0] sc_ly = i_pix_y - Y_TOP;
// SCALE=8 → power-of-2 slices
wire [2:0] sc_font_col = sc_lx[5:3];
wire [3:0] sc_font_row = sc_ly[6:3];

// LIVES — LV_SCALE=4 → power-of-2 slices
/* verilator lint_off WIDTHEXPAND */
wire [13:0] lv_lx = in_lv_label ? (i_pix_x - X_LV_LABEL) : (i_pix_x - X_LV_DIGIT);
wire [13:0] lv_ly = in_lv_label ? (i_pix_y - Y_LV_LABEL)  : (i_pix_y - Y_LV_DIGIT);
wire [2:0]  lv_slot     = lv_lx[7:5];   // which of 5 label chars (/32 via bits[6:5] for 0..4)
wire [2:0]  lv_font_col = lv_lx[4:2];   // /4
wire [3:0]  lv_font_row = lv_ly[5:2];   // /4
reg [6:0] ascii_lives;
always @(*) begin
    if (in_lv_digit) begin
        ascii_lives = 7'h30 + {5'b0, i_balls};
    end else begin
        case (lv_slot)
            3'd0: ascii_lives = 7'h4C; // L
            3'd1: ascii_lives = 7'h49; // I
            3'd2: ascii_lives = 7'h56; // V
            3'd3: ascii_lives = 7'h45; // E
            3'd4: ascii_lives = 7'h53; // S
            default: ascii_lives = 7'h20;
        endcase
    end
end

//  Splash: title "BitPong"  (SP_SCALE=12 → non-power-of-2 divide-by-12)
wire [13:0] ti_lx = i_pix_x - TITLE_X0;
wire [13:0] ti_ly = i_pix_y - TITLE_Y0;

// Slot = ti_lx / 96  (7 slots: 0..6)
reg [2:0] ti_slot;
always @(*) begin
    if      (ti_lx < 14'd96)  ti_slot = 3'd0;
    else if (ti_lx < 14'd192) ti_slot = 3'd1;
    else if (ti_lx < 14'd288) ti_slot = 3'd2;
    else if (ti_lx < 14'd384) ti_slot = 3'd3;
    else if (ti_lx < 14'd480) ti_slot = 3'd4;
    else if (ti_lx < 14'd576) ti_slot = 3'd5;
    else                       ti_slot = 3'd6;
end

// Intra-slot x offset (0..95)
reg [6:0] ti_lx_in_slot;
always @(*) begin
    case (ti_slot)
        3'd0: ti_lx_in_slot = ti_lx[6:0];
        3'd1: ti_lx_in_slot = ti_lx[6:0] - 7'd96;
        3'd2: ti_lx_in_slot = ti_lx[6:0] - 7'd64; // 192 mod 128 = 64
        3'd3: ti_lx_in_slot = ti_lx[6:0] - 7'd32; // 288 mod 128 = 32
        3'd4: ti_lx_in_slot = ti_lx[6:0] - 7'd0;  // 384 mod 128 = 0
        3'd5: ti_lx_in_slot = ti_lx[6:0] - 7'd96;
        default: ti_lx_in_slot = ti_lx[6:0] - 7'd64;
    endcase
end

// col = ti_lx_in_slot / 12  (0..7)
function [2:0] div12c;
    input [6:0] n;
    begin
        if      (n < 7'd12) div12c = 3'd0;
        else if (n < 7'd24) div12c = 3'd1;
        else if (n < 7'd36) div12c = 3'd2;
        else if (n < 7'd48) div12c = 3'd3;
        else if (n < 7'd60) div12c = 3'd4;
        else if (n < 7'd72) div12c = 3'd5;
        else if (n < 7'd84) div12c = 3'd6;
        else                 div12c = 3'd7;
    end
endfunction

// row = ti_ly / 12  (0..15)
function [3:0] div12r;
    input [7:0] n;
    begin
        if      (n < 8'd12)  div12r = 4'd0;
        else if (n < 8'd24)  div12r = 4'd1;
        else if (n < 8'd36)  div12r = 4'd2;
        else if (n < 8'd48)  div12r = 4'd3;
        else if (n < 8'd60)  div12r = 4'd4;
        else if (n < 8'd72)  div12r = 4'd5;
        else if (n < 8'd84)  div12r = 4'd6;
        else if (n < 8'd96)  div12r = 4'd7;
        else if (n < 8'd108) div12r = 4'd8;
        else if (n < 8'd120) div12r = 4'd9;
        else if (n < 8'd132) div12r = 4'd10;
        else if (n < 8'd144) div12r = 4'd11;
        else if (n < 8'd156) div12r = 4'd12;
        else if (n < 8'd168) div12r = 4'd13;
        else if (n < 8'd180) div12r = 4'd14;
        else                  div12r = 4'd15;
    end
endfunction

wire [2:0] ti_font_col = div12c(ti_lx_in_slot);
wire [3:0] ti_font_row = div12r(ti_ly[7:0]);

reg [6:0] ascii_title;
always @(*) begin
    case (ti_slot)
        3'd0: ascii_title = 7'h42; // B
        3'd1: ascii_title = 7'h69; // i
        3'd2: ascii_title = 7'h74; // t
        3'd3: ascii_title = 7'h50; // P
        3'd4: ascii_title = 7'h6F; // o
        3'd5: ascii_title = 7'h6E; // n
        default: ascii_title = 7'h67; // g
    endcase
end

// ---------------------------------------------------------------------------
//  Splash: rule lines  (RU_SCALE=3 → divide-by-3, divide-by-24)
//  All three lines share the same X0=576 / same hit-test column logic.
//  Line 0: "AUTO vs PLAYER  press AUTO key  "  (32 chars)
//  Line 1: "2 PLAYER MODE   press any key   "  (32 chars)
//  Line 2: "3 LIVES SHARED  rally for score "  (32 chars)
// ---------------------------------------------------------------------------
wire [13:0] ru_lx = i_pix_x - RULE_X0;
wire [13:0] ru_ly = in_rule0 ? (i_pix_y - RULE0_Y0) :
                    in_rule1 ? (i_pix_y - RULE1_Y0) :
                               (i_pix_y - RULE2_Y0);

// Slot = ru_lx / 24  (0..31)
reg [4:0] ru_slot;
always @(*) begin
    if      (ru_lx < 14'd24)  ru_slot = 5'd0;
    else if (ru_lx < 14'd48)  ru_slot = 5'd1;
    else if (ru_lx < 14'd72)  ru_slot = 5'd2;
    else if (ru_lx < 14'd96)  ru_slot = 5'd3;
    else if (ru_lx < 14'd120) ru_slot = 5'd4;
    else if (ru_lx < 14'd144) ru_slot = 5'd5;
    else if (ru_lx < 14'd168) ru_slot = 5'd6;
    else if (ru_lx < 14'd192) ru_slot = 5'd7;
    else if (ru_lx < 14'd216) ru_slot = 5'd8;
    else if (ru_lx < 14'd240) ru_slot = 5'd9;
    else if (ru_lx < 14'd264) ru_slot = 5'd10;
    else if (ru_lx < 14'd288) ru_slot = 5'd11;
    else if (ru_lx < 14'd312) ru_slot = 5'd12;
    else if (ru_lx < 14'd336) ru_slot = 5'd13;
    else if (ru_lx < 14'd360) ru_slot = 5'd14;
    else if (ru_lx < 14'd384) ru_slot = 5'd15;
    else if (ru_lx < 14'd408) ru_slot = 5'd16;
    else if (ru_lx < 14'd432) ru_slot = 5'd17;
    else if (ru_lx < 14'd456) ru_slot = 5'd18;
    else if (ru_lx < 14'd480) ru_slot = 5'd19;
    else if (ru_lx < 14'd504) ru_slot = 5'd20;
    else if (ru_lx < 14'd528) ru_slot = 5'd21;
    else if (ru_lx < 14'd552) ru_slot = 5'd22;
    else if (ru_lx < 14'd576) ru_slot = 5'd23;
    else if (ru_lx < 14'd600) ru_slot = 5'd24;
    else if (ru_lx < 14'd624) ru_slot = 5'd25;
    else if (ru_lx < 14'd648) ru_slot = 5'd26;
    else if (ru_lx < 14'd672) ru_slot = 5'd27;
    else if (ru_lx < 14'd696) ru_slot = 5'd28;
    else if (ru_lx < 14'd720) ru_slot = 5'd29;
    else if (ru_lx < 14'd744) ru_slot = 5'd30;
    else                       ru_slot = 5'd31;
end

// Intra-slot x offset (0..23); slot*24 mod 32 cycles as {0,24,16,8} repeating
reg [4:0] ru_lx_in_slot;
always @(*) begin
    // ru_lx[4:0] gives bits 4:0; subtract (slot*24 mod 32)
    // slot*24 mod 32: slot%4==0→0, slot%4==1→24, slot%4==2→16, slot%4==3→8
    case (ru_slot[1:0])
        2'd0: ru_lx_in_slot = ru_lx[4:0] - 5'd0;
        2'd1: ru_lx_in_slot = ru_lx[4:0] - 5'd24;
        2'd2: ru_lx_in_slot = ru_lx[4:0] - 5'd16;
        2'd3: ru_lx_in_slot = ru_lx[4:0] - 5'd8;
    endcase
end

// col = ru_lx_in_slot / 3  (0..7)
function [2:0] div3c;
    input [4:0] n;
    begin
        if      (n < 5'd3)  div3c = 3'd0;
        else if (n < 5'd6)  div3c = 3'd1;
        else if (n < 5'd9)  div3c = 3'd2;
        else if (n < 5'd12) div3c = 3'd3;
        else if (n < 5'd15) div3c = 3'd4;
        else if (n < 5'd18) div3c = 3'd5;
        else if (n < 5'd21) div3c = 3'd6;
        else                 div3c = 3'd7;
    end
endfunction

// row = ru_ly / 3  (0..15)
function [3:0] div3r;
    input [5:0] n;
    begin
        if      (n < 6'd3)  div3r = 4'd0;
        else if (n < 6'd6)  div3r = 4'd1;
        else if (n < 6'd9)  div3r = 4'd2;
        else if (n < 6'd12) div3r = 4'd3;
        else if (n < 6'd15) div3r = 4'd4;
        else if (n < 6'd18) div3r = 4'd5;
        else if (n < 6'd21) div3r = 4'd6;
        else if (n < 6'd24) div3r = 4'd7;
        else if (n < 6'd27) div3r = 4'd8;
        else if (n < 6'd30) div3r = 4'd9;
        else if (n < 6'd33) div3r = 4'd10;
        else if (n < 6'd36) div3r = 4'd11;
        else if (n < 6'd39) div3r = 4'd12;
        else if (n < 6'd42) div3r = 4'd13;
        else if (n < 6'd45) div3r = 4'd14;
        else                 div3r = 4'd15;
    end
endfunction

wire [2:0] ru_font_col = div3c(ru_lx_in_slot);
wire [3:0] ru_font_row = div3r(ru_ly[5:0]);

reg [6:0] ascii_rule;
always @(*) begin
    ascii_rule = 7'h20; // space default
    if (in_rule0) begin
        // "AUTO vs PLAYER  press AUTO key  "
        case (ru_slot)
            5'd0:  ascii_rule = 7'h41; // A
            5'd1:  ascii_rule = 7'h55; // U
            5'd2:  ascii_rule = 7'h54; // T
            5'd3:  ascii_rule = 7'h4F; // O
            5'd4:  ascii_rule = 7'h20; // ' '
            5'd5:  ascii_rule = 7'h76; // v
            5'd6:  ascii_rule = 7'h73; // s
            5'd7:  ascii_rule = 7'h20; // ' '
            5'd8:  ascii_rule = 7'h50; // P
            5'd9:  ascii_rule = 7'h4C; // L
            5'd10: ascii_rule = 7'h41; // A
            5'd11: ascii_rule = 7'h59; // Y
            5'd12: ascii_rule = 7'h45; // E
            5'd13: ascii_rule = 7'h52; // R
            5'd14: ascii_rule = 7'h20; // ' '
            5'd15: ascii_rule = 7'h20; // ' '
            5'd16: ascii_rule = 7'h70; // p
            5'd17: ascii_rule = 7'h72; // r
            5'd18: ascii_rule = 7'h65; // e
            5'd19: ascii_rule = 7'h73; // s
            5'd20: ascii_rule = 7'h73; // s
            5'd21: ascii_rule = 7'h20; // ' '
            5'd22: ascii_rule = 7'h41; // A
            5'd23: ascii_rule = 7'h55; // U
            5'd24: ascii_rule = 7'h54; // T
            5'd25: ascii_rule = 7'h4F; // O
            5'd26: ascii_rule = 7'h20; // ' '
            5'd27: ascii_rule = 7'h6B; // k
            5'd28: ascii_rule = 7'h65; // e
            5'd29: ascii_rule = 7'h79; // y
            5'd30: ascii_rule = 7'h20; // ' '
            default: ascii_rule = 7'h20;
        endcase
    end else if (in_rule1) begin
        // "2 PLAYER MODE   press any key   "
        case (ru_slot)
            5'd0:  ascii_rule = 7'h32; // 2
            5'd1:  ascii_rule = 7'h20; // ' '
            5'd2:  ascii_rule = 7'h50; // P
            5'd3:  ascii_rule = 7'h4C; // L
            5'd4:  ascii_rule = 7'h41; // A
            5'd5:  ascii_rule = 7'h59; // Y
            5'd6:  ascii_rule = 7'h45; // E
            5'd7:  ascii_rule = 7'h52; // R
            5'd8:  ascii_rule = 7'h20; // ' '
            5'd9:  ascii_rule = 7'h4D; // M
            5'd10: ascii_rule = 7'h4F; // O
            5'd11: ascii_rule = 7'h44; // D
            5'd12: ascii_rule = 7'h45; // E
            5'd13: ascii_rule = 7'h20; // ' '
            5'd14: ascii_rule = 7'h20; // ' '
            5'd15: ascii_rule = 7'h20; // ' '
            5'd16: ascii_rule = 7'h70; // p
            5'd17: ascii_rule = 7'h72; // r
            5'd18: ascii_rule = 7'h65; // e
            5'd19: ascii_rule = 7'h73; // s
            5'd20: ascii_rule = 7'h73; // s
            5'd21: ascii_rule = 7'h20; // ' '
            5'd22: ascii_rule = 7'h61; // a
            5'd23: ascii_rule = 7'h6E; // n
            5'd24: ascii_rule = 7'h79; // y
            5'd25: ascii_rule = 7'h20; // ' '
            5'd26: ascii_rule = 7'h6B; // k
            5'd27: ascii_rule = 7'h65; // e
            5'd28: ascii_rule = 7'h79; // y
            5'd29: ascii_rule = 7'h20; // ' '
            5'd30: ascii_rule = 7'h20; // ' '
            default: ascii_rule = 7'h20;
        endcase
    end else begin
        // "3 LIVES SHARED  rally for score "
        case (ru_slot)
            5'd0:  ascii_rule = 7'h33; // 3
            5'd1:  ascii_rule = 7'h20; // ' '
            5'd2:  ascii_rule = 7'h4C; // L
            5'd3:  ascii_rule = 7'h49; // I
            5'd4:  ascii_rule = 7'h56; // V
            5'd5:  ascii_rule = 7'h45; // E
            5'd6:  ascii_rule = 7'h53; // S
            5'd7:  ascii_rule = 7'h20; // ' '
            5'd8:  ascii_rule = 7'h53; // S
            5'd9:  ascii_rule = 7'h48; // H
            5'd10: ascii_rule = 7'h41; // A
            5'd11: ascii_rule = 7'h52; // R
            5'd12: ascii_rule = 7'h45; // E
            5'd13: ascii_rule = 7'h44; // D
            5'd14: ascii_rule = 7'h20; // ' '
            5'd15: ascii_rule = 7'h20; // ' '
            5'd16: ascii_rule = 7'h72; // r
            5'd17: ascii_rule = 7'h61; // a
            5'd18: ascii_rule = 7'h6C; // l
            5'd19: ascii_rule = 7'h6C; // l
            5'd20: ascii_rule = 7'h79; // y
            5'd21: ascii_rule = 7'h20; // ' '
            5'd22: ascii_rule = 7'h66; // f
            5'd23: ascii_rule = 7'h6F; // o
            5'd24: ascii_rule = 7'h72; // r
            5'd25: ascii_rule = 7'h20; // ' '
            5'd26: ascii_rule = 7'h73; // s
            5'd27: ascii_rule = 7'h63; // c
            5'd28: ascii_rule = 7'h6F; // o
            5'd29: ascii_rule = 7'h72; // r
            5'd30: ascii_rule = 7'h65; // e
            default: ascii_rule = 7'h20;
        endcase
    end
end

// ---------------------------------------------------------------------------
//  Prompt "PRESS ANY KEY TO LAUNCH"  (PR_SCALE=4 → power-of-2 slices)
//  23 slots × 32 px = 736 px; slot = pr_lx / 32.
//  BUG FIX: must use pr_lx[9:5] (5 bits) not pr_lx[8:5] (4 bits).
//  pr_lx max = 735; 735 >> 5 = 22 → fits in 5 bits.
// ---------------------------------------------------------------------------
wire [13:0] pr_lx = i_pix_x - PROMPT_X0;
wire [13:0] pr_ly = i_pix_y - PROMPT_Y0;
wire [4:0]  pr_slot     = pr_lx[9:5];   // /32, 5 bits → correct for slots 0..22
wire [2:0]  pr_font_col = pr_lx[4:2];   // (lx mod 32) / 4
wire [3:0]  pr_font_row = pr_ly[5:2];   // ly / 4

reg [6:0] ascii_prompt;
always @(*) begin
    // "PRESS ANY KEY TO LAUNCH"
    case (pr_slot)
        5'd0:  ascii_prompt = 7'h50; // P
        5'd1:  ascii_prompt = 7'h52; // R
        5'd2:  ascii_prompt = 7'h45; // E
        5'd3:  ascii_prompt = 7'h53; // S
        5'd4:  ascii_prompt = 7'h53; // S
        5'd5:  ascii_prompt = 7'h20; // ' '
        5'd6:  ascii_prompt = 7'h41; // A
        5'd7:  ascii_prompt = 7'h4E; // N
        5'd8:  ascii_prompt = 7'h59; // Y
        5'd9:  ascii_prompt = 7'h20; // ' '
        5'd10: ascii_prompt = 7'h4B; // K
        5'd11: ascii_prompt = 7'h45; // E
        5'd12: ascii_prompt = 7'h59; // Y
        5'd13: ascii_prompt = 7'h20; // ' '
        5'd14: ascii_prompt = 7'h54; // T
        5'd15: ascii_prompt = 7'h4F; // O
        5'd16: ascii_prompt = 7'h20; // ' '
        5'd17: ascii_prompt = 7'h4C; // L
        5'd18: ascii_prompt = 7'h41; // A
        5'd19: ascii_prompt = 7'h55; // U
        5'd20: ascii_prompt = 7'h4E; // N
        5'd21: ascii_prompt = 7'h43; // C
        5'd22: ascii_prompt = 7'h48; // H
        default: ascii_prompt = 7'h20;
    endcase
end

wire [10:0] rom_addr;
wire [2:0]  font_col;
wire [23:0] cur_color;

assign {rom_addr, font_col, cur_color} =
    (show_splash && in_title) ?
        {{ascii_title, ti_font_row}, ti_font_col, C_TITLE}  :
    (show_splash && (in_rule0 | in_rule1 | in_rule2)) ?
        {{ascii_rule,  ru_font_row}, ru_font_col, C_RULE}   :
    (show_prompt) ?
        {{ascii_prompt, pr_font_row}, pr_font_col, C_PROMPT} :
    (show_hud && score_active) ?
        {{ascii_score, sc_font_row}, sc_font_col, C_HUD}    :
    (show_hud && lives_active) ?
        {{ascii_lives, lv_font_row}, lv_font_col, C_HUD}    :
        {11'd0, 3'd0, 24'd0};

wire [7:0] rom_data;
ascii_rom u_ascii_rom (
    .clk    (i_clk),
    .addr   (rom_addr),
    .o_data (rom_data)
);

//  2-cycle output pipeline  (ROM registered read + output register)
//  Pipeline active flag, font_col, and colour together.
reg        active_d1;
reg [2:0]  fcol_d1;
reg [23:0] color_d1;

always @(posedge i_clk) begin
    active_d1 <= any_active;
    fcol_d1   <= font_col;
    color_d1  <= cur_color;
end

wire pixel_set = rom_data[3'd7 - fcol_d1];

reg        text_on_q;
reg [23:0] rgb_q;
always @(posedge i_clk) begin
    text_on_q <= active_d1 & pixel_set;
    rgb_q     <= (active_d1 & pixel_set) ? color_d1 : 24'h00_00_00;
end

assign o_text_on = text_on_q;
assign o_rgb     = rgb_q;

endmodule
