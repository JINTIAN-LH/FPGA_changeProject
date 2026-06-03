`timescale 1ns/1ps

`include "board_protocol_contract.vh"

module board_eth_bridge (
    input  wire        clk,
    input  wire        rst_n,

    inout  wire        eth_mdio,
    output wire        eth_mdc,
    output wire        eth_rst,

    input  wire        etha_rxck,
    input  wire        etha_rxctl,
    input  wire        etha_rxd0,
    input  wire        etha_rxd1,
    input  wire        etha_rxd2,
    input  wire        etha_rxd3,
    output wire        etha_txck,
    output wire        etha_txctl,
    output wire        etha_txd0,
    output wire        etha_txd1,
    output wire        etha_txd2,
    output wire        etha_txd3,

    input  wire        ethb_rxck,
    input  wire        ethb_rxctl,
    input  wire        ethb_rxd0,
    input  wire        ethb_rxd1,
    input  wire        ethb_rxd2,
    input  wire        ethb_rxd3,
    output wire        ethb_txck,
    output wire        ethb_txctl,
    output wire        ethb_txd0,
    output wire        ethb_txd1,
    output wire        ethb_txd2,
    output wire        ethb_txd3,

    output wire        m1_rx_valid,
    output wire [7:0]  m1_rx_data,
    output wire        m1_rx_last,
    output wire        market_frame_valid,
    output wire [7:0]  market_frame_data,
    output wire        market_frame_last,
    output wire        m1_tx_ready,
    input  wire [7:0]  m1_tx_data,
    input  wire        m1_tx_valid,
    input  wire        m1_tx_last,

    // Debug outputs
    output wire        arp_responded,
    output wire        ping_responded
);

localparam [47:0] LOCAL_MAC = 48'h02_00_00_00_00_01;
localparam [31:0] LOCAL_IP  = 32'hA9FE0076;  // 169.254.0.118
localparam [15:0] M1_UDP_DST_PORT = 16'd5001;

wire        gmii_rx_clk;
wire        gmii_rx_dv;
wire [7:0]  gmii_rx_data;
wire        gmii_tx_clk;
wire        gmii_tx_en;
wire [7:0]  gmii_tx_data;

wire        eth_rx_valid;
wire [7:0]  eth_rx_data;
wire        eth_rx_last;

wire        udp_payload_valid;
wire [7:0]  udp_payload_data;
wire        udp_payload_last;

wire        net_tx_valid;
wire [7:0]  net_tx_data;
wire        net_tx_last;
wire        net_tx_ready;

wire        mdio_mdc;
wire        mdio_out;
wire        mdio_oe;
wire        mdio_in;
wire        phy_rst_n;
wire        mdio_init_done;

wire [8:0]  rx_fifo_dout;
wire [8:0]  tx_fifo_dout;
wire        rx_fifo_full;
wire        rx_fifo_empty;
wire        tx_fifo_full;
wire        tx_fifo_empty;

reg         rx_fifo_rd_en;
wire        tx_fifo_rd_en;
wire        tx_stream_valid;
wire [7:0]  tx_stream_data;
wire        tx_stream_last;
wire        tx_stream_ready;

assign gmii_tx_clk = etha_rxck;

assign eth_mdc = mdio_mdc;
assign eth_rst = phy_rst_n;
IOBUF u_mdio_iobuf (
    .I (mdio_out),
    .O (mdio_in),
    .IO(eth_mdio),
    .T (~mdio_oe)
);

assign m1_tx_ready = ~tx_fifo_full;

assign ethb_txck  = 1'b0;
assign ethb_txctl = 1'b0;
assign ethb_txd0  = 1'b0;
assign ethb_txd1  = 1'b0;
assign ethb_txd2  = 1'b0;
assign ethb_txd3  = 1'b0;

rgmii_rx_sync u_rgmii_rx_sync (
    .rgmii_rx_clk (etha_rxck),
    .rgmii_rx_ctl (etha_rxctl),
    .rgmii_rxd    ({etha_rxd3, etha_rxd2, etha_rxd1, etha_rxd0}),
    .gmii_rx_clk  (gmii_rx_clk),
    .gmii_rx_dv   (gmii_rx_dv),
    .gmii_rx_data (gmii_rx_data)
);

mac_rx u_mac_rx (
    .clk          (gmii_rx_clk),
    .rst_n        (rst_n),
    .gmii_rx_dv   (gmii_rx_dv),
    .gmii_rx_data (gmii_rx_data),
    .eth_rx_valid (eth_rx_valid),
    .eth_rx_data  (eth_rx_data),
    .eth_rx_last  (eth_rx_last)
);

