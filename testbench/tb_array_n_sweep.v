`timescale 1ns/1ps

// N-parameter sweep for the systolic array.
// The same testbench is compiled for each array size by overriding N,
// so it checks that the generate-based grid really scales.
// Each run multiplies random signed INT8 matrices (full -128..127 range)
// and checks every output against a reference computed in the testbench.
//
// Run one size (example N = 8):
//   iverilog -g2012 -s tb_array_n_sweep -Ptb_array_n_sweep.N=8 -o sweep.vvp \
//     rtl/mac_unit.v rtl/processing_element.v rtl/systolic_array.v \
//     testbench/tb_array_n_sweep.v
//   vvp sweep.vvp
//
// Sizes used in the sweep: N = 2, 3, 4, 5, 8, 100.
module tb_array_n_sweep;

    parameter N          = 4;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH  = 32;
    // Fewer trials for very large arrays to keep simulation time reasonable.
    parameter NUM_TRIALS = (N <= 8) ? 50 : 3;

    reg clk, rst, en;
    reg  signed [(N*DATA_WIDTH)-1:0]   a_in;
    reg  signed [(N*DATA_WIDTH)-1:0]   b_in;
    wire signed [(N*N*ACC_WIDTH)-1:0]  acc_out;

    integer i, j, k, t, trial, errors, cycles;
    integer seed;

    reg signed [DATA_WIDTH-1:0] A [0:N-1][0:N-1];
    reg signed [DATA_WIDTH-1:0] B [0:N-1][0:N-1];
    reg signed [ACC_WIDTH-1:0]  C_expected [0:N-1][0:N-1];

    systolic_array #(.N(N), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) dut (
        .clk(clk), .rst(rst), .en(en),
        .a_in(a_in), .b_in(b_in), .acc_out(acc_out)
    );

    always #5 clk = ~clk;

    // Skewed feed: row r delayed r cycles, column c delayed c cycles.
    task drive_inputs(input integer t);
        integer r, c;
        begin
            a_in = {(N*DATA_WIDTH){1'b0}};
            b_in = {(N*DATA_WIDTH){1'b0}};
            for (r = 0; r < N; r = r + 1)
                if (t - r >= 0 && t - r < N)
                    a_in[(r+1)*DATA_WIDTH-1 -: DATA_WIDTH] = A[r][t-r];
            for (c = 0; c < N; c = c + 1)
                if (t - c >= 0 && t - c < N)
                    b_in[(c+1)*DATA_WIDTH-1 -: DATA_WIDTH] = B[t-c][c];
        end
    endtask

    function signed [ACC_WIDTH-1:0] get_acc(input integer r, input integer c);
        get_acc = acc_out[((r*N+c)+1)*ACC_WIDTH-1 -: ACC_WIDTH];
    endfunction

    initial begin
        seed = 20261124 + N;
        clk = 0; rst = 1; en = 0; a_in = 0; b_in = 0; errors = 0;
        @(negedge clk);

        for (trial = 0; trial < NUM_TRIALS; trial = trial + 1) begin
            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1) begin
                    A[i][j] = $random(seed);
                    B[i][j] = $random(seed);
                end

            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1) begin
                    C_expected[i][j] = 0;
                    for (k = 0; k < N; k = k + 1)
                        C_expected[i][j] = C_expected[i][j] + A[i][k] * B[k][j];
                end

            // Reset, feed skewed inputs (2N-1 cycles), drain (N cycles).
            rst = 1; en = 0; a_in = 0; b_in = 0;
            @(negedge clk);
            rst = 0; en = 1;
            cycles = 0;

            for (t = 0; t < (2*N - 1); t = t + 1) begin
                drive_inputs(t);
                @(negedge clk);
                cycles = cycles + 1;
            end

            a_in = 0; b_in = 0;
            repeat (N) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1)
                    if (get_acc(i, j) !== C_expected[i][j]) begin
                        if (errors < 20)
                            $display("FAIL N=%0d trial %0d: C[%0d][%0d] = %0d, expected %0d",
                                     N, trial, i, j, get_acc(i, j), C_expected[i][j]);
                        errors = errors + 1;
                    end
        end

        $display("------------------------------");
        $display("N = %0d: %0d PEs, %0d trials, %0d outputs checked, %0d compute cycles per multiply",
                 N, N*N, NUM_TRIALS, NUM_TRIALS*N*N, cycles);
        if (errors == 0)
            $display("N=%0d SYSTOLIC ARRAY SWEEP PASSED", N);
        else
            $fatal(1, "N=%0d: %0d mismatches", N, errors);
        $display("------------------------------");
        $finish;
    end

endmodule
