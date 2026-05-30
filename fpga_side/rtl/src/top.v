`timescale 1ns/1ps

module top (
    input  wire        sys_clk_50m,
    input  wire        sys_rst_n,
    input  wire        price_valid,
    input  wire [31:0] open_price,
    input  wire [31:0] high_price,
    input  wire [31:0] low_price,
    input  wire [31:0] close_price,
    input  wire [31:0] volume,
    input  wire [7:0]  cfg_strong_buy,
    input  wire [7:0]  cfg_buy,
    input  wire [7:0]  cfg_neutral,
    input  wire [7:0]  cfg_sell,
    input  wire        cfg_valid,

    input  wire        m1_rx_valid,
    input  wire [7:0]  m1_rx_data,
    input  wire        m1_rx_last,
    input  wire        m1_tx_ready,

    output wire [7:0]  m1_tx_data,
    output wire        m1_tx_valid,
    output wire        m1_tx_last,
    output wire        m1_frame_accepted,
    output wire        m1_frame_rejected,
    output wire [2:0]  m1_frame_reject_reason,

    input  wire        tx_ready,
    output wire [7:0]  tx_data,
    output wire        tx_valid,
    output wire        tx_last,
    output wire        heartbeat,
    output wire [7:0]  score_debug,
    output wire [2:0]  decision_debug,
    output wire        result_valid_debug,
    output wire [31:0] ma5_debug,
    output wire [31:0] ma20_debug,
    output wire [31:0] ma60_debug,
    output wire [31:0] rsi_debug,
    output wire [31:0] macd_dif_debug,
    output wire [31:0] macd_dea_debug,
    output wire [31:0] boll_upper_debug,
    output wire [31:0] boll_lower_debug,
    output wire [31:0] atr_debug,
    output wire [31:0] vol_ratio_debug
);

wire [7:0] score;
wire [2:0] decision;
wire       result_valid;
wire [31:0] ma5;
wire [31:0] ma20;
wire [31:0] ma60;
wire [31:0] rsi;
wire [31:0] macd_dif;
wire [31:0] macd_dea;
wire [31:0] boll_upper;
wire [31:0] boll_lower;
wire [31:0] atr;
wire [31:0] vol_ratio;
wire [7:0]  trade_signal_m1;

assign heartbeat = sys_clk_50m & sys_rst_n;
assign trade_signal_m1 = {5'd0, decision};
assign score_debug = score;
assign decision_debug = decision;
assign result_valid_debug = result_valid;
assign ma5_debug = ma5;
assign ma20_debug = ma20;
assign ma60_debug = ma60;
assign rsi_debug = rsi;
assign macd_dif_debug = macd_dif;
assign macd_dea_debug = macd_dea;
assign boll_upper_debug = boll_upper;
assign boll_lower_debug = boll_lower;
assign atr_debug = atr;
assign vol_ratio_debug = vol_ratio;

indicator_top u_indicator_top (
    .clk           (sys_clk_50m),
    .rst_n         (sys_rst_n),
    .price_valid   (price_valid),
    .open_price    (open_price),
    .high_price    (high_price),
    .low_price     (low_price),
    .close_price   (close_price),
    .volume        (volume),
    .cfg_strong_buy(cfg_strong_buy),
    .cfg_buy       (cfg_buy),
    .cfg_neutral   (cfg_neutral),
    .cfg_sell      (cfg_sell),
    .cfg_valid     (cfg_valid),
    .score         (score),
    .decision      (decision),
    .result_valid  (result_valid),
    .ma5           (ma5),
    .ma20          (ma20),
    .ma60          (ma60),
    .rsi           (rsi),
    .macd_dif      (macd_dif),
    .macd_dea      (macd_dea),
    .boll_upper    (boll_upper),
    .boll_lower    (boll_lower),
    .atr           (atr),
    .vol_ratio     (vol_ratio)
);

udp_result_tx u_udp_result_tx (
    .clk        (sys_clk_50m),
    .rst_n      (sys_rst_n),
    .tx_start   (result_valid),
    .score      (score),
    .decision   (decision),
    .ma5        (ma5),
    .ma20       (ma20),
    .ma60       (ma60),
    .rsi        (rsi),
    .dif        (macd_dif),
    .dea        (macd_dea),
    .boll_upper (boll_upper),
    .boll_lower (boll_lower),
    .atr        (atr),
    .vol_ratio  (vol_ratio),
    .status_word(8'hAA),
    .error_cnt  (16'd0),
    .tx_data    (tx_data),
    .tx_valid   (tx_valid),
    .tx_last    (tx_last),
    .tx_ready   (tx_ready)
);

m1_protocol_core u_m1_protocol_core (
    .clk                 (sys_clk_50m),
    .rst_n               (sys_rst_n),
    .rx_valid            (m1_rx_valid),
    .rx_data             (m1_rx_data),
    .rx_last             (m1_rx_last),
    .tx_ready            (m1_tx_ready),
    .indicator_valid     (result_valid),
    .ma5_value           (ma5),
    .ma10_value          (ma20),
    .rsi6_value          (rsi),
    .rsi14_value         (rsi),
    .trade_signal_value  (trade_signal_m1),
    .signal_strength_value(score),
    .tx_valid            (m1_tx_valid),
    .tx_data             (m1_tx_data),
    .tx_last             (m1_tx_last),
    .frame_accepted      (m1_frame_accepted),
    .frame_rejected      (m1_frame_rejected),
    .frame_reject_reason (m1_frame_reject_reason)
);

endmodule
