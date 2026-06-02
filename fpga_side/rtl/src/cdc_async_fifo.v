`timescale 1ns/1ps

module cdc_async_fifo #(
    parameter integer DATA_W = 9,
    parameter integer ADDR_W = 8
) (
    input  wire              wr_clk,
    input  wire              wr_rst_n,
    input  wire              rd_clk,
    input  wire              rd_rst_n,
    input  wire [DATA_W-1:0] din,
    input  wire              wr_en,
    input  wire              rd_en,
    output wire [DATA_W-1:0] dout,
    output wire              full,
    output wire              empty
);

localparam integer DEPTH = (1 << ADDR_W);
localparam integer DATA_COUNT_W = ADDR_W + 1;

wire fifo_rst = ~(wr_rst_n & rd_rst_n);

xpm_fifo_async #(
    .CDC_SYNC_STAGES     (2),
    .DOUT_RESET_VALUE    ("0"),
    .ECC_MODE            ("no_ecc"),
    .FIFO_MEMORY_TYPE    ("auto"),
    .FIFO_READ_LATENCY   (0),
    .FIFO_WRITE_DEPTH    (DEPTH),
    .PROG_EMPTY_THRESH   (10),
    .PROG_FULL_THRESH    (DEPTH - 10),
    .RD_DATA_COUNT_WIDTH (DATA_COUNT_W),
    .READ_DATA_WIDTH     (DATA_W),
    .READ_MODE           ("fwft"),
    .RELATED_CLOCKS      (0),
    .SIM_ASSERT_CHK      (0),
    .USE_ADV_FEATURES    ("0000"),
    .WAKEUP_TIME         (0),
    .WR_DATA_COUNT_WIDTH (DATA_COUNT_W),
    .WRITE_DATA_WIDTH    (DATA_W)
) u_xpm_fifo_async (
    .rst            (fifo_rst),
    .wr_clk         (wr_clk),
    .wr_en          (wr_en),
    .din            (din),
    .full           (full),
    .overflow       (),
    .wr_rst_busy    (),
    .rd_clk         (rd_clk),
    .rd_en          (rd_en),
    .dout           (dout),
    .empty          (empty),
    .underflow      (),
    .rd_rst_busy    (),
    .almost_full    (),
    .almost_empty   (),
    .prog_full      (),
    .prog_empty     (),
    .rd_data_count  (),
    .wr_data_count  (),
    .sleep          (1'b0),
    .injectsbiterr  (1'b0),
    .injectdbiterr  (1'b0),
    .sbiterr        (),
    .dbiterr        ()
);

endmodule
