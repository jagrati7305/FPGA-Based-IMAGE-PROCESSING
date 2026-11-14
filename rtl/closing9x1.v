module closing9x1 (
    input  wire clk, input wire [7:0] pix_in, input wire valid_in,
    output wire [7:0] pix_out, output wire valid_out);
    wire [7:0] min_in = valid_in ? pix_in : 8'hFF;
    wire [7:0] m1, m2, m3, m4;
    win2 #(.D(1), .IS_MAX(0)) u_min1 (clk, min_in, m1);
    win2 #(.D(2), .IS_MAX(0)) u_min2 (clk, m1,     m2);
    win2 #(.D(4), .IS_MAX(0)) u_min3 (clk, m2,     m3);
    win2 #(.D(1), .IS_MAX(0)) u_min4 (clk, m3,     m4);
    reg [3:0] v_min;
    always @(posedge clk) v_min <= {v_min[2:0], valid_in};
    wire v_after_min = v_min[3];
    wire [7:0] max_in = v_after_min ? m4 : 8'h00;
    wire [7:0] x1, x2, x3, x4;
    win2 #(.D(1), .IS_MAX(1)) u_max1 (clk, max_in, x1);
    win2 #(.D(2), .IS_MAX(1)) u_max2 (clk, x1,     x2);
    win2 #(.D(4), .IS_MAX(1)) u_max3 (clk, x2,     x3);
    win2 #(.D(1), .IS_MAX(1)) u_max4 (clk, x3,     x4);
    reg [3:0] v_max;
    always @(posedge clk) v_max <= {v_max[2:0], v_after_min};
    assign pix_out   = x4;
    assign valid_out = v_max[3];
endmodule
