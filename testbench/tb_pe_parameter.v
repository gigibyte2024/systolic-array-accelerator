
`timescale 1ns/1ps

module tb_pe_parameter;

    reg clk, rst, en;

    reg signed [15:0] a_in, b_in;

    wire signed [15:0] a_out, b_out;
    wire signed [39:0] acc;

    processing_element #(
        .DATA_WIDTH(16),
        .ACC_WIDTH(40)
    ) uut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .a_in(a_in),
        .b_in(b_in),
        .a_out(a_out),
        .b_out(b_out),
        .acc(acc)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        en = 0;
        a_in = 0;
        b_in = 0;

        // Reset
        @(negedge clk);
        rst = 0;
        en = 1;

        // Test 1: 1000 * 2000 = 2000000
        a_in = 1000;
        b_in = 2000;

        @(posedge clk);
        #1;

        if (acc == 2000000)
            $display("PASS: 16-bit multiplication");
        else
            $display("FAIL: Expected 2000000, got %0d", acc);

        // Test 2: Add another product
        @(negedge clk);
        a_in = -500;
        b_in = 200;

        @(posedge clk);
        #1;

        if (acc == 1900000)
            $display("PASS: Signed multiplication and accumulation");
        else
            $display("FAIL: Expected 1900000, got %0d", acc);

        // Test forwarding
        if (a_out == -500 && b_out == 200)
            $display("PASS: 16-bit data forwarding");
        else
            $display("FAIL: Data forwarding");

        $display("----------------------------");
        $display("Final accumulator = %0d", acc);
        $display("----------------------------");

        $finish;
    end

endmodule
