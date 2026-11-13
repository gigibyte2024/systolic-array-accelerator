
`timescale 1ns / 1ps

module tb_member3_integration;

    localparam N = 4;
    localparam DATA_WIDTH = 8;
    localparam ACC_WIDTH = 32;
    localparam CNT_WIDTH = 8;

    reg clk, rst_n, start;
    reg load_en;
    reg signed [DATA_WIDTH-1:0] load_a, load_b;

    wire buffer_ready;
    wire array_rst, array_en, buffer_rd_en;
    wire done, busy;
    wire [CNT_WIDTH-1:0] cycle_cnt;

    wire signed [(N*DATA_WIDTH)-1:0] a_in, b_in;
    wire signed [(N*N*DATA_WIDTH)-1:0] matrix_a_flat;
    wire signed [(N*N*DATA_WIDTH)-1:0] matrix_b_flat;
    wire signed [(N*N*ACC_WIDTH)-1:0] acc_out;

    reg signed [DATA_WIDTH-1:0] A [0:N*N-1];
    reg signed [DATA_WIDTH-1:0] B [0:N*N-1];
    reg signed [ACC_WIDTH-1:0] expected [0:N-1][0:N-1];

    integer i, j, k, idx, errors, timeout;

    // Member 3: Input buffer
    input_buffer #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .load_en(load_en),
        .load_a(load_a),
        .load_b(load_b),
        .buffer_ready(buffer_ready),
        .matrix_a_flat(matrix_a_flat),
        .matrix_b_flat(matrix_b_flat)
    );

    // Member 3: Matrix interface
    matrix_interface #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .CNT_WIDTH(CNT_WIDTH)
    ) u_interface (
        .buffer_rd_en(buffer_rd_en),
        .cycle_cnt(cycle_cnt),
        .matrix_a_flat(matrix_a_flat),
        .matrix_b_flat(matrix_b_flat),
        .a_in(a_in),
        .b_in(b_in)
    );

    // Member 4: Controller
    systolic_controller #(
        .N(N),
        .CNT_WIDTH(CNT_WIDTH)
    ) u_controller (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .buffer_ready(buffer_ready),
        .array_rst(array_rst),
        .array_en(array_en),
        .buffer_rd_en(buffer_rd_en),
        .done(done),
        .busy(busy),
        .cycle_cnt(cycle_cnt)
    );

    // Member 2: Systolic array
    systolic_array #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_array (
        .clk(clk),
        .rst(array_rst),
        .en(array_en),
        .a_in(a_in),
        .b_in(b_in),
        .acc_out(acc_out)
    );

    always #5 clk = ~clk;

    function signed [ACC_WIDTH-1:0] get_acc;
        input integer row;
        input integer col;
        begin
            get_acc =
                acc_out[((row*N+col)+1)*ACC_WIDTH-1 -: ACC_WIDTH];
        end
    endfunction

    initial begin
        $dumpfile("report/member3/waveforms/member3_integration.vcd");
        $dumpvars(0, tb_member3_integration);

        clk = 0;
        rst_n = 0;
        start = 0;
        load_en = 0;
        load_a = 0;
        load_b = 0;
        errors = 0;

        // Matrix A
        A[0]=1;  A[1]=2;  A[2]=3;  A[3]=4;
        A[4]=5;  A[5]=6;  A[6]=7;  A[7]=8;
        A[8]=1;  A[9]=-1; A[10]=2; A[11]=-2;
        A[12]=3; A[13]=0; A[14]=-3; A[15]=1;

        // Matrix B
        B[0]=2;  B[1]=0;  B[2]=1;  B[3]=3;
        B[4]=-1; B[5]=4;  B[6]=2;  B[7]=1;
        B[8]=3;  B[9]=1;  B[10]=-2; B[11]=0;
        B[12]=0; B[13]=-2; B[14]=1; B[15]=2;

        // Calculate reference matrix C = A x B.
        for (i=0; i<N; i=i+1) begin
            for (j=0; j<N; j=j+1) begin
                expected[i][j] = 0;
                for (k=0; k<N; k=k+1)
                    expected[i][j] =
                        expected[i][j] +
                        (A[i*N+k] * B[k*N+j]);
            end
        end

        // Reset controller and input buffer.
        repeat (2) @(negedge clk);
        rst_n = 1;

        // Load the two matrices, one element pair per clock.
        for (idx=0; idx<N*N; idx=idx+1) begin
            @(negedge clk);
            load_en = 1;
            load_a = A[idx];
            load_b = B[idx];
            @(posedge clk);
        end

        @(negedge clk);
        load_en = 0;
        load_a = 0;
        load_b = 0;

        #1;
        if (buffer_ready !== 1'b1)
            $fatal(1, "FAIL: Input buffer did not become ready");

        $display("PASS: Both matrices loaded into input buffer");

        // Start the controller.
        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        // Wait for completion, with a timeout.
        timeout = 0;
        while ((done !== 1'b1) && (timeout < 30)) begin
            @(negedge clk);
            timeout = timeout + 1;
        end

        #1;
        if (done !== 1'b1)
            $fatal(1, "FAIL: Controller did not assert done");

        $display("PASS: Controller completed computation");

        // Check all systolic array results.
        for (i=0; i<N; i=i+1) begin
            for (j=0; j<N; j=j+1) begin
                if (get_acc(i,j) !== expected[i][j]) begin
                    $display(
                        "FAIL: C[%0d][%0d] = %0d, expected %0d",
                        i, j, get_acc(i,j), expected[i][j]
                    );
                    errors = errors + 1;
                end else begin
                    $display(
                        "PASS: C[%0d][%0d] = %0d",
                        i, j, get_acc(i,j)
                    );
                end
            end
        end

        if (errors == 0)
            $display("MEMBER 3 INTEGRATION TEST PASSED");
        else
            $display("MEMBER 3 INTEGRATION TEST FAILED: %0d errors", errors);

        $finish;
    end

endmodule
