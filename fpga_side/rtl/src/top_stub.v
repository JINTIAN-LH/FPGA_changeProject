module top_stub (
    input  wire clk,
    input  wire rst_n,
    output wire heartbeat
);

assign heartbeat = clk & rst_n;

endmodule
