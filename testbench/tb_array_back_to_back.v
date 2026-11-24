`timescale 1ns/1ps

// Back-to-back multiplication tests for the 4x4 systolic array.
//
// Case 1 - reset between runs:   C = A1 x B1, reset, then C = A2 x B2.
//          Checks that reset fully clears the array so the second result
//          has no leftover values from the first.
// Case 2 - no reset between runs: run A1 x B1, drain, then A2 x B2.
//          Accumulators keep adding, so the result must be
//          A1 x B1 + A2 x B2.
// Case 3 - continuous streaming:  A1/B1 then A2/B2 with no gap at all,
//          i.e. one multiply with inner dimension K = 2N:
//          [A1 A2] x [B1; B2] = A1 x B1 + A2 x B2.
//          This is how a large AI layer is split into tiles along K.
//
// All operands are random signed INT8; references are computed here.
module tb_array_back_to_back;

    localparam N          = 4;
    localparam DATA_WIDTH = 8;
    localparam ACC_WIDTH  = 32;
    localparam KMAX       = 2*N;

    reg clk, rst, en;
    reg  signed [(N*DATA_WIDTH)-1:0]   a_in;
    reg  signed [(N*DATA_WIDTH)-1:0]   b_in;
    wire signed [(N*N*ACC_WIDTH)-1:0]  acc_out;

    integer i, j, k, t, errors, seed;

    // A1 = columns 0..N-1 of A_big, A2 = columns N..2N-1.
    // B1 = rows    0..N-1 of B_big, B2 = rows    N..2N-1.
    reg signed [DATA_WIDTH-1:0] A_big [0:N-1][0:KMAX-1];
    reg signed [DATA_WIDTH-1:0] B_big [0:KMAX-1][0:N-1];
    reg signed [ACC_WIDTH-1:0]  C1 [0:N-1][0:N-1];   // A1 x B1
    reg signed [ACC_WIDTH-1:0]  C2 [0:N-1][0:N-1];   // A2 x B2

    systolic_array #(.N(N), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) dut (
        .clk(clk), .rst(rst), .en(en),
        .a_in(a_in), .b_in(b_in), .acc_out(acc_out)
    );

    always #5 clk = ~clk;

    function signed [ACC_WIDTH-1:0] get_acc(input integer r, input integer c);
        get_acc = acc_out[((r*N+c)+1)*ACC_WIDTH-1 -: ACC_WIDTH];
    endfunction

    // Skewed feed of inner-dimension slice k0 .. k0+klen-1.
    // Row r is delayed r cycles, column c is delayed c cycles.
    task feed(input integer k0, input integer klen);
        integer r, c, tt;
        begin
            for (tt = 0; tt < klen + N - 1; tt = tt + 1) begin
                a_in = {(N*DATA_WIDTH){1'b0}};
                b_in = {(N*DATA_WIDTH){1'b0}};
                for (r = 0; r < N; r = r + 1)
                    if (tt - r >= 0 && tt - r < klen)
                        a_in[(r+1)*DATA_WIDTH-1 -: DATA_WIDTH] = A_big[r][k0 + tt - r];
                for (c = 0; c < N; c = c + 1)
                    if (tt - c >= 0 && tt - c < klen)
                        b_in[(c+1)*DATA_WIDTH-1 -: DATA_WIDTH] = B_big[k0 + tt - c][c];
                @(negedge clk);
            end
        end
    endtask

    task drain;
        begin
            a_in = 0; b_in = 0;
            repeat (N) @(negedge clk);
        end
    endtask

    task reset_array;
        begin
            rst = 1; en = 0; a_in = 0; b_in = 0;
            @(negedge clk);
            rst = 0; en = 1;
        end
    endtask

    // mode 0: expect C1, mode 1: expect C2, mode 2: expect C1 + C2,
    // mode 3: expect all zeros.
    task check(input integer mode, input [8*24-1:0] label);
        reg signed [ACC_WIDTH-1:0] expv;
        integer case_errors;
        begin
            case_errors = 0;
            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1) begin
                    case (mode)
                        0: expv = C1[i][j];
                        1: expv = C2[i][j];
                        2: expv = C1[i][j] + C2[i][j];
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
            for (k = 0; k < KMAX; k = k + 1) begin
                A_big[i][k] = $random(seed);
                B_big[k][i] = $random(seed);
            end

        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                C1[i][j] = 0;
                C2[i][j] = 0;
                for (k = 0; k < N; k = k + 1) begin
                    C1[i][j] = C1[i][j] + A_big[i][k]     * B_big[k][j];
                    C2[i][j] = C2[i][j] + A_big[i][k + N] * B_big[k + N][j];
                end
            end

        clk = 0; rst = 1; en = 0; a_in = 0; b_in = 0; errors = 0;
        @(negedge clk);

        // Case 1: reset between runs.
        reset_array;  feed(0, N);  drain;  check(0, "case1 first  (A1xB1)");
        reset_array;                       check(3, "case1 after reset (0)");
        feed(N, N);   drain;               check(1, "case1 second (A2xB2)");

        // Case 2: no reset between runs, accumulators keep adding.
        reset_array;  feed(0, N);  drain;  check(0, "case2 first  (A1xB1)");
        feed(N, N);   drain;               check(2, "case2 sum (A1B1+A2B2)");

        // Case 3: continuous stream, inner dimension K = 2N, no gap.
        reset_array;  feed(0, 2*N); drain; check(2, "case3 stream K=2N");

        $display("------------------------------");
        if (errors == 0)
            $display("4x4 BACK-TO-BACK MULTIPLICATION TEST PASSED");
        else
            $fatal(1, "%0d mismatches in back-to-back test", errors);
        $display("------------------------------");
        $finish;
    end

endmodule
