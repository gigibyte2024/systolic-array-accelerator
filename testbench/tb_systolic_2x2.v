
`timescale 1ns/1ps

module tb_systolic_2x2;

    reg clk, rst, en;

    reg signed [7:0] a_top, a_bottom;
    reg signed [7:0] b_left, b_right;

    wire signed [7:0] a00_out, b00_out;
    wire signed [7:0] a01_out, b01_out;
    wire signed [7:0] a10_out, b10_out;
    wire signed [7:0] a11_out, b11_out;

    wire signed [31:0] acc00, acc01;
    wire signed [31:0] acc10, acc11;

    processing_element PE00 (
        .clk(clk), .rst(rst), .en(en),
        .a_in(a_top), .b_in(b_left),
        .a_out(a00_out), .b_out(b00_out),
        .acc(acc00)
    );

    processing_element PE01 (
        .clk(clk), .rst(rst), .en(en),
        .a_in(a00_out), .b_in(b_right),
        .a_out(a01_out), .b_out(b01_out),
        .acc(acc01)
    );

    processing_element PE10 (
        .clk(clk), .rst(rst), .en(en),
        .a_in(a_bottom), .b_in(b00_out),
        .a_out(a10_out), .b_out(b10_out),
        .acc(acc10)
    );

    processing_element PE11 (
        .clk(clk), .rst(rst), .en(en),
        .a_in(a10_out), .b_in(b01_out),
        .a_out(a11_out), .b_out(b11_out),
        .acc(acc11)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("simulation/systolic_2x2_waveform.vcd");
        $dumpvars(0, tb_systolic_2x2);

        clk = 0;
        rst = 1;
        en = 0;

        a_top = 0;
        a_bottom = 0;
        b_left = 0;
        b_right = 0;

        // Reset
        @(negedge clk);
        rst = 0;
        en = 1;

        // Cycle 0
        a_top = 1;
        b_left = 5;

        @(negedge clk);

        // Cycle 1
        a_top = 2;
        a_bottom = 3;
        b_left = 6;
        b_right = 7;

        @(negedge clk);

        // Cycle 2
        a_top = 0;
        a_bottom = 4;
        b_left = 0;
        b_right = 8;

        @(negedge clk);

        // Drain the pipeline
        a_top = 0;
        a_bottom = 0;
        b_left = 0;
        b_right = 0;

        repeat (3) @(negedge clk);

        // Check matrix multiplication result
        if (acc00 == 17)
            $display("PASS: C[0][0] = %0d", acc00);
        else
            $fatal(1, "C[0][0] failed: %0d", acc00);

        if (acc01 == 23)
            $display("PASS: C[0][1] = %0d", acc01);
        else
            $fatal(1, "C[0][1] failed: %0d", acc01);

        if (acc10 == 39)
            $display("PASS: C[1][0] = %0d", acc10);
        else
            $fatal(1, "C[1][0] failed: %0d", acc10);

        if (acc11 == 53)
            $display("PASS: C[1][1] = %0d", acc11);
        else
            $fatal(1, "C[1][1] failed: %0d", acc11);

        $display("------------------------------");
        $display("2x2 MATRIX MULTIPLICATION PASSED");
        $display("------------------------------");

        $finish;
    end

endmodule
