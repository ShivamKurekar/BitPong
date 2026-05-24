module ascii_rom (
    input             clk,
    input      [10:0] addr,
    output reg  [7:0] o_data
);

/*
ROM with synchronous read (inferring Block RAM via $readmemh)
Character ROM:
    - 8-by-16 (8-by-2^4) font
    - 128 (2^7) characters
    - ROM size: 2048-by-8 (2^11-by-8) bits  =>  1 BRAM
Font data loaded from: font_8x16.mem  (2048 lines, one hex byte per line)
*/

reg [7:0] mem [0:2047];

initial begin
    $readmemh("font_8x16.mem", mem);
end

// Synchronous read — same behaviour as the original (registered address)
always @(posedge clk) begin
    o_data <= mem[addr];
end

endmodule