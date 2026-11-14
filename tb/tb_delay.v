`timescale 1ns/1ps
// Standalone check of delay_line against a software shift register.
module tb_delay;
    reg clk = 0; always #5 clk = ~clk;
    reg [1:0] din = 0;
    wire [1:0] d2, d10, d330;
    delay_line #(.WIDTH(2), .DELAY(2))   u2   (clk, din, d2);
    delay_line #(.WIDTH(2), .DELAY(10))  u10  (clk, din, d10);
    delay_line #(.WIDTH(2), .DELAY(330)) u330 (clk, din, d330);

    reg [1:0] r [0:330];     // r[k] = din delayed by k+1 clocks
    integer k, n = 0, err = 0;
    always @(posedge clk) begin
        din <= $random;
        r[0] <= din; for (k=1;k<=330;k=k+1) r[k] <= r[k-1];
        n = n + 1;
        if (n > 400) begin
            if (d2 !== r[1]) err = err + 1;
            if (d10 !== r[9]) err = err + 1;
            if (d330 !== r[329]) err = err + 1;
        end
        if (n == 3000) begin
            if (err == 0) $display("delay_line: PASS"); else $display("delay_line: FAIL, %0d errors", err);
            $finish;
        end
    end
endmodule
