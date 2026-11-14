`include "produce_params.vh"
// produce_top.v : asparagus grader, top level.
//   camera (emulated from a hex image) -> exposure control / LUT (invert) -> 9x1 greyscale closing
//   -> frame buffer (transpose) -> background subtraction + threshold -> 1x9 binary closing
//   -> 5x1 opening/closing -> edge detection (start / end / weight) + 2 histogram paths
//   -> result_uart (one packet per captured frame)
// The bypass ("Delay") path carries the thresholded bit to the histogram XOR.
module produce_top #(
    parameter W = `CFG_W, parameter H = `CFG_H, parameter HB = `CFG_HB, parameter VB = `CFG_VB,
    parameter OB = `CFG_OB, parameter N = `CFG_N, parameter RECIP = `CFG_RECIP,
    parameter SHIFT = `CFG_SHIFT, parameter MIN_LEVEL = `CFG_MIN_LEVEL, parameter CNT_W = `CFG_CNT_W, parameter OC_MODE = `CFG_OC_MODE,
    parameter CENTER = `CFG_CENTER, parameter CLKS_PER_BIT = `CFG_CPB,
    parameter SKIP_FRAMES = `CFG_SKIP,
    parameter FRAME_FILE = "data/frame.hex", parameter LUT_FILE = "data/lut.hex"
)(
    input  wire clk,
    input  wire rst,            // synchronous, active high
    output wire uart_tx,
    output wire exp_inc,        // exposure should go up   (drive the camera / light controller)
    output wire exp_dec,        // exposure should go down
    output wire busy            // 1 while a packet is being sent
);
    localparam LINE_LEN  = H + OB;                       // clocks per scan line after the transpose
    localparam CLOSE_LAT = 10;                           // latency of closing1x9_bin
    localparam OC_LAT    = (OC_MODE ? 4 : 2) * (2*LINE_LEN + 1);

    initial if (H > 255) begin $display("ERROR: H must be <= 255 (UART carries 8-bit positions)"); $finish; end

    // ---------------- camera ----------------
    wire [7:0]  cam_pix;  wire cam_valid, cam_vs, cam_hs;
    wire [10:0] cam_x;    wire [9:0] cam_y;
    cam_emu #(.W(W), .H(H), .HB(HB), .VB(VB), .FILE(FRAME_FILE)) u_cam (
        .clk(clk), .rst(rst), .pix(cam_pix), .valid(cam_valid), .vs(cam_vs), .hs(cam_hs),
        .x(cam_x), .y(cam_y));

    // ---------------- exposure control + LUT + greyscale closing ----------------
    exposure_control #(.CNT_W(CNT_W)) u_exp (.clk(clk), .rst(rst), .pix(cam_pix),
        .valid(cam_valid), .frame_start(cam_vs), .exp_inc(exp_inc), .exp_dec(exp_dec));

    wire [7:0] lut_pix;  wire lut_valid;
    lut_rom #(.FILE(LUT_FILE)) u_lut (.clk(clk), .pix_in(cam_pix), .valid_in(cam_valid),
        .pix_out(lut_pix), .valid_out(lut_valid));

    wire [7:0] cl_pix;   wire cl_valid;
    closing9x1 u_close (.clk(clk), .pix_in(lut_pix), .valid_in(lut_valid),
        .pix_out(cl_pix), .valid_out(cl_valid));

    // ---------------- frame buffer (transpose) ----------------
    wire [7:0] fb_pix;   wire fb_valid;
    frame_buffer #(.W(W), .H(H), .TRANSPOSE(1), .OB(OB)) u_fb (.clk(clk), .rst(rst),
        .pix_in(cl_pix), .valid_in(cl_valid), .pix_out(fb_pix), .valid_out(fb_valid));

    // ---------------- background subtraction, binary closing, 5x1 filter ----------------
    wire bg_bin, bg_valid;
    bg_threshold #(.N(N), .RECIP(RECIP), .SHIFT(SHIFT), .MIN_LEVEL(MIN_LEVEL)) u_bg (.clk(clk), .rst(rst),
        .pix(fb_pix), .valid(fb_valid), .bin_out(bg_bin), .valid_out(bg_valid));

    wire bc_bin, bc_valid;
    closing1x9_bin u_bc (.clk(clk), .rst(rst), .bin_in(bg_bin), .valid_in(bg_valid),
        .bin_out(bc_bin), .valid_out(bc_valid));

    wire oc_bin, oc_valid;
    opening_closing5x1 #(.LINE_LEN(LINE_LEN), .MODE(OC_MODE)) u_oc (.clk(clk),
        .bin_in(bc_bin), .valid_in(bc_valid), .bin_out(oc_bin), .valid_out(oc_valid));

    // ---------------- delay (bypass) ----------------
    wire [1:0] dly_o;
    delay_line #(.WIDTH(2), .DELAY(CLOSE_LAT + OC_LAT)) u_dly (clk, {bg_valid, bg_bin}, dly_o);

    // ---------------- edge detection ----------------
    wire ed_ce, ed_lv, ed_lf, ed_wv;  wire [8:0] ed_ls, ed_le;  wire [31:0] ed_w;
    edge_detect #(.OW(H), .OH(W), .AW(8), .CENTER(CENTER)) u_edge (
        .clk(clk), .rst(rst), .bin(oc_bin), .valid(oc_valid), .ce(ed_ce),
        .line_valid(ed_lv), .line_start(ed_ls), .line_end(ed_le), .line_found(ed_lf),
        .weight_valid(ed_wv), .weight(ed_w));

    // ---------------- histogram paths (one result per frame) ----------------
    wire hs_valid, hs_ovr;  wire [7:0] hs_y;  wire [23:0] hs_tot;      // silhouette projection
    hist_path #(.OW(H), .OH(W), .AW(8), .GROUP_FRAME(1), .FLAG_SEL(1)) u_hist_sil (
        .clk(clk), .rst(rst), .raw_bin(dly_o[0]), .clean_bin(oc_bin), .valid(oc_valid),
        .ce(ed_ce), .med_valid(hs_valid), .med_y(hs_y), .med_total(hs_tot), .overrun(hs_ovr));

    wire hx_valid, hx_ovr;  wire [7:0] hx_y;  wire [23:0] hx_tot;      // pixels changed by cleaning
    hist_path #(.OW(H), .OH(W), .AW(8), .GROUP_FRAME(1), .FLAG_SEL(0)) u_hist_xor (
        .clk(clk), .rst(rst), .raw_bin(dly_o[0]), .clean_bin(oc_bin), .valid(oc_valid),
        .ce(ed_ce), .med_valid(hx_valid), .med_y(hx_y), .med_total(hx_tot), .overrun(hx_ovr));

    // ---------------- results -> PC ----------------
    result_uart #(.NLINES(W), .CLKS_PER_BIT(CLKS_PER_BIT), .SKIP_FRAMES(SKIP_FRAMES)) u_res (
        .clk(clk), .rst(rst),
        .line_valid(ed_lv), .line_start(ed_ls), .line_end(ed_le),
        .weight_valid(ed_wv), .weight(ed_w),
        .sil_valid(hs_valid), .sil_y(hs_y), .sil_total(hs_tot),
        .xor_valid(hx_valid), .xor_total(hx_tot),
        .exp_flags({exp_dec, exp_inc}), .tx(uart_tx), .busy(busy));
endmodule
