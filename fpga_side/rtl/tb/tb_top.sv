`timescale 1ns/1ps

module tb_top;

reg         sys_clk_50m;
reg         sys_rst_n;
reg         price_valid;
reg  [31:0] open_price;
reg  [31:0] high_price;
reg  [31:0] low_price;
reg  [31:0] close_price;
reg  [31:0] volume;
reg  [7:0]  cfg_strong_buy;
reg  [7:0]  cfg_buy;
reg  [7:0]  cfg_neutral;
reg  [7:0]  cfg_sell;
reg         cfg_valid;
reg         tx_ready;

wire [7:0]  tx_data;
wire        tx_valid;
wire        tx_last;
wire        heartbeat;
wire [7:0]  score_debug;
wire [2:0]  decision_debug;
wire        result_valid_debug;
wire [31:0] ma5_debug;
wire [31:0] ma20_debug;
wire [31:0] ma60_debug;
wire [31:0] rsi_debug;
wire [31:0] macd_dif_debug;
wire [31:0] macd_dea_debug;
wire [31:0] boll_upper_debug;
wire [31:0] boll_lower_debug;
wire [31:0] atr_debug;
wire [31:0] vol_ratio_debug;

top dut (
    .sys_clk_50m       (sys_clk_50m),
    .sys_rst_n         (sys_rst_n),
    .price_valid       (price_valid),
    .open_price        (open_price),
    .high_price        (high_price),
    .low_price         (low_price),
    .close_price       (close_price),
    .volume            (volume),
    .cfg_strong_buy    (cfg_strong_buy),
    .cfg_buy           (cfg_buy),
    .cfg_neutral       (cfg_neutral),
    .cfg_sell          (cfg_sell),
    .cfg_valid         (cfg_valid),
    .m1_rx_valid       (1'b0),
    .m1_rx_data        (8'h00),
    .m1_rx_last        (1'b0),
    .m1_tx_ready       (1'b1),
    .m1_tx_data        (),
    .m1_tx_valid       (),
    .m1_tx_last        (),
    .m1_frame_accepted (),
    .m1_frame_rejected (),
    .m1_frame_reject_reason(),
    .tx_ready          (tx_ready),
    .tx_data           (tx_data),
    .tx_valid          (tx_valid),
    .tx_last           (tx_last),
    .heartbeat         (heartbeat),
    .score_debug       (score_debug),
    .decision_debug    (decision_debug),
    .result_valid_debug(result_valid_debug),
    .ma5_debug         (ma5_debug),
    .ma20_debug        (ma20_debug),
    .ma60_debug        (ma60_debug),
    .rsi_debug         (rsi_debug),
    .macd_dif_debug    (macd_dif_debug),
    .macd_dea_debug    (macd_dea_debug),
    .boll_upper_debug  (boll_upper_debug),
    .boll_lower_debug  (boll_lower_debug),
    .atr_debug         (atr_debug),
    .vol_ratio_debug   (vol_ratio_debug)
);

initial sys_clk_50m = 1'b0;
always #10 sys_clk_50m = ~sys_clk_50m;

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
        @(posedge sys_clk_50m);
        price_valid = 1'b0;
        @(posedge sys_clk_50m);
    end
endtask

initial begin
    sys_rst_n = 1'b0;
    price_valid = 1'b0;
    cfg_valid = 1'b0;
    tx_ready = 1'b1;
    cfg_strong_buy = 8'd75;
    cfg_buy = 8'd60;
    cfg_neutral = 8'd45;
    cfg_sell = 8'd25;
    open_price = 32'd0;
    high_price = 32'd0;
    low_price = 32'd0;
    close_price = 32'd0;
    volume = 32'd0;

    #100;
    sys_rst_n = 1'b1;

    drive_bar(32'h000E_F000, 32'h000F_8000, 32'h000E_A000, 32'h000F_0000, 32'h0001_2000);
    drive_bar(32'h000F_0000, 32'h0010_0000, 32'h000E_F000, 32'h000F_8000, 32'h0001_5000);
    drive_bar(32'h000F_8000, 32'h0010_8000, 32'h000F_4000, 32'h0010_0000, 32'h0001_8000);
    drive_bar(32'h0010_0000, 32'h0011_0000, 32'h000F_C000, 32'h0010_8000, 32'h0001_A000);
    drive_bar(32'h0010_8000, 32'h0011_8000, 32'h0010_0000, 32'h0011_0000, 32'h0001_F000);
    drive_bar(32'h0011_0000, 32'h0012_0000, 32'h0010_8000, 32'h0011_8000, 32'h0002_2000);

    #100;
    $display("[tb_top] heartbeat=%0d score=%0d decision=%0d result_valid=%0d tx_valid=%0d tx_last=%0d", heartbeat, score_debug, decision_debug, result_valid_debug, tx_valid, tx_last);
    $display("[tb_top] ma5=%h ma20=%h ma60=%h rsi=%h dif=%h dea=%h vol_ratio=%h", ma5_debug, ma20_debug, ma60_debug, rsi_debug, macd_dif_debug, macd_dea_debug, vol_ratio_debug);

    #100;
    $finish;
end

endmodule
