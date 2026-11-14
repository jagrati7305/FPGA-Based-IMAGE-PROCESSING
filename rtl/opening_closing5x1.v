// opening_closing5x1.v
// 5x1 vertical opening (erode -> dilate), optionally followed by a closing (dilate -> erode).
//   MODE = 0 : opening only         latency = 2 * (2*LINE_LEN+1)
//   MODE = 1 : opening then closing latency = 4 * (2*LINE_LEN+1)
module opening_closing5x1 #(
    parameter LINE_LEN = 64,
    parameter MODE     = 1
)(
    input  wire clk,
    input  wire bin_in,
    input  wire valid_in,
    output wire bin_out,
    output wire valid_out
);
    wire b1, v1, b2, v2, b3, v3, b4, v4;

    vmorph5 #(.LINE_LEN(LINE_LEN), .IS_DILATE(0)) u_erode1  (clk, bin_in, valid_in, b1, v1);
    vmorph5 #(.LINE_LEN(LINE_LEN), .IS_DILATE(1)) u_dilate1 (clk, b1,     v1,       b2, v2);

    generate
        if (MODE != 0) begin : g_close
            vmorph5 #(.LINE_LEN(LINE_LEN), .IS_DILATE(1)) u_dilate2 (clk, b2, v2, b3, v3);
            vmorph5 #(.LINE_LEN(LINE_LEN), .IS_DILATE(0)) u_erode2  (clk, b3, v3, b4, v4);
            assign bin_out   = b4;
            assign valid_out = v4;
        end else begin : g_open_only
            assign bin_out   = b2;
            assign valid_out = v2;
        end
    endgenerate
endmodule
