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
reg [63:0] avg_gain;
reg [63:0] avg_loss;
reg [5:0]  sample_cnt;

wire signed [32:0] delta = $signed({1'b0, close}) - $signed({1'b0, prev_close});
wire [32:0] delta_abs = (delta < 0) ? -delta : delta;
wire [31:0] gain = (delta > 0) ? delta[31:0] : 32'd0;
wire [31:0] loss = (delta < 0) ? delta_abs[31:0] : 32'd0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        prev_close <= 32'd0;
        has_prev <= 1'b0;
        avg_gain <= 64'd0;
        avg_loss <= 64'd0;
        sample_cnt <= 6'd0;
        rsi <= 32'd0;
        valid_out <= 1'b0;
    end else begin
        valid_out <= 1'b0;
        if (valid_in) begin
            if (has_prev) begin
                if (sample_cnt < 6'd14) begin
                    avg_gain <= avg_gain + gain;
                    avg_loss <= avg_loss + loss;
                    sample_cnt <= sample_cnt + 6'd1;
                end else begin
                    avg_gain <= ((avg_gain * 64'd13) + gain) / 64'd14;
                    avg_loss <= ((avg_loss * 64'd13) + loss) / 64'd14;
                end

                if ((avg_gain + avg_loss) != 64'd0) begin
                    rsi <= (((avg_gain * 64'd100) / (avg_gain + avg_loss)) << 16);
                end else begin
                    rsi <= 32'd0;
                end
            end

            prev_close <= close;
            has_prev <= 1'b1;
            valid_out <= 1'b1;
        end
    end
end

endmodule
