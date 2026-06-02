`timescale 1ns/1ps

module vol_ratio_calc (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] volume,
    input  wire        valid_in,
    output reg  [31:0] vol_ratio,
    output reg         valid_out
);

reg [31:0] vol_hist [0:4];
reg [2:0]  sample_cnt;
reg [63:0] sum5;
reg [63:0] sum5_next;
reg [63:0] lhs_5x;
reg [63:0] lhs_10x;
reg [63:0] rhs_2x;
reg [63:0] rhs_3x;
integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < 5; i = i + 1) begin
            vol_hist[i] <= 32'd0;
        end
        sample_cnt <= 3'd0;
        sum5 <= 64'd0;
        vol_ratio <= 32'h0001_0000;
        valid_out <= 1'b0;
    end else begin
        valid_out <= 1'b0;
        if (valid_in) begin
            sum5_next = volume;
            for (i = 0; i < 4; i = i + 1) begin
                if (sample_cnt > i) begin
                    sum5_next = sum5_next + vol_hist[i];
                end
            end

            sum5 <= sum5_next;

            for (i = 4; i > 0; i = i - 1) begin
                vol_hist[i] <= vol_hist[i - 1];
            end
            vol_hist[0] <= volume;

            if (sample_cnt != 3'd7) begin
                sample_cnt <= sample_cnt + 3'd1;
            end

            if (sample_cnt >= 3'd4 && sum5_next != 64'd0) begin
                // 去除运行时除法：只保留评分所需阈值（1.0x / 1.5x / 2.0x）比较。
                // vol_ratio > 2.0  <=> 5*volume > 2*sum5
                // vol_ratio > 1.5 <=> 10*volume > 3*sum5
                // vol_ratio > 1.0 <=> 5*volume > sum5
                lhs_5x  = ({32'd0, volume} << 2) + {32'd0, volume};
                lhs_10x = ({32'd0, volume} << 3) + ({32'd0, volume} << 1);
                rhs_2x  = (sum5_next << 1);
                rhs_3x  = sum5_next + (sum5_next << 1);

                if (lhs_5x > rhs_2x) begin
                    vol_ratio <= 32'h0002_0001;
                end else if (lhs_10x > rhs_3x) begin
                    vol_ratio <= 32'h0001_8001;
                end else if (lhs_5x > sum5_next) begin
                    vol_ratio <= 32'h0001_0001;
                end else begin
                    vol_ratio <= 32'h0000_FFFF;
                end
            end else begin
                vol_ratio <= 32'h0001_0000;
            end

            valid_out <= 1'b1;
        end
    end
end

endmodule
