`timescale 1ns/1ps

// Randomized full-system regression:
//   input_buffer -> matrix_interface -> systolic_controller -> systolic_array
//
// Each trial:
//   1. pulses the system reset (rst_n),
//   2. loads random signed INT8 matrices A and B through the buffer's
//      load port, with random idle gaps in load_en,
//   3. drives garbage on the load port after buffer_ready (must be ignored),
//   4. waits a random number of idle cycles, then pulses start,
//   5. checks done, the compute-cycle count (3N-1), the feed-cycle count
//      (2N-1) and all N*N outputs against a reference product,
//   6. pulses start again on the same loaded data and checks the result is
//      identical (the controller's INIT state must clear the old sums).
//
// The controller cycle counter is sized from N (CNT_WIDTH) so large arrays
// fit. Run one size (example N = 8):
//   iverilog -g2012 -s tb_system_random_regression \
//     -Ptb_system_random_regression.N=8 -o sys.vvp \
//     rtl/mac_unit.v rtl/processing_element.v rtl/systolic_array.v \
//     rtl/input_buffer.v rtl/matrix_interface.v rtl/systolic_controller.v \
//     testbench/tb_system_random_regression.v
//   vvp sys.vvp            (optional: +seed=1234)
module tb_system_random_regression;

    parameter N          = 4;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH  = 32;
    parameter CNT_WIDTH  = $clog2(3*N) + 1;
    parameter NUM_TRIALS = (N <= 8) ? 50 : 1;   // large N is slow to simulate

    reg clk, rst_n, start, load_en;
    reg  signed [DATA_WIDTH-1:0] load_a, load_b;
    wire buffer_ready, array_rst, array_en, buffer_rd_en, done, busy;
    wire [CNT_WIDTH-1:0] cycle_cnt;
    wire signed [(N*N*DATA_WIDTH)-1:0] matrix_a_flat, matrix_b_flat;
    wire signed [(N*DATA_WIDTH)-1:0]   a_in, b_in;
    wire signed [(N*N*ACC_WIDTH)-1:0]  acc_out;

    reg signed [DATA_WIDTH-1:0] A [0:N*N-1];
    reg signed [DATA_WIDTH-1:0] B [0:N*N-1];
    reg signed [ACC_WIDTH-1:0]  expected [0:N*N-1];

    integer r, c, k, idx, trial, run, gap, timeout;
    integer errors, failed_trials, trial_errors;
    integer compute_cycles, feed_cycles, done_pulses;
    integer seed;

    input_buffer #(.N(N), .DATA_WIDTH(DATA_WIDTH)) u_buffer (
        .clk(clk), .rst_n(rst_n), .load_en(load_en),
        .load_a(load_a), .load_b(load_b), .buffer_ready(buffer_ready),
        .matrix_a_flat(matrix_a_flat), .matrix_b_flat(matrix_b_flat)
    );

    matrix_interface #(.N(N), .DATA_WIDTH(DATA_WIDTH), .CNT_WIDTH(CNT_WIDTH)) u_interface (
        .buffer_rd_en(buffer_rd_en), .cycle_cnt(cycle_cnt),
        .matrix_a_flat(matrix_a_flat), .matrix_b_flat(matrix_b_flat),
        .a_in(a_in), .b_in(b_in)
    );

    systolic_controller #(.N(N), .CNT_WIDTH(CNT_WIDTH)) u_controller (
        .clk(clk), .rst_n(rst_n), .start(start), .buffer_ready(buffer_ready),
        .array_rst(array_rst), .array_en(array_en), .buffer_rd_en(buffer_rd_en),
        .done(done), .busy(busy), .cycle_cnt(cycle_cnt)
    );

    systolic_array #(.N(N), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) u_array (
        .clk(clk), .rst(array_rst), .en(array_en),
        .a_in(a_in), .b_in(b_in), .acc_out(acc_out)
    );

    always #5 clk = ~clk;

    // Count control activity on every rising edge.
    always @(posedge clk) begin
        if (array_en)     compute_cycles = compute_cycles + 1;
        if (buffer_rd_en) feed_cycles    = feed_cycles + 1;
        if (done)         done_pulses    = done_pulses + 1;
    end

    function signed [ACC_WIDTH-1:0] get_acc(input integer row, input integer col);
        get_acc = acc_out[((row*N+col)+1)*ACC_WIDTH-1 -: ACC_WIDTH];
    endfunction

    // One start -> done run on the data already in the buffer.
    task run_once(input integer run_id);
        begin
            compute_cycles = 0; feed_cycles = 0; done_pulses = 0;

            @(negedge clk); start = 1;
            @(negedge clk); start = 0;

            timeout = 0;
            while (done !== 1'b1 && timeout < 3*N + 8) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            @(negedge clk);   // let the done cycle complete

            if (timeout >= 3*N + 8) begin
                $display("FAIL N=%0d trial %0d run %0d: controller timeout", N, trial, run_id);
                trial_errors = trial_errors + 1;
            end
            if (compute_cycles != 3*N - 1) begin
                $display("FAIL N=%0d trial %0d run %0d: %0d compute cycles, expected %0d",
                         N, trial, run_id, compute_cycles, 3*N - 1);
                trial_errors = trial_errors + 1;
            end
            if (feed_cycles != 2*N - 1) begin
                $display("FAIL N=%0d trial %0d run %0d: %0d feed cycles, expected %0d",
                         N, trial, run_id, feed_cycles, 2*N - 1);
                trial_errors = trial_errors + 1;
            end
            if (done_pulses != 1) begin
                $display("FAIL N=%0d trial %0d run %0d: done high for %0d cycles, expected 1",
                         N, trial, run_id, done_pulses);
                trial_errors = trial_errors + 1;
            end
            if (busy !== 1'b0) begin
                $display("FAIL N=%0d trial %0d run %0d: busy still high after done",
                         N, trial, run_id);
                trial_errors = trial_errors + 1;
            end

            for (r = 0; r < N; r = r + 1)
                for (c = 0; c < N; c = c + 1)
                    if (get_acc(r, c) !== expected[r*N+c]) begin
                        if (errors + trial_errors < 20)
                            $display("FAIL N=%0d trial %0d run %0d: C[%0d][%0d] = %0d, expected %0d",
                                     N, trial, run_id, r, c, get_acc(r, c), expected[r*N+c]);
                        trial_errors = trial_errors + 1;
                    end
        end
    endtask

    initial begin
        seed = 20261124 + N;
        if ($value$plusargs("seed=%d", seed))
            $display("Using seed from command line: %0d", seed);

        clk = 0; rst_n = 0; start = 0; load_en = 0;
        load_a = 0; load_b = 0;
        errors = 0; failed_trials = 0;

        for (trial = 0; trial < NUM_TRIALS; trial = trial + 1) begin
            trial_errors = 0;

            // Random matrices and reference product (row-major).
            for (idx = 0; idx < N*N; idx = idx + 1) begin
                A[idx] = $random(seed);
                B[idx] = $random(seed);
            end
            for (r = 0; r < N; r = r + 1)
                for (c = 0; c < N; c = c + 1) begin
                    expected[r*N+c] = 0;
                    for (k = 0; k < N; k = k + 1)
                        expected[r*N+c] = expected[r*N+c] + A[r*N+k] * B[k*N+c];
                end

            // 1. System reset.
            rst_n = 0;
            repeat (2) @(negedge clk);
            rst_n = 1;

            // 2. Load with random idle gaps in load_en.
            idx = 0;
            while (idx < N*N) begin
                @(negedge clk);
                if (($random(seed) & 3) == 0) begin
                    load_en = 0;                       // idle cycle
                    load_a  = $random(seed);           // must not be stored
                    load_b  = $random(seed);
                end else begin
                    load_en = 1;
                    load_a  = A[idx];
                    load_b  = B[idx];
                    idx = idx + 1;
                end
            end

            // 3. Keep load_en high with garbage after the buffer is full.
            repeat (3) begin
                @(negedge clk);
                load_en = 1;
                load_a  = $random(seed);
                load_b  = $random(seed);
            end
            @(negedge clk);
            load_en = 0; load_a = 0; load_b = 0;

            if (buffer_ready !== 1'b1) begin
                $display("FAIL N=%0d trial %0d: buffer_ready not set after loading", N, trial);
                trial_errors = trial_errors + 1;
            end

            // 4. Random idle time before start.
            gap = $random(seed) & 7;
            repeat (gap) @(negedge clk);

            // 5. First run, then 6. repeated start on the same data.
            run_once(0);
            run_once(1);

            errors = errors + trial_errors;
            if (trial_errors != 0)
                failed_trials = failed_trials + 1;
        end

        $display("------------------------------");
        $display("N = %0d: %0d trials x 2 runs, %0d outputs checked, CNT_WIDTH = %0d",
                 N, NUM_TRIALS, NUM_TRIALS * 2 * N * N, CNT_WIDTH);
        $display("Failed trials: %0d", failed_trials);
        if (errors == 0)
            $display("N=%0d FULL-SYSTEM RANDOM REGRESSION PASSED", N);
        else
            $fatal(1, "N=%0d: %0d errors across %0d failed trials", N, errors, failed_trials);
        $display("------------------------------");
        $finish;
    end

endmodule
