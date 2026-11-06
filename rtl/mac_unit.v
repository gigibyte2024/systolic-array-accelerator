
module mac_unit (
    input wire clk,
    input wire rst,
    input wire en,

    input wire signed [7:0] a,
    input wire signed [7:0] b,

    output reg signed [31:0] acc
);

    wire signed [15:0] product;

    assign product = a * b;

    always @(posedge clk) begin
        if (rst) begin
            acc <= 32'sd0;
        end
        else if (en) begin
            acc <= acc + product;
        end
    end

endmodule
