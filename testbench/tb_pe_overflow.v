
`timescale 1ns/1ps

module tb_pe_overflow;

    reg clk, rst, en;
    reg signed [15:0] a_in, b_in;

    wire signed [15:0] a_out, b_out;
    wire signed [31:0] acc;

    processing_element #(
        .DATA_WIDTH(16),
        .ACC_WIDTH(32)
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

        @(negedge clk);
        rst = 0;
        en = 1;

        // First product: 1073741824
        a_in = -32768;
        b_in = -32768;

        @(posedge clk);
        #1;

        if (acc == 1073741824)
            $display("PASS: First accumulation");
        else
            $display("FAIL: First accumulation = %0d", acc);

        // Second product causes 32-bit signed overflow
        @(negedge clk);
        a_in = -32768;
        b_in = -32768;

        @(posedge clk);
        #1;

        if (acc == -2147483648)
            $display("PASS: 32-bit overflow wraparound");
        else
            $display("FAIL: Overflow result = %0d", acc);

        $display("Final accumulator = %0d", acc);
        $finish;
    end

endmodule

