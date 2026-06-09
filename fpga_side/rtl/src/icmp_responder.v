`timescale 1ns/1ps

// ICMP Echo (Ping) Responder Module
// Responds to ICMP Echo Request packets with Echo Reply.
// This allows using 'ping' command to test network connectivity.

module icmp_responder #(
    parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_00_01,
    parameter [31:0] LOCAL_IP  = 32'hA9FE0076  // 169.254.0.118
) (
    input  wire        clk,
    input  wire        rst_n,

    // RX interface (from mac_rx, after Ethernet header stripped)
    input  wire        rx_valid,
    input  wire [7:0]  rx_data,
    input  wire        rx_last,

    // TX interface
    output reg         tx_valid,
    output reg  [7:0]  tx_data,
    output reg         tx_last,
    input  wire        tx_ready,

    // Status
    output reg         ping_responded  // Pulse when ping reply sent
);

// State machine
localparam [3:0] ST_IDLE       = 4'd0;
localparam [3:0] ST_RX_ETH     = 4'd1;
localparam [3:0] ST_RX_IP      = 4'd2;
localparam [3:0] ST_RX_ICMP    = 4'd3;
localparam [3:0] ST_RX_DATA    = 4'd4;
localparam [3:0] ST_TX_PREAMBLE = 4'd5;
localparam [3:0] ST_TX_HEADER  = 4'd6;
localparam [3:0] ST_TX_PAYLOAD = 4'd7;
localparam [3:0] ST_TX_FCS     = 4'd8;

reg [3:0] state;
reg [8:0] byte_cnt;
reg [3:0] pre_cnt;
reg [1:0] fcs_idx;
reg [8:0] payload_len;

// Captured fields from request
reg [47:0] rx_src_mac;
reg [31:0] rx_src_ip;
reg [31:0] rx_dst_ip;
reg [15:0] rx_ip_total_len;
reg [15:0] rx_icmp_ident;
reg [15:0] rx_icmp_seq;

// ICMP payload buffer (store up to 256 bytes)
reg [7:0] icmp_payload [0:255];
reg [8:0] icmp_payload_cnt;

// CRC calculation
reg [31:0] crc;
reg [31:0] crc_final;

// IP checksum
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

// Ethernet + IP + ICMP header construction
// Total header: 14 (ETH) + 20 (IP) + 8 (ICMP) = 42 bytes
function [7:0] reply_header_byte;
    input [7:0] idx;
    reg [15:0] ip_total_len_reply;
    begin
        ip_total_len_reply = rx_ip_total_len;  // Same length as request

        case (idx)
            // Ethernet header (14 bytes)
            8'd0:  reply_header_byte = rx_src_mac[47:40];    // DST MAC
            8'd1:  reply_header_byte = rx_src_mac[39:32];
            8'd2:  reply_header_byte = rx_src_mac[31:24];
            8'd3:  reply_header_byte = rx_src_mac[23:16];
            8'd4:  reply_header_byte = rx_src_mac[15:8];
            8'd5:  reply_header_byte = rx_src_mac[7:0];
            8'd6:  reply_header_byte = LOCAL_MAC[47:40];     // SRC MAC
            8'd7:  reply_header_byte = LOCAL_MAC[39:32];
            8'd8:  reply_header_byte = LOCAL_MAC[31:24];
            8'd9:  reply_header_byte = LOCAL_MAC[23:16];
            8'd10: reply_header_byte = LOCAL_MAC[15:8];
            8'd11: reply_header_byte = LOCAL_MAC[7:0];
            8'd12: reply_header_byte = 8'h08;                // EtherType = IPv4
            8'd13: reply_header_byte = 8'h00;

            // IPv4 header (20 bytes)
            8'd14: reply_header_byte = 8'h45;                // Version + IHL
            8'd15: reply_header_byte = 8'h00;                // DSCP/ECN
            8'd16: reply_header_byte = ip_total_len_reply[15:8];
            8'd17: reply_header_byte = ip_total_len_reply[7:0];
            8'd18: reply_header_byte = 8'h00;                // Identification
            8'd19: reply_header_byte = 8'h00;
            8'd20: reply_header_byte = 8'h40;                // Flags + Fragment
            8'd21: reply_header_byte = 8'h00;
            8'd22: reply_header_byte = 8'h40;                // TTL = 64
            8'd23: reply_header_byte = 8'h01;                // Protocol = ICMP
            8'd24: reply_header_byte = ip_checksum[15:8];
            8'd25: reply_header_byte = ip_checksum[7:0];
            8'd26: reply_header_byte = LOCAL_IP[31:24];      // SRC IP
            8'd27: reply_header_byte = LOCAL_IP[23:16];
            8'd28: reply_header_byte = LOCAL_IP[15:8];
            8'd29: reply_header_byte = LOCAL_IP[7:0];
            8'd30: reply_header_byte = rx_src_ip[31:24];     // DST IP
            8'd31: reply_header_byte = rx_src_ip[23:16];
            8'd32: reply_header_byte = rx_src_ip[15:8];
            8'd33: reply_header_byte = rx_src_ip[7:0];

            // ICMP header (8 bytes)
            8'd34: reply_header_byte = 8'h00;                // Type = Echo Reply
            8'd35: reply_header_byte = 8'h00;                // Code = 0
            8'd36: reply_header_byte = 8'h00;                // Checksum (placeholder)
            8'd37: reply_header_byte = 8'h00;
            8'd38: reply_header_byte = rx_icmp_ident[15:8];  // Identifier
            8'd39: reply_header_byte = rx_icmp_ident[7:0];
            8'd40: reply_header_byte = rx_icmp_seq[15:8];    // Sequence
            8'd41: reply_header_byte = rx_icmp_seq[7:0];

            default: reply_header_byte = 8'h00;
        endcase
    end
endfunction

// IP checksum calculation
wire [15:0] ip_total_len_reply = rx_ip_total_len;
wire [31:0] ip_checksum_raw = 16'h4500 + ip_total_len_reply + 16'h0000 + 16'h4001 +
                              LOCAL_IP[31:16] + LOCAL_IP[15:0] + rx_src_ip[31:16] + rx_src_ip[15:0];
assign ip_checksum = ~(ip_checksum_raw[31:16] + ip_checksum_raw[15:0]);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= ST_IDLE;
        byte_cnt <= 9'd0;
        pre_cnt <= 4'd0;
        fcs_idx <= 2'd0;
        payload_len <= 9'd0;
        crc <= 32'hFFFFFFFF;
        crc_final <= 32'd0;
        tx_valid <= 1'b0;
        tx_data <= 8'h00;
        tx_last <= 1'b0;
        ping_responded <= 1'b0;
        rx_src_mac <= 48'd0;
        rx_src_ip <= 32'd0;
        rx_dst_ip <= 32'd0;
        rx_ip_total_len <= 16'd0;
        rx_icmp_ident <= 16'd0;
        rx_icmp_seq <= 16'd0;
        icmp_payload_cnt <= 9'd0;
    end else begin
        tx_valid <= 1'b0;
        tx_last <= 1'b0;
        ping_responded <= 1'b0;

        case (state)
            ST_IDLE: begin
                if (rx_valid) begin
                    state <= ST_RX_ETH;
                    byte_cnt <= 9'd1;
                    icmp_payload_cnt <= 9'd0;
                end
            end

            ST_RX_ETH: begin
                if (rx_valid) begin
                    byte_cnt <= byte_cnt + 9'd1;

                    // Capture sender MAC (bytes 6-11)
                    case (byte_cnt)
                        9'd6:  rx_src_mac[47:40] <= rx_data;
                        9'd7:  rx_src_mac[39:32] <= rx_data;
                        9'd8:  rx_src_mac[31:24] <= rx_data;
                        9'd9:  rx_src_mac[23:16] <= rx_data;
                        9'd10: rx_src_mac[15:8]  <= rx_data;
                        9'd11: rx_src_mac[7:0]   <= rx_data;
                        // EtherType (bytes 12-13)
                        9'd12: begin
                            if (rx_data != 8'h08) begin
                                state <= ST_IDLE;  // Not IPv4
                            end
                        end
                        9'd13: begin
                            if (rx_data != 8'h00) begin
                                state <= ST_IDLE;  // Not IPv4
                            end else begin
                                state <= ST_RX_IP;
                                byte_cnt <= 9'd0;
                            end
                        end
                    endcase

                    if (rx_last) state <= ST_IDLE;
                end
            end

            ST_RX_IP: begin
                if (rx_valid) begin
                    byte_cnt <= byte_cnt + 9'd1;

                    case (byte_cnt)
                        9'd0: begin
                            if (rx_data != 8'h45) begin
                                state <= ST_IDLE;  // Not IPv4 with IHL=5
                            end
                        end
                        9'd2: rx_ip_total_len[15:8] <= rx_data;
                        9'd3: rx_ip_total_len[7:0] <= rx_data;
                        9'd9: begin
                            if (rx_data != 8'd1) begin
                                state <= ST_IDLE;  // Not ICMP
                            end
                        end
                        9'd12: rx_src_ip[31:24] <= rx_data;
                        9'd13: rx_src_ip[23:16] <= rx_data;
                        9'd14: rx_src_ip[15:8] <= rx_data;
                        9'd15: rx_src_ip[7:0] <= rx_data;
                        9'd16: rx_dst_ip[31:24] <= rx_data;
                        9'd17: rx_dst_ip[23:16] <= rx_data;
                        9'd18: rx_dst_ip[15:8] <= rx_data;
                        9'd19: begin
                            rx_dst_ip[7:0] <= rx_data;
                            // Check if destination IP matches our IP
                            if ({rx_dst_ip[31:8], rx_data} != LOCAL_IP) begin
                                state <= ST_IDLE;  // Not for us
                            end else begin
                                state <= ST_RX_ICMP;
                                byte_cnt <= 9'd0;
                            end
                        end
                    endcase

                    if (rx_last) state <= ST_IDLE;
                end
            end

            ST_RX_ICMP: begin
                if (rx_valid) begin
                    byte_cnt <= byte_cnt + 9'd1;

                    case (byte_cnt)
                        9'd0: begin
                            if (rx_data != 8'h08) begin
                                state <= ST_IDLE;  // Not Echo Request
                            end
                        end
                        9'd1: begin
                            if (rx_data != 8'h00) begin
                                state <= ST_IDLE;  // Not Echo Request
                            end
                        end
                        // Skip checksum (bytes 2-3)
                        9'd4: rx_icmp_ident[15:8] <= rx_data;
                        9'd5: rx_icmp_ident[7:0] <= rx_data;
                        9'd6: rx_icmp_seq[15:8] <= rx_data;
                        9'd7: begin
                            rx_icmp_seq[7:0] <= rx_data;
                            state <= ST_RX_DATA;
                            icmp_payload_cnt <= 9'd0;
                        end
                    endcase

                    if (rx_last) state <= ST_IDLE;
                end
            end

            ST_RX_DATA: begin
                if (rx_valid) begin
                    // Store ICMP payload
                    if (icmp_payload_cnt < 9'd256) begin
                        icmp_payload[icmp_payload_cnt[7:0]] <= rx_data;
                        icmp_payload_cnt <= icmp_payload_cnt + 9'd1;
                    end

                    if (rx_last) begin
                        payload_len <= icmp_payload_cnt;
                        state <= ST_TX_PREAMBLE;
                        pre_cnt <= 4'd0;
                    end
                end
            end

            ST_TX_PREAMBLE: begin
                if (tx_ready) begin
                    tx_valid <= 1'b1;
                    tx_data <= (pre_cnt == 4'd7) ? 8'hD5 : 8'h55;
                    if (pre_cnt == 4'd7) begin
                        state <= ST_TX_HEADER;
                        byte_cnt <= 9'd0;
                        crc <= 32'hFFFFFFFF;
                    end
                    pre_cnt <= pre_cnt + 4'd1;
                end
            end

            ST_TX_HEADER: begin
                if (tx_ready) begin
                    tx_valid <= 1'b1;
                    tx_data <= reply_header_byte(byte_cnt[7:0]);
                    crc <= crc32_byte(crc, reply_header_byte(byte_cnt[7:0]));
                    if (byte_cnt == 9'd41) begin
                        state <= ST_TX_PAYLOAD;
                        byte_cnt <= 9'd0;
                    end
                    byte_cnt <= byte_cnt + 9'd1;
                end
            end

            ST_TX_PAYLOAD: begin
                if (tx_ready) begin
                    tx_valid <= 1'b1;
                    tx_data <= icmp_payload[byte_cnt[7:0]];
                    crc <= crc32_byte(crc, icmp_payload[byte_cnt[7:0]]);
                    if (byte_cnt == payload_len - 9'd1) begin
                        state <= ST_TX_FCS;
                        fcs_idx <= 2'd0;
                        crc_final <= ~crc;
                    end
                    byte_cnt <= byte_cnt + 9'd1;
                end
            end

            ST_TX_FCS: begin
                if (tx_ready) begin
                    tx_valid <= 1'b1;
                    case (fcs_idx)
                        2'd0: tx_data <= crc_final[7:0];
                        2'd1: tx_data <= crc_final[15:8];
                        2'd2: tx_data <= crc_final[23:16];
                        default: tx_data <= crc_final[31:24];
                    endcase

                    if (fcs_idx == 2'd3) begin
                        tx_last <= 1'b1;
                        ping_responded <= 1'b1;
                        state <= ST_IDLE;
                    end else begin
                        fcs_idx <= fcs_idx + 2'd1;
                    end
                end
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule
