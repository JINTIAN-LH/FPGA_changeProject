`timescale 1ns/1ps

// Decode 48-byte upstream market frame into OHLCV outputs.
// Frame layout follows host-side protocol contract.

module market_frame_decoder (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [7:0]  in_data,
    input  wire        in_last,
    output reg         price_valid,
    output reg [31:0]  open_price,
    output reg [31:0]  high_price,
    output reg [31:0]  low_price,
    output reg [31:0]  close_price,
    output reg [31:0]  volume
);

reg [5:0]  byte_idx;
reg [15:0] header;
reg [15:0] length_field;
reg        frame_ok;
reg [31:0] crc_work;
reg [31:0] rx_crc;

function [31:0] crc32_byte;
    input [31:0] crc_in;
    input [7:0] data_in;
    reg [31:0] c;
    reg [7:0] d;
    integer k;
begin
    c = crc_in;
    d = data_in;
    for (k = 0; k < 8; k = k + 1) begin
        if (c[0] ^ d[0]) begin
            c = (c >> 1) ^ 32'hEDB88320;
        end else begin
            c = c >> 1;
        end
        d = d >> 1;
    end
    crc32_byte = c;
end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        byte_idx      <= 6'd0;
        header        <= 16'd0;
        length_field  <= 16'd0;
        frame_ok      <= 1'b0;
        crc_work      <= 32'hFFFFFFFF;
        rx_crc        <= 32'd0;
        price_valid   <= 1'b0;
        open_price    <= 32'd0;
        high_price    <= 32'd0;
        low_price     <= 32'd0;
        close_price   <= 32'd0;
        volume        <= 32'd0;
    end else begin
        price_valid <= 1'b0;

        if (in_valid) begin
            if (byte_idx == 6'd0) begin
                frame_ok <= 1'b1;
                crc_work <= 32'hFFFFFFFF;
            end

            if (byte_idx < 6'd44) begin
                crc_work <= crc32_byte(crc_work, in_data);
            end

            case (byte_idx)
                6'd0: header[15:8] <= in_data;
                6'd1: begin
                    header[7:0] <= in_data;
                    if ({header[15:8], in_data} != 16'hAA55) frame_ok <= 1'b0;
                end
                6'd2: length_field[15:8] <= in_data;
                6'd3: begin
                    length_field[7:0] <= in_data;
                    if ({length_field[15:8], in_data} != 16'd48) frame_ok <= 1'b0;
                end
                6'd16: open_price[31:24] <= in_data;
                6'd17: open_price[23:16] <= in_data;
                6'd18: open_price[15:8]  <= in_data;
                6'd19: open_price[7:0]   <= in_data;

                6'd20: high_price[31:24] <= in_data;
                6'd21: high_price[23:16] <= in_data;
                6'd22: high_price[15:8]  <= in_data;
                6'd23: high_price[7:0]   <= in_data;

                6'd24: low_price[31:24]  <= in_data;
                6'd25: low_price[23:16]  <= in_data;
                6'd26: low_price[15:8]   <= in_data;
                6'd27: low_price[7:0]    <= in_data;

                6'd28: close_price[31:24] <= in_data;
                6'd29: close_price[23:16] <= in_data;
                6'd30: close_price[15:8]  <= in_data;
                6'd31: close_price[7:0]   <= in_data;

                6'd32: volume[31:24] <= in_data;
                6'd33: volume[23:16] <= in_data;
                6'd34: volume[15:8]  <= in_data;
                6'd35: volume[7:0]   <= in_data;
                6'd44: rx_crc[31:24] <= in_data;
                6'd45: rx_crc[23:16] <= in_data;
                6'd46: rx_crc[15:8]  <= in_data;
                6'd47: rx_crc[7:0]   <= in_data;
                default: begin
                end
            endcase

            byte_idx <= byte_idx + 6'd1;
        end

        if (in_last) begin
            if (frame_ok && (byte_idx == 6'd47) && ((~crc_work) == rx_crc)) begin
                price_valid <= 1'b1;
            end
            byte_idx <= 6'd0;
        end
    end
end

endmodule
