
module processing_element #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input wire clk,
    input wire rst,
    input wire en,

    input wire signed [DATA_WIDTH-1:0] a_in,
    input wire signed [DATA_WIDTH-1:0] b_in,

    output reg signed [DATA_WIDTH-1:0] a_out,
    output reg signed [DATA_WIDTH-1:0] b_out,

    output wire signed [ACC_WIDTH-1:0] acc
);

    // Forward input data to the neighbouring PE
    always @(posedge clk) begin
        if (rst) begin
            a_out <= {DATA_WIDTH{1'b0}};
            b_out <= {DATA_WIDTH{1'b0}};
        end
        else begin
            a_out <= a_in;
            b_out <= b_in;
        end
    end

    // Parameterised MAC unit
    mac_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) mac_inst (
        .clk(clk),
        .rst(rst),
        .en(en),
        .a(a_in),
        .b(b_in),
        .acc(acc)
    );

endmodule

