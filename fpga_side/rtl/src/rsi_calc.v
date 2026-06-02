`timescale 1ns/1ps

module rsi_calc (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] close,
    input  wire        valid_in,
    output reg  [31:0] rsi,
    output reg         valid_out
);

reg [31:0] prev_close;
reg        has_prev;
reg [31:0] avg_gain;
reg [31:0] avg_loss;
reg [5:0]  sample_cnt;

reg        ratio_stage1_valid;
reg [31:0] ratio_stage1_gain;
reg [31:0] ratio_stage1_loss;

reg        ratio_stage2_valid;
reg [31:0] ratio_stage2_gain;
reg [31:0] ratio_stage2_loss;

wire signed [32:0] delta = $signed({1'b0, close}) - $signed({1'b0, prev_close});
wire [32:0] delta_abs = (delta < 0) ? -delta : delta;
wire [31:0] gain = (delta > 0) ? delta[31:0] : 32'd0;
wire [31:0] loss = (delta < 0) ? delta_abs[31:0] : 32'd0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        prev_close <= 32'd0;
        has_prev <= 1'b0;
        avg_gain <= 32'd0;
        avg_loss <= 32'd0;
        sample_cnt <= 6'd0;
        ratio_stage1_valid <= 1'b0;
        ratio_stage1_gain  <= 32'd0;
        ratio_stage1_loss  <= 32'd0;
        ratio_stage2_valid <= 1'b0;
        ratio_stage2_gain  <= 32'd0;
        ratio_stage2_loss  <= 32'd0;
        rsi <= 32'd0;
        valid_out <= 1'b0;
    end else begin
        valid_out <= 1'b0;

        ratio_stage2_valid <= ratio_stage1_valid;
        ratio_stage2_gain  <= ratio_stage1_gain;
        ratio_stage2_loss  <= ratio_stage1_loss;

        if (ratio_stage2_valid) begin
            // Remove runtime divider by classifying RSI with equivalent inequalities:
            // RSI < 30  <=> 7*gain < 3*loss
            // RSI <= 70 <=> 3*gain <= 7*loss
            // This preserves score_calc thresholds while shortening the critical path.
            if ((ratio_stage2_gain == 32'd0) && (ratio_stage2_loss == 32'd0)) begin
                rsi <= 32'h0032_0000; // 50.0 in Q16.16
            end else if ((({3'd0, ratio_stage2_gain} << 3) - {3'd0, ratio_stage2_gain}) <
                         (({3'd0, ratio_stage2_loss} << 1) + {3'd0, ratio_stage2_loss})) begin
                rsi <= 32'h0014_0000; // 20.0 in Q16.16
            end else if ((({3'd0, ratio_stage2_gain} << 1) + {3'd0, ratio_stage2_gain}) <=
                         (({3'd0, ratio_stage2_loss} << 3) - {3'd0, ratio_stage2_loss})) begin
                rsi <= 32'h0032_0000; // 50.0 in Q16.16
            end else begin
                rsi <= 32'h0050_0000; // 80.0 in Q16.16
            end
            valid_out <= 1'b1;
        end

        ratio_stage1_valid <= 1'b0;

        if (valid_in) begin
            if (has_prev) begin
                if (sample_cnt < 6'd14) begin
                    avg_gain <= avg_gain + gain;
                    avg_loss <= avg_loss + loss;
                    sample_cnt <= sample_cnt + 6'd1;
                    ratio_stage1_gain <= avg_gain + gain;
                    ratio_stage1_loss <= avg_loss + loss;
                end else begin
                    // EMA-like update with alpha=1/16 to avoid deep divider logic.
                    avg_gain <= avg_gain - (avg_gain >> 4) + (gain >> 4);
                    avg_loss <= avg_loss - (avg_loss >> 4) + (loss >> 4);
                    ratio_stage1_gain <= avg_gain - (avg_gain >> 4) + (gain >> 4);
                    ratio_stage1_loss <= avg_loss - (avg_loss >> 4) + (loss >> 4);
                end
                ratio_stage1_valid <= 1'b1;
            end

            prev_close <= close;
            has_prev <= 1'b1;
        end
    end
end

endmodule
