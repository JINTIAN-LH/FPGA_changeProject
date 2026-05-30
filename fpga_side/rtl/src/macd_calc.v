`timescale 1ns/1ps

module macd_calc (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] close,
    input  wire        valid_in,
    output reg  [31:0] dif,
    output reg  [31:0] dea,
    output reg         valid_out
);

reg [31:0] ema_fast;
reg [31:0] ema_slow;
reg [5:0]  sample_cnt;

wire [63:0] fast_num = (64'd11 * ema_fast) + (64'd2 * close);
wire [63:0] slow_num = (64'd25 * ema_slow) + (64'd2 * close);
wire [63:0] dea_num  = (64'd8 * dea) + (64'd2 * dif);
wire [31:0] fast_next = fast_num / 64'd13;
wire [31:0] slow_next = slow_num / 64'd27;
wire [31:0] dea_next  = dea_num / 64'd10;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ema_fast <= 32'd0;
        ema_slow <= 32'd0;
        dif <= 32'd0;
        dea <= 32'd0;
        sample_cnt <= 6'd0;
        valid_out <= 1'b0;
    end else begin
        valid_out <= 1'b0;
        if (valid_in) begin
            if (sample_cnt == 6'd0) begin
                ema_fast <= close;
                ema_slow <= close;
                dif <= 32'd0;
                dea <= 32'd0;
            end else begin
                ema_fast <= fast_next;
                ema_slow <= slow_next;
                dif <= fast_next - slow_next;
                dea <= dea_next;
            end

            if (sample_cnt != 6'd63) begin
                sample_cnt <= sample_cnt + 6'd1;
            end
            valid_out <= 1'b1;
        end
    end
end

endmodule
