module bitpong_engine #(
   parameter MAX_X = 1920,
   parameter MAX_Y = 1080,
   parameter BOUND_WIDTH = 10
)
(
   input  wire        clk, reset_n,
   input  wire [1:0]  btn1,
   input  wire [1:0]  btn2,
   input  wire        ai_switch,
   input  wire [13:0] pix_x, pix_y,
   input  wire        gra_still,
   output wire        graph_on,
   output reg         hit_r, hit_l, miss,
   output reg  [23:0] graph_rgb
);

localparam [23:0] COLOR_BG     = 24'h00_00_00;
localparam [23:0] COLOR_PADDLE = 24'hFF_FF_FF;
localparam [23:0] COLOR_BALL   = 24'hFF_FF_FF;

wire refr_tick;

localparam PADDLE_MARGIN = BOUND_WIDTH + 10;

// right paddle -- btn1
localparam BARR_X_L   = MAX_X - BOUND_WIDTH - 36;
localparam BARR_X_R   = BARR_X_L + 27;
wire [10:0] barr_y_t, barr_y_b;
localparam BARR_Y_SIZE = 160;
reg  [10:0] barr_y_reg, barr_y_next;
localparam BARR_V = 12;

// left paddle -- btn2 / AI
localparam BARL_X_L   = BOUND_WIDTH + 6;
localparam BARL_X_R   = BARL_X_L + 27;
wire [10:0] barl_y_t, barl_y_b;
localparam BARL_Y_SIZE = 160;
reg  [10:0] barl_y_reg, barl_y_next;
localparam BARL_V = 12;


localparam BALL_SCALE = 6;
localparam BALL_SIZE  = 48;

localparam BALL_SPAWN_X = (MAX_X - BALL_SIZE) / 2;
localparam BALL_SPAWN_Y = (MAX_Y - BALL_SIZE) / 2;

wire [10:0] ball_x_l, ball_x_r;
wire [10:0] ball_y_t, ball_y_b;
reg  [10:0] ball_x_reg, ball_y_reg;
wire [10:0] ball_x_next, ball_y_next;
reg  [10:0] x_delta_reg, x_delta_next;
reg  [10:0] y_delta_reg, y_delta_next;
localparam BALL_V_P =  10;
localparam BALL_V_N = -10;

// LFSR
reg [7:0] lfsr_reg;
wire      lfsr_fb = lfsr_reg[0];
wire [7:0] lfsr_next;
assign lfsr_next[7] = lfsr_fb;
assign lfsr_next[6] = lfsr_reg[7];
assign lfsr_next[5] = lfsr_reg[6] ^ lfsr_fb;
assign lfsr_next[4] = lfsr_reg[5] ^ lfsr_fb;
assign lfsr_next[3] = lfsr_reg[4] ^ lfsr_fb;
assign lfsr_next[2] = lfsr_reg[3];
assign lfsr_next[1] = lfsr_reg[2];
assign lfsr_next[0] = lfsr_reg[1];

reg  gra_still_prev;
wire launch_tick = gra_still_prev & ~gra_still;

// ball ROM
wire [2:0] rom_addr, rom_col;
reg  [7:0] rom_data;
wire       rom_bit;

always @*
case (rom_addr)
   3'h0: rom_data = 8'b00111100;
   3'h1: rom_data = 8'b01111110;
   3'h2: rom_data = 8'b11111111;
   3'h3: rom_data = 8'b11111111;
   3'h4: rom_data = 8'b11111111;
   3'h5: rom_data = 8'b11111111;
   3'h6: rom_data = 8'b01111110;
   3'h7: rom_data = 8'b00111100;
endcase

wire        barr_on, barl_on, sq_ball_on, rd_ball_on;
wire [23:0] barr_rgb, barl_rgb, ball_rgb;

wire [10:0] ball_center;
wire [10:0] paddlel_center;
reg  [10:0] hit_point;

