`timescale 1ns/1ps

module tb_member5_verification;
    parameter N = 4;
    parameter DATA_WIDTH = 8;
    parameter ACC_WIDTH = 32;
    parameter CNT_WIDTH = 8;

    reg clk, rst_n, start, load_en;
    reg signed [DATA_WIDTH-1:0] load_a, load_b;
    wire buffer_ready, array_rst, array_en, buffer_rd_en, done, busy;
    wire [CNT_WIDTH-1:0] cycle_cnt;
    wire signed [(N*N*DATA_WIDTH)-1:0] matrix_a_flat, matrix_b_flat;
    wire signed [(N*DATA_WIDTH)-1:0] a_in, b_in;
    wire signed [(N*N*ACC_WIDTH)-1:0] acc_out;

    reg signed [DATA_WIDTH-1:0] A [0:N*N-1];
    reg signed [DATA_WIDTH-1:0] B [0:N*N-1];
    integer expected [0:N*N-1];
    integer r, c, k, idx, errors, compute_cycles, stream_cycles, timeout;
    reg [8*80-1:0] vcd_name;

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
    always @(posedge clk) if (array_en) compute_cycles = compute_cycles + 1;
    always @(negedge clk) begin
        if (array_en) begin
            if (cycle_cnt !== stream_cycles)
                $fatal(1, "N=%0d cycle counter=%0d expected=%0d",
                       N, cycle_cnt, stream_cycles);
            if (buffer_rd_en !== (stream_cycles < (2*N-1)))
                $fatal(1, "N=%0d incorrect feed/flush control at cycle %0d",
                       N, stream_cycles);
            stream_cycles = stream_cycles + 1;
        end
    end

    function signed [ACC_WIDTH-1:0] get_acc;
        input integer row, col;
        begin
            get_acc = acc_out[((row*N+col)+1)*ACC_WIDTH-1 -: ACC_WIDTH];
        end
    endfunction

    initial begin
        $sformat(vcd_name, "report/member5/waveforms/member5_N%0d.vcd", N);
        $dumpfile(vcd_name);
        $dumpvars(0, tb_member5_verification);
        clk = 0; rst_n = 0; start = 0; load_en = 0;
        load_a = 0; load_b = 0; errors = 0;
        compute_cycles = 0; stream_cycles = 0;

        // Deterministic signed matrices with varied values for reproducibility.
        for (r = 0; r < N; r = r + 1) begin
            for (c = 0; c < N; c = c + 1) begin
                A[r*N+c] = ((r*7 + c*5) % 13) - 6;
                B[r*N+c] = ((r*4 + c*3) % 11) - 5;
            end
        end
        for (r = 0; r < N; r = r + 1) begin
            for (c = 0; c < N; c = c + 1) begin
                expected[r*N+c] = 0;
                for (k = 0; k < N; k = k + 1)
                    expected[r*N+c] = expected[r*N+c] + A[r*N+k] * B[k*N+c];
            end
        end

        repeat (2) @(negedge clk);
        rst_n = 1;
        for (idx = 0; idx < N*N; idx = idx + 1) begin
            @(negedge clk);
            load_en = 1;
            load_a = A[idx];
            load_b = B[idx];
        end
        @(negedge clk);
        load_en = 0; load_a = 0; load_b = 0;
        #1;
        if (buffer_ready !== 1'b1) $fatal(1, "N=%0d buffer failed to become ready", N);

        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;
        timeout = 0;
        while (done !== 1'b1 && timeout < (3*N+8)) begin
            @(negedge clk);
            timeout = timeout + 1;
        end
        #1;
        if (done !== 1'b1) $fatal(1, "N=%0d controller timeout", N);
        if (compute_cycles != (3*N-1) || stream_cycles != (3*N-1))
            $fatal(1, "N=%0d compute cycles=%0d expected=%0d", N, compute_cycles, 3*N-1);

        for (r = 0; r < N; r = r + 1) begin
            for (c = 0; c < N; c = c + 1) begin
                if (get_acc(r,c) !== expected[r*N+c]) begin
                    $display("FAIL N=%0d C[%0d][%0d]=%0d expected=%0d", N, r, c,
                             get_acc(r,c), expected[r*N+c]);
                    errors = errors + 1;
                end
            end
        end
        if (errors != 0) $fatal(1, "N=%0d result mismatches=%0d", N, errors);

        $display("PASS N=%0d: %0d outputs, %0d compute cycles, %0d init+compute cycles",
                 N, N*N, compute_cycles, 3*N);
        $display("PERF N=%0d: %0d MAC operations / %0d compute cycles = %.3f MAC/cycle",
                 N, N*N*N, compute_cycles, (1.0*N*N*N)/compute_cycles);
        $finish;
    end
endmodule
