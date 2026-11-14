`timescale 1ns/1ps
// Standalone test of opening_closing5x1 with random binary noise.
module tb_oc;
    parameter OW = 48, OH = 64, OB = 16, GAP_LINES = 20, NF = 3;
    parameter MODE = 1;
    localparam L = OW + OB;
    reg clk = 0; always #5 clk = ~clk;
    reg bin = 0, valid = 0;
    wire ob, ov;
    opening_closing5x1 #(.LINE_LEN(L), .MODE(MODE)) dut (clk, bin, valid, ob, ov);

    reg [OW*OH-1:0] img;                  // current frame bits
    integer f, y, x, c, fin, fout;
    initial begin
        fin  = $fopen("out/oc_in.txt","w");
        fout = $fopen("out/oc_out.txt","w");
        for (f = 0; f < NF; f = f + 1) begin
            for (y = 0; y < OH; y = y + 1)
                for (x = 0; x < OW; x = x + 1)       // blobs + noise: ~60 % ones
                    img[y*OW+x] = (($random & 7) < 5) ^ (($random & 15) == 0);
            repeat (3) @(posedge clk);
            for (y = 0; y < OH; y = y + 1) begin
                for (c = 0; c < L; c = c + 1) begin
                    valid <= (c < OW);
                    bin   <= (c < OW) ? img[y*OW+c] : 1'b0;
                    if (c < OW) $fwrite(fin, "%0d\n", img[y*OW+c]);
                    @(posedge clk);
                end
            end
            valid <= 0; bin <= 0;
            repeat (GAP_LINES*L) @(posedge clk);
        end
        $fclose(fin); $fclose(fout);
        $finish;
    end
    always @(posedge clk) if (ov !== 1'b0 || 1) if (ov === 1'b1) $fwrite(fout, "%0d\n", ob);
endmodule
