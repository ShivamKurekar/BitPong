module bitpong_graphics (
    input i_clk,
    input i_reset_n,
    input i_den,

    /* Right Player */
    input p1_up,
    input p1_down,

    /* Left Player */
    input p2_up,
    input p2_down,

    /* for one player mode */
    input auto_play,

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

wire w_cntr_line;
wire w_wall_en;
wire w_score_on;
wire graph_on;

wire [23:0] w_wall_pixel;
wire [23:0] w_score_rgb;
wire [23:0] graph_rgb;

reg gra_still;
reg gra_stll_next;
reg d_inc_l;
reg d_inc_r;
reg d_clr;
reg timer_start;

// Left player score
wire [3:0] dig0_l;
wire [3:0] dig1_l;
// Right player score
wire [3:0] dig0_r;
wire [3:0] dig1_r;

bitpong_walls walls (
    .i_pixel_x(i_pixel_x),
    .i_pixel_y(i_pixel_y),
    .o_cntr_line(w_cntr_line),
    .o_wall_en(w_wall_en),
    .o_pixel(w_wall_pixel)
);

bitpong_text text (
    .i_clk(i_clk),
    .i_pix_x(i_pixel_x),
    .i_pix_y(i_pixel_y),
    .i_balls(ball_count),
    .i_score_l_tens(dig1_l),
    .i_score_l_ones(dig0_l),
    .i_score_r_tens(dig1_r),
    .i_score_r_ones(dig0_r),
    .o_text_on(w_score_on),
    .o_rgb(w_score_rgb)
);

wire hit_r;
wire hit_l;
wire miss;

bitpong_engine physics (
    .clk(i_clk),
    .reset_n(i_reset_n),
    .btn1({p2_down, p2_up}),
    .btn2({p1_down, p1_up}),
    .ai_switch(auto_play),
    .pix_x(i_pixel_x),
    .pix_y(i_pixel_y),
    .gra_still(gra_still), // to pause game

    .hit_r(hit_r),
    .hit_l(hit_l),
    .miss(miss),
    .graph_on(graph_on),
    .graph_rgb(graph_rgb)
);

score_counter scc_l (
    .clk(i_clk),
    .reset_n(i_reset_n),
    .d_inc(d_inc_l),
    .d_clr(d_clr),
    .dig0(dig0_l),
    .dig1(dig1_l)
);

score_counter scc_r (
    .clk(i_clk),
    .reset_n(i_reset_n),
    .d_inc(d_inc_r),
    .d_clr(d_clr),
    .dig0(dig0_r),
    .dig1(dig1_r)
);

wire timer_tick;
wire timer_up;
wire refr_tick;

assign timer_tick = (i_pixel_x == 0) && (i_pixel_y == 0);
assign refr_tick = (i_pixel_x == 14'd1919) && (i_pixel_y == 14'd1079);

bitpong_timer bt (
    .clk(i_clk),
    .reset_n(i_reset_n),
    .timer_start(timer_start),
    .timer_tick(timer_tick),
    .timer_up(timer_up)
);

reg [1:0] ball_count;
reg [1:0] new_ball_count;
reg [23:0] r_pixel;
reg [23:0] r_next_pixel;

localparam NEW_GAME   = 2'b00;
localparam PLAY       = 2'b01;
localparam NEW_BALL   = 2'b10;
localparam GAME_OVER  = 2'b11;
reg [1:0] state;
reg [1:0] next_state;

// syncing the updated values to clk
always @(posedge i_clk or negedge i_reset_n) begin
    if (!i_reset_n) begin
        state <= NEW_GAME;
        ball_count <= 2'd3;
        r_pixel <= 0;
        gra_still <= 1'b1;   // hold ball at spawn on reset
    end else begin
        state <= next_state;
        ball_count <= new_ball_count;
        r_pixel <= r_next_pixel;
        gra_still <= gra_stll_next;
    end
end

always @(*) begin
    gra_stll_next = 1'b1;
    timer_start = 1'b0;
    d_inc_l = 1'b0;
    d_inc_r = 1'b0;
    d_clr = 1'b0;
    next_state = state;
    new_ball_count = ball_count;

    case (state)
        NEW_GAME: begin
            new_ball_count = 2'd3;
            d_clr = 1'b1; // clear both scores

            if (p1_up || p1_down || p2_up || p2_down || auto_play) begin
                next_state = PLAY;
            end
        end 

        PLAY: begin
            gra_stll_next = 1'b0;

            if (refr_tick && hit_r) begin
                d_inc_r = 1'b1;
            end else if (refr_tick && hit_l) begin
                d_inc_l = 1'b1;
            end else if (miss) begin
                if (ball_count == 0)
                    next_state = GAME_OVER;
                else
                    next_state = NEW_BALL;

                timer_start = 1'b1;
                new_ball_count = ball_count - 1;
            end
        end

        NEW_BALL: begin
            // Human button resumes after timer expires
            if (timer_up && (p1_up || p1_down || p2_up || p2_down))
                next_state = PLAY;
            else
                next_state = NEW_BALL;
        end

        GAME_OVER: begin
            if (timer_up)
                next_state = NEW_GAME;
        end

        default: next_state = NEW_GAME;
    endcase
end

always @(*) begin
    if(i_den) begin
        if (graph_on)
            r_next_pixel = graph_rgb;
        else if (w_score_on)
            r_next_pixel = w_score_rgb;
        else if(w_wall_en || w_cntr_line)
            r_next_pixel = w_wall_pixel;
        else
            r_next_pixel = 24'h00_00_00;
    end else begin
        r_next_pixel = 24'h00_00_00;
    end
end

assign o_pixel = r_pixel;

endmodule