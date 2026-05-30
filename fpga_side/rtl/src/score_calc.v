`timescale 1ns/1ps

// module: score_calc.v
// 功能：百分制评分 + 五档决策（阈值可配置）
module score_calc (
    input  wire        clk,
    input  wire        rst_n,

    // 输入指标（Q16.16）
    input  wire [31:0] ma5,
    input  wire [31:0] ma20,
    input  wire [31:0] ma60,
    input  wire [31:0] rsi,
    input  wire [31:0] dif,
    input  wire [31:0] dea,
    input  wire [31:0] dif_prev,
    input  wire [31:0] dea_prev,
    input  wire [31:0] vol_ratio,
    input  wire        data_valid,

    // 可配置阈值（上位机下发）
    input  wire [7:0]  cfg_strong_buy,
    input  wire [7:0]  cfg_buy,
    input  wire [7:0]  cfg_neutral,
    input  wire [7:0]  cfg_sell,
    input  wire        cfg_valid,

    // 输出
    output reg  [7:0]  score,
    output reg  [2:0]  decision,       // 0:强烈卖出 1:建议卖出 2:观望 3:建议买入 4:强烈买入
    output reg         score_valid
);

reg [7:0] thresh_strong_buy;
reg [7:0] thresh_buy;
reg [7:0] thresh_neutral;
reg [7:0] thresh_sell;

reg [7:0] score_ma;
reg [7:0] score_rsi;
reg [7:0] score_macd;
reg [7:0] score_vol;
reg [8:0] score_total;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        thresh_strong_buy <= 8'd75;
        thresh_buy        <= 8'd60;
        thresh_neutral    <= 8'd45;
        thresh_sell       <= 8'd25;
    end else if (cfg_valid) begin
        thresh_strong_buy <= cfg_strong_buy;
        thresh_buy        <= cfg_buy;
        thresh_neutral    <= cfg_neutral;
        thresh_sell       <= cfg_sell;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        score_ma    <= 8'd0;
        score_rsi   <= 8'd0;
        score_macd  <= 8'd0;
        score_vol   <= 8'd0;
        score_total <= 9'd0;
        score       <= 8'd0;
        decision    <= 3'd0;
        score_valid <= 1'b0;
    end else begin
        score_valid <= 1'b0;

        if (data_valid) begin
            // 1) 均线维度 (0~30)
            if (ma5 > ma20 && ma20 > ma60)
                score_ma <= 8'd30;
            else if (ma5 > ma20 && ma20 < ma60)
                score_ma <= 8'd20;
            else if (ma5 > ma20)
                score_ma <= 8'd15;
            else if (ma5 < ma20 && ma20 > ma60)
                score_ma <= 8'd10;
            else
                score_ma <= 8'd5;

            // 2) RSI 维度 (5~25)
            if (rsi >= 32'h001E_0000 && rsi <= 32'h0046_0000)
                score_rsi <= 8'd25;
            else if (rsi < 32'h001E_0000)
                score_rsi <= 8'd18;
            else
                score_rsi <= 8'd8;

            // 3) MACD 维度 (0~25)
            if (dif > dea && dif_prev <= dea_prev)
                score_macd <= 8'd25;
            else if (dif < dea && dif_prev >= dea_prev)
                score_macd <= 8'd5;
            else if (dif > dea)
                score_macd <= 8'd18;
            else
                score_macd <= 8'd10;

            // 4) 成交量维度 (5~20)
            if (vol_ratio > 32'h0002_0000)
                score_vol <= 8'd20;
            else if (vol_ratio > 32'h0001_8000)
                score_vol <= 8'd15;
            else if (vol_ratio > 32'h0001_0000)
                score_vol <= 8'd10;
            else
                score_vol <= 8'd5;

            // 当拍先组合求和，再用于输出与阈值判定，避免决策滞后一拍。
            score_total = score_ma + score_rsi + score_macd + score_vol;
            score <= score_total[7:0];

            // 五档决策（使用可配置阈值）
            if (score_total >= thresh_strong_buy)
                decision <= 3'd4;
            else if (score_total >= thresh_buy)
                decision <= 3'd3;
            else if (score_total >= thresh_neutral)
                decision <= 3'd2;
            else if (score_total >= thresh_sell)
                decision <= 3'd1;
            else
                decision <= 3'd0;

            score_valid <= 1'b1;
        end
    end
end

endmodule
