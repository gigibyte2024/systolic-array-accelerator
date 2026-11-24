`timescale 1ns/1ps

// 4x4 systolic array test with signed operands (negative values).
// The expected product is computed inside the testbench, so no
// hand-calculated reference matrix is needed.
module tb_systolic_array_signed;

    localparam N          = 4;
    localparam DATA_WIDTH = 8;
    localparam ACC_WIDTH  = 32;

    reg clk, rst, en;
    reg  signed [(N*DATA_WIDTH)-1:0]   a_in;
    reg  signed [(N*DATA_WIDTH)-1:0]   b_in;
    wire signed [(N*N*ACC_WIDTH)-1:0]  acc_out;

    integer i, j, k, t, errors;

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
        A[0][0]= 3;  A[0][1]=-2; A[0][2]= 5;  A[0][3]= 1;
        A[1][0]=-4;  A[1][1]= 6; A[1][2]= 0;  A[1][3]=-1;
        A[2][0]= 7;  A[2][1]= 2; A[2][2]=-3;  A[2][3]= 4;
        A[3][0]=-1;  A[3][1]=-5; A[3][2]= 2;  A[3][3]= 8;

        B[0][0]= 2;  B[0][1]=-1; B[0][2]= 4;  B[0][3]= 0;
        B[1][0]=-3;  B[1][1]= 5; B[1][2]= 1;  B[1][3]=-2;
        B[2][0]= 6;  B[2][1]= 0; B[2][2]=-4;  B[2][3]= 3;
        B[3][0]= 1;  B[3][1]=-2; B[3][2]= 7;  B[3][3]=-1;

        // Reference product computed in the testbench.
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                C_expected[i][j] = 0;
                for (k = 0; k < N; k = k + 1)
                    C_expected[i][j] = C_expected[i][j] + A[i][k] * B[k][j];
            end

        clk = 0; rst = 1; en = 0; a_in = 0; b_in = 0; errors = 0;
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
                    $display("FAIL: C[%0d][%0d] = %0d, expected %0d",
                             i, j, get_acc(i, j), C_expected[i][j]);
                    errors = errors + 1;
                end else
                    $display("PASS: C[%0d][%0d] = %0d", i, j, get_acc(i, j));

        $display("------------------------------");
        if (errors == 0)
            $display("4x4 SIGNED SYSTOLIC ARRAY TEST PASSED");
        else
            $fatal(1, "%0d mismatches", errors);
        $display("------------------------------");
        $finish;
    end

endmodule
