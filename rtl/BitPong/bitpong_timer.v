module bitpong_timer (
    input  wire clk,
    input  wire reset_n,
    input  wire timer_start,
    input  wire timer_tick,
    output wire timer_up
);

    // Signal declarations
    reg [6:0] timer_reg;
    reg [6:0] timer_next;

    // State register
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            timer_reg <= 7'b1111111;
        else
            timer_reg <= timer_next;
    end

    // Next-state logic
    always @* begin
        if (timer_start)
            timer_next = 7'b1111111;
        else if (timer_tick && (timer_reg != 7'd0))
            timer_next = timer_reg - 1'b1;
        else
            timer_next = timer_reg;
    end

    // Output logic
    assign timer_up = (timer_reg == 7'd0);

endmodule