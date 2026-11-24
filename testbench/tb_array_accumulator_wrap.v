`timescale 1ns/1ps

// Accumulator wrap-around (overflow) test for the systolic array.
//
// The MAC accumulator is a signed ACC_WIDTH-bit register with no
// saturation, so a sum that goes past the signed range wraps around in
// two's complement. A single 4x4 multiply cannot overflow 32 bits
// (worst case 4 * 16384 = 65536), but an AI layer split into many tiles
// along the inner dimension K keeps adding into the same accumulators.
//
// Part 1 - 32-bit accumulator, long stream:
//   a_in and b_in are held at -128 on every row and column, so once a PE
//   has data it adds (-128)(-128) = 16384 every cycle. PE[i][j] sees
//   valid A after j cycles and valid B after i cycles, so after n cycles
//   it holds 16384 * (n - max(i, j)) modulo 2^32.
//   2^31 / 16384 = 131072 products, so PE[0][0] reaches the largest
//   positive step (2^31 - 16384) at n = 131071 and wraps to -2^31 at
//   n = 131072. All 16 PEs are then checked against the modular model.
//
// Part 2 - 16-bit accumulator, ordinary 4x4 multiply:
//   With ACC_WIDTH = 16 the wrap shows up in a single multiply:
//   all -128: true 65536 -> stored 0;  all 127: true 64516 -> stored -1020.
module tb_array_accumulator_wrap;

    localparam N          = 4;
    localparam DATA_WIDTH = 8;
    localparam ACC32      = 32;
    localparam ACC16      = 16;
    localparam STEP       = 16384;          // (-128) * (-128)
    localparam WRAP_N     = 131072;         // 2^31 / STEP
    localparam EXTRA      = 50;             // run a little past the wrap

    reg clk;
    reg rst32, en32, rst16, en16;
    reg  signed [(N*DATA_WIDTH)-1:0]   a32, b32, a16, b16;
    wire signed [(N*N*ACC32)-1:0]      acc32;
    wire signed [(N*N*ACC16)-1:0]      acc16;

    integer i, j, k, n, t, errors, case_id;
    reg signed [63:0] model;
    reg signed [ACC32-1:0] expected32;
    reg signed [ACC16-1:0] expected16;
    reg signed [ACC32-1:0] true_sum;

    reg signed [DATA_WIDTH-1:0] A [0:N-1][0:N-1];
    reg signed [DATA_WIDTH-1:0] B [0:N-1][0:N-1];

    systolic_array #(.N(N), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC32)) dut32 (
        .clk(clk), .rst(rst32), .en(en32),
        .a_in(a32), .b_in(b32), .acc_out(acc32)
    );

    systolic_array #(.N(N), .DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC16)) dut16 (
        .clk(clk), .rst(rst16), .en(en16),
        .a_in(a16), .b_in(b16), .acc_out(acc16)
    );

    always #5 clk = ~clk;

    function signed [ACC32-1:0] get32(input integer r, input integer c);
        get32 = acc32[((r*N+c)+1)*ACC32-1 -: ACC32];
    endfunction

    function signed [ACC16-1:0] get16(input integer r, input integer c);
        get16 = acc16[((r*N+c)+1)*ACC16-1 -: ACC16];
    endfunction

    function integer max2(input integer x, input integer y);
        max2 = (x > y) ? x : y;
    endfunction

    // Skewed feed for the 16-bit array.
    task drive16(input integer t);
        integer r, c;
        begin
            a16 = {(N*DATA_WIDTH){1'b0}};
            b16 = {(N*DATA_WIDTH){1'b0}};
            for (r = 0; r < N; r = r + 1)
                if (t - r >= 0 && t - r < N)
                    a16[(r+1)*DATA_WIDTH-1 -: DATA_WIDTH] = A[r][t-r];
            for (c = 0; c < N; c = c + 1)
                if (t - c >= 0 && t - c < N)
                    b16[(c+1)*DATA_WIDTH-1 -: DATA_WIDTH] = B[t-c][c];
        end
    endtask

    initial begin
        clk = 0; errors = 0;
        rst32 = 1; en32 = 0; a32 = 0; b32 = 0;
        rst16 = 1; en16 = 0; a16 = 0; b16 = 0;
        @(negedge clk);

        // ---------------- Part 1: 32-bit long stream ----------------
        rst32 = 0; en32 = 1;
        a32 = {N{8'sh80}};   // -128 on every row
        b32 = {N{8'sh80}};   // -128 on every column

        for (n = 1; n <= WRAP_N + EXTRA; n = n + 1) begin
            @(negedge clk);   // n rising edges have now happened

            if (n == WRAP_N - 1) begin
                if (get32(0, 0) !== 32'sd2147467264) begin
                    $display("FAIL: before wrap PE[0][0] = %0d, expected 2147467264", get32(0, 0));
                    errors = errors + 1;
                end else
                    $display("PASS n=%0d: PE[0][0] = %0d (largest value before wrap)", n, get32(0, 0));
            end

            if (n == WRAP_N) begin
                if (get32(0, 0) !== -32'sd2147483648) begin
                    $display("FAIL: at wrap PE[0][0] = %0d, expected -2147483648", get32(0, 0));
                    errors = errors + 1;
                end else
                    $display("PASS n=%0d: PE[0][0] = %0d (wrapped to most negative)", n, get32(0, 0));
            end
        end

        // Every PE against the modular model.
        n = WRAP_N + EXTRA;
        for (i = 0; i < N; i = i + 1)
            for (j = 0; j < N; j = j + 1) begin
                model      = n - max2(i, j);
                model      = model * STEP;   // 64-bit true sum
                expected32 = model[ACC32-1:0];
                if (get32(i, j) !== expected32) begin
                    $display("FAIL: PE[%0d][%0d] = %0d, expected %0d (true sum %0d)",
                             i, j, get32(i, j), expected32, model);
                    errors = errors + 1;
                end
            end
        model = n;
        model = model * STEP;   // 64-bit true sum for PE[0][0]
        $display("Part 1 checked all 16 PEs at n=%0d (true sum for PE[0][0] = %0d, stored %0d)",
                 n, model, get32(0, 0));
        en32 = 0; a32 = 0; b32 = 0;

        // ---------------- Part 2: 16-bit single multiply ----------------
        for (case_id = 0; case_id < 2; case_id = case_id + 1) begin
            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1) begin
                    A[i][j] = (case_id == 0) ? -128 : 127;
                    B[i][j] = (case_id == 0) ? -128 : 127;
                end

            rst16 = 1; en16 = 0; a16 = 0; b16 = 0;
            @(negedge clk);
            rst16 = 0; en16 = 1;
            for (t = 0; t < 2*N - 1; t = t + 1) begin
                drive16(t);
                @(negedge clk);
            end
            a16 = 0; b16 = 0;
            repeat (N) @(negedge clk);

            for (i = 0; i < N; i = i + 1)
                for (j = 0; j < N; j = j + 1) begin
                    true_sum = 0;
                    for (k = 0; k < N; k = k + 1)
                        true_sum = true_sum + A[i][k] * B[k][j];
                    expected16 = true_sum[ACC16-1:0];
                    if (get16(i, j) !== expected16) begin
                        $display("FAIL 16-bit case %0d: C[%0d][%0d] = %0d, expected %0d",
                                 case_id, i, j, get16(i, j), expected16);
                        errors = errors + 1;
                    end
                end
            $display("Part 2 case %0d: true sum %0d, 16-bit accumulator holds %0d",
                     case_id, true_sum, get16(0, 0));
        end

        $display("------------------------------");
        if (errors == 0)
            $display("ACCUMULATOR WRAP-AROUND TEST PASSED");
        else
            $fatal(1, "%0d mismatches in wrap-around test", errors);
        $display("------------------------------");
        $finish;
    end

endmodule
