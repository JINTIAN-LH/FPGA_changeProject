`timescale 1ns/1ps

module mdio_init_fsm #(
    parameter integer CLK_DIV = 50,
    parameter [4:0] PHY_ADDR = 5'd1
) (
    input  wire clk,
    input  wire rst_n,
    output reg  mdc,
    output reg  mdio_o,
    output reg  mdio_oe,
    output reg  phy_rst_n,
    output reg  init_done
);

localparam [2:0] ST_RESET_HOLD = 3'd0;
localparam [2:0] ST_POST_RESET = 3'd1;
localparam [2:0] ST_LOAD_CMD   = 3'd2;
localparam [2:0] ST_SHIFT      = 3'd3;
localparam [2:0] ST_DONE       = 3'd4;

reg [2:0] state;
reg [15:0] reset_cnt;
reg [15:0] wait_cnt;
reg [7:0]  div_cnt;
reg        mdc_ce;
reg [6:0]  bit_cnt;
reg [63:0] shift_reg;
reg [1:0]  cmd_idx;

function [63:0] mdio_write_frame;
    input [4:0] phy;
    input [4:0] reg_addr;
    input [15:0] data;
    reg [63:0] f;
begin
    // 32'hFFFF_FFFF + ST(01) + OP(01 write) + PHY + REG + TA(10) + DATA
    f = 64'hFFFF_FFFF_0000_0000;
    f[31:30] = 2'b01;
    f[29:28] = 2'b01;
    f[27:23] = phy;
    f[22:18] = reg_addr;
    f[17:16] = 2'b10;
    f[15:0]  = data;
    mdio_write_frame = f;
end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        div_cnt   <= 8'd0;
        mdc       <= 1'b0;
        mdc_ce    <= 1'b0;
    end else begin
        mdc_ce <= 1'b0;
        if (div_cnt == CLK_DIV-1) begin
            div_cnt <= 8'd0;
            mdc <= ~mdc;
            mdc_ce <= 1'b1;
        end else begin
            div_cnt <= div_cnt + 8'd1;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state      <= ST_RESET_HOLD;
        reset_cnt  <= 16'd0;
        wait_cnt   <= 16'd0;
        bit_cnt    <= 7'd0;
        shift_reg  <= 64'd0;
        cmd_idx    <= 2'd0;
        mdio_o     <= 1'b1;
        mdio_oe    <= 1'b1;
        phy_rst_n  <= 1'b0;
        init_done  <= 1'b0;
    end else begin
        case (state)
            ST_RESET_HOLD: begin
                phy_rst_n <= 1'b0;
                mdio_o    <= 1'b1;
                mdio_oe   <= 1'b1;
                if (reset_cnt == 16'd50000) begin
                    reset_cnt <= 16'd0;
                    phy_rst_n <= 1'b1;
                    state <= ST_POST_RESET;
                end else begin
                    reset_cnt <= reset_cnt + 16'd1;
                end
            end

            ST_POST_RESET: begin
                if (wait_cnt == 16'd50000) begin
                    wait_cnt <= 16'd0;
                    state <= ST_LOAD_CMD;
                end else begin
                    wait_cnt <= wait_cnt + 16'd1;
                end
            end

            ST_LOAD_CMD: begin
                case (cmd_idx)
                    2'd0: shift_reg <= mdio_write_frame(PHY_ADDR, 5'd0, 16'h8000);
                    2'd1: shift_reg <= mdio_write_frame(PHY_ADDR, 5'd9, 16'h0200);
                    default: shift_reg <= mdio_write_frame(PHY_ADDR, 5'd0, 16'h1140);
                endcase
                bit_cnt <= 7'd0;
                mdio_oe <= 1'b1;
                state <= ST_SHIFT;
            end

            ST_SHIFT: begin
                if (mdc_ce && (mdc == 1'b0)) begin
                    mdio_o <= shift_reg[63];
                    shift_reg <= {shift_reg[62:0], 1'b1};
                    if (bit_cnt == 7'd63) begin
                        if (cmd_idx == 2'd2) begin
                            state <= ST_DONE;
                        end else begin
                            cmd_idx <= cmd_idx + 2'd1;
                            state <= ST_LOAD_CMD;
                        end
                    end
                    bit_cnt <= bit_cnt + 7'd1;
                end
            end

            ST_DONE: begin
                mdio_o <= 1'b1;
                mdio_oe <= 1'b0;
                init_done <= 1'b1;
            end

            default: state <= ST_RESET_HOLD;
        endcase
    end
end

endmodule
