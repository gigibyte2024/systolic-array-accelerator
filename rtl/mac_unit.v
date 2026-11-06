module mac_unit #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input wire clk,
    input wire rst,
    input wire en,

    input wire signed [DATA_WIDTH-1:0] a,
    input wire signed [DATA_WIDTH-1:0] b,

    output reg signed [ACC_WIDTH-1:0] acc
);

    // Product width is twice the input width
    wire signed [(2*DATA_WIDTH)-1:0] product;

    // Multiply input operands
    assign product = a * b;

    // Accumulate product on each enabled clock cycle
    always @(posedge clk) begin
        if (rst)
            acc <= {ACC_WIDTH{1'b0}};

        else if (en)
            acc <= acc + product;
    end

endmodule
