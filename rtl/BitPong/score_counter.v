module score_counter (
    input  wire       clk,
    input  wire       reset_n,
    input  wire       d_inc,
    input  wire       d_clr,
    output wire [3:0] dig0,
    output wire [3:0] dig1
);

    // Signal declarations
    reg [3:0] dig0_reg, dig1_reg;
    reg [3:0] dig0_next, dig1_next;

    // State registers
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            dig1_reg <= 4'd0;
            dig0_reg <= 4'd0;
        end
        else begin
            dig1_reg <= dig1_next;
            dig0_reg <= dig0_next;
        end
    end

    // Next-state logic
    always @* begin
        dig0_next = dig0_reg;
        dig1_next = dig1_reg;

        if (d_clr) begin
            dig0_next = 4'd0;
            dig1_next = 4'd0;
        end
        else if (d_inc) begin
            if (dig0_reg == 4'd9) begin
                dig0_next = 4'd0;

                if (dig1_reg == 4'd9)
                    dig1_next = 4'd0;
                else
                    dig1_next = dig1_reg + 1'b1;
            end
            else begin
                dig0_next = dig0_reg + 1'b1;
            end
        end
    end

    // Outputs
    assign dig0 = dig0_reg;
    assign dig1 = dig1_reg;

endmodule