
`timescale 1ns / 1ps

module matrix_interface #(
    parameter N = 4,
    parameter DATA_WIDTH = 8,
    parameter CNT_WIDTH = 8
)(
    input wire buffer_rd_en,
    input wire [CNT_WIDTH-1:0] cycle_cnt,

    input wire signed [(N*N*DATA_WIDTH)-1:0] matrix_a_flat,
    input wire signed [(N*N*DATA_WIDTH)-1:0] matrix_b_flat,

    output reg signed [(N*DATA_WIDTH)-1:0] a_in,
    output reg signed [(N*DATA_WIDTH)-1:0] b_in
);

    integer r, c;
    integer a_k, b_k;

    always @(*) begin
        // Default: feed zeros during idle and pipeline flush.
        a_in = {(N*DATA_WIDTH){1'b0}};
        b_in = {(N*DATA_WIDTH){1'b0}};

        if (buffer_rd_en) begin

            // Skew matrix A: row r is delayed by r cycles.
            for (r = 0; r < N; r = r + 1) begin
                if (cycle_cnt >= r) begin
                    a_k = cycle_cnt - r;

                    if (a_k < N) begin
                        a_in[(r+1)*DATA_WIDTH-1 -: DATA_WIDTH] =
                            matrix_a_flat[((r*N+a_k)*DATA_WIDTH) +: DATA_WIDTH];
                    end
                end
            end

            // Skew matrix B: column c is delayed by c cycles.
            for (c = 0; c < N; c = c + 1) begin
                if (cycle_cnt >= c) begin
                    b_k = cycle_cnt - c;

                    if (b_k < N) begin
                        b_in[(c+1)*DATA_WIDTH-1 -: DATA_WIDTH] =
                            matrix_b_flat[((b_k*N+c)*DATA_WIDTH) +: DATA_WIDTH];
                    end
                end
            end

        end
    end

endmodule
