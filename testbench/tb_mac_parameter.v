
`timescale 1ns/1ps

module tb_mac_parameter;

    reg clk, rst, en;
    reg signed [15:0] a, b;

    wire signed [39:0] acc;

    mac_unit #(
        .DATA_WIDTH(16),
        .ACC_WIDTH(40)
    ) uut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .a(a),
        .b(b),
        .acc(acc)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        en = 0;
        a = 0;
        b = 0;

        @(negedge clk);
        rst = 0;
        en = 1;

        a = 1000;
        b = 2000;

        @(posedge clk);
        #1;

        $display("Accumulator = %0d", acc);

        if (acc == 2000000)
            $display("PARAMETER TEST PASSED");
        else
            $display("PARAMETER TEST FAILED");

        $finish;
    end

endmodule

