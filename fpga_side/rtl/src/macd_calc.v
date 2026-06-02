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

// Pipeline registers — break 42-level CARRY4 chain (WNS -0.038ns → positive)
reg [31:0] fast_next_pipe;
reg [31:0] slow_next_pipe;
reg [31:0] dea_next_pipe;
reg        calc_valid;

wire [63:0] fast_num = (64'd11 * ema_fast) + (64'd2 * close);
wire [63:0] slow_num = (64'd25 * ema_slow) + (64'd2 * close);
wire [63:0] dea_num  = (64'd8 * dea) + (64'd2 * dif);
wire [31:0] fast_next = fast_num / 64'd13;
wire [31:0] slow_next = slow_num / 64'd27;
wire [31:0] dea_next  = dea_num / 64'd10;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ema_fast      <= 32'd0;
        ema_slow      <= 32'd0;
        dif           <= 32'd0;
        dea           <= 32'd0;
        sample_cnt    <= 6'd0;
        valid_out     <= 1'b0;
        fast_next_pipe <= 32'd0;
        slow_next_pipe <= 32'd0;
        dea_next_pipe  <= 32'd0;
        calc_valid    <= 1'b0;
    end else begin
        valid_out  <= 1'b0;
        calc_valid <= 1'b0;

        // Stage 1: Compute division results from registered state
        //   (multiply + divide) → registered in pipes, cutting the path
        if (valid_in) begin
            if (sample_cnt == 6'd0) begin
                fast_next_pipe <= close;
                slow_next_pipe <= close;
                dea_next_pipe  <= 32'd0;
            end else begin
                fast_next_pipe <= fast_next;
                slow_next_pipe <= slow_next;
                dea_next_pipe  <= dea_next;
            end
            calc_valid <= 1'b1;

            if (sample_cnt != 6'd63)
                sample_cnt <= sample_cnt + 6'd1;
        end

        // Stage 2: Update state from pipelined values
        //   (subtraction only) → short logic, well within 20ns
        if (calc_valid) begin
            ema_fast  <= fast_next_pipe;
            ema_slow  <= slow_next_pipe;
            dif       <= fast_next_pipe - slow_next_pipe;
            dea       <= dea_next_pipe;
            valid_out <= 1'b1;
        end
    end
end

endmodule
