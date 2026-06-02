`timescale 1ns/1ps

// Minimal MAC RX framing helper.
// Converts GMII-like bytes into frame stream and strips 8-byte preamble/SFD.

module mac_rx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       gmii_rx_dv,
    input  wire [7:0] gmii_rx_data,
    output reg        eth_rx_valid,
    output reg  [7:0] eth_rx_data,
    output reg        eth_rx_last
);

reg        in_frame;
reg [3:0]  preamble_count;
reg [7:0]  prev_data;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        in_frame       <= 1'b0;
        preamble_count <= 4'd0;
        prev_data      <= 8'h00;
        eth_rx_valid   <= 1'b0;
        eth_rx_data    <= 8'h00;
        eth_rx_last    <= 1'b0;
    end else begin
        eth_rx_valid <= 1'b0;
        eth_rx_last  <= 1'b0;

        if (gmii_rx_dv) begin
            if (!in_frame) begin
                in_frame       <= 1'b1;
                preamble_count <= 4'd1;
                prev_data      <= gmii_rx_data;
            end else begin
                preamble_count <= preamble_count + 4'd1;
                prev_data      <= gmii_rx_data;

                if (preamble_count >= 4'd8) begin
                    eth_rx_valid <= 1'b1;
                    eth_rx_data  <= gmii_rx_data;
                end
            end
        end else if (in_frame) begin
            in_frame       <= 1'b0;
            preamble_count <= 4'd0;
            eth_rx_last    <= 1'b1;
            prev_data      <= 8'h00;
        end
    end
end

wire _unused_prev_data = prev_data[0];

endmodule
