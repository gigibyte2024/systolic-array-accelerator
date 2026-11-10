
`timescale 1ns / 1ps

module input_buffer #(
    parameter N = 4,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,

    // Matrix loading interface
    input wire load_en,
    input wire signed [DATA_WIDTH-1:0] load_a,
    input wire signed [DATA_WIDTH-1:0] load_b,

    // Buffer status
    output reg buffer_ready,

    // Flattened matrix outputs
    output wire signed [(N*N*DATA_WIDTH)-1:0] matrix_a_flat,
    output wire signed [(N*N*DATA_WIDTH)-1:0] matrix_b_flat
);

    // Internal matrix storage
    reg signed [DATA_WIDTH-1:0] mem_a [0:N*N-1];
    reg signed [DATA_WIDTH-1:0] mem_b [0:N*N-1];

    // Sequential loading counter
    integer load_count;

    // Store one A/B element pair per enabled clock
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_count <= 0;
            buffer_ready <= 1'b0;
        end
        else if (load_en && !buffer_ready) begin

            mem_a[load_count] <= load_a;
            mem_b[load_count] <= load_b;

            if (load_count == (N*N - 1)) begin
                buffer_ready <= 1'b1;
            end

            load_count <= load_count + 1;
        end
    end

    // Flatten stored matrices into output vectors
    genvar g;
    generate
        for (g = 0; g < N*N; g = g + 1) begin : flatten
            assign matrix_a_flat[g*DATA_WIDTH +: DATA_WIDTH] = mem_a[g];
            assign matrix_b_flat[g*DATA_WIDTH +: DATA_WIDTH] = mem_b[g];
        end
    endgenerate

endmodule
