`timescale 1ns/1ps

module udp_result_tx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tx_start,
    input  wire [7:0]  score,
    input  wire [2:0]  decision,
    input  wire [31:0] ma5,
    input  wire [31:0] ma20,
    input  wire [31:0] ma60,
    input  wire [31:0] rsi,
    input  wire [31:0] dif,
    input  wire [31:0] dea,
    input  wire [31:0] boll_upper,
    input  wire [31:0] boll_lower,
    input  wire [31:0] atr,
    input  wire [31:0] vol_ratio,
    input  wire [7:0]  status_word,
    input  wire [15:0] error_cnt,
    output reg  [7:0]  tx_data,
    output reg         tx_valid,
    output reg         tx_last,
    input  wire        tx_ready
);

localparam [3:0] IDLE = 4'd0;
localparam [3:0] ETH_HDR = 4'd1;
localparam [3:0] IP_HDR = 4'd2;
localparam [3:0] UDP_HDR = 4'd3;
localparam [3:0] PAYLOAD = 4'd4;

reg [3:0] state;
reg [7:0] byte_cnt;
reg [7:0] payload [0:43];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        payload[0]  <= 8'd0;
        payload[1]  <= 8'd0;
        payload[2]  <= 8'd0;
        payload[3]  <= 8'd0;
        payload[4]  <= 8'd0;
        payload[5]  <= 8'd0;
        payload[6]  <= 8'd0;
        payload[7]  <= 8'd0;
        payload[8]  <= 8'd0;
        payload[9]  <= 8'd0;
        payload[10] <= 8'd0;
        payload[11] <= 8'd0;
        payload[12] <= 8'd0;
        payload[13] <= 8'd0;
        payload[14] <= 8'd0;
        payload[15] <= 8'd0;
        payload[16] <= 8'd0;
        payload[17] <= 8'd0;
        payload[18] <= 8'd0;
        payload[19] <= 8'd0;
        payload[20] <= 8'd0;
        payload[21] <= 8'd0;
        payload[22] <= 8'd0;
        payload[23] <= 8'd0;
        payload[24] <= 8'd0;
        payload[25] <= 8'd0;
        payload[26] <= 8'd0;
        payload[27] <= 8'd0;
        payload[28] <= 8'd0;
        payload[29] <= 8'd0;
        payload[30] <= 8'd0;
        payload[31] <= 8'd0;
        payload[32] <= 8'd0;
        payload[33] <= 8'd0;
        payload[34] <= 8'd0;
        payload[35] <= 8'd0;
        payload[36] <= 8'd0;
        payload[37] <= 8'd0;
        payload[38] <= 8'd0;
        payload[39] <= 8'd0;
        payload[40] <= 8'd0;
        payload[41] <= 8'd0;
        payload[42] <= 8'd0;
        payload[43] <= 8'd0;
        state <= IDLE;
        byte_cnt <= 8'd0;
        tx_data <= 8'd0;
        tx_valid <= 1'b0;
        tx_last <= 1'b0;
    end else begin
        tx_valid <= 1'b0;
        tx_last <= 1'b0;

        if (tx_start) begin
            payload[0]  <= score;
            payload[1]  <= {5'd0, decision};
            payload[2]  <= status_word;
            payload[3]  <= error_cnt[15:8];
            payload[4]  <= ma5[31:24];
            payload[5]  <= ma5[23:16];
            payload[6]  <= ma5[15:8];
            payload[7]  <= ma5[7:0];
            payload[8]  <= ma20[31:24];
            payload[9]  <= ma20[23:16];
            payload[10] <= ma20[15:8];
            payload[11] <= ma20[7:0];
            payload[12] <= ma60[31:24];
            payload[13] <= ma60[23:16];
            payload[14] <= ma60[15:8];
            payload[15] <= ma60[7:0];
            payload[16] <= rsi[31:24];
            payload[17] <= rsi[23:16];
            payload[18] <= rsi[15:8];
            payload[19] <= rsi[7:0];
            payload[20] <= dif[31:24];
            payload[21] <= dif[23:16];
            payload[22] <= dif[15:8];
            payload[23] <= dif[7:0];
            payload[24] <= dea[31:24];
            payload[25] <= dea[23:16];
            payload[26] <= dea[15:8];
            payload[27] <= dea[7:0];
            payload[28] <= boll_upper[31:24];
            payload[29] <= boll_upper[23:16];
            payload[30] <= boll_upper[15:8];
            payload[31] <= boll_upper[7:0];
            payload[32] <= boll_lower[31:24];
            payload[33] <= boll_lower[23:16];
            payload[34] <= boll_lower[15:8];
            payload[35] <= boll_lower[7:0];
            payload[36] <= atr[31:24];
            payload[37] <= atr[23:16];
            payload[38] <= atr[15:8];
            payload[39] <= atr[7:0];
            payload[40] <= vol_ratio[31:24];
            payload[41] <= vol_ratio[23:16];
            payload[42] <= vol_ratio[15:8];
            payload[43] <= vol_ratio[7:0];
        end

        case (state)
            IDLE: begin
                if (tx_start && tx_ready) begin
                    state <= ETH_HDR;
                    byte_cnt <= 8'd0;
                end
            end
            ETH_HDR: begin
                if (tx_ready) begin
                    tx_data <= 8'hAA;
                    tx_valid <= 1'b1;
                    if (byte_cnt == 8'd13) begin
                        state <= IP_HDR;
                        byte_cnt <= 8'd0;
                    end else begin
                        byte_cnt <= byte_cnt + 8'd1;
                    end
                end
            end
            IP_HDR: begin
                if (tx_ready) begin
                    tx_data <= 8'h45;
                    tx_valid <= 1'b1;
                    if (byte_cnt == 8'd19) begin
                        state <= UDP_HDR;
                        byte_cnt <= 8'd0;
                    end else begin
                        byte_cnt <= byte_cnt + 8'd1;
                    end
                end
            end
            UDP_HDR: begin
                if (tx_ready) begin
                    tx_data <= 8'h11;
                    tx_valid <= 1'b1;
                    if (byte_cnt == 8'd7) begin
                        state <= PAYLOAD;
                        byte_cnt <= 8'd0;
                    end else begin
                        byte_cnt <= byte_cnt + 8'd1;
                    end
                end
            end
            PAYLOAD: begin
                if (tx_ready) begin
                    tx_data <= payload[byte_cnt];
                    tx_valid <= 1'b1;
                    if (byte_cnt == 8'd43) begin
                        tx_last <= 1'b1;
                        state <= IDLE;
                        byte_cnt <= 8'd0;
                    end else begin
                        byte_cnt <= byte_cnt + 8'd1;
                    end
                end
            end
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule
