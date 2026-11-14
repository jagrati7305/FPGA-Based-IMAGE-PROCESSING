`timescale 1ns/1ps
// Standalone test of edge_detect with random runs.
module tb_edge;
    parameter OW = 48, OB = 16, OH = 6, NF = 8, CENTER = 24;
    localparam L = OW + OB;
    reg clk = 0, rst = 1; always #5 clk = ~clk;
    reg bin = 0, valid = 0;
    wire ce, lv, lf, wv; wire [8:0] ls, le; wire [31:0] w;
    edge_detect #(.OW(OW), .OH(OH), .AW(8), .CENTER(CENTER)) dut (
        clk, rst, bin, valid, ce, lv, ls, le, lf, wv, w);

    integer fin, fce, fl, fw, f, ln, c, mode;
    reg cur;
    initial begin
        fin = $fopen("out/e_in.txt","w"); fce = $fopen("out/e_ce.txt","w");
        fl  = $fopen("out/e_line.txt","w"); fw = $fopen("out/e_w.txt","w");
        repeat (5) @(posedge clk); rst = 0; repeat (3) @(posedge clk);
        for (f = 0; f < NF; f = f + 1) begin
            for (ln = 0; ln < OH; ln = ln + 1) begin
                mode = $random & 7;                       // 0: all ones, 1: all zeros, else random runs
                cur  = $random;
                for (c = 0; c < L; c = c + 1) begin
                    valid <= (c < OW);
                    if (mode == 0)      bin <= (c < OW);
                    else if (mode == 1) bin <= 0;
                    else begin
                        if (($random & 7) == 0) cur = ~cur;   // average run length 8
                        bin <= (c < OW) & cur;
                    end
                    @(posedge clk);
                    if (valid) begin $fwrite(fin, "%0d\n", bin); $fwrite(fce, "%0d\n", ce); end
                end
            end
            valid <= 0; bin <= 0;
            repeat (3*L) @(posedge clk);
        end
        repeat (2*L) @(posedge clk);
        $fclose(fin); $fclose(fce); $fclose(fl); $fclose(fw);
        $finish;
    end
    always @(posedge clk) begin
        if (lv) $fwrite(fl, "%0d %0d %0d\n", ls, le, lf);
        if (wv) $fwrite(fw, "%0d\n", w);
    end
endmodule
