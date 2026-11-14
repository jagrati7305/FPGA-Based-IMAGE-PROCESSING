// vmorph5.v
// One vertical 5-tap morphology pass across 5 scan lines: erosion (AND5) or dilation (OR5).
// The four line ("column") buffers are ONE circular RAM, 4 bits wide:
//   tap[0] = input delayed 1 line, tap[1] = 2 lines, tap[2] = 3 lines, tap[3] = 4 lines.
// LINE_LEN = clocks per scan line INCLUDING blanking (= OW + OB).
// Output is centred: latency = 2*LINE_LEN + 1 clocks. Window is clipped at the frame
// border because blanking/idle clocks are fed as the neutral value (1 for AND, 0 for OR).
module vmorph5 #(
    parameter LINE_LEN  = 64,
    parameter IS_DILATE = 0
)(
    input  wire clk,
    input  wire bin_in,
    input  wire valid_in,
    output wire bin_out,
    output wire valid_out
);
    localparam NEUTRAL = IS_DILATE ? 1'b0 : 1'b1;
    wire x = valid_in ? bin_in : NEUTRAL;

    // four 1-bit line buffers in one RAM word: din = {tap2,tap1,tap0,x}, dout = {tap3,tap2,tap1,tap0}
    wire [3:0] tap;
    delay_line #(.WIDTH(4), .DELAY(LINE_LEN), .INIT_ONES(IS_DILATE ? 0 : 1)) u_lines (
        .clk(clk), .din({tap[2:0], x}), .dout(tap));

    wire [4:0] w = {tap, x};                   // 5 vertical neighbours
    reg o;
    always @(posedge clk) o <= IS_DILATE ? (|w) : (&w);

    wire [0:0] v;
    delay_line #(.WIDTH(1), .DELAY(2*LINE_LEN + 1)) u_valid (
        .clk(clk), .din(valid_in), .dout(v));

    assign valid_out = v[0];
    assign bin_out   = o & v[0];
endmodule
