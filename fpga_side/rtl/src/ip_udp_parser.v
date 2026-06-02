`timescale 1ns/1ps

// Minimal Ethernet/IPv4/UDP payload extractor.
// Assumes MAC has removed preamble/SFD and input begins at destination MAC.

module ip_udp_parser (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        eth_rx_valid,
    input  wire [7:0]  eth_rx_data,
    input  wire        eth_rx_last,
    input  wire [15:0] cfg_udp_dst_port,
    output reg         udp_payload_valid,
    output reg  [7:0]  udp_payload_data,
    output reg         udp_payload_last
);

reg [15:0] byte_count;
reg [15:0] ip_byte_index;
reg [15:0] udp_byte_index;
reg [15:0] udp_payload_len;
reg [15:0] udp_payload_count;

reg [15:0] eth_type;
reg [7:0]  ip_version_ihl;
reg [7:0]  ip_protocol;
reg [15:0] udp_dst_port;
reg        frame_ok;
reg        in_frame;
reg        in_ip;
reg        in_udp;
reg        in_payload;

always @(posedge clk) begin
    if (!rst_n) begin
        byte_count         <= 16'd0;
        ip_byte_index      <= 16'd0;
        udp_byte_index     <= 16'd0;
        udp_payload_len    <= 16'd0;
        udp_payload_count  <= 16'd0;
        eth_type           <= 16'd0;
        ip_version_ihl     <= 8'd0;
        ip_protocol        <= 8'd0;
        udp_dst_port       <= 16'd0;
        frame_ok           <= 1'b0;
        in_frame           <= 1'b0;
        in_ip              <= 1'b0;
        in_udp             <= 1'b0;
        in_payload         <= 1'b0;
        udp_payload_valid  <= 1'b0;
        udp_payload_data   <= 8'd0;
        udp_payload_last   <= 1'b0;
    end else begin
        udp_payload_valid <= 1'b0;
        udp_payload_last  <= 1'b0;

        if (eth_rx_valid) begin
            if (!in_frame) begin
                in_frame          <= 1'b1;
                byte_count        <= 16'd1;
                ip_byte_index     <= 16'd0;
                udp_byte_index    <= 16'd0;
                udp_payload_count <= 16'd0;
                eth_type          <= 16'd0;
                ip_version_ihl    <= 8'd0;
                ip_protocol       <= 8'd0;
                udp_dst_port      <= 16'd0;
                frame_ok          <= 1'b1;
                in_ip             <= 1'b0;
                in_udp            <= 1'b0;
                in_payload        <= 1'b0;
            end else begin
                byte_count <= byte_count + 16'd1;
            end

            // Ethertype at bytes 13..14 (1-based index).
            if (byte_count == 16'd13) begin
                eth_type[15:8] <= eth_rx_data;
            end else if (byte_count == 16'd14) begin
                eth_type[7:0] <= eth_rx_data;
                in_ip <= 1'b1;
                ip_byte_index <= 16'd0;
            end else if (in_ip && !in_udp) begin
                ip_byte_index <= ip_byte_index + 16'd1;

                if (ip_byte_index == 16'd0) begin
                    ip_version_ihl <= eth_rx_data;
                    if (eth_rx_data[7:4] != 4'h4 || eth_rx_data[3:0] != 4'h5) begin
                        frame_ok <= 1'b0;
                    end
                end

                if (ip_byte_index == 16'd9) begin
                    ip_protocol <= eth_rx_data;
                    if (eth_rx_data != 8'd17) begin
                        frame_ok <= 1'b0;
                    end
                end

                if (ip_byte_index == 16'd19) begin
                    in_udp <= 1'b1;
                    in_ip <= 1'b0;
                    udp_byte_index <= 16'd0;
                end
            end else if (in_udp && !in_payload) begin
                udp_byte_index <= udp_byte_index + 16'd1;

                if (udp_byte_index == 16'd2) begin
                    udp_dst_port[15:8] <= eth_rx_data;
                end else if (udp_byte_index == 16'd3) begin
                    udp_dst_port[7:0] <= eth_rx_data;
                    if ({udp_dst_port[15:8], eth_rx_data} != cfg_udp_dst_port) begin
                        frame_ok <= 1'b0;
                    end
                end

                if (udp_byte_index == 16'd4) begin
                    udp_payload_len[15:8] <= eth_rx_data;
                end else if (udp_byte_index == 16'd5) begin
                    udp_payload_len[7:0] <= eth_rx_data;
                    if ({udp_payload_len[15:8], eth_rx_data} < 16'd8) begin
                        frame_ok <= 1'b0;
                    end
                end

                if (udp_byte_index == 16'd7) begin
                    in_payload <= 1'b1;
                    in_udp <= 1'b0;
                    udp_payload_count <= 16'd0;
                end
            end else if (in_payload) begin
                udp_payload_count <= udp_payload_count + 16'd1;

                if (frame_ok && eth_type == 16'h0800 && ip_protocol == 8'd17) begin
                    udp_payload_valid <= 1'b1;
                    udp_payload_data  <= eth_rx_data;

                    if (udp_payload_count + 16'd1 == (udp_payload_len - 16'd8)) begin
                        udp_payload_last <= 1'b1;
                        in_payload <= 1'b0;
                    end
                end
            end
        end

        if (eth_rx_last) begin
            in_frame          <= 1'b0;
            in_ip             <= 1'b0;
            in_udp            <= 1'b0;
            in_payload        <= 1'b0;
            byte_count        <= 16'd0;
            ip_byte_index     <= 16'd0;
            udp_byte_index    <= 16'd0;
            udp_payload_count <= 16'd0;
        end
    end
end

wire _unused_ip_version_ihl = ip_version_ihl[0];

endmodule
