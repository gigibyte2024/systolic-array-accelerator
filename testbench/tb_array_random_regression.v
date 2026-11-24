`timescale 1ns/1ps

// Randomized regression for the 4x4 systolic array.
// Runs NUM_TRIALS matrix multiplications with random signed INT8 operands
// across the full range (-128..127) and checks every output against a
// reference product computed inside the testbench.
//
// The seed is fixed so results are reproducible. A different seed can be
// passed at run time:  vvp <file>.vvp +seed=1234
module tb_array_random_regression;

    localparam N          = 4;
    localparam DATA_WIDTH = 8;
    localparam ACC_WIDTH  = 32;
    localparam NUM_TRIALS = 500;

    reg clk, rst, en;
    reg  signed [(N*DATA_WIDTH)-1:0]   a_in;
    reg  signed [(N*DATA_WIDTH)-1:0]   b_in;
    wire signed [(N*N*ACC_WIDTH)-1:0]  acc_out;

    integer i, j, k, t, trial, errors, failed_trials, trial_errors;
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

    // Fill A and B with random signed INT8 values (low 8 bits of $random).
    task load_random;
        integer r, c;
        begin
            for (r = 0; r < N; r = r + 1)
                for (c = 0; c < N; c = c + 1) begin
                    A[r][c] = $random(seed);
                    B[r][c] = $random(seed);
                end
        end
    endtask

    initial begin
        seed = 20261124;
        if ($value$plusargs("seed=%d", seed))
            $display("Using seed from command line: %0d", seed);
        else
            $display("Using default seed: %0d", seed);

        clk = 0; rst = 1; en = 0; a_in = 0; b_in = 0;
        errors = 0; failed_trials = 0;
        @(negedge clk);

        for (trial = 0; trial < NUM_TRIALS; trial = trial + 1) begin
            load_random;

            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1) begin
                    C_expected[i][j] = 0;
                    for (k = 0; k < N; k = k + 1)
                        C_expected[i][j] = C_expected[i][j] + A[i][k] * B[k][j];
                end

            // Reset, feed skewed inputs, drain.
            rst = 1; en = 0; a_in = 0; b_in = 0;
            @(negedge clk);
            rst = 0; en = 1;

            for (t = 0; t < (2*N - 1); t = t + 1) begin
                drive_inputs(t);
                @(negedge clk);
            end

            a_in = 0; b_in = 0;
            repeat (N) @(negedge clk);

            trial_errors = 0;
            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1)
                    if (get_acc(i, j) !== C_expected[i][j]) begin
                        if (errors < 20)
                            $display("FAIL trial %0d: C[%0d][%0d] = %0d, expected %0d",
                                     trial, i, j, get_acc(i, j), C_expected[i][j]);
                        errors = errors + 1;
                        trial_errors = trial_errors + 1;
                    end
            if (trial_errors != 0)
                failed_trials = failed_trials + 1;
        end

        $display("------------------------------");
        $display("Trials run      : %0d", NUM_TRIALS);
        $display("Outputs checked : %0d", NUM_TRIALS * N * N);
        $display("Failed trials   : %0d", failed_trials);
        if (errors == 0)
            $display("4x4 RANDOM REGRESSION PASSED");
        else
            $fatal(1, "%0d mismatches across %0d failed trials", errors, failed_trials);
        $display("------------------------------");
        $finish;
    end

endmodule
