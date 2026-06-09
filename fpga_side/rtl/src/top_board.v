`timescale 1ns/1ps

// Board-level wrapper for MA703FA-100T.
//
// Active data path:
// host UDP -> PHY-A RGMII -> MAC/UDP parser -> m1_rx stream + market decoder -> core
// core m1_tx stream -> UDP packetizer -> PHY-A RGMII TX
//
// ETHA is the active first-link interface. ETHB remains available for later
// dual-port expansion and validation.

module top_board (
    // Board clock
    input  wire        sys_clk_50m,

    // Shared PHY management
    inout  wire        eth_mdio,
    output wire        eth_mdc,
    output wire        eth_rst,

    // PHY-A (PL_LANA)
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

    // PHY-B (PL_LANB)
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
    output wire        ethb_txd3
);

wire        sys_rst_n;

wire        price_valid;
wire [31:0] open_price;
wire [31:0] high_price;
wire [31:0] low_price;
wire [31:0] close_price;
wire [31:0] volume;
wire [7:0]  cfg_strong_buy;
wire [7:0]  cfg_buy;
wire [7:0]  cfg_neutral;
wire [7:0]  cfg_sell;
wire        cfg_valid;

wire        m1_rx_valid;
wire [7:0]  m1_rx_data;
wire        m1_rx_last;
wire        market_frame_valid;
wire [7:0]  market_frame_data;
wire        market_frame_last;
wire        m1_tx_ready;
wire [7:0]  m1_tx_data;
wire        m1_tx_valid;
wire        m1_tx_last;
wire        m1_frame_accepted;
wire        m1_frame_rejected;
wire [2:0]  m1_frame_reject_reason;
wire        heartbeat;
wire [7:0]  score_debug;
wire [2:0]  decision_debug;
wire        result_valid_debug;
wire [2:0]  frame_reject_reason_debug;
wire        dbg_arp_responded;
wire        dbg_ping_responded;

board_reset_gen u_reset_gen (
    .clk   (sys_clk_50m),
    .rst_n (sys_rst_n)
);

board_market_feed_ingress u_market_feed_ingress (
    .clk            (sys_clk_50m),
    .rst_n          (sys_rst_n),
    .frame_valid    (market_frame_valid),
    .frame_data     (market_frame_data),
    .frame_last     (market_frame_last),
    .price_valid    (price_valid),
    .open_price     (open_price),
    .high_price     (high_price),
    .low_price      (low_price),
    .close_price    (close_price),
    .volume         (volume),
    .cfg_strong_buy (cfg_strong_buy),
    .cfg_buy        (cfg_buy),
    .cfg_neutral    (cfg_neutral),
    .cfg_sell       (cfg_sell),
    .cfg_valid      (cfg_valid)
);

board_eth_bridge u_eth_bridge (
    .clk            (sys_clk_50m),
    .rst_n          (sys_rst_n),

    .eth_mdio       (eth_mdio),
    .eth_mdc        (eth_mdc),
    .eth_rst        (eth_rst),

    .etha_rxck      (etha_rxck),
    .etha_rxctl     (etha_rxctl),
    .etha_rxd0      (etha_rxd0),
    .etha_rxd1      (etha_rxd1),
    .etha_rxd2      (etha_rxd2),
    .etha_rxd3      (etha_rxd3),
    .etha_txck      (etha_txck),
    .etha_txctl     (etha_txctl),
    .etha_txd0      (etha_txd0),
    .etha_txd1      (etha_txd1),
    .etha_txd2      (etha_txd2),
    .etha_txd3      (etha_txd3),

    .ethb_rxck      (ethb_rxck),
    .ethb_rxctl     (ethb_rxctl),
    .ethb_rxd0      (ethb_rxd0),
    .ethb_rxd1      (ethb_rxd1),
    .ethb_rxd2      (ethb_rxd2),
    .ethb_rxd3      (ethb_rxd3),
    .ethb_txck      (ethb_txck),
    .ethb_txctl     (ethb_txctl),
    .ethb_txd0      (ethb_txd0),
    .ethb_txd1      (ethb_txd1),
    .ethb_txd2      (ethb_txd2),
    .ethb_txd3      (ethb_txd3),

    .m1_rx_valid    (m1_rx_valid),
    .m1_rx_data     (m1_rx_data),
    .m1_rx_last     (m1_rx_last),
    .market_frame_valid(market_frame_valid),
    .market_frame_data (market_frame_data),
    .market_frame_last (market_frame_last),
    .m1_tx_ready    (m1_tx_ready),
    .m1_tx_data     (m1_tx_data),
    .m1_tx_valid    (m1_tx_valid),
    .m1_tx_last     (m1_tx_last),

    .arp_responded  (dbg_arp_responded),
    .ping_responded (dbg_ping_responded)
);

top u_core (
    .sys_clk_50m          (sys_clk_50m),
    .sys_rst_n            (sys_rst_n),
    .price_valid          (price_valid),
    .open_price           (open_price),
    .high_price           (high_price),
    .low_price            (low_price),
    .close_price          (close_price),
    .volume               (volume),
    .cfg_strong_buy       (cfg_strong_buy),
    .cfg_buy              (cfg_buy),
    .cfg_neutral          (cfg_neutral),
    .cfg_sell             (cfg_sell),
    .cfg_valid            (cfg_valid),
    .m1_rx_valid          (m1_rx_valid),
    .m1_rx_data           (m1_rx_data),
    .m1_rx_last           (m1_rx_last),
    .m1_tx_ready          (m1_tx_ready),
    .m1_tx_data           (m1_tx_data),
    .m1_tx_valid          (m1_tx_valid),
    .m1_tx_last           (m1_tx_last),
    .m1_frame_accepted    (m1_frame_accepted),
    .m1_frame_rejected    (m1_frame_rejected),
    .m1_frame_reject_reason(m1_frame_reject_reason),
    .tx_ready             (1'b1),
    .tx_data              (),
    .tx_valid             (),
    .tx_last              (),
    .heartbeat            (heartbeat),
    .score_debug          (score_debug),
    .decision_debug       (decision_debug),
    .result_valid_debug   (result_valid_debug),
    .ma5_debug            (),
    .ma20_debug           (),
    .ma60_debug           (),
    .rsi_debug            (),
    .macd_dif_debug       (),
    .macd_dea_debug       (),
    .boll_upper_debug     (),
    .boll_lower_debug     (),
    .atr_debug            (),
    .vol_ratio_debug      ()
);

assign frame_reject_reason_debug = m1_frame_reject_reason;

endmodule