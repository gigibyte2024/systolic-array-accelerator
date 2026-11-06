
`timescale 1ns/1ps

module tb_pe_2x2_integration;

    reg clk, rst, en;

    // External matrix inputs
    reg signed [7:0] a_top, a_bottom;
    reg signed [7:0] b_left, b_right;

    // Horizontal and vertical connections
    wire signed [7:0] a00_out, b00_out;
    wire signed [7:0] a01_out, b01_out;
    wire signed [7:0] a10_out, b10_out;
    wire signed [7:0] a11_out, b11_out;

    // Accumulators
    wire signed [31:0] acc00, acc01;
    wire signed [31:0] acc10, acc11;

    // PE00: Top-left
    processing_element PE00 (
        .clk(clk), .rst(rst), .en(en),
        .a_in(a_top), .b_in(b_left),
        .a_out(a00_out), .b_out(b00_out),
        .acc(acc00)
    );

    // PE01: Top-right
    processing_element PE01 (
        .clk(clk), .rst(rst), .en(en),
        .a_in(a00_out), .b_in(b_right),
        .a_out(a01_out), .b_out(b01_out),
        .acc(acc01)
    );

    // PE10: Bottom-left
    processing_element PE10 (
        .clk(clk), .rst(rst), .en(en),
        .a_in(a_bottom), .b_in(b00_out),
        .a_out(a10_out), .b_out(b10_out),
        .acc(acc10)
    );

    // PE11: Bottom-right
    processing_element PE11 (
        .clk(clk), .rst(rst), .en(en),
        .a_in(a10_out), .b_in(b01_out),
        .a_out(a11_out), .b_out(b11_out),
        .acc(acc11)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("simulation/pe_2x2_waveform.vcd");
        $dumpvars(0, tb_pe_2x2_integration);

        clk = 0;
        rst = 1;
        en = 0;

        a_top = 2;
        a_bottom = 3;
        b_left = 5;
        b_right = 7;

        // Reset all four PEs
        @(negedge clk);
        rst = 0;

        // Allow data to propagate through the array
        repeat (4) @(posedge clk);
        #1;

        // Verify data forwarding
        if (a00_out == 2 && b00_out == 5 &&
            a01_out == 2 && b01_out == 7 &&
            a10_out == 3 && b10_out == 5 &&
            a11_out == 3 && b11_out == 7)
            $display("PASS: 2x2 PE data forwarding");
        else
            $fatal(1, "FAIL: Data forwarding");

        // Accumulate one product in every PE
        @(negedge clk);
        en = 1;

        @(posedge clk);
        #1;

        // Verify all four accumulators
        if (acc00 == 10)
            $display("PASS: PE00 accumulator = %0d", acc00);
        else
            $fatal(1, "PE00 failed: %0d", acc00);

        if (acc01 == 14)
            $display("PASS: PE01 accumulator = %0d", acc01);
        else
            $fatal(1, "PE01 failed: %0d", acc01);

        if (acc10 == 15)
            $display("PASS: PE10 accumulator = %0d", acc10);
        else
            $fatal(1, "PE10 failed: %0d", acc10);

        if (acc11 == 21)
            $display("PASS: PE11 accumulator = %0d", acc11);
        else
            $fatal(1, "PE11 failed: %0d", acc11);

        $display("--------------------------------");
        $display("2x2 PE INTEGRATION TEST PASSED");
        $display("--------------------------------");

        $finish;
    end

endmodule
