`timescale 1ns/1ps

module ma_calc (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] close,
    input  wire        valid_in,
    output reg  [31:0] ma5,
    output reg  [31:0] ma20,
    output reg  [31:0] ma60,
    output reg         valid_out
);

reg [31:0] close_hist [0:59];
reg [5:0]  sample_cnt;
reg [63:0] sum5;
reg [63:0] sum20;
reg [63:0] sum60;
reg [63:0] sum5_next;
reg [63:0] sum20_next;
reg [63:0] sum60_next;
integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < 60; i = i + 1) begin
            close_hist[i] <= 32'd0;
        end
        sample_cnt <= 6'd0;
        sum5 <= 64'd0;
        sum20 <= 64'd0;
        sum60 <= 64'd0;
        ma5 <= 32'd0;
        ma20 <= 32'd0;
        ma60 <= 32'd0;
        valid_out <= 1'b0;
    end else begin
        valid_out <= 1'b0;

        if (valid_in) begin
            // 运行和更新，替代大规模历史重求和，降低组合深度。
            sum5_next  = sum5 + {32'd0, close};
            sum20_next = sum20 + {32'd0, close};
            sum60_next = sum60 + {32'd0, close};

            if (sample_cnt >= 6'd5) begin
                sum5_next = sum5_next - {32'd0, close_hist[4]};
            end
            if (sample_cnt >= 6'd20) begin
                sum20_next = sum20_next - {32'd0, close_hist[19]};
            end
            if (sample_cnt >= 6'd60) begin
                sum60_next = sum60_next - {32'd0, close_hist[59]};
            end

            sum5  <= sum5_next;
            sum20 <= sum20_next;
            sum60 <= sum60_next;

            for (i = 59; i > 0; i = i - 1) begin
                close_hist[i] <= close_hist[i - 1];
            end
            close_hist[0] <= close;

            if (sample_cnt != 6'd63) begin
                sample_cnt <= sample_cnt + 6'd1;
            end

            if (sample_cnt >= 6'd4) begin
                ma5 <= sum5_next / 32'd5;
            end else begin
                ma5 <= close;
            end

            if (sample_cnt >= 6'd19) begin
                ma20 <= sum20_next / 32'd20;
            end else begin
                ma20 <= close;
            end

            if (sample_cnt >= 6'd59) begin
                ma60 <= sum60_next / 32'd60;
            end else begin
                ma60 <= close;
            end

            valid_out <= 1'b1;
        end
    end
end

endmodule
