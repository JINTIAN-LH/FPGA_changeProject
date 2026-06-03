`timescale 1ns/1ps

// Network Protocol Handler
// Integrates ARP responder, ICMP ping responder, and UDP parser.
// Sits between MAC RX/TX and protocol-specific handlers.
//
// Architecture:
//   MAC RX -> [EtherType demux] -> ARP Responder
//                                -> ICMP Responder
//                                -> UDP Parser -> Application
//   [TX MUX] <- ARP TX
//            <- ICMP TX
//            <- UDP TX (from application)

module network_handler #(
    parameter [47:0] LOCAL_MAC = 48'h02_00_00_00_00_01,
    parameter [31:0] LOCAL_IP  = 32'hA9FE0076,  // 169.254.0.118
    parameter [15:0] UDP_DST_PORT = 16'd5001
) (
    input  wire        clk,
    input  wire        rst_n,

    // MAC RX interface (from rgmii_rx_sync -> mac_rx)
    input  wire        rx_valid,
    input  wire [7:0]  rx_data,
    input  wire        rx_last,

    // MAC TX interface (to rgmii_tx_sync)
    output reg         tx_valid,
    output reg  [7:0]  tx_data,
    output reg         tx_last,
    input  wire        tx_ready,

    // UDP payload output (to application)
    output wire        udp_payload_valid,
    output wire [7:0]  udp_payload_data,
    output wire        udp_payload_last,

    // UDP payload input (from application)
    input  wire        app_tx_valid,
    input  wire [7:0]  app_tx_data,
    input  wire        app_tx_last,
    output wire        app_tx_ready,

    // Status outputs
    output wire        arp_responded,
    output wire        ping_responded
);

// Ethernet header capture
reg [47:0] eth_dst_mac;
reg [47:0] eth_src_mac;
reg [15:0] eth_type;
reg [5:0]  eth_byte_cnt;
reg        eth_header_done;

// RX state machine
localparam [2:0] RX_ST_IDLE     = 3'd0;
localparam [2:0] RX_ST_ETH_HDR  = 3'd1;
localparam [2:0] RX_ST_DEMUX    = 3'd2;

reg [2:0] rx_state;

// Demuxed streams
wire rx_valid_arp = rx_valid & eth_header_done & (eth_type == 16'h0806);
wire rx_valid_icmp = rx_valid & eth_header_done & (eth_type == 16'h0800);
wire rx_valid_udp = rx_valid & eth_header_done & (eth_type == 16'h0800);

// ARP responder outputs
wire        arp_tx_valid;
wire [7:0]  arp_tx_data;
wire        arp_tx_last;

// ICMP responder outputs
wire        icmp_tx_valid;
wire [7:0]  icmp_tx_data;
wire        icmp_tx_last;

// UDP parser outputs (already declared in module ports)

// TX mux
reg [1:0] tx_select;  // 0=none, 1=ARP, 2=ICMP, 3=UDP

// Capture Ethernet header
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        eth_dst_mac <= 48'd0;
        eth_src_mac <= 48'd0;
        eth_type <= 16'd0;
        eth_byte_cnt <= 6'd0;
        eth_header_done <= 1'b0;
        rx_state <= RX_ST_IDLE;
    end else begin
        case (rx_state)
            RX_ST_IDLE: begin
                eth_header_done <= 1'b0;
                eth_byte_cnt <= 6'd0;
                if (rx_valid) begin
                    eth_dst_mac[47:40] <= rx_data;
                    eth_byte_cnt <= 6'd1;
                    rx_state <= RX_ST_ETH_HDR;
                end
            end

            RX_ST_ETH_HDR: begin
                if (rx_valid) begin
                    eth_byte_cnt <= eth_byte_cnt + 6'd1;
                    case (eth_byte_cnt)
                        6'd1:  eth_dst_mac[39:32] <= rx_data;
                        6'd2:  eth_dst_mac[31:24] <= rx_data;
                        6'd3:  eth_dst_mac[23:16] <= rx_data;
                        6'd4:  eth_dst_mac[15:8]  <= rx_data;
                        6'd5:  eth_dst_mac[7:0]   <= rx_data;
                        6'd6:  eth_src_mac[47:40] <= rx_data;
                        6'd7:  eth_src_mac[39:32] <= rx_data;
                        6'd8:  eth_src_mac[31:24] <= rx_data;
                        6'd9:  eth_src_mac[23:16] <= rx_data;
                        6'd10: eth_src_mac[15:8]  <= rx_data;
                        6'd11: eth_src_mac[7:0]   <= rx_data;
                        6'd12: eth_type[15:8]     <= rx_data;
                        6'd13: begin
                            eth_type[7:0] <= rx_data;
                            eth_header_done <= 1'b1;
                            rx_state <= RX_ST_DEMUX;
                        end
                    endcase

                    if (rx_last) begin
                        rx_state <= RX_ST_IDLE;
                    end
                end
            end

            RX_ST_DEMUX: begin
                if (rx_last) begin
                    rx_state <= RX_ST_IDLE;
                    eth_header_done <= 1'b0;
                end
            end

            default: rx_state <= RX_ST_IDLE;
        endcase
    end
end

// ARP Responder
arp_responder #(
    .LOCAL_MAC(LOCAL_MAC),
    .LOCAL_IP(LOCAL_IP)
) u_arp_responder (
    .clk(clk),
    .rst_n(rst_n),
    .rx_valid(rx_valid_arp),
    .rx_data(rx_data),
    .rx_last(rx_last),
    .tx_valid(arp_tx_valid),
    .tx_data(arp_tx_data),
    .tx_last(arp_tx_last),
    .tx_ready(tx_ready & (tx_select == 2'd1)),
    .arp_responded(arp_responded)
);

// ICMP Responder
icmp_responder #(
    .LOCAL_MAC(LOCAL_MAC),
    .LOCAL_IP(LOCAL_IP)
) u_icmp_responder (
    .clk(clk),
    .rst_n(rst_n),
    .rx_valid(rx_valid_icmp),
    .rx_data(rx_data),
    .rx_last(rx_last),
    .tx_valid(icmp_tx_valid),
    .tx_data(icmp_tx_data),
    .tx_last(icmp_tx_last),
    .tx_ready(tx_ready & (tx_select == 2'd2)),
    .ping_responded(ping_responded)
);

// UDP Parser
ip_udp_parser u_ip_udp_parser (
    .clk(clk),
    .rst_n(rst_n),
    .eth_rx_valid(rx_valid_udp),
    .eth_rx_data(rx_data),
    .eth_rx_last(rx_last),
    .cfg_udp_dst_port(UDP_DST_PORT),
    .udp_payload_valid(udp_payload_valid),
    .udp_payload_data(udp_payload_data),
    .udp_payload_last(udp_payload_last)
);

// TX MUX - Priority: ARP > ICMP > Application UDP
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_select <= 2'd0;
        tx_valid <= 1'b0;
        tx_data <= 8'h00;
        tx_last <= 1'b0;
    end else begin
        tx_valid <= 1'b0;
        tx_data <= 8'h00;
        tx_last <= 1'b0;

        // Priority mux
        if (arp_tx_valid) begin
            tx_select <= 2'd1;
            tx_valid <= arp_tx_valid;
            tx_data <= arp_tx_data;
            tx_last <= arp_tx_last;
        end else if (icmp_tx_valid) begin
            tx_select <= 2'd2;
            tx_valid <= icmp_tx_valid;
            tx_data <= icmp_tx_data;
            tx_last <= icmp_tx_last;
        end else if (app_tx_valid) begin
            tx_select <= 2'd3;
            tx_valid <= app_tx_valid;
            tx_data <= app_tx_data;
            tx_last <= app_tx_last;
        end else begin
            tx_select <= 2'd0;
        end
    end
end

// Application TX ready signal
assign app_tx_ready = tx_ready & (tx_select == 2'd3) & ~arp_tx_valid & ~icmp_tx_valid;

endmodule
