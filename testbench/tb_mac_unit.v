
`timescale 1ns/1ps

module tb_mac_unit;

    reg clk;
    reg rst;
    reg en;

    reg signed [7:0] a;
    reg signed [7:0] b;

    wire signed [31:0] acc;

    mac_unit uut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .a(a),
        .b(b),
        .acc(acc)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("simulation/mac_waveform.vcd");
        $dumpvars(0, tb_mac_unit);

        clk = 0;
        rst = 1;
        en = 0;
        a = 0;
        b = 0;

        #10;
        rst = 0;
        en = 1;

        // 3 * 4 = 12
        a = 3;
        b = 4;
        #10;

        // 2 * 5 = 10; accumulator = 22
        a = 2;
        b = 5;
        #10;

        // -2 * 3 = -6; accumulator = 16
        a = -2;
        b = 3;
        #10;

        en = 0;
        #10;

        $display("Final accumulator = %0d", acc);

        if (acc == 16)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");

        $finish;
    end

endmodule