// registers
always @(posedge clk or negedge reset_n)
   if (!reset_n) begin
      barr_y_reg     <= (MAX_Y - BARR_Y_SIZE) / 2;
      barl_y_reg     <= (MAX_Y - BARL_Y_SIZE) / 2;
      ball_x_reg     <= BALL_SPAWN_X;
      ball_y_reg     <= BALL_SPAWN_Y;
      x_delta_reg    <= 11'h004;
      y_delta_reg    <= 11'h004;
      lfsr_reg       <= 8'hAC;
      gra_still_prev <= 1'b1;
   end else begin
      barr_y_reg     <= barr_y_next;
      barl_y_reg     <= barl_y_next;
      ball_x_reg     <= ball_x_next;
      ball_y_reg     <= ball_y_next;
      x_delta_reg    <= x_delta_next;
      y_delta_reg    <= y_delta_next;
      lfsr_reg       <= lfsr_next;
      gra_still_prev <= gra_still;
   end

// refr_tick must fire exactly once per frame.
assign refr_tick = (pix_y == (MAX_Y - 1)) && (pix_x == (MAX_X - 1));

// right paddle
assign barr_y_t = barr_y_reg;
assign barr_y_b = barr_y_t + BARR_Y_SIZE - 1;
/* verilator lint_off WIDTHEXPAND */
assign barr_on  = (BARR_X_L <= pix_x) && (pix_x <= BARR_X_R) &&
                  (barr_y_t <= pix_y) && (pix_y <= barr_y_b);
assign barr_rgb = COLOR_PADDLE;

always @* begin
   barr_y_next = barr_y_reg;
   if (gra_still)
      barr_y_next = (MAX_Y - BARR_Y_SIZE) / 2;
   else if (refr_tick) begin
      if (btn1[1] && (barr_y_b < (MAX_Y - PADDLE_MARGIN - 1)))
         barr_y_next = barr_y_reg + BARR_V;
      else if (btn1[0] && (barr_y_t > (PADDLE_MARGIN + BARR_V)))
         barr_y_next = barr_y_reg - BARR_V;
   end
end

// left paddle
assign barl_y_t = barl_y_reg;
assign barl_y_b = barl_y_t + BARL_Y_SIZE - 1;
assign barl_on  = (BARL_X_L <= pix_x) && (pix_x <= BARL_X_R) &&
                  (barl_y_t <= pix_y) && (pix_y <= barl_y_b);
assign barl_rgb = COLOR_PADDLE;

assign ball_center    = ball_y_t + ((ball_y_b - ball_y_t) / 2);
assign paddlel_center = barl_y_t + ((barl_y_b - barl_y_t) / 2);

localparam AI_STEP = 9;

always @(*) begin
if (ai_switch) begin
   if (ball_x_l < 2*(MAX_X / 3) && refr_tick) begin
      if (ball_center < paddlel_center) begin
         if (barl_y_t > (PADDLE_MARGIN + AI_STEP))
            barl_y_next = barl_y_reg - AI_STEP;
         else
            barl_y_next = PADDLE_MARGIN;
      end else if (ball_center > paddlel_center) begin
         barl_y_next = barl_y_reg + AI_STEP;
         if (barl_y_next + BARL_Y_SIZE >= (MAX_Y - PADDLE_MARGIN))
            barl_y_next = MAX_Y - PADDLE_MARGIN - BARL_Y_SIZE;
      end else
         barl_y_next = barl_y_reg;
   end else
      barl_y_next = barl_y_reg;
end else begin
   barl_y_next = barl_y_reg;
   if (gra_still)
      barl_y_next = (MAX_Y - BARL_Y_SIZE) / 2;
   else if (refr_tick) begin
      if (btn2[1] && (barl_y_b < (MAX_Y - PADDLE_MARGIN - 1)))
         barl_y_next = barl_y_reg + BARL_V;
      else if (btn2[0] && (barl_y_t > (PADDLE_MARGIN + BARL_V)))
         barl_y_next = barl_y_reg - BARL_V;
   end
end
end

// ball
assign ball_x_l = ball_x_reg;
assign ball_y_t = ball_y_reg;
assign ball_x_r = ball_x_l + BALL_SIZE - 1;
assign ball_y_b = ball_y_t + BALL_SIZE - 1;

assign sq_ball_on =
         (ball_x_l <= pix_x) && (pix_x <= ball_x_r) &&
         (ball_y_t <= pix_y) && (pix_y <= ball_y_b);

wire [5:0] ball_row_off = pix_y[5:0] - ball_y_t[5:0];
wire [5:0] ball_col_off = pix_x[5:0] - ball_x_l[5:0];

