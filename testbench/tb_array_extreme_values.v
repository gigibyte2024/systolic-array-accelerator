`timescale 1ns/1ps

// 4x4 systolic array test at the extremes of signed INT8 (-128 and +127).
// These give the largest-magnitude products (-128 * -128 = 16384) and
// check that sign handling and accumulation hold up in the worst case.
// The expected product is computed inside the testbench.
module tb_array_extreme_values;

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

    // Fill A and B for the selected extreme-value case.
    task load_case(input integer id);
        integer r, c;
        begin
            for (r = 0; r < N; r = r + 1)
                for (c = 0; c < N; c = c + 1)
                    case (id)
                        0: begin A[r][c] = -128; B[r][c] = -128; end  // min x min
                        1: begin A[r][c] =  127; B[r][c] =  127; end  // max x max
                        2: begin A[r][c] = -128; B[r][c] =  127; end  // min x max
                        3: begin A[r][c] =  127; B[r][c] = -128; end  // max x min
                        default: begin                                // checkerboard
                            A[r][c] = ((r + c) % 2 == 0) ? -128 :  127;
                            B[r][c] = ((r + c) % 2 == 0) ?  127 : -128;
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

            $display("case %0d done: C[0][0] = %0d (expected %0d)",
                     id, get_acc(0, 0), C_expected[0][0]);
        end
    endtask

    initial begin
        clk = 0; rst = 1; en = 0; a_in = 0; b_in = 0; errors = 0;
        @(negedge clk);

        for (case_id = 0; case_id < 5; case_id = case_id + 1)
            run_case(case_id);

        $display("------------------------------");
        if (errors == 0)
            $display("4x4 INT8 EXTREME-VALUE TEST PASSED");
        else
            $fatal(1, "%0d mismatches in extreme-value test", errors);
        $display("------------------------------");
        $finish;
    end

endmodule
