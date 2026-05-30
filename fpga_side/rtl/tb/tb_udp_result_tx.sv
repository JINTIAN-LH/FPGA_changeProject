`timescale 1ns/1ps

module tb_udp_result_tx;

reg         clk;
reg         rst_n;
reg         tx_start;
reg  [7:0]  score;
reg  [2:0]  decision;
reg  [31:0] ma5, ma20, ma60, rsi, dif, dea, boll_upper, boll_lower, atr, vol_ratio;
reg  [7:0]  status_word;
reg  [15:0] error_cnt;
wire [7:0]  tx_data;
wire        tx_valid;
wire        tx_last;

udp_result_tx dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .tx_start   (tx_start),
    .score      (score),
    .decision   (decision),
    .ma5        (ma5),
    .ma20       (ma20),
    .ma60       (ma60),
    .rsi        (rsi),
    .dif        (dif),
    .dea        (dea),
    .boll_upper (boll_upper),
    .boll_lower (boll_lower),
    .atr        (atr),
    .vol_ratio  (vol_ratio),
    .status_word(status_word),
    .error_cnt  (error_cnt),
    .tx_data    (tx_data),
    .tx_valid   (tx_valid),
    .tx_last    (tx_last),
    .tx_ready   (1'b1)
);

initial clk = 1'b0;
always #5 clk = ~clk;

integer valid_bytes;

initial begin
    rst_n = 1'b0;
    tx_start = 1'b0;
    valid_bytes = 0;

    score = 8'd88;
    decision = 3'd4;
    ma5 = 32'h000F_0000;
    ma20 = 32'h000E_0000;
    ma60 = 32'h000D_0000;
    rsi = 32'h0032_0000;
    dif = 32'h0001_0000;
    dea = 32'h0000_8000;
    boll_upper = 32'h0010_0000;
    boll_lower = 32'h000E_0000;
    atr = 32'h0000_2000;
    vol_ratio = 32'h0001_8000;
    status_word = 8'hA5;
    error_cnt = 16'h0012;

    #100;
    rst_n = 1'b1;

    @(posedge clk);
    tx_start = 1'b1;
    @(posedge clk);
    tx_start = 1'b0;

    repeat (60) begin
        @(posedge clk);
        if (tx_valid) begin
            valid_bytes = valid_bytes + 1;
        end
    end

    $display("[tb_udp_result_tx] valid_bytes=%0d tx_last=%0d", valid_bytes, tx_last);
    $finish;
end

endmodule
