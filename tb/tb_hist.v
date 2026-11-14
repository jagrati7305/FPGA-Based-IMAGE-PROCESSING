`timescale 1ns/1ps
// Standalone test of hist_path: random flags, per-line and per-group (G lines) histograms.
module tb_hist;
    parameter OW = 48, OB = 16, G = 5, NG = 12;
    localparam L = OW + OB;
    reg clk = 0, rst = 1; always #5 clk = ~clk;
    reg clean = 0, valid = 0, ce = 1;

    wire mv_g, mv_l, ovr_g, ovr_l; wire [7:0] my_g, my_l; wire [23:0] mt_g, mt_l;
    hist_path #(.OW(OW), .OH(G), .GROUP_FRAME(1), .FLAG_SEL(1)) u_grp (clk, rst, 1'b0, clean, valid, ce, mv_g, my_g, mt_g, ovr_g);
    hist_path #(.OW(OW), .OH(G), .GROUP_FRAME(0), .FLAG_SEL(1)) u_lin (clk, rst, 1'b0, clean, valid, ce, mv_l, my_l, mt_l, ovr_l);
    // third instance: XOR mode (raw = random, clean = random), checked only for "no overrun"
    wire mv_x, ovr_x; wire [7:0] my_x; wire [23:0] mt_x;
    hist_path #(.OW(OW), .OH(G), .GROUP_FRAME(1), .FLAG_SEL(0)) u_xor (clk, rst, clean ^ ce, clean, valid, 1'b1, mv_x, my_x, mt_x, ovr_x);

    integer fin, fg, fl, g, ln, c, dens;
    initial begin
        fin = $fopen("out/h_in.txt","w"); fg = $fopen("out/h_grp.txt","w"); fl = $fopen("out/h_line.txt","w");
        repeat (5) @(posedge clk); rst = 0; repeat (3) @(posedge clk);
        for (g = 0; g < NG; g = g + 1) begin
            dens = (g % 3 == 0) ? 63 : 3;                 // sparse groups give empty lines
            for (ln = 0; ln < G; ln = ln + 1)
                for (c = 0; c < L; c = c + 1) begin
                    valid <= (c < OW);
                    clean <= (c < OW) && (($random & dens) == 0);
                    ce    <= (($random & 7) != 0);
                    @(posedge clk);
                    if (valid) $fwrite(fin, "%0d\n", clean & ce);   // values that were just applied
                end
            valid <= 0; clean <= 0;
            repeat (3*L) @(posedge clk);
        end
        repeat (2*L) @(posedge clk);
        $display("overrun flags: grp=%b line=%b xor=%b", ovr_g, ovr_l, ovr_x);
        $fclose(fin); $fclose(fg); $fclose(fl);
        $finish;
    end
    always @(posedge clk) begin
        if (mv_g) $fwrite(fg, "%0d %0d\n", my_g, mt_g);
        if (mv_l) $fwrite(fl, "%0d %0d\n", my_l, mt_l);
    end
endmodule
