
`timescale 1ns/1ps

module tb_processing_element;

    reg clk;
    reg rst;
    reg en;

    reg signed [7:0] a_in;
    reg signed [7:0] b_in;

    wire signed [7:0] a_out;
    wire signed [7:0] b_out;
    wire signed [31:0] acc;

    processing_element uut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .a_in(a_in),
        .b_in(b_in),
        .a_out(a_out),
        .b_out(b_out),
        .acc(acc)
    );

    // Generate clock: 10 ns period
    always #5 clk = ~clk;

    initial begin
        $dumpfile("simulation/pe_waveform.vcd");
        $dumpvars(0, tb_processing_element);

        clk = 0;
        rst = 1;
        en = 0;
        a_in = 0;
        b_in = 0;

        // Apply reset
        #10;
        rst = 0;
        en = 1;

        // Test 1: 3 * 4 = 12
        @(negedge clk);
        a_in = 3;
        b_in = 4;

        @(posedge clk);
        #1;
        if (acc == 12 && a_out == 3 && b_out == 4)
            $display("TEST 1 PASSED");
        else
            $display("TEST 1 FAILED");

        // Test 2: 2 * 5 = 10, total = 22
        @(negedge clk);
        a_in = 2;
        b_in = 5;

        @(posedge clk);
        #1;
        if (acc == 22 && a_out == 2 && b_out == 5)
            $display("TEST 2 PASSED");
        else
            $display("TEST 2 FAILED");

        // Test 3: -2 * 3 = -6, total = 16
        @(negedge clk);
        a_in = -2;
        b_in = 3;

        @(posedge clk);
        #1;
        if (acc == 16 && a_out == -2 && b_out == 3)
            $display("TEST 3 PASSED");
        else
            $display("TEST 3 FAILED");

        // Test 4: Disable accumulation
        @(negedge clk);
        en = 0;
        a_in = 7;
        b_in = 2;

        @(posedge clk);
        #1;
        if (acc == 16 && a_out == 7 && b_out == 2)
            $display("TEST 4 PASSED");
        else
            $display("TEST 4 FAILED");

        $display("--------------------------------");
        $display("Final accumulator = %0d", acc);
        $display("--------------------------------");

        $finish;
    end

endmodule