// Network handler with ARP, ICMP, and UDP support
network_handler #(
    .LOCAL_MAC(LOCAL_MAC),
    .LOCAL_IP(LOCAL_IP),
    .UDP_DST_PORT(M1_UDP_DST_PORT)
) u_network_handler (
    .clk(gmii_rx_clk),
    .rst_n(rst_n),
    .rx_valid(eth_rx_valid),
    .rx_data(eth_rx_data),
    .rx_last(eth_rx_last),
    .tx_valid(net_tx_valid),
    .tx_data(net_tx_data),
    .tx_last(net_tx_last),
    .tx_ready(net_tx_ready),
    .udp_payload_valid(udp_payload_valid),
    .udp_payload_data(udp_payload_data),
    .udp_payload_last(udp_payload_last),
    .app_tx_valid(tx_stream_valid),
    .app_tx_data(tx_stream_data),
    .app_tx_last(tx_stream_last),
    .app_tx_ready(tx_stream_ready),
    .arp_responded(arp_responded),
    .ping_responded(ping_responded)
);

cdc_async_fifo #(
    .DATA_W(9),
    .ADDR_W(8)
) u_rx_cdc_fifo (
    .wr_clk   (gmii_rx_clk),
    .wr_rst_n (rst_n),
    .rd_clk   (clk),
    .rd_rst_n (rst_n),
    .din      ({udp_payload_last, udp_payload_data}),
    .wr_en    (udp_payload_valid),
    .rd_en    (rx_fifo_rd_en),
    .dout     (rx_fifo_dout),
    .full     (rx_fifo_full),
    .empty    (rx_fifo_empty)
);

cdc_async_fifo #(
    .DATA_W(9),
    .ADDR_W(8)
) u_tx_cdc_fifo (
    .wr_clk   (clk),
    .wr_rst_n (rst_n),
    .rd_clk   (gmii_tx_clk),
    .rd_rst_n (rst_n),
    .din      ({m1_tx_last, m1_tx_data}),
    .wr_en    (m1_tx_valid & m1_tx_ready),
    .rd_en    (tx_fifo_rd_en),
    .dout     (tx_fifo_dout),
    .full     (tx_fifo_full),
    .empty    (tx_fifo_empty)
);

assign tx_stream_valid = ~tx_fifo_empty;
assign tx_stream_data  = tx_fifo_dout[7:0];
assign tx_stream_last  = tx_fifo_dout[8];
assign tx_fifo_rd_en   = tx_stream_valid & tx_stream_ready;

// TX MUX: network_handler output or direct UDP TX
// For now, use network_handler which handles ARP/ICMP priority
assign net_tx_ready = 1'b1;  // Always ready to TX

udp_tx_engine u_udp_tx_engine (
    .clk      (gmii_tx_clk),
    .rst_n    (rst_n & mdio_init_done),
    .s_valid  (tx_stream_valid),
    .s_data   (tx_stream_data),
    .s_last   (tx_stream_last),
    .s_ready  (tx_stream_ready),
    .gmii_tx_en (gmii_tx_en),
    .gmii_txd   (gmii_tx_data)
);

rgmii_tx_sync u_rgmii_tx_sync (
    .gmii_tx_clk (gmii_tx_clk),
    .gmii_tx_en  (gmii_tx_en),
    .gmii_txd    (gmii_tx_data),
    .rgmii_txc   (etha_txck),
    .rgmii_tx_ctl(etha_txctl),
    .rgmii_txd   ({etha_txd3, etha_txd2, etha_txd1, etha_txd0})
);

mdio_init_fsm #(
    .CLK_DIV (50),
    .PHY_ADDR(5'd1)
) u_mdio_init_fsm (
    .clk      (clk),
    .rst_n    (rst_n),
    .mdc      (mdio_mdc),
    .mdio_o   (mdio_out),
    .mdio_oe  (mdio_oe),
    .phy_rst_n(phy_rst_n),
    .init_done(mdio_init_done)
);

assign m1_rx_valid = ~rx_fifo_empty;
assign m1_rx_data  = rx_fifo_dout[7:0];
assign m1_rx_last  = rx_fifo_dout[8];

assign market_frame_valid = ~rx_fifo_empty;
assign market_frame_data  = rx_fifo_dout[7:0];
assign market_frame_last  = rx_fifo_dout[8];

always @(posedge clk) begin
    if (!rst_n) begin
        rx_fifo_rd_en <= 1'b0;
    end else begin
        rx_fifo_rd_en <= ~rx_fifo_empty;
    end
end

wire _unused_ethb_rxck  = ethb_rxck;
wire _unused_ethb_rxctl = ethb_rxctl;
wire _unused_ethb_rxd0  = ethb_rxd0;
wire _unused_ethb_rxd1  = ethb_rxd1;
wire _unused_ethb_rxd2  = ethb_rxd2;
wire _unused_ethb_rxd3  = ethb_rxd3;

wire _unused_rx_fifo_full = rx_fifo_full;

endmodule
