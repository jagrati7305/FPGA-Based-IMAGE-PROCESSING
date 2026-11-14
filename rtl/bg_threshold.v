// bg_threshold.v
// Sliding-mean background estimate + threshold, along the scan direction.
//   mean   = (sum of last N pixels) * RECIP >> SHIFT      (no divider)
//   thr    = mean + mean/8 + mean/32                      (= mean * 1.156)
//   bin    = 1  if  pixel > thr  AND  pixel >= MIN_LEVEL
// The compared pixel is taken from the middle of the delay line (N/2 samples
// back) so that it sits at the centre of the window. Output is forced to 0 where
// the window is not completely inside the row.
// Latency = N/2 + 3 clocks. Needs N even, N <= 255+, 255*N < 2^SUM_W.
module bg_threshold #(
    parameter N     = 16,
    parameter RECIP = 2048,      // round(2^SHIFT / N)
    parameter SHIFT = 15,
    parameter SUM_W = 16,
    parameter AGE_W = 10,
    parameter MIN_LEVEL = 0      // pixel must also be >= this absolute level (rejects noise on dark frames)
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] pix,
    input  wire       valid,
    output reg        bin_out,
    output wire       valid_out
);
    localparam L = N/2 + 3;                      // total latency

    // ---------- stage 0: window sum ----------
    reg [7:0]       sr [0:N-1];                  // delay line: sr[k] = x(t-1-k) during clock t
    reg             vprev;
    reg [AGE_W-1:0] age;                         // clocks since row start
    reg [SUM_W-1:0] sum_reg;
    integer k;

    wire [7:0]       x       = valid ? pix : 8'd0;
    wire             first   = valid & ~vprev;   // first pixel of a row
    wire [AGE_W-1:0] age_eff = first ? {AGE_W{1'b0}} : age;
    wire [7:0]       old     = (age_eff >= N) ? sr[N-1] : 8'd0;
    wire [SUM_W-1:0] sum_nxt = first ? x : (sum_reg + x - old);
    wire             full    = valid & (age_eff >= N-1);   // window completely inside the row

    always @(posedge clk) begin                  // delay line: no reset (shift register)
        sr[0] <= x;
        for (k = 1; k < N; k = k + 1) sr[k] <= sr[k-1];
    end

    reg full_r1, full_r2;
    always @(posedge clk) begin
        if (rst) begin
            vprev <= 1'b0; age <= 0; sum_reg <= 0; full_r1 <= 1'b0;
        end else begin
            vprev   <= valid;
            age     <= first ? 1 : ((age < N) ? age + 1'b1 : age);
            sum_reg <= sum_nxt;
            full_r1 <= full;
        end
    end

    // ---------- stage 1: mean ----------
    reg [7:0] mean_r, cp_r;
    wire [31:0] prod = sum_reg * RECIP;
    always @(posedge clk) begin
        if (rst) full_r2 <= 1'b0;
        else     full_r2 <= full_r1;
        mean_r <= prod >> SHIFT;
        cp_r   <= sr[N/2];                       // pixel at the centre of the window
    end

    // ---------- stage 2: threshold + compare ----------
    wire [9:0] thr = mean_r + (mean_r >> 3) + (mean_r >> 5);
    always @(posedge clk) begin
        if (rst) bin_out <= 1'b0;
        else     bin_out <= full_r2 & ({2'b00, cp_r} > thr) & (cp_r >= MIN_LEVEL);
    end

    // ---------- valid delay ----------
    reg [L-1:0] vpipe;
    always @(posedge clk) begin
        if (rst) vpipe <= 0;
        else     vpipe <= {vpipe[L-2:0], valid};
    end
    assign valid_out = vpipe[L-1];
endmodule
