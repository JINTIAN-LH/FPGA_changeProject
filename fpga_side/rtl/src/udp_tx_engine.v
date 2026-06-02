`timescale 1ns/1ps

// Build Ethernet/IPv4/UDP frame from byte-stream payload and send via GMII.

module udp_tx_engine #(
    parameter [47:0] SRC_MAC = 48'h02_00_00_00_00_01,
    parameter [47:0] DST_MAC = 48'hff_ff_ff_ff_ff_ff,
    parameter [31:0] SRC_IP  = 32'hA9FE0076, // 169.254.0.118
    parameter [31:0] DST_IP  = 32'hC0A86468, // 192.168.100.104
    parameter [15:0] SRC_PORT = 16'd5001,
    parameter [15:0] DST_PORT = 16'd5000,
    parameter integer MAX_PAYLOAD = 256
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       s_valid,
    input  wire [7:0] s_data,
    input  wire       s_last,
    output wire       s_ready,
    output reg        gmii_tx_en,
    output reg  [7:0] gmii_txd,
    output reg        tx_busy
);

localparam [2:0] ST_IDLE     = 3'd0;
localparam [2:0] ST_COLLECT  = 3'd1;
localparam [2:0] ST_PREAMBLE = 3'd2;
localparam [2:0] ST_HEADER   = 3'd3;
localparam [2:0] ST_PAYLOAD  = 3'd4;
localparam [2:0] ST_FCS      = 3'd5;

reg [2:0] state;
reg [7:0] payload_mem [0:MAX_PAYLOAD-1];
reg [8:0] payload_len;
reg [8:0] payload_idx;
reg [7:0] pre_cnt;
reg [7:0] hdr_idx;
reg [1:0] fcs_idx;

reg [31:0] crc;
reg [31:0] crc_final;

wire [15:0] ip_total_len = 16'd20 + 16'd8 + payload_len;
wire [15:0] udp_total_len = 16'd8 + payload_len;

wire [15:0] ip_checksum;

function [31:0] crc32_byte;
    input [31:0] crc_in;
    input [7:0] d_in;
    reg [31:0] c;
    reg [7:0] d;
    integer k;
begin
    c = crc_in;
    d = d_in;
    for (k = 0; k < 8; k = k + 1) begin
        if (c[0] ^ d[0]) begin
            c = (c >> 1) ^ 32'hEDB88320;
        end else begin
            c = (c >> 1);
        end
        d = d >> 1;
    end
    crc32_byte = c;
end
endfunction

function [7:0] header_byte;
    input [7:0] idx;
    begin
        case (idx)
            // Ethernet
            8'd0:  header_byte = DST_MAC[47:40];
            8'd1:  header_byte = DST_MAC[39:32];
            8'd2:  header_byte = DST_MAC[31:24];
            8'd3:  header_byte = DST_MAC[23:16];
            8'd4:  header_byte = DST_MAC[15:8];
            8'd5:  header_byte = DST_MAC[7:0];
            8'd6:  header_byte = SRC_MAC[47:40];
            8'd7:  header_byte = SRC_MAC[39:32];
            8'd8:  header_byte = SRC_MAC[31:24];
            8'd9:  header_byte = SRC_MAC[23:16];
            8'd10: header_byte = SRC_MAC[15:8];
            8'd11: header_byte = SRC_MAC[7:0];
            8'd12: header_byte = 8'h08;
            8'd13: header_byte = 8'h00;
            // IPv4 header (20B)
            8'd14: header_byte = 8'h45;
            8'd15: header_byte = 8'h00;
            8'd16: header_byte = ip_total_len[15:8];
            8'd17: header_byte = ip_total_len[7:0];
            8'd18: header_byte = 8'h00;
            8'd19: header_byte = 8'h01;
            8'd20: header_byte = 8'h00;
            8'd21: header_byte = 8'h00;
            8'd22: header_byte = 8'h40;
            8'd23: header_byte = 8'h11;
            8'd24: header_byte = ip_checksum[15:8];
            8'd25: header_byte = ip_checksum[7:0];
            8'd26: header_byte = SRC_IP[31:24];
            8'd27: header_byte = SRC_IP[23:16];
            8'd28: header_byte = SRC_IP[15:8];
            8'd29: header_byte = SRC_IP[7:0];
            8'd30: header_byte = DST_IP[31:24];
            8'd31: header_byte = DST_IP[23:16];
            8'd32: header_byte = DST_IP[15:8];
            8'd33: header_byte = DST_IP[7:0];
            // UDP header (8B)
            8'd34: header_byte = SRC_PORT[15:8];
            8'd35: header_byte = SRC_PORT[7:0];
            8'd36: header_byte = DST_PORT[15:8];
            8'd37: header_byte = DST_PORT[7:0];
            8'd38: header_byte = udp_total_len[15:8];
            8'd39: header_byte = udp_total_len[7:0];
            8'd40: header_byte = 8'h00; // checksum disabled
            8'd41: header_byte = 8'h00;
            default: header_byte = 8'h00;
        endcase
    end
endfunction

assign ip_checksum = ~(16'h4500 + ip_total_len + 16'h0001 + 16'h0000 + 16'h4011 +
                       SRC_IP[31:16] + SRC_IP[15:0] + DST_IP[31:16] + DST_IP[15:0]);

assign s_ready = (state == ST_IDLE || state == ST_COLLECT) && (payload_len < MAX_PAYLOAD);

always @(posedge clk) begin
    if (!rst_n) begin
        state <= ST_IDLE;
        payload_len <= 9'd0;
        payload_idx <= 9'd0;
        pre_cnt <= 8'd0;
        hdr_idx <= 8'd0;
        fcs_idx <= 2'd0;
        crc <= 32'hFFFFFFFF;
        crc_final <= 32'd0;
        gmii_tx_en <= 1'b0;
        gmii_txd <= 8'h00;
        tx_busy <= 1'b0;
    end else begin
        gmii_tx_en <= 1'b0;
        gmii_txd <= 8'h00;

        case (state)
            ST_IDLE: begin
                tx_busy <= 1'b0;
                payload_len <= 9'd0;
                payload_idx <= 9'd0;
                if (s_valid) begin
                    payload_mem[0] <= s_data;
                    payload_len <= 9'd1;
                    state <= s_last ? ST_PREAMBLE : ST_COLLECT;
                end
            end

            ST_COLLECT: begin
                if (s_valid && payload_len < MAX_PAYLOAD) begin
                    payload_mem[payload_len] <= s_data;
                    payload_len <= payload_len + 9'd1;
                    if (s_last) begin
                        state <= ST_PREAMBLE;
                        pre_cnt <= 8'd0;
                    end
                end
            end

            ST_PREAMBLE: begin
                tx_busy <= 1'b1;
                gmii_tx_en <= 1'b1;
                gmii_txd <= (pre_cnt == 8'd7) ? 8'hD5 : 8'h55;
                if (pre_cnt == 8'd7) begin
                    state <= ST_HEADER;
                    hdr_idx <= 8'd0;
                    crc <= 32'hFFFFFFFF;
                end
                pre_cnt <= pre_cnt + 8'd1;
            end

            ST_HEADER: begin
                gmii_tx_en <= 1'b1;
                gmii_txd <= header_byte(hdr_idx);
                crc <= crc32_byte(crc, header_byte(hdr_idx));
                if (hdr_idx == 8'd41) begin
                    state <= ST_PAYLOAD;
                    payload_idx <= 9'd0;
                end
                hdr_idx <= hdr_idx + 8'd1;
            end

            ST_PAYLOAD: begin
                gmii_tx_en <= 1'b1;
                gmii_txd <= payload_mem[payload_idx];
                crc <= crc32_byte(crc, payload_mem[payload_idx]);
                if (payload_idx == payload_len - 1'b1) begin
                    state <= ST_FCS;
                    fcs_idx <= 2'd0;
                    crc_final <= ~crc32_byte(crc, payload_mem[payload_idx]);
                end
                payload_idx <= payload_idx + 9'd1;
            end

            ST_FCS: begin
                gmii_tx_en <= 1'b1;
                case (fcs_idx)
                    2'd0: gmii_txd <= crc_final[7:0];
                    2'd1: gmii_txd <= crc_final[15:8];
                    2'd2: gmii_txd <= crc_final[23:16];
                    default: gmii_txd <= crc_final[31:24];
                endcase

                if (fcs_idx == 2'd3) begin
                    state <= ST_IDLE;
                end else begin
                    fcs_idx <= fcs_idx + 2'd1;
                end
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule
