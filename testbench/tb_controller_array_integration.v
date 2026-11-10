`timescale 1ns/1ps

module tb_controller_array_integration;

    localparam N          = 4;
    localparam DATA_WIDTH = 8;
    localparam ACC_WIDTH  = 32;
    localparam CNT_WIDTH  = 8;

    reg clk;
    reg rst_n;
    reg start;
    reg buffer_ready;

    // Interconnect wires between Controller and Systolic Array
    wire array_rst;
    wire array_en;
    wire buffer_rd_en;
    wire done;
    wire busy;
    wire [CNT_WIDTH-1:0] cycle_cnt;

    // Array I/O
    reg signed [(N*DATA_WIDTH)-1:0] a_in;
    reg signed [(N*DATA_WIDTH)-1:0] b_in;
    wire signed [(N*N*ACC_WIDTH)-1:0] acc_out;

    // Test matrices
    reg signed [DATA_WIDTH-1:0] A [0:N-1][0:N-1];
    reg signed [DATA_WIDTH-1:0] B [0:N-1][0:N-1];
    reg signed [ACC_WIDTH-1:0]  C_expected [0:N-1][0:N-1];

    integer i, j, k, r, c, errors;

    // 1. Instantiate Member 4's Controller
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

    // 2. Instantiate Member 2's Systolic Array
    systolic_array #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_array (
        .clk(clk),
        .rst(array_rst),       // Array reset driven by controller
        .en(array_en),         // Array enable driven by controller
        .a_in(a_in),
        .b_in(b_in),
        .acc_out(acc_out)
    );

    // Clock generator (10ns period)
    always #5 clk = ~clk;

    // Function to extract individual PE accumulator
    function signed [ACC_WIDTH-1:0] get_acc(input integer row, input integer col);
        get_acc = acc_out[((row*N+col)+1)*ACC_WIDTH-1 -: ACC_WIDTH];
    endfunction

    // Skewed input streaming driven when controller asserts buffer_rd_en
    always @(posedge clk) begin
        if (buffer_rd_en) begin
            // cycle_cnt indicates current skewed step (0 to 2N-2)
            for (r = 0; r < N; r = r + 1) begin
                if (cycle_cnt - r >= 0 && cycle_cnt - r < N)
                    a_in[(r+1)*DATA_WIDTH-1 -: DATA_WIDTH] <= A[r][cycle_cnt - r];
                else
                    a_in[(r+1)*DATA_WIDTH-1 -: DATA_WIDTH] <= {DATA_WIDTH{1'b0}};
            end

            for (c = 0; c < N; c = c + 1) begin
                if (cycle_cnt - c >= 0 && cycle_cnt - c < N)
                    b_in[(c+1)*DATA_WIDTH-1 -: DATA_WIDTH] <= B[cycle_cnt - c][c];
                else
                    b_in[(c+1)*DATA_WIDTH-1 -: DATA_WIDTH] <= {DATA_WIDTH{1'b0}};
            end
        end
        else begin
            // When not reading from buffer (flush phase or idle), feed 0s
            a_in <= {(N*DATA_WIDTH){1'b0}};
            b_in <= {(N*DATA_WIDTH){1'b0}};
        end
    end

    initial begin
        $dumpfile("simulation/controller_array_integration_waveform.vcd");
        $dumpvars(0, tb_controller_array_integration);

        clk = 0;
        rst_n = 0;
        start = 0;
        buffer_ready = 0;
        a_in = 0;
        b_in = 0;
        errors = 0;

        // Initialize test matrices (A and B) and calculate reference result C
        // Matrix A:
        //  1  2  3  4
        //  5  6  7  8
        //  1 -1  2 -2
        //  3  0 -3  1
        A[0][0] =  1; A[0][1] =  2; A[0][2] =  3; A[0][3] =  4;
        A[1][0] =  5; A[1][1] =  6; A[1][2] =  7; A[1][3] =  8;
        A[2][0] =  1; A[2][1] = -1; A[2][2] =  2; A[2][3] = -2;
        A[3][0] =  3; A[3][1] =  0; A[3][2] = -3; A[3][3] =  1;

        // Matrix B:
        //  2  0  1  3
        // -1  4  2  1
        //  3  1 -2  0
        //  0 -2  1  2
        B[0][0] =  2; B[0][1] =  0; B[0][2] =  1; B[0][3] =  3;
        B[1][0] = -1; B[1][1] =  4; B[1][2] =  2; B[1][3] =  1;
        B[2][0] =  3; B[2][1] =  1; B[2][2] = -2; B[2][3] =  0;
        B[3][0] =  0; B[3][1] = -2; B[3][2] =  1; B[3][3] =  2;

        // Compute Expected C = A x B
        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                C_expected[i][j] = 0;
                for (k = 0; k < N; k = k + 1) begin
                    C_expected[i][j] = C_expected[i][j] + (A[i][k] * B[k][j]);
                end
            end
        end

        $display("=================================================================");
        $display("   TESTBENCH: Member 4 Controller + Member 2 Systolic Array");
        $display("=================================================================");

        // Reset the system
        #20;
        rst_n = 1;
        #10;

        // Start computation
        @(posedge clk);
        buffer_ready = 1;
        start = 1;
        @(posedge clk);
        start = 0;

        // Controller pulses array_rst during S_INIT
        @(posedge clk);

        // Verification of active COMPUTE window (3*N - 1 = 11 cycles for N=4)
        $display("[INFO] Starting computation across systolic array...");
        for (i = 0; i < (3 * N - 1); i = i + 1) begin
            #1;
            if (array_en !== 1'b1) begin
                $display("[FAIL] Cycle %0d: array_en is not asserted!", i);
                errors = errors + 1;
            end
            @(posedge clk);
        end

        // Check that 'done' is asserted immediately following (3*N - 1) compute cycles
        #1;
        if (done !== 1'b1) begin
            $display("[FAIL] 'done' signal was not asserted at cycle 3N-1!");
            errors = errors + 1;
        end else begin
            $display("[PASS] 'done' asserted precisely after 3N-1 (%0d) compute cycles.", (3*N-1));
        end

        // Check computed matrix C in accumulators against reference model
        $display("[INFO] Checking systolic array accumulator outputs against reference matrix product C:");
        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                if (get_acc(i, j) !== C_expected[i][j]) begin
                    $display("[FAIL] PE[%0d][%0d] = %0d, expected = %0d",
                             i, j, get_acc(i, j), C_expected[i][j]);
                    errors = errors + 1;
                end else begin
                    $display("[PASS] PE[%0d][%0d] = %0d (Matches reference)",
                             i, j, get_acc(i, j));
                end
            end
        end

        #20;
        $display("=================================================================");
        if (errors == 0) begin
            $display("   ALL CHECKS PASSED: Controller + Systolic Array Verified!");
        end else begin
            $display("   TEST FAILED with %0d errors.", errors);
        end
        $display("=================================================================");

        $finish;
    end

endmodule
