
`timescale 1ns/1ps

module tb_systolic_array;

    localparam N          = 4;
    localparam DATA_WIDTH = 8;
    localparam ACC_WIDTH  = 32;

    reg clk, rst, en;

    reg signed [(N*DATA_WIDTH)-1:0] a_in;
    reg signed [(N*DATA_WIDTH)-1:0] b_in;
    wire signed [(N*N*ACC_WIDTH)-1:0] acc_out;

    integer i, j, t, errors;

    // A and B are stored row/column-major so they can be fed in skewed
    // (diagonal) order: row i is delayed by i cycles, column j by j cycles.
    reg signed [DATA_WIDTH-1:0] A [0:N-1][0:N-1];
    reg signed [DATA_WIDTH-1:0] B [0:N-1][0:N-1];
    reg signed [ACC_WIDTH-1:0]  C_expected [0:N-1][0:N-1];

    systolic_array #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .a_in(a_in),
        .b_in(b_in),
        .acc_out(acc_out)
    );

    always #5 clk = ~clk;

    // Build the skewed a_in / b_in buses for the current cycle t.
    task drive_inputs(input integer t);
        integer r, c;
        begin
            a_in = {(N*DATA_WIDTH){1'b0}};
            b_in = {(N*DATA_WIDTH){1'b0}};
            for (r = 0; r < N; r = r + 1) begin
                if (t - r >= 0 && t - r < N)
                    a_in[(r+1)*DATA_WIDTH-1 -: DATA_WIDTH] = A[r][t-r];
            end
            for (c = 0; c < N; c = c + 1) begin
                if (t - c >= 0 && t - c < N)
                    b_in[(c+1)*DATA_WIDTH-1 -: DATA_WIDTH] = B[t-c][c];
            end
        end
    endtask

    function signed [ACC_WIDTH-1:0] get_acc(input integer r, input integer c);
        get_acc = acc_out[((r*N+c)+1)*ACC_WIDTH-1 -: ACC_WIDTH];
    endfunction

    initial begin
        $dumpfile("simulation/systolic_array_waveform.vcd");
        $dumpvars(0, tb_systolic_array);

        // A = [[1,2,3,4],[5,6,7,8],[2,1,4,3],[0,1,2,1]]
        A[0][0]=1; A[0][1]=2; A[0][2]=3; A[0][3]=4;
        A[1][0]=5; A[1][1]=6; A[1][2]=7; A[1][3]=8;
        A[2][0]=2; A[2][1]=1; A[2][2]=4; A[2][3]=3;
        A[3][0]=0; A[3][1]=1; A[3][2]=2; A[3][3]=1;

        // B = [[2,0,1,3],[1,2,0,1],[3,1,2,0],[0,1,1,2]]
        B[0][0]=2; B[0][1]=0; B[0][2]=1; B[0][3]=3;
        B[1][0]=1; B[1][1]=2; B[1][2]=0; B[1][3]=1;
        B[2][0]=3; B[2][1]=1; B[2][2]=2; B[2][3]=0;
        B[3][0]=0; B[3][1]=1; B[3][2]=1; B[3][3]=2;

        // Expected C = A x B
        C_expected[0][0]=13; C_expected[0][1]=11; C_expected[0][2]=11; C_expected[0][3]=13;
        C_expected[1][0]=37; C_expected[1][1]=27; C_expected[1][2]=27; C_expected[1][3]=37;
        C_expected[2][0]=17; C_expected[2][1]=9;  C_expected[2][2]=13; C_expected[2][3]=13;
        C_expected[3][0]=7;  C_expected[3][1]=5;  C_expected[3][2]=5;  C_expected[3][3]=3;

        clk = 0;
        rst = 1;
        en  = 0;
        a_in = 0;
        b_in = 0;
        errors = 0;

        @(negedge clk);
        rst = 0;
        en  = 1;

        // Feed the skewed operand stream: N rows + (N-1) extra cycles for
        // the last diagonal to fully enter the array.
        for (t = 0; t < (2*N - 1); t = t + 1) begin
            drive_inputs(t);
            @(negedge clk);
        end

        // Hold zero inputs while partial sums drain through the array.
        a_in = {(N*DATA_WIDTH){1'b0}};
        b_in = {(N*DATA_WIDTH){1'b0}};
        repeat (N) @(negedge clk);

        // Check every PE's accumulator against the reference product.
        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                if (get_acc(i, j) !== C_expected[i][j]) begin
                    $display("FAIL: C[%0d][%0d] = %0d, expected %0d",
                              i, j, get_acc(i, j), C_expected[i][j]);
                    errors = errors + 1;
                end
                else begin
                    $display("PASS: C[%0d][%0d] = %0d", i, j, get_acc(i, j));
                end
            end
        end

        $display("------------------------------");
        if (errors == 0)
            $display("4x4 SYSTOLIC ARRAY MATRIX MULTIPLICATION PASSED");
        else
            $fatal(1, "%0d mismatches in systolic array output", errors);
        $display("------------------------------");

        $finish;
    end

endmodule
