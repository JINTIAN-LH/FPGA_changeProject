`timescale 1ns/1ps

module m1_protocol_core #(
    parameter [31:0] MA5_PLACEHOLDER             = 32'h00000000,
    parameter [31:0] MA10_PLACEHOLDER            = 32'h00000000,
    parameter [31:0] RSI_PLACEHOLDER             = 32'h00000000,
    parameter [7:0]  TRADE_SIGNAL_PLACEHOLDER    = 8'd0,
    parameter [7:0]  SIGNAL_STRENGTH_PLACEHOLDER = 8'd0
) (
    input  wire       clk,
    input  wire       rst_n,

    input  wire       rx_valid,
    input  wire [7:0] rx_data,
    input  wire       rx_last,

    input  wire       tx_ready,
    input  wire       indicator_valid,
    input  wire [31:0] ma5_value,
    input  wire [31:0] ma10_value,
    input  wire [31:0] rsi6_value,
    input  wire [31:0] rsi14_value,
    input  wire [7:0] trade_signal_value,
    input  wire [7:0] signal_strength_value,
    output reg        tx_valid,
    output reg  [7:0] tx_data,
    output reg        tx_last,

    output reg        frame_accepted,
    output reg        frame_rejected,
    output reg  [2:0] frame_reject_reason
);

localparam integer UP_LEN   = 48;
localparam integer DOWN_LEN = 44;

localparam [2:0] REJ_NONE   = 3'd0;
localparam [2:0] REJ_HEADER = 3'd1;
localparam [2:0] REJ_LENGTH = 3'd2;
localparam [2:0] REJ_CRC    = 3'd3;
localparam [2:0] REJ_SIZE   = 3'd4;

reg [7:0] up_buf [0:UP_LEN-1];
reg [7:0] dn_buf [0:DOWN_LEN-1];

reg [5:0] rx_idx;
reg       rx_active;

reg       tx_active;
reg [5:0] tx_idx;

integer i;
reg [31:0] crc_tmp;
reg [31:0] crc_rx;
reg [31:0] crc_dn;

function [31:0] crc32_byte;
    input [31:0] crc_in;
    input [7:0]  data_in;
    reg [31:0] c;
    reg [7:0]  d;
    integer k;
begin
    c = crc_in;
    d = data_in;
    for (k = 0; k < 8; k = k + 1) begin
        if ((c[0] ^ d[0]) == 1'b1) begin
            c = (c >> 1) ^ 32'hEDB88320;
        end else begin
            c = (c >> 1);
        end
        d = d >> 1;
    end
    crc32_byte = c;
end
endfunction

always @(posedge clk) begin
    if (!rst_n) begin
        rx_idx          <= 6'd0;
        rx_active       <= 1'b0;
        tx_active       <= 1'b0;
        tx_idx          <= 6'd0;
        tx_valid        <= 1'b0;
        tx_data         <= 8'h00;
        tx_last         <= 1'b0;
        frame_accepted  <= 1'b0;
        frame_rejected  <= 1'b0;
        frame_reject_reason <= REJ_NONE;
    end else begin
        frame_accepted <= 1'b0;
        frame_rejected <= 1'b0;

        tx_valid <= 1'b0;
        tx_last  <= 1'b0;

        if (tx_active && tx_ready) begin
            tx_valid <= 1'b1;
            tx_data  <= dn_buf[tx_idx];
            tx_last  <= (tx_idx == (DOWN_LEN - 1));

            if (tx_idx == (DOWN_LEN - 1)) begin
                tx_active <= 1'b0;
                tx_idx    <= 6'd0;
            end else begin
                tx_idx <= tx_idx + 6'd1;
            end
        end

        if (rx_valid) begin
            if (!rx_active) begin
                rx_active <= 1'b1;
                rx_idx    <= 6'd0;
            end

            up_buf[rx_idx] = rx_data;

            if (rx_last) begin
                if (rx_idx == (UP_LEN - 1)) begin
                    if ((up_buf[0] != 8'hAA) || (up_buf[1] != 8'h55)) begin
                        frame_rejected <= 1'b1;
                        frame_reject_reason <= REJ_HEADER;
                    end else if ((up_buf[2] != 8'h00) || (up_buf[3] != 8'h30)) begin
                        frame_rejected <= 1'b1;
                        frame_reject_reason <= REJ_LENGTH;
                    end else begin
                        crc_tmp = 32'hFFFFFFFF;
                        for (i = 0; i < 44; i = i + 1) begin
                            crc_tmp = crc32_byte(crc_tmp, up_buf[i]);
                        end
                        crc_tmp = ~crc_tmp;

                        crc_rx = {up_buf[44], up_buf[45], up_buf[46], up_buf[47]};

                        if (crc_tmp == crc_rx) begin
                            dn_buf[0]  = 8'h55;
                            dn_buf[1]  = 8'hAA;
                            dn_buf[2]  = 8'h00;
                            dn_buf[3]  = 8'h2C;

                            dn_buf[4]  = up_buf[4];
                            dn_buf[5]  = up_buf[5];
                            dn_buf[6]  = up_buf[6];
                            dn_buf[7]  = up_buf[7];
                            dn_buf[8]  = up_buf[8];
                            dn_buf[9]  = up_buf[9];
                            dn_buf[10] = up_buf[10];
                            dn_buf[11] = up_buf[11];

                            dn_buf[12] = up_buf[12];
                            dn_buf[13] = up_buf[13];
                            dn_buf[14] = up_buf[14];
                            dn_buf[15] = up_buf[15];

                            dn_buf[16] = indicator_valid ? ma5_value[31:24] : MA5_PLACEHOLDER[31:24];
                            dn_buf[17] = indicator_valid ? ma5_value[23:16] : MA5_PLACEHOLDER[23:16];
                            dn_buf[18] = indicator_valid ? ma5_value[15:8]  : MA5_PLACEHOLDER[15:8];
                            dn_buf[19] = indicator_valid ? ma5_value[7:0]   : MA5_PLACEHOLDER[7:0];

                            dn_buf[20] = indicator_valid ? ma10_value[31:24] : MA10_PLACEHOLDER[31:24];
                            dn_buf[21] = indicator_valid ? ma10_value[23:16] : MA10_PLACEHOLDER[23:16];
                            dn_buf[22] = indicator_valid ? ma10_value[15:8]  : MA10_PLACEHOLDER[15:8];
                            dn_buf[23] = indicator_valid ? ma10_value[7:0]   : MA10_PLACEHOLDER[7:0];

                            dn_buf[24] = indicator_valid ? rsi6_value[31:24] : RSI_PLACEHOLDER[31:24];
                            dn_buf[25] = indicator_valid ? rsi6_value[23:16] : RSI_PLACEHOLDER[23:16];
                            dn_buf[26] = indicator_valid ? rsi6_value[15:8]  : RSI_PLACEHOLDER[15:8];
                            dn_buf[27] = indicator_valid ? rsi6_value[7:0]   : RSI_PLACEHOLDER[7:0];

                            dn_buf[28] = indicator_valid ? rsi14_value[31:24] : RSI_PLACEHOLDER[31:24];
                            dn_buf[29] = indicator_valid ? rsi14_value[23:16] : RSI_PLACEHOLDER[23:16];
                            dn_buf[30] = indicator_valid ? rsi14_value[15:8]  : RSI_PLACEHOLDER[15:8];
                            dn_buf[31] = indicator_valid ? rsi14_value[7:0]   : RSI_PLACEHOLDER[7:0];

                            dn_buf[32] = indicator_valid ? trade_signal_value : TRADE_SIGNAL_PLACEHOLDER;
                            dn_buf[33] = indicator_valid ? signal_strength_value : SIGNAL_STRENGTH_PLACEHOLDER;

                            dn_buf[34] = 8'h00;
                            dn_buf[35] = 8'h00;
                            dn_buf[36] = 8'h00;
                            dn_buf[37] = 8'h00;
                            dn_buf[38] = 8'h00;
                            dn_buf[39] = 8'h00;

                            crc_dn = 32'hFFFFFFFF;
                            for (i = 0; i < 40; i = i + 1) begin
                                crc_dn = crc32_byte(crc_dn, dn_buf[i]);
                            end
                            crc_dn = ~crc_dn;

                            dn_buf[40] = crc_dn[31:24];
                            dn_buf[41] = crc_dn[23:16];
                            dn_buf[42] = crc_dn[15:8];
                            dn_buf[43] = crc_dn[7:0];

                            tx_active      <= 1'b1;
                            tx_idx         <= 6'd0;
                            frame_accepted <= 1'b1;
                            frame_reject_reason <= REJ_NONE;
                        end else begin
                            frame_rejected <= 1'b1;
                            frame_reject_reason <= REJ_CRC;
                        end
                    end
                end else begin
                    frame_rejected <= 1'b1;
                    frame_reject_reason <= REJ_SIZE;
                end

                rx_active <= 1'b0;
                rx_idx    <= 6'd0;
            end else begin
                if (rx_idx < (UP_LEN - 1)) begin
                    rx_idx <= rx_idx + 6'd1;
                end else begin
                    frame_rejected <= 1'b1;
                    frame_reject_reason <= REJ_SIZE;
                    rx_active <= 1'b0;
                    rx_idx    <= 6'd0;
                end
            end
        end
    end
end

endmodule
