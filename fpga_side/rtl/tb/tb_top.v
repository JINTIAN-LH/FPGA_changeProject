`timescale 1ns/1ps

module tb_m1_protocol_core;
    reg clk;
    reg rst_n;
    reg rx_valid;
    reg [7:0] rx_data;
    reg rx_last;
    reg tx_ready;

    wire tx_valid;
    wire [7:0] tx_data;
    wire tx_last;
    wire frame_accepted;
    wire frame_rejected;
    wire [2:0] frame_reject_reason;

    reg [7:0] frame [0:47];
    reg [7:0] rsp [0:43];
    integer i;
    integer rsp_idx;
    integer test_fail;

    m1_protocol_core dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx_valid(rx_valid),
        .rx_data(rx_data),
        .rx_last(rx_last),
        .tx_ready(tx_ready),
        .indicator_valid(1'b0),
        .ma5_value(32'h00000000),
        .ma10_value(32'h00000000),
        .rsi6_value(32'h00000000),
        .rsi14_value(32'h00000000),
        .trade_signal_value(8'd0),
        .signal_strength_value(8'd0),
        .tx_valid(tx_valid),
        .tx_data(tx_data),
        .tx_last(tx_last),
        .frame_accepted(frame_accepted),
        .frame_rejected(frame_rejected),
        .frame_reject_reason(frame_reject_reason)
    );

    localparam [2:0] REJ_HEADER = 3'd1;
    localparam [2:0] REJ_LENGTH = 3'd2;
    localparam [2:0] REJ_CRC    = 3'd3;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

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

    task build_valid_up_frame;
        reg [31:0] crc;
    begin
        frame[0]  = 8'hAA;
        frame[1]  = 8'h55;
        frame[2]  = 8'h00;
        frame[3]  = 8'h30;

        frame[4]  = "0";
        frame[5]  = "0";
        frame[6]  = "0";
        frame[7]  = "8";
        frame[8]  = "5";
        frame[9]  = "8";
        frame[10] = "S";
        frame[11] = "Z";

        frame[12] = 8'h12;
        frame[13] = 8'h34;
        frame[14] = 8'h56;
        frame[15] = 8'h78;

        for (i = 16; i <= 43; i = i + 1) begin
            frame[i] = 8'h00;
        end

        crc = 32'hFFFFFFFF;
        for (i = 0; i < 44; i = i + 1) begin
            crc = crc32_byte(crc, frame[i]);
        end
        crc = ~crc;

        frame[44] = crc[31:24];
        frame[45] = crc[23:16];
        frame[46] = crc[15:8];
        frame[47] = crc[7:0];
    end
    endtask

    task send_up_frame;
    begin
        for (i = 0; i < 48; i = i + 1) begin
            @(posedge clk);
            rx_valid <= 1'b1;
            rx_data  <= frame[i];
            rx_last  <= (i == 47);
        end
        @(posedge clk);
        rx_valid <= 1'b0;
        rx_data  <= 8'h00;
        rx_last  <= 1'b0;
    end
    endtask

    task collect_response;
    begin
        rsp_idx = 0;
        for (i = 0; i < 120; i = i + 1) begin
            @(posedge clk);
            if (tx_valid) begin
                rsp[rsp_idx] = tx_data;
                rsp_idx = rsp_idx + 1;
                if (tx_last) begin
                    disable collect_response;
                end
            end
        end
    end
    endtask

    task expect_no_response;
        input [2:0] exp_reason;
        integer seen;
        integer rej_seen;
    begin
        seen = 0;
        rej_seen = 0;
        for (i = 0; i < 80; i = i + 1) begin
            @(posedge clk);
            if (tx_valid) begin
                seen = 1;
            end
            if (frame_rejected) begin
                rej_seen = 1;
                if (frame_reject_reason != exp_reason) begin
                    $display("[FAIL] reject reason mismatch: exp=%0d got=%0d", exp_reason, frame_reject_reason);
                    test_fail = 1;
                end
            end
        end
        if (seen) begin
            $display("[FAIL] unexpected response observed");
            test_fail = 1;
        end
        if (!rej_seen) begin
            $display("[FAIL] expected frame_rejected pulse not observed");
            test_fail = 1;
        end
    end
    endtask

    task case_normal;
    begin
        $display("[CASE] normal");
        build_valid_up_frame();
        send_up_frame();
        collect_response();

        if (rsp_idx != 44) begin
            $display("[FAIL] normal: response length = %0d", rsp_idx);
            test_fail = 1;
        end
        if (rsp[0] != 8'h55 || rsp[1] != 8'hAA || rsp[2] != 8'h00 || rsp[3] != 8'h2C) begin
            $display("[FAIL] normal: response header/len mismatch");
            test_fail = 1;
        end
        if (rsp[4] != frame[4] || rsp[11] != frame[11]) begin
            $display("[FAIL] normal: stock code not echoed");
            test_fail = 1;
        end
        if (rsp[12] != frame[12] || rsp[15] != frame[15]) begin
            $display("[FAIL] normal: timestamp not echoed");
            test_fail = 1;
        end
    end
    endtask

    task case_bad_header;
    begin
        $display("[CASE] bad_header");
        build_valid_up_frame();
        frame[0] = 8'hAB;
        send_up_frame();
        expect_no_response(REJ_HEADER);
    end
    endtask

    task case_bad_length;
    begin
        $display("[CASE] bad_length");
        build_valid_up_frame();
        frame[3] = 8'h31;
        send_up_frame();
        expect_no_response(REJ_LENGTH);
    end
    endtask

    task case_bad_crc;
    begin
        $display("[CASE] bad_crc");
        build_valid_up_frame();
        frame[47] = frame[47] ^ 8'h01;
        send_up_frame();
        expect_no_response(REJ_CRC);
    end
    endtask

    initial begin
        rx_valid = 1'b0;
        rx_data  = 8'h00;
        rx_last  = 1'b0;
        tx_ready = 1'b1;
        test_fail = 0;

        rst_n = 1'b0;
        #50;
        rst_n = 1'b1;

        case_normal();
        case_bad_header();
        case_bad_length();
        case_bad_crc();

        if (test_fail) begin
            $display("[TB] FAILED");
        end else begin
            $display("[TB] PASSED");
        end

        #50;
        $finish;
    end
endmodule
