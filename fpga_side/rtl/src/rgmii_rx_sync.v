`timescale 1ns/1ps

// RGMII RX DDR capture into GMII-style 8-bit stream.
// Captures low nibble on rising edge and high nibble on falling edge.

module rgmii_rx_sync (
    input  wire       rgmii_rx_clk,
    input  wire       rgmii_rx_ctl,
    input  wire [3:0] rgmii_rxd,
    output wire       gmii_rx_clk,
    output reg        gmii_rx_dv,
    output reg  [7:0] gmii_rx_data
);

reg [3:0] data_rise;
reg [3:0] data_fall;
reg       ctl_rise;
reg       ctl_fall;

always @(posedge rgmii_rx_clk) begin
    data_rise <= rgmii_rxd;
    ctl_rise  <= rgmii_rx_ctl;
end

always @(negedge rgmii_rx_clk) begin
    data_fall <= rgmii_rxd;
    ctl_fall  <= rgmii_rx_ctl;
end

always @(posedge rgmii_rx_clk) begin
    gmii_rx_data <= {data_fall, data_rise};
    gmii_rx_dv   <= ctl_rise;
end

assign gmii_rx_clk = rgmii_rx_clk;

wire _unused_ctl_fall = ctl_fall;

endmodule
