
module processing_element (
    input wire clk,
    input wire rst,
    input wire en,

    input wire signed [7:0] a_in,
    input wire signed [7:0] b_in,

    output reg signed [7:0] a_out,
    output reg signed [7:0] b_out,

    output wire signed [31:0] acc
);

    // Forward input data to the neighbouring PE
    always @(posedge clk) begin
        if (rst) begin
            a_out <= 8'sd0;
            b_out <= 8'sd0;
        end
        else begin
            a_out <= a_in;
            b_out <= b_in;
        end
    end

    // MAC unit performs multiplication and accumulation
    mac_unit mac_inst (
        .clk(clk),
        .rst(rst),
        .en(en),
        .a(a_in),
        .b(b_in),
        .acc(acc)
    );

endmodule

