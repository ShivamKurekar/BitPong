module bitpong_button_toggle (
    input  wire clk,
    input  wire rst_n,
    input  wire btn_n,      // Active-low push button
    output reg  toggle      // Toggles on each button press
);

reg btn_n_d;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        btn_n_d <= 1'b1;
        toggle  <= 1'b0;
    end
    else begin
        // Store previous button state
        btn_n_d <= btn_n;

        // Falling edge detection (button press)
        if (btn_n_d && !btn_n)
            toggle <= ~toggle;
    end
end

endmodule