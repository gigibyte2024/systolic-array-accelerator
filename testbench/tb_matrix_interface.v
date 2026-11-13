
`timescale 1ns / 1ps

module tb_matrix_interface;

    parameter N = 4;
    parameter DATA_WIDTH = 8;
    parameter CNT_WIDTH = 8;

    reg buffer_rd_en;
    reg [CNT_WIDTH-1:0] cycle_cnt;

    reg signed [(N*N*DATA_WIDTH)-1:0] matrix_a_flat;
    reg signed [(N*N*DATA_WIDTH)-1:0] matrix_b_flat;

    wire signed [(N*DATA_WIDTH)-1:0] a_in;
    wire signed [(N*DATA_WIDTH)-1:0] b_in;

    integer r, c, k;
    integer expected;
    integer errors;

    matrix_interface #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .CNT_WIDTH(CNT_WIDTH)
    ) uut (
        .buffer_rd_en(buffer_rd_en),
        .cycle_cnt(cycle_cnt),
        .matrix_a_flat(matrix_a_flat),
        .matrix_b_flat(matrix_b_flat),
        .a_in(a_in),
        .b_in(b_in)
    );

    initial begin
        $dumpfile("report/member3/waveforms/matrix_interface_waveform.vcd");
        $dumpvars(0, tb_matrix_interface);

        errors = 0;
        buffer_rd_en = 0;
        cycle_cnt = 0;
        matrix_a_flat = 0;
        matrix_b_flat = 0;

        // Initialize test matrices with distinct values.
        for (r = 0; r < N; r = r + 1) begin
            for (c = 0; c < N; c = c + 1) begin
                matrix_a_flat[((r*N+c)*DATA_WIDTH) +: DATA_WIDTH]
                    = r*10 + c + 1;

                matrix_b_flat[((r*N+c)*DATA_WIDTH) +: DATA_WIDTH]
                    = r*10 + c + 1;
            end
        end

        // Check all 2N-1 skewed feed cycles.
        buffer_rd_en = 1;

        for (k = 0; k < (2*N-1); k = k + 1) begin
            cycle_cnt = k;
            #1;

            for (r = 0; r < N; r = r + 1) begin
                expected = 0;

                if ((k-r) >= 0 && (k-r) < N)
                    expected = r*10 + (k-r) + 1;

                if ($signed(a_in[(r+1)*DATA_WIDTH-1 -: DATA_WIDTH])
                    !== expected) begin
                    $display("FAIL: A row %0d cycle %0d", r, k);
                    errors = errors + 1;
                end
            end

            for (c = 0; c < N; c = c + 1) begin
                expected = 0;

                if ((k-c) >= 0 && (k-c) < N)
                    expected = (k-c)*10 + c + 1;

                if ($signed(b_in[(c+1)*DATA_WIDTH-1 -: DATA_WIDTH])
                    !== expected) begin
                    $display("FAIL: B column %0d cycle %0d", c, k);
                    errors = errors + 1;
                end
            end
        end

        // Check that outputs are zero when reading is disabled.
        buffer_rd_en = 0;
        #1;

        if (a_in !== 0 || b_in !== 0) begin
            $display("FAIL: Outputs should be zero when buffer_rd_en is low");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("MATRIX INTERFACE TEST PASSED");
        else
            $display("MATRIX INTERFACE TEST FAILED: %0d errors", errors);

        $finish;
    end

endmodule
