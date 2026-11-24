`timescale 1ns/1ps

// 4x4 systolic array tests with special matrices:
//   zero matrices, identity matrices (A x I = A, I x B = B) and a
//   single-nonzero pair that checks no value leaks into the wrong PE.
// The expected product is computed inside the testbench.
module tb_array_special_matrices;

    localparam N          = 4;
    localparam DATA_WIDTH = 8;
    localparam ACC_WIDTH  = 32;

    reg clk, rst, en;
    reg  signed [(N*DATA_WIDTH)-1:0]   a_in;
    reg  signed [(N*DATA_WIDTH)-1:0]   b_in;
    wire signed [(N*N*ACC_WIDTH)-1:0]  acc_out;

    integer i, j, k, t, errors, case_id;

    reg signed [DATA_WIDTH-1:0] A [0:N-1][0:N-1];
    reg signed [DATA_WIDTH-1:0] B [0:N-1][0:N-1];
    reg signed [DATA_WIDTH-1:0] M [0:N-1][0:N-1];   // general signed matrix
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

    // Fill A and B for the selected case.
    task load_case(input integer id);
        integer r, c;
        begin
            for (r = 0; r < N; r = r + 1)
                for (c = 0; c < N; c = c + 1)
                    case (id)
                        0: begin A[r][c] = 0;       B[r][c] = 0;       end  // 0 x 0
                        1: begin A[r][c] = M[r][c]; B[r][c] = 0;       end  // M x 0
                        2: begin A[r][c] = 0;       B[r][c] = M[r][c]; end  // 0 x M
                        3: begin A[r][c] = M[r][c];                          // M x I
                                 B[r][c] = (r == c) ? 1 : 0;           end
                        4: begin A[r][c] = (r == c) ? 1 : 0;                 // I x M
                                 B[r][c] = M[r][c];                    end
                        5: begin A[r][c] = (r == c) ? 1 : 0;                 // I x I
                                 B[r][c] = (r == c) ? 1 : 0;           end
                        default: begin                                       // single nonzero
                            A[r][c] = (r == 1 && c == 2) ?  9 : 0;
                            B[r][c] = (r == 2 && c == 3) ? -7 : 0;
                        end
                    endcase
        end
    endtask

    // Run one multiply: reset, feed skewed inputs, drain, then check.
    task run_case(input integer id);
        begin
            load_case(id);

            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1) begin
                    C_expected[i][j] = 0;
                    for (k = 0; k < N; k = k + 1)
                        C_expected[i][j] = C_expected[i][j] + A[i][k] * B[k][j];
                end

            rst = 1; en = 0; a_in = 0; b_in = 0;
            @(negedge clk);
            rst = 0; en = 1;

            for (t = 0; t < (2*N - 1); t = t + 1) begin
                drive_inputs(t);
                @(negedge clk);
            end

            a_in = 0; b_in = 0;
            repeat (N) @(negedge clk);

            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1)
                    if (get_acc(i, j) !== C_expected[i][j]) begin
                        $display("FAIL case %0d: C[%0d][%0d] = %0d, expected %0d",
                                 id, i, j, get_acc(i, j), C_expected[i][j]);
                        errors = errors + 1;
                    end

            $display("case %0d checked", id);
        end
    endtask

    initial begin
        M[0][0]= 3;  M[0][1]=-2; M[0][2]= 5;  M[0][3]= 1;
        M[1][0]=-4;  M[1][1]= 6; M[1][2]= 0;  M[1][3]=-1;
        M[2][0]= 7;  M[2][1]= 2; M[2][2]=-3;  M[2][3]= 4;
        M[3][0]=-1;  M[3][1]=-5; M[3][2]= 2;  M[3][3]= 8;

        clk = 0; rst = 1; en = 0; a_in = 0; b_in = 0; errors = 0;
        @(negedge clk);

        for (case_id = 0; case_id < 7; case_id = case_id + 1)
            run_case(case_id);

        // Extra explicit check, independent of the computed reference: the
        // single-nonzero case must give C[1][3] = 9 * -7 = -63.
        if (get_acc(1, 3) !== -63) begin
            $display("FAIL: single-nonzero C[1][3] = %0d, expected -63", get_acc(1, 3));
            errors = errors + 1;
        end

        $display("------------------------------");
        if (errors == 0)
            $display("4x4 ZERO / IDENTITY / SINGLE-NONZERO TEST PASSED");
        else
            $fatal(1, "%0d mismatches in special-matrix test", errors);
        $display("------------------------------");
        $finish;
    end

endmodule
