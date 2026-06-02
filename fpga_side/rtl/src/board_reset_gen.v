`timescale 1ns/1ps

// Power-up reset generator for MA703FA-100T.
//
// MA703FA does not expose a dedicated external reset pushbutton on the board
// variant being targeted here, so the design uses an internal active-low reset
// that deasserts after a fixed power-up delay.
//
// This keeps the board flow honest: there is no fake external reset pin in the
// top-level, but the RTL still starts from a known reset state.

module board_reset_gen #(
    parameter integer HOLD_CYCLES = 2500000
) (
    input  wire clk,
    output reg  rst_n
);

reg [31:0] counter;

always @(posedge clk) begin
    if (counter < HOLD_CYCLES[31:0]) begin
        counter <= counter + 32'd1;
        rst_n   <= 1'b0;
    end else begin
        rst_n   <= 1'b1;
    end
end

initial begin
    counter = 32'd0;
    rst_n   = 1'b0;
end

endmodule