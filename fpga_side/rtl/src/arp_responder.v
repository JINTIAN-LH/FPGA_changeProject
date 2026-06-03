`timescale 1ns/1ps

// ARP Responder Module
// Responds to ARP requests for our IP address with our MAC address.
// This allows the PC to discover the FPGA's MAC address for UDP communication.

module arp_responder #(
    parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_00_01,
    parameter [31:0] LOCAL_IP  = 32'hA9FE0076  // 169.254.0.118
) (
    input  wire        clk,
    input  wire        rst_n,

    // RX interface (from mac_rx)
    input  wire        rx_valid,
    input  wire [7:0]  rx_data,
    input  wire        rx_last,

    // TX interface (to udp_tx_engine or direct GMII)
    output reg         tx_valid,
    output reg  [7:0]  tx_data,
    output reg         tx_last,
    input  wire        tx_ready,

    // Status
    output reg         arp_responded  // Pulse when ARP reply sent
);

// State machine
localparam [2:0] ST_IDLE      = 3'd0;
localparam [2:0] ST_RX_PARSE  = 3'd1;
localparam [2:0] ST_TX_PREAMBLE = 3'd2;
localparam [2:0] ST_TX_HEADER = 3'd3;
localparam [2:0] ST_TX_DATA   = 3'd4;
localparam [2:0] ST_TX_FCS    = 3'd5;

reg [2:0] state;
reg [5:0] byte_cnt;
reg [3:0] pre_cnt;
reg [1:0] fcs_idx;

// ARP frame fields
reg [47:0] rx_sender_mac;
reg [31:0] rx_sender_ip;
reg [31:0] rx_target_ip;
reg [15:0] rx_opcode;

// CRC calculation
reg [31:0] crc;
reg [31:0] crc_final;

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

// ARP reply header construction
function [7:0] arp_reply_byte;
    input [7:0] idx;
    begin
        case (idx)
            // Ethernet header
            8'd0:  arp_reply_byte = rx_sender_mac[47:40];  // DST MAC
            8'd1:  arp_reply_byte = rx_sender_mac[39:32];
            8'd2:  arp_reply_byte = rx_sender_mac[31:24];
            8'd3:  arp_reply_byte = rx_sender_mac[23:16];
            8'd4:  arp_reply_byte = rx_sender_mac[15:8];
            8'd5:  arp_reply_byte = rx_sender_mac[7:0];
            8'd6:  arp_reply_byte = LOCAL_MAC[47:40];      // SRC MAC
            8'd7:  arp_reply_byte = LOCAL_MAC[39:32];
            8'd8:  arp_reply_byte = LOCAL_MAC[31:24];
            8'd9:  arp_reply_byte = LOCAL_MAC[23:16];
            8'd10: arp_reply_byte = LOCAL_MAC[15:8];
            8'd11: arp_reply_byte = LOCAL_MAC[7:0];
            8'd12: arp_reply_byte = 8'h08;                 // EtherType = ARP
            8'd13: arp_reply_byte = 8'h06;
            // ARP header
            8'd14: arp_reply_byte = 8'h00;                 // HW Type = Ethernet
            8'd15: arp_reply_byte = 8'h01;
            8'd16: arp_reply_byte = 8'h08;                 // Proto Type = IPv4
            8'd17: arp_reply_byte = 8'h00;
            8'd18: arp_reply_byte = 8'h06;                 // HW Size = 6
            8'd19: arp_reply_byte = 8'h04;                 // Proto Size = 4
            8'd20: arp_reply_byte = 8'h00;                 // Opcode = Reply
            8'd21: arp_reply_byte = 8'h02;
            // Sender MAC (us)
            8'd22: arp_reply_byte = LOCAL_MAC[47:40];
            8'd23: arp_reply_byte = LOCAL_MAC[39:32];
            8'd24: arp_reply_byte = LOCAL_MAC[31:24];
            8'd25: arp_reply_byte = LOCAL_MAC[23:16];
            8'd26: arp_reply_byte = LOCAL_MAC[15:8];
            8'd27: arp_reply_byte = LOCAL_MAC[7:0];
            // Sender IP (us)
            8'd28: arp_reply_byte = LOCAL_IP[31:24];
            8'd29: arp_reply_byte = LOCAL_IP[23:16];
            8'd30: arp_reply_byte = LOCAL_IP[15:8];
            8'd31: arp_reply_byte = LOCAL_IP[7:0];
            // Target MAC (requester)
            8'd32: arp_reply_byte = rx_sender_mac[47:40];
            8'd33: arp_reply_byte = rx_sender_mac[39:32];
            8'd34: arp_reply_byte = rx_sender_mac[31:24];
            8'd35: arp_reply_byte = rx_sender_mac[23:16];
            8'd36: arp_reply_byte = rx_sender_mac[15:8];
            8'd37: arp_reply_byte = rx_sender_mac[7:0];
            // Target IP (requester)
            8'd38: arp_reply_byte = rx_sender_ip[31:24];
            8'd39: arp_reply_byte = rx_sender_ip[23:16];
            8'd40: arp_reply_byte = rx_sender_ip[15:8];
            8'd41: arp_reply_byte = rx_sender_ip[7:0];
            default: arp_reply_byte = 8'h00;
        endcase
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= ST_IDLE;
        byte_cnt <= 6'd0;
        pre_cnt <= 4'd0;
        fcs_idx <= 2'd0;
        crc <= 32'hFFFFFFFF;
        crc_final <= 32'd0;
        tx_valid <= 1'b0;
        tx_data <= 8'h00;
        tx_last <= 1'b0;
        arp_responded <= 1'b0;
        rx_sender_mac <= 48'd0;
        rx_sender_ip <= 32'd0;
        rx_target_ip <= 32'd0;
        rx_opcode <= 16'd0;
    end else begin
        tx_valid <= 1'b0;
        tx_last <= 1'b0;
        arp_responded <= 1'b0;

        case (state)
            ST_IDLE: begin
                if (rx_valid) begin
                    state <= ST_RX_PARSE;
                    byte_cnt <= 6'd1;
                    // Parse Ethernet header
                    // Bytes 0-5: DST MAC (we check later if it's broadcast or our MAC)
                    // Bytes 6-11: SRC MAC (sender)
                    // Bytes 12-13: EtherType
                end
            end

            ST_RX_PARSE: begin
                if (rx_valid) begin
                    byte_cnt <= byte_cnt + 6'd1;

                    // Capture sender MAC (bytes 6-11)
                    case (byte_cnt)
                        6'd6:  rx_sender_mac[47:40] <= rx_data;
                        6'd7:  rx_sender_mac[39:32] <= rx_data;
                        6'd8:  rx_sender_mac[31:24] <= rx_data;
                        6'd9:  rx_sender_mac[23:16] <= rx_data;
                        6'd10: rx_sender_mac[15:8]  <= rx_data;
                        6'd11: rx_sender_mac[7:0]   <= rx_data;
                        // EtherType (bytes 12-13)
                        6'd12: begin
                            if (rx_data != 8'h08) begin
                                // Not ARP, ignore frame
                                state <= ST_IDLE;
                            end
                        end
                        6'd13: begin
                            if (rx_data != 8'h06) begin
                                // Not ARP, ignore frame
                                state <= ST_IDLE;
                            end
                        end
                        // ARP header starts at byte 14
                        // Opcode (bytes 20-21)
                        6'd20: rx_opcode[15:8] <= rx_data;
                        6'd21: begin
                            rx_opcode[7:0] <= rx_data;
                            if ({rx_opcode[15:8], rx_data} != 16'h0001) begin
                                // Not ARP request, ignore
                                state <= ST_IDLE;
                            end
                        end
                        // Sender IP (bytes 28-31)
                        6'd28: rx_sender_ip[31:24] <= rx_data;
                        6'd29: rx_sender_ip[23:16] <= rx_data;
                        6'd30: rx_sender_ip[15:8]  <= rx_data;
                        6'd31: rx_sender_ip[7:0]   <= rx_data;
                        // Target IP (bytes 38-41)
                        6'd38: rx_target_ip[31:24] <= rx_data;
                        6'd39: rx_target_ip[23:16] <= rx_data;
                        6'd40: rx_target_ip[15:8]  <= rx_data;
                        6'd41: begin
                            rx_target_ip[7:0] <= rx_data;
                            // Check if target IP matches our IP
                            if ({rx_target_ip[31:8], rx_data} == LOCAL_IP) begin
                                // This is an ARP request for us!
                                state <= ST_TX_PREAMBLE;
                                pre_cnt <= 4'd0;
                            end else begin
                                state <= ST_IDLE;
                            end
                        end
                    endcase

                    if (rx_last) begin
                        state <= ST_IDLE;
                    end
                end
            end

            ST_TX_PREAMBLE: begin
                if (tx_ready) begin
                    tx_valid <= 1'b1;
                    tx_data <= (pre_cnt == 4'd7) ? 8'hD5 : 8'h55;
                    if (pre_cnt == 4'd7) begin
                        state <= ST_TX_HEADER;
                        byte_cnt <= 6'd0;
                        crc <= 32'hFFFFFFFF;
                    end
                    pre_cnt <= pre_cnt + 4'd1;
                end
            end

            ST_TX_HEADER: begin
                if (tx_ready) begin
                    tx_valid <= 1'b1;
                    tx_data <= arp_reply_byte(byte_cnt[5:0]);
                    crc <= crc32_byte(crc, arp_reply_byte(byte_cnt[5:0]));
                    if (byte_cnt == 6'd41) begin
                        state <= ST_TX_FCS;
                        fcs_idx <= 2'd0;
                        crc_final <= ~crc;
                    end
                    byte_cnt <= byte_cnt + 6'd1;
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
                        arp_responded <= 1'b1;
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
