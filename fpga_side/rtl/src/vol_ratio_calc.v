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
            sum5 = volume;
            for (i = 0; i < 4; i = i + 1) begin
                if (sample_cnt > i) begin
                    sum5 = sum5 + vol_hist[i];
                end
            end

            for (i = 4; i > 0; i = i - 1) begin
                vol_hist[i] <= vol_hist[i - 1];
            end
            vol_hist[0] <= volume;

            if (sample_cnt != 3'd7) begin
                sample_cnt <= sample_cnt + 3'd1;
            end

            if (sample_cnt >= 3'd4 && sum5 != 64'd0) begin
                vol_ratio <= (volume << 16) / (sum5 / 64'd5);
            end else begin
                vol_ratio <= 32'h0001_0000;
            end

            valid_out <= 1'b1;
        end
    end
end

endmodule
