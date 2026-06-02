`timescale 1ns/1ps

module rgmii_tx_sync (
    input  wire       gmii_tx_clk,
    input  wire       gmii_tx_en,
    input  wire [7:0] gmii_txd,
    output wire       rgmii_txc,
    output wire       rgmii_tx_ctl,
    output wire [3:0] rgmii_txd
);

assign rgmii_txc = gmii_tx_clk;

ODDR #(
    .DDR_CLK_EDGE("SAME_EDGE"),
    .INIT(1'b0),
    .SRTYPE("SYNC")
) u_oddr_ctl (
    .Q(rgmii_tx_ctl),
    .C(gmii_tx_clk),
    .CE(1'b1),
    .D1(gmii_tx_en),
    .D2(gmii_tx_en),
    .R(1'b0),
    .S(1'b0)
);

genvar i;
generate
for (i = 0; i < 4; i = i + 1) begin : g_tx_oddr
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) u_oddr_data (
        .Q(rgmii_txd[i]),
        .C(gmii_tx_clk),
        .CE(1'b1),
        .D1(gmii_txd[i]),
        .D2(gmii_txd[i+4]),
        .R(1'b0),
        .S(1'b0)
    );
end
endgenerate

endmodule
