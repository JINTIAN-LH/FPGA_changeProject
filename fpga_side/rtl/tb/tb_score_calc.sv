`timescale 1ns/1ps

module tb_score_calc;

reg         clk;
reg         rst_n;
reg  [31:0] ma5, ma20, ma60, rsi, dif, dea, vol_ratio;
reg  [31:0] dif_prev, dea_prev;
reg         data_valid;
reg  [7:0]  cfg_strong_buy, cfg_buy, cfg_neutral, cfg_sell;
reg         cfg_valid;

wire [7:0]  score;
wire [2:0]  decision;
wire        score_valid;

score_calc uut (
    .clk(clk),
    .rst_n(rst_n),
    .ma5(ma5),
    .ma20(ma20),
    .ma60(ma60),
    .rsi(rsi),
    .dif(dif),
    .dea(dea),
    .dif_prev(dif_prev),
    .dea_prev(dea_prev),
    .vol_ratio(vol_ratio),
    .data_valid(data_valid),
    .cfg_strong_buy(cfg_strong_buy),
    .cfg_buy(cfg_buy),
    .cfg_neutral(cfg_neutral),
    .cfg_sell(cfg_sell),
    .cfg_valid(cfg_valid),
    .score(score),
    .decision(decision),
    .score_valid(score_valid)
);

initial clk = 1'b0;
always #5 clk = ~clk;

initial begin
    rst_n = 1'b0;
    data_valid = 1'b0;
    cfg_valid = 1'b0;

    cfg_strong_buy = 8'd75;
    cfg_buy        = 8'd60;
    cfg_neutral    = 8'd45;
    cfg_sell       = 8'd25;

    ma5 = 32'd0;
    ma20 = 32'd0;
    ma60 = 32'd0;
    rsi = 32'd0;
    dif = 32'd0;
    dea = 32'd0;
    dif_prev = 32'd0;
    dea_prev = 32'd0;
    vol_ratio = 32'd0;

    #100;
    rst_n = 1'b1;

    // 测试用例：强势多头 + 金叉 + 放量
    #20;
    ma5       = 32'h000F_0000;
    ma20      = 32'h000E_0000;
    ma60      = 32'h000D_0000;
    rsi       = 32'h0032_0000;
    dif       = 32'h0001_0000;
    dea       = 32'h0000_8000;
    dif_prev  = 32'h0000_7000;
    dea_prev  = 32'h0000_9000;
    vol_ratio = 32'h0001_8000;

    data_valid = 1'b1;
    #10;
    data_valid = 1'b0;

    #100;
    $display("[tb_score_calc] score=%0d decision=%0d valid=%0d", score, decision, score_valid);

    #200;
    $finish;
end

endmodule
