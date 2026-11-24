`timescale 1ns/1ps

// Reset and enable behaviour of the 4x4 systolic array.
//
// In processing_element.v, `en` gates only the MAC accumulation; the
// A/B forwarding registers shift every clock regardless of `en`.
// So `en` is an accumulate-enable, not a pipeline stall. These tests
// check exactly that behaviour:
//
// Case 1 - en low for a whole run:   data flows, accumulators stay 0.
// Case 2 - hold after compute:       en low + new inputs, results frozen.
// Case 3 - reset mid-run:            all accumulators clear, and a new
//                                    multiply started immediately after
//                                    reset is exact (no in-flight data
//                                    from the aborted run leaks in).
// Case 4 - reset with en low:        reset still clears the array.
// Case 5 - en dropped for one cycle: the products scheduled in that
//                                    cycle (k = c - i - j) are skipped
//                                    and nothing else changes.
//
// Inside the array, PE[i][j] multiplies A[i][k] * B[k][j] in cycle
// c = i + j + k (counting from the first feed cycle).
module tb_array_reset_enable;

    localparam N          = 4;
    localparam DATA_WIDTH = 8;
    localparam ACC_WIDTH  = 32;
    localparam CYCLES     = 3*N - 1;   // 2N-1 feed + N drain
    localparam SKIP_CYCLE = 3;         // cycle with en low in case 5

    reg clk, rst, en;
    reg  signed [(N*DATA_WIDTH)-1:0]   a_in;
    reg  signed [(N*DATA_WIDTH)-1:0]   b_in;
    wire signed [(N*N*ACC_WIDTH)-1:0]  acc_out;

    integer i, j, k, c, errors, seed;

    reg signed [DATA_WIDTH-1:0] A  [0:N-1][0:N-1];
    reg signed [DATA_WIDTH-1:0] B  [0:N-1][0:N-1];
    reg signed [DATA_WIDTH-1:0] A2 [0:N-1][0:N-1];
    reg signed [DATA_WIDTH-1:0] B2 [0:N-1][0:N-1];
    reg signed [ACC_WIDTH-1:0]  C_full [0:N-1][0:N-1];   // A  x B
    reg signed [ACC_WIDTH-1:0]  C2     [0:N-1][0:N-1];   // A2 x B2
    reg signed [ACC_WIDTH-1:0]  C_skip [0:N-1][0:N-1];   // A x B minus skipped cycle
    reg signed [ACC_WIDTH-1:0]  saved  [0:N-1][0:N-1];

    systolic_array #(.N(N), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) dut (
        .clk(clk), .rst(rst), .en(en),
        .a_in(a_in), .b_in(b_in), .acc_out(acc_out)
    );

    always #5 clk = ~clk;

    function signed [ACC_WIDTH-1:0] get_acc(input integer r, input integer cc);
        get_acc = acc_out[((r*N+cc)+1)*ACC_WIDTH-1 -: ACC_WIDTH];
    endfunction

    // Drive the skewed inputs for cycle t. sel = 0 feeds A/B, sel = 1 feeds A2/B2.
    task drive(input integer t, input integer sel);
        integer r, cc;
        begin
            a_in = {(N*DATA_WIDTH){1'b0}};
            b_in = {(N*DATA_WIDTH){1'b0}};
            for (r = 0; r < N; r = r + 1)
                if (t - r >= 0 && t - r < N)
                    a_in[(r+1)*DATA_WIDTH-1 -: DATA_WIDTH] = sel ? A2[r][t-r] : A[r][t-r];
            for (cc = 0; cc < N; cc = cc + 1)
                if (t - cc >= 0 && t - cc < N)
                    b_in[(cc+1)*DATA_WIDTH-1 -: DATA_WIDTH] = sel ? B2[t-cc][cc] : B[t-cc][cc];
        end
    endtask

    // Full run of CYCLES cycles. en is low in cycle `skip` (use -1 for none)
    // and low for the whole run if all_off = 1.
    task run(input integer sel, input integer skip, input integer all_off);
        integer t;
        begin
            for (t = 0; t < CYCLES; t = t + 1) begin
                drive(t, sel);
                en = (all_off || t == skip) ? 1'b0 : 1'b1;
                @(negedge clk);
            end
            a_in = 0; b_in = 0; en = 1;
        end
    endtask

    task do_reset;
        begin
            rst = 1; a_in = 0; b_in = 0;
            @(negedge clk);
            rst = 0;
        end
    endtask

    // mode 0: C_full, 1: C2, 2: C_skip, 3: zeros, 4: saved
    task check(input integer mode, input [8*28-1:0] label);
        reg signed [ACC_WIDTH-1:0] expv;
        integer case_errors;
        begin
            case_errors = 0;
            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1) begin
                    case (mode)
                        0: expv = C_full[i][j];
                        1: expv = C2[i][j];
                        2: expv = C_skip[i][j];
                        4: expv = saved[i][j];
                        default: expv = 0;
                    endcase
                    if (get_acc(i, j) !== expv) begin
                        $display("FAIL %0s: C[%0d][%0d] = %0d, expected %0d",
                                 label, i, j, get_acc(i, j), expv);
                        case_errors = case_errors + 1;
                    end
                end
            errors = errors + case_errors;
            if (case_errors == 0)
                $display("PASS %0s", label);
        end
    endtask

    initial begin
        seed = 20261124;
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                A[i][j]  = $random(seed);  B[i][j]  = $random(seed);
                A2[i][j] = $random(seed);  B2[i][j] = $random(seed);
            end

        // References. C_skip drops the term k = SKIP_CYCLE - i - j.
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                C_full[i][j] = 0; C2[i][j] = 0; C_skip[i][j] = 0;
                for (k = 0; k < N; k = k + 1) begin
                    C_full[i][j] = C_full[i][j] + A[i][k]  * B[k][j];
                    C2[i][j]     = C2[i][j]     + A2[i][k] * B2[k][j];
                    if (i + j + k != SKIP_CYCLE)
                        C_skip[i][j] = C_skip[i][j] + A[i][k] * B[k][j];
                end
            end

        clk = 0; rst = 1; en = 0; a_in = 0; b_in = 0; errors = 0;
        @(negedge clk);
        rst = 0; en = 1;

        // Case 1: en low for the whole run.
        do_reset;
        run(0, -1, 1);
        check(3, "case1 en low whole run");

        // Case 2: compute, then hold with en low while new data arrives.
        do_reset;
        run(0, -1, 0);
        check(0, "case2 normal result");
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1)
                saved[i][j] = get_acc(i, j);
        en = 0;
        for (c = 0; c < 10; c = c + 1) begin
            a_in = $random(seed);
            b_in = $random(seed);
            @(negedge clk);
        end
        a_in = 0; b_in = 0;
        check(4, "case2 held with en low");
        en = 1;

        // Case 3: reset in the middle of a run, then start over at once.
        do_reset;
        for (c = 0; c < 4; c = c + 1) begin
            drive(c, 0);
            @(negedge clk);
        end
        do_reset;
        check(3, "case3 cleared mid-run");
        run(1, -1, 0);
        check(1, "case3 fresh run after reset");

        // Case 4: reset while en is low.
        do_reset;
        run(0, -1, 0);
        en = 0;
        do_reset;
        check(3, "case4 reset with en low");
        en = 1;

        // Case 5: en low for exactly one cycle in the middle of a run.
        do_reset;
        run(0, SKIP_CYCLE, 0);
        check(2, "case5 one-cycle en drop");

        $display("------------------------------");
        if (errors == 0)
            $display("4x4 RESET / ENABLE BEHAVIOUR TEST PASSED");
        else
            $fatal(1, "%0d mismatches in reset/enable test", errors);
        $display("------------------------------");
        $finish;
    end

endmodule
