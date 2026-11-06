
`timescale 1ns/1ps

module tb_pe_back_to_back;

    reg clk, rst, en;
    reg signed [7:0] a_in, b_in;

    wire signed [7:0] a_out, b_out;
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

    always #5 clk = ~clk;

    task check_acc;
        input signed [31:0] expected;
        begin
            if (acc === expected)
                $display("PASS: Accumulator = %0d", acc);
            else begin
                $display("FAIL: Expected %0d, got %0d",
                         expected, acc);
                $fatal(1, "Accumulator mismatch");
            end
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        en = 0;
        a_in = 0;
        b_in = 0;
        $dumpfile("simulation/pe_back_to_back_waveform.vcd");
        $dumpvars(0, tb_pe_back_to_back);

        // Reset
        @(negedge clk);
        rst = 0;
        en = 1;

        // Cycle 1: 3 * 4 = 12
        a_in = 3;
        b_in = 4;
        @(posedge clk);
        #1;
        check_acc(12);

        // Cycle 2: 2 * 5 = 10, total = 22
        @(negedge clk);
        a_in = 2;
        b_in = 5;
        @(posedge clk);
        #1;
        check_acc(22);

        // Cycle 3: -2 * 3 = -6, total = 16
        @(negedge clk);
        a_in = -2;
        b_in = 3;
        @(posedge clk);
        #1;
        check_acc(16);

        // Cycle 4: Disable accumulation
        @(negedge clk);
        en = 0;
        a_in = 7;
        b_in = 5;
        @(posedge clk);
        #1;
        check_acc(16);

        // Forwarding should still work when en = 0
        if (a_out === 7 && b_out === 5)
            $display("PASS: Forwarding while MAC disabled");
        else
            $fatal(1, "Forwarding failed");

        // Cycle 5: Re-enable accumulation
        @(negedge clk);
        en = 1;
        a_in = 1;
        b_in = 10;
        @(posedge clk);
        #1;
        check_acc(26);

        $display("--------------------------------");
        $display("BACK-TO-BACK TEST COMPLETED");
        $display("Final accumulator = %0d", acc);
        $display("--------------------------------");

        $finish;
    end

endmodule
