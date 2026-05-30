`timescale 1ns/1ps

module indicator_top (
    input  wire        clk,
    input  wire        rst_n,
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
    output wire [7:0]  score,
    output wire [2:0]  decision,
    output wire        result_valid,
    output wire [31:0] ma5,
    output wire [31:0] ma20,
    output wire [31:0] ma60,
    output wire [31:0] rsi,
    output wire [31:0] macd_dif,
    output wire [31:0] macd_dea,
    output wire [31:0] boll_upper,
    output wire [31:0] boll_lower,
    output wire [31:0] atr,
    output wire [31:0] vol_ratio
);

wire ma_valid;
wire rsi_valid;
wire macd_valid;
wire vol_valid;
reg  [31:0] dif_prev;
reg  [31:0] dea_prev;

ma_calc u_ma (
    .clk      (clk),
    .rst_n    (rst_n),
    .close    (close_price),
    .valid_in (price_valid),
    .ma5      (ma5),
    .ma20     (ma20),
    .ma60     (ma60),
    .valid_out(ma_valid)
);

rsi_calc u_rsi (
    .clk      (clk),
    .rst_n    (rst_n),
    .close    (close_price),
    .valid_in (price_valid),
    .rsi      (rsi),
    .valid_out(rsi_valid)
);

macd_calc u_macd (
    .clk      (clk),
    .rst_n    (rst_n),
    .close    (close_price),
    .valid_in (price_valid),
    .dif      (macd_dif),
    .dea      (macd_dea),
    .valid_out(macd_valid)
);

vol_ratio_calc u_vol_ratio (
    .clk      (clk),
    .rst_n    (rst_n),
    .volume   (volume),
    .valid_in (price_valid),
    .vol_ratio(vol_ratio),
    .valid_out(vol_valid)
);

assign boll_upper = ma20 + (ma20 >> 4);
assign boll_lower = (ma20 > (ma20 >> 4)) ? (ma20 - (ma20 >> 4)) : 32'd0;
assign atr = (high_price > low_price) ? (high_price - low_price) : 32'd0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dif_prev <= 32'd0;
        dea_prev <= 32'd0;
    end else if (price_valid) begin
        dif_prev <= macd_dif;
        dea_prev <= macd_dea;
    end
end

score_calc u_score_calc (
    .clk           (clk),
    .rst_n         (rst_n),
    .ma5           (ma5),
    .ma20          (ma20),
    .ma60          (ma60),
    .rsi           (rsi),
    .dif           (macd_dif),
    .dea           (macd_dea),
    .dif_prev      (dif_prev),
    .dea_prev      (dea_prev),
    .vol_ratio     (vol_ratio),
    .data_valid    (price_valid && ma_valid && rsi_valid && macd_valid && vol_valid),
    .cfg_strong_buy(cfg_strong_buy),
    .cfg_buy       (cfg_buy),
    .cfg_neutral   (cfg_neutral),
    .cfg_sell      (cfg_sell),
    .cfg_valid     (cfg_valid),
    .score         (score),
    .decision      (decision),
    .score_valid   (result_valid)
);

endmodule
