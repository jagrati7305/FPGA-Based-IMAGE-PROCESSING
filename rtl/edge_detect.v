// edge_detect.v : Start / End / Weight
// For every scan line:
//   * find the runs of 1s in the cleaned binary stream: run = [start, end)  (end is exclusive)
//   * keep the run whose MIDPOINT is closest to CENTER:  |start + end - 2*CENTER| smallest
//     (a tie keeps the earlier run, a line without any run gives start = end = 0, found = 0)
//   * output the line's start/end ("1-D data for S/W") with a 1-clock line_valid pulse
//   * Weight = sum over the lines of a frame of (end - start)^2, with a 1-clock weight_valid pulse
// The previous line's start/end are held in registers; `ce` is 1 while the current pixel's y is
// inside that held range [start, end). It is the clock enable for the histogram (no extra buffer).
// Timing: results appear 3 clocks after the line's last pixel, the next line must start later
// than that (blanking OB >= 4).
module edge_detect #(
    parameter OW     = 48,      // scan-line length
    parameter OH     = 64,      // scan lines per frame
    parameter AW     = 8,       // OW <= 2**AW
    parameter CENTER = 24,      // preferred position (80 in the book's 160-pixel line)
    parameter WW     = 32       // weight width
)(
    input  wire          clk,
    input  wire          rst,
    input  wire          bin,
    input  wire          valid,
    output wire          ce,
    output reg           line_valid,
    output reg  [AW:0]   line_start,
    output reg  [AW:0]   line_end,
    output reg           line_found,
    output reg           weight_valid,
    output reg  [WW-1:0] weight
);
    localparam PW = AW + 1;

    // ---------------- position and run detection ----------------
    reg           vprev, bprev;
    reg  [PW-1:0] ycnt;
    reg  [PW-1:0] run_start;
    wire          first      = valid & ~vprev;
    wire [PW-1:0] y          = first ? {PW{1'b0}} : ycnt;
    wire          line_last  = vprev & ~valid;                 // clock after the last pixel
    wire          bprev_eff  = first ? 1'b0 : bprev;
    wire          rise       = valid & bin & ~bprev_eff;
    wire          fall       = valid & ~bin & bprev_eff;
    wire          close_run  = fall | (line_last & bprev);     // a run ends here, at ycnt

    // ---------------- stage 1: candidate register ----------------
    reg           cand_v;
    reg  [PW-1:0] cand_s, cand_e;

    // ---------------- stage 2: keep the best run ----------------
    wire [PW+1:0] dsum = cand_s + cand_e - (2*CENTER);         // two's complement, MSB = sign
    wire [PW+1:0] dabs = dsum[PW+1] ? (~dsum + 1'b1) : dsum;
    reg           best_v;
    reg  [PW-1:0] best_s, best_e;
    reg  [PW+1:0] best_d;

    reg           le_d1, le_d2;

    // ---------------- stage 3: weight, hold registers ----------------
    reg  [PW-1:0] hold_s, hold_e;
    reg  [15:0]   lcnt;
    reg  [WW-1:0] weight_acc;
    wire [PW-1:0]   width = line_end - line_start;
    wire [2*PW-1:0] sq    = width * width;

    assign ce = valid & (y >= hold_s) & (y < hold_e);

    always @(posedge clk) begin
        if (rst) begin
            vprev <= 1'b0; bprev <= 1'b0; ycnt <= 0; run_start <= 0;
            cand_v <= 1'b0; cand_s <= 0; cand_e <= 0;
            best_v <= 1'b0; best_s <= 0; best_e <= 0; best_d <= 0;
            le_d1 <= 1'b0; le_d2 <= 1'b0;
            line_valid <= 1'b0; line_start <= 0; line_end <= 0; line_found <= 1'b0;
            hold_s <= 0; hold_e <= 0; lcnt <= 0; weight_acc <= 0;
            weight_valid <= 1'b0; weight <= 0;
        end else begin
            // ---- position / run detection ----
            vprev <= valid;
            if (valid) begin
                bprev <= bin;
                ycnt  <= y + 1'b1;
            end
            if (rise) run_start <= y;

            // ---- stage 1 ----
            cand_v <= close_run;
            cand_s <= run_start;
            cand_e <= ycnt;

            // ---- stage 2 ----
            if (cand_v && (!best_v || dabs < best_d)) begin
                best_v <= 1'b1; best_s <= cand_s; best_e <= cand_e; best_d <= dabs;
            end
            le_d1 <= line_last;
            le_d2 <= le_d1;

            // ---- line result ----
            line_valid <= le_d2;
            if (le_d2) begin
                line_found <= best_v;
                line_start <= best_v ? best_s : 0;
                line_end   <= best_v ? best_e : 0;
                best_v     <= 1'b0;
            end

            // ---- weight accumulation / hold registers ----
            weight_valid <= 1'b0;
            if (line_valid) begin
                hold_s <= line_start;
                hold_e <= line_end;
                if (lcnt == OH-1) begin
                    weight       <= weight_acc + sq;
                    weight_valid <= 1'b1;
                    weight_acc   <= 0;
                    lcnt         <= 0;
                    hold_s       <= 0;                     // next frame starts with an empty range
                    hold_e       <= 0;
                end else begin
                    weight_acc <= weight_acc + sq;
                    lcnt       <= lcnt + 1'b1;
                end
            end
        end
    end
endmodule
