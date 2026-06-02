`timescale 1ns/1ps

`include "board_protocol_contract.vh"

// Market-data ingress contract for MA703FA-100T bring-up.
//
// Current behavior:
// - Generates a deterministic low-rate synthetic feed so the core can elaborate.
// - Provides stable OHLCV/config outputs for board-level bring-up.
//
// Planned real behavior:
// 1) Host-fed UDP reader: decode host-side market packets into OHLCV + config.
// 2) On-board acquisition bridge: read from existing board interfaces and emit
//    price_valid/open/high/low/close/volume.
// 3) Offline replay engine: drive a captured CSV/JSON stream for board-only demo.

module board_market_feed_ingress (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        frame_valid,
    input  wire [7:0]  frame_data,
    input  wire        frame_last,
    output reg         price_valid,
    output reg  [31:0] open_price,
    output reg  [31:0] high_price,
    output reg  [31:0] low_price,
    output reg  [31:0] close_price,
    output reg  [31:0] volume,
    output reg  [7:0]  cfg_strong_buy,
    output reg  [7:0]  cfg_buy,
    output reg  [7:0]  cfg_neutral,
    output reg  [7:0]  cfg_sell,
    output reg         cfg_valid
);

wire        decoded_valid;
wire [31:0] decoded_open;
wire [31:0] decoded_high;
wire [31:0] decoded_low;
wire [31:0] decoded_close;
wire [31:0] decoded_volume;

market_frame_decoder u_market_frame_decoder (
    .clk        (clk),
    .rst_n      (rst_n),
    .in_valid   (frame_valid),
    .in_data    (frame_data),
    .in_last    (frame_last),
    .price_valid(decoded_valid),
    .open_price (decoded_open),
    .high_price (decoded_high),
    .low_price  (decoded_low),
    .close_price(decoded_close),
    .volume     (decoded_volume)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        price_valid    <= 1'b0;
        open_price     <= 32'd0;
        high_price     <= 32'd0;
        low_price      <= 32'd0;
        close_price    <= 32'd0;
        volume         <= 32'd0;
        cfg_strong_buy <= 8'd30;
        cfg_buy        <= 8'd40;
        cfg_neutral    <= 8'd50;
        cfg_sell       <= 8'd70;
        cfg_valid      <= 1'b1;
    end else begin
        cfg_valid   <= 1'b1;
        price_valid <= 1'b0;

        if (decoded_valid) begin
            open_price  <= decoded_open;
            high_price  <= decoded_high;
            low_price   <= decoded_low;
            close_price <= decoded_close;
            volume      <= decoded_volume;
            price_valid <= 1'b1;
        end
    end
end

endmodule
