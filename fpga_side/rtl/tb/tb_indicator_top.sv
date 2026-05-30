`timescale 1ns/1ps

module tb_indicator_top;

reg         clk;
reg         rst_n;
reg         price_valid;
reg  [31:0] open_price, high_price, low_price, close_price, volume;
reg  [7:0]  cfg_strong_buy, cfg_buy, cfg_neutral, cfg_sell;
reg         cfg_valid;

wire [7:0]  score;
wire [2:0]  decision;
wire        result_valid;
wire [31:0] ma5, ma20, ma60, rsi, macd_dif, macd_dea, boll_upper, boll_lower, atr, vol_ratio;

indicator_top dut (
    .clk           (clk),
    .rst_n         (rst_n),
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

initial clk = 1'b0;
always #5 clk = ~clk;

task drive_bar;
    input [31:0] open_i;
    input [31:0] high_i;
    input [31:0] low_i;
    input [31:0] close_i;
    input [31:0] volume_i;
    begin
        open_price = open_i;
        high_price = high_i;
        low_price = low_i;
        close_price = close_i;
        volume = volume_i;
        price_valid = 1'b1;
        @(posedge clk);
        price_valid = 1'b0;
        @(posedge clk);
    end
endtask

initial begin
    rst_n = 1'b0;
    price_valid = 1'b0;
    cfg_valid = 1'b0;

    cfg_strong_buy = 8'd75;
    cfg_buy        = 8'd60;
    cfg_neutral    = 8'd45;
    cfg_sell       = 8'd25;

    open_price = 32'd0;
    high_price = 32'd0;
    low_price = 32'd0;
    close_price = 32'd0;
    volume = 32'd0;

    #100;
    rst_n = 1'b1;

    drive_bar(32'h000E_F000, 32'h000F_8000, 32'h000E_A000, 32'h000F_0000, 32'h0001_2000);
    drive_bar(32'h000F_0000, 32'h0010_0000, 32'h000E_F000, 32'h000F_8000, 32'h0001_5000);
    drive_bar(32'h000F_8000, 32'h0010_8000, 32'h000F_4000, 32'h0010_0000, 32'h0001_8000);
    drive_bar(32'h0010_0000, 32'h0011_0000, 32'h000F_C000, 32'h0010_8000, 32'h0001_A000);
    drive_bar(32'h0010_8000, 32'h0011_8000, 32'h0010_0000, 32'h0011_0000, 32'h0001_F000);
    drive_bar(32'h0011_0000, 32'h0012_0000, 32'h0010_8000, 32'h0011_8000, 32'h0002_2000);

    #50;
    $display("[tb_indicator_top] score=%0d decision=%0d result_valid=%0d ma5=%h ma20=%h ma60=%h rsi=%h macd_dif=%h macd_dea=%h vol_ratio=%h", score, decision, result_valid, ma5, ma20, ma60, rsi, macd_dif, macd_dea, vol_ratio);

    #100;
    $finish;
end

endmodule
