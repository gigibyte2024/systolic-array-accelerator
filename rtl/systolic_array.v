
module systolic_array #(
    parameter N          = 4,  // array size: N x N processing elements
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input wire clk,
    input wire rst,
    input wire en,

    // Row inputs: A operands enter from the left, one row per PE row.
    // a_in[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH] feeds row i.
    input wire signed [(N*DATA_WIDTH)-1:0] a_in,

    // Column inputs: B operands enter from the top, one column per PE column.
    // b_in[(j+1)*DATA_WIDTH-1 : j*DATA_WIDTH] feeds column j.
    input wire signed [(N*DATA_WIDTH)-1:0] b_in,

    // Flattened N x N accumulator outputs.
    // acc_out for PE[i][j] occupies bits [((i*N+j)+1)*ACC_WIDTH-1 : (i*N+j)*ACC_WIDTH]
    output wire signed [(N*N*ACC_WIDTH)-1:0] acc_out
);

    // Internal forwarding grids.
    // a_grid[i][j]: A value entering PE[i][j] (j = 0 is the array's left edge)
    // b_grid[i][j]: B value entering PE[i][j] (i = 0 is the array's top edge)
    wire signed [DATA_WIDTH-1:0] a_grid [0:N-1][0:N];
    wire signed [DATA_WIDTH-1:0] b_grid [0:N][0:N-1];

    genvar i, j;

    // Wire the array's left edge to the row inputs.
    generate
        for (i = 0; i < N; i = i + 1) begin : row_edge
            assign a_grid[i][0] = a_in[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
        end
    endgenerate

    // Wire the array's top edge to the column inputs.
    generate
        for (j = 0; j < N; j = j + 1) begin : col_edge
            assign b_grid[0][j] = b_in[(j+1)*DATA_WIDTH-1 -: DATA_WIDTH];
        end
    endgenerate

    // Instantiate the N x N grid of processing elements.
    generate
        for (i = 0; i < N; i = i + 1) begin : pe_row
            for (j = 0; j < N; j = j + 1) begin : pe_col

                wire signed [ACC_WIDTH-1:0] pe_acc;

                processing_element #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) pe_inst (
                    .clk(clk),
                    .rst(rst),
                    .en(en),
                    .a_in(a_grid[i][j]),
                    .b_in(b_grid[i][j]),
                    .a_out(a_grid[i][j+1]),
                    .b_out(b_grid[i+1][j]),
                    .acc(pe_acc)
                );

                assign acc_out[((i*N+j)+1)*ACC_WIDTH-1 -: ACC_WIDTH] = pe_acc;

            end
        end
    endgenerate

endmodule
