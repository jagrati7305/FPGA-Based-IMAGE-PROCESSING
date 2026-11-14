module win2 #(parameter W=8, parameter D=1, parameter IS_MAX=0)(
    input  wire clk, input wire [W-1:0] in, output reg [W-1:0] out);
    reg [W-1:0] dly [0:D-1];
    integer i;
    always @(posedge clk) begin
        dly[0] <= in;
        for (i = 1; i < D; i = i + 1) dly[i] <= dly[i-1];
    end
    wire [W-1:0] a = in;
    wire [W-1:0] b = dly[D-1];
    wire a_gt_b = (a > b);
    always @(posedge clk)
        out <= IS_MAX ? (a_gt_b ? a : b) : (a_gt_b ? b : a);
endmodule
