
`timescale 1ns/1ps

module tb_input_buffer;

    parameter N = 4;
    parameter DATA_WIDTH = 8;

    reg clk, rst_n, load_en;
    reg signed [DATA_WIDTH-1:0] load_a, load_b;

    wire buffer_ready;

    wire signed [N*N*DATA_WIDTH-1:0] matrix_a_flat;
    wire signed [N*N*DATA_WIDTH-1:0] matrix_b_flat;

    integer i;

    input_buffer #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .load_en(load_en),
        .load_a(load_a),
        .load_b(load_b),
        .buffer_ready(buffer_ready),
        .matrix_a_flat(matrix_a_flat),
        .matrix_b_flat(matrix_b_flat)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("report/member3/waveforms/input_buffer_waveform.vcd");
        $dumpvars(0, tb_input_buffer);

        clk = 0;
        rst_n = 0;
        load_en = 0;
        load_a = 0;
        load_b = 0;

        // Release reset
        @(negedge clk);
        rst_n = 1;
        load_en = 1;

        // Load 16 pairs
        for (i = 0; i < N*N; i = i + 1) begin
            load_a = i + 1;
            load_b = (i + 1) * 2;
            @(negedge clk);
        end

        load_en = 0;

        #1;

        // Verify ready signal
        if (buffer_ready !== 1'b1)
            $fatal(1, "FAIL: buffer_ready not asserted");

        $display("PASS: Buffer ready");

        // Verify every stored element
        for (i = 0; i < N*N; i = i + 1) begin

            if ($signed(matrix_a_flat[i*DATA_WIDTH +: DATA_WIDTH]) !== i+1)
                $fatal(1, "FAIL: Matrix A element %0d", i);

            if ($signed(matrix_b_flat[i*DATA_WIDTH +: DATA_WIDTH]) !== (i+1)*2)
                $fatal(1, "FAIL: Matrix B element %0d", i);

            $display("PASS: A[%0d]=%0d, B[%0d]=%0d",
                     i, $signed(matrix_a_flat[i*DATA_WIDTH +: DATA_WIDTH]),
                     i, $signed(matrix_b_flat[i*DATA_WIDTH +: DATA_WIDTH]));
        end

        $display("--------------------------------");
        $display("INPUT BUFFER TEST PASSED");
        $display("--------------------------------");

        $finish;
    end

endmodule