function [2:0] div6;
   input [5:0] n;
   begin
      if      (n < 6)  div6 = 3'd0;
      else if (n < 12) div6 = 3'd1;
      else if (n < 18) div6 = 3'd2;
      else if (n < 24) div6 = 3'd3;
      else if (n < 30) div6 = 3'd4;
      else if (n < 36) div6 = 3'd5;
      else if (n < 42) div6 = 3'd6;
      else             div6 = 3'd7;
   end
endfunction

assign rom_addr = div6(ball_row_off);
assign rom_col  = div6(ball_col_off);
assign rom_bit  = rom_data[7 - rom_col];

assign rd_ball_on = sq_ball_on & rom_bit;
assign ball_rgb   = COLOR_BALL;

assign ball_x_next = gra_still ? BALL_SPAWN_X :
                     refr_tick ? ball_x_reg + x_delta_reg :
                     ball_x_reg;
assign ball_y_next = gra_still ? BALL_SPAWN_Y :
                     refr_tick ? ball_y_reg + y_delta_reg :
                     ball_y_reg;

always @(*) begin
   hit_r        = 1'b0;
   hit_l        = 1'b0;
   miss         = 1'b0;
   x_delta_next = x_delta_reg;
   y_delta_next = y_delta_reg;
   hit_point    = 11'd0;

   if (gra_still) begin
      x_delta_next = BALL_V_N;
      y_delta_next = BALL_V_P;
   end else if (launch_tick) begin
      x_delta_next = lfsr_reg[0] ? BALL_V_N : BALL_V_P;
      y_delta_next = lfsr_reg[1] ? BALL_V_N : BALL_V_P;
   end else if (ball_y_t <= BOUND_WIDTH)
      y_delta_next = BALL_V_P;
   else if (ball_y_b >= (MAX_Y - BOUND_WIDTH - 1))
      y_delta_next = BALL_V_N;
   // Right paddle (human, btn1) deflect → score for right player
   else if ((BARR_X_L <= ball_x_r) && (ball_x_r <= BARR_X_R) &&
            (barr_y_t <= ball_y_b) && (ball_y_t <= barr_y_b)) begin
      hit_point = ball_center - barr_y_t;
      if      (hit_point < 1*(BARR_Y_SIZE / 5)) x_delta_next = -8;
      else if (hit_point < 2*(BARR_Y_SIZE / 5)) x_delta_next = -7;
      else if (hit_point < 3*(BARR_Y_SIZE / 5)) x_delta_next = -6;
      else if (hit_point < 4*(BARR_Y_SIZE / 5)) x_delta_next = -7;
      else                                        x_delta_next = -8;
      hit_r = 1'b1;
   // Left paddle (human in 2P, AI in auto) deflect → score for left player
   end else if ((BARL_X_L <= ball_x_l) && (ball_x_l <= BARL_X_R) &&
                  (barl_y_t <= ball_y_b) && (ball_y_t <= barl_y_b)) begin
      hit_point = ball_center - barl_y_t;
      if      (hit_point < 1*(BARL_Y_SIZE / 5)) x_delta_next = 8;
      else if (hit_point < 2*(BARL_Y_SIZE / 5)) x_delta_next = 7;
      else if (hit_point < 3*(BARL_Y_SIZE / 5)) x_delta_next = 6;
      else if (hit_point < 4*(BARL_Y_SIZE / 5)) x_delta_next = 7;
      else                                        x_delta_next = 8;
      hit_l = 1'b1;
   // Right wall escape → right player missed → shared life lost
   end else if (ball_x_r >= (MAX_X - BOUND_WIDTH))
      miss = 1'b1;
   // Left wall escape → left player/AI missed → shared life lost
   // In auto mode AI missing is still a life drain, not a score event.
   else if (ball_x_l <= BOUND_WIDTH)
      miss = 1'b1;
end

// rgb mux
always @(*)
   if      (barr_on)    graph_rgb = barr_rgb;
   else if (barl_on)    graph_rgb = barl_rgb;
   else if (rd_ball_on) graph_rgb = ball_rgb;
   else                 graph_rgb = COLOR_BG;

assign graph_on = barr_on | barl_on | rd_ball_on;

endmodule