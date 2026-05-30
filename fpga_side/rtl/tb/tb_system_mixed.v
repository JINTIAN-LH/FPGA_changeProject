`timescale 1ns/1ps

module tb_system_mixed;
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
    integer i;
    integer good_count;
    integer bad_header_count;
    integer bad_length_count;
    integer bad_crc_count;
    integer accepted_count;
    integer rejected_count;
    integer response_count;
    integer response_len_err;
    integer test_fail;
    integer resp_bytes;

    localparam [2:0] REJ_HEADER = 3'd1;
    localparam [2:0] REJ_LENGTH = 3'd2;
    localparam [2:0] REJ_CRC    = 3'd3;

    localparam integer CASE_GOOD       = 0;
    localparam integer CASE_BAD_HEADER = 1;
    localparam integer CASE_BAD_LENGTH = 2;
    localparam integer CASE_BAD_CRC    = 3;

    m1_protocol_core #(
        .MA5_PLACEHOLDER(16'h0011),
        .MA10_PLACEHOLDER(16'h0022),
        .RSI_PLACEHOLDER(16'h0033)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx_valid(rx_valid),
        .rx_data(rx_data),
        .rx_last(rx_last),
        .tx_ready(tx_ready),
        .tx_valid(tx_valid),
        .tx_data(tx_data),
        .tx_last(tx_last),
        .frame_accepted(frame_accepted),
        .frame_rejected(frame_rejected),
        .frame_reject_reason(frame_reject_reason)
    );

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

    task build_base_frame;
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

        frame[12] = 8'hAA;
        frame[13] = 8'hBB;
        frame[14] = 8'hCC;
        frame[15] = 8'hDD;

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

    task apply_case;
        input integer case_type;
    begin
        build_base_frame();
        if (case_type == CASE_BAD_HEADER) begin
            frame[0] = 8'h00;
            bad_header_count = bad_header_count + 1;
        end else if (case_type == CASE_BAD_LENGTH) begin
            frame[3] = 8'h31;
            bad_length_count = bad_length_count + 1;
        end else if (case_type == CASE_BAD_CRC) begin
            frame[47] = frame[47] ^ 8'h01;
            bad_crc_count = bad_crc_count + 1;
        end else begin
            good_count = good_count + 1;
        end
    end
    endtask

    task send_frame;
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

    task check_window;
        input integer expect_response;
        input [2:0] expect_reason;
        integer cyc;
        integer seen_accept;
        integer seen_reject;
    begin
        resp_bytes = 0;
        seen_accept = 0;
        seen_reject = 0;

        for (cyc = 0; cyc < 120; cyc = cyc + 1) begin
            @(posedge clk);
            if (tx_valid) begin
                resp_bytes = resp_bytes + 1;
            end
            if (tx_last && (resp_bytes != 44)) begin
                response_len_err = response_len_err + 1;
                test_fail = 1;
            end
            if (frame_accepted) begin
                seen_accept = 1;
                accepted_count = accepted_count + 1;
            end
            if (frame_rejected) begin
                seen_reject = 1;
                rejected_count = rejected_count + 1;
                if (frame_reject_reason != expect_reason) begin
                    $display("[FAIL] reject reason mismatch exp=%0d got=%0d", expect_reason, frame_reject_reason);
                    test_fail = 1;
                end
            end
        end

        if (expect_response) begin
            if (!seen_accept) begin
                $display("[FAIL] expected frame_accepted pulse missing");
                test_fail = 1;
            end
            if (resp_bytes != 44) begin
                $display("[FAIL] response bytes=%0d expected=44", resp_bytes);
                test_fail = 1;
            end
            response_count = response_count + 1;
        end else begin
            if (resp_bytes != 0) begin
                $display("[FAIL] unexpected response bytes=%0d", resp_bytes);
                test_fail = 1;
            end
            if (!seen_reject) begin
                $display("[FAIL] expected frame_rejected pulse missing");
                test_fail = 1;
            end
        end
    end
    endtask

    initial begin
        rx_valid = 1'b0;
        rx_data  = 8'h00;
        rx_last  = 1'b0;
        tx_ready = 1'b1;

        good_count = 0;
        bad_header_count = 0;
        bad_length_count = 0;
        bad_crc_count = 0;
        accepted_count = 0;
        rejected_count = 0;
        response_count = 0;
        response_len_err = 0;
        test_fail = 0;

        rst_n = 1'b0;
        #50;
        rst_n = 1'b1;

        apply_case(CASE_GOOD);
        send_frame();
        check_window(1, 3'd0);

        apply_case(CASE_BAD_HEADER);
        send_frame();
        check_window(0, REJ_HEADER);

        apply_case(CASE_GOOD);
        send_frame();
        check_window(1, 3'd0);

        apply_case(CASE_BAD_LENGTH);
        send_frame();
        check_window(0, REJ_LENGTH);

        apply_case(CASE_GOOD);
        send_frame();
        check_window(1, 3'd0);

        apply_case(CASE_BAD_CRC);
        send_frame();
        check_window(0, REJ_CRC);

        apply_case(CASE_GOOD);
        send_frame();
        check_window(1, 3'd0);

        if (accepted_count != good_count) begin
            $display("[FAIL] accepted_count=%0d good_count=%0d", accepted_count, good_count);
            test_fail = 1;
        end
        if (rejected_count != (bad_header_count + bad_length_count + bad_crc_count)) begin
            $display("[FAIL] rejected_count=%0d expected=%0d", rejected_count, (bad_header_count + bad_length_count + bad_crc_count));
            test_fail = 1;
        end
        if (response_count != good_count) begin
            $display("[FAIL] response_count=%0d good_count=%0d", response_count, good_count);
            test_fail = 1;
        end

        if (test_fail) begin
            $display("[TB_SYSTEM] FAILED");
        end else begin
            $display("[TB_SYSTEM] PASSED good=%0d bad_header=%0d bad_length=%0d bad_crc=%0d", good_count, bad_header_count, bad_length_count, bad_crc_count);
        end

        #50;
        $finish;
    end
endmodule
