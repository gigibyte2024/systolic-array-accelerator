
`timescale 1ns/1ps

module tb_pe_stress;

    reg clk, rst, en;
    reg signed [7:0] a_in, b_in;

    wire signed [7:0] a_out, b_out;
    wire signed [31:0] acc;

    integer expected;

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

    always #5 clk = ~clk;

    // Apply one input pair and verify the result
    task apply_test;
        input signed [7:0] a;
        input signed [7:0] b;
        input integer enable_mac;
        input integer expected_acc;

        begin
            @(negedge clk);
            a_in = a;
            b_in = b;
            en = enable_mac;

            @(posedge clk);
            #1;

            if (acc !== expected_acc)
                $display("FAIL: A=%0d B=%0d ACC=%0d Expected=%0d",
                         a, b, acc, expected_acc);
            else
                $display("PASS: A=%0d B=%0d ACC=%0d",
                         a, b, acc);

            if (a_out !== a || b_out !== b)
                $display("FAIL: Forwarding incorrect");
            else
                $display("PASS: Forwarding correct");
        end
    endtask

    initial begin
        $dumpfile("simulation/pe_stress_waveform.vcd");
        $dumpvars(0, tb_pe_stress);

        clk = 0;
        rst = 1;
        en = 0;
        a_in = 0;
        b_in = 0;

        // Initial reset
        @(posedge clk);
        #1;
        if (acc !== 0)
            $display("FAIL: Initial reset");
        else
            $display("PASS: Initial reset");

        rst = 0;

        // Maximum positive signed inputs
        apply_test(127, 127, 1, 16129);

        // Maximum negative input multiplied by positive
        apply_test(-128, 127, 1, -127);

        // Accumulation continues
        apply_test(10, 10, 1, -27);

        // Disable MAC; accumulator should hold
        apply_test(7, 5, 0, -27);

        // Reset during computation
        @(negedge clk);
        rst = 1;
        en = 1;
        a_in = 4;
        b_in = 5;

        @(posedge clk);
        #1;

        if (acc !== 0)
            $display("FAIL: Reset during computation");
        else
            $display("PASS: Reset during computation");

        rst = 0;

        // Verify operation after reset
        apply_test(3, 4, 1, 12);

        $display("--------------------------------");
        $display("STRESS TEST COMPLETED");
        $display("Final accumulator = %0d", acc);
        $display("--------------------------------");

        $finish;
    end

endmodule
