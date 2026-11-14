// hist_median.v
// Bank-switched histogram + median finder.
//   * Bank A accumulates: hist[y] += 1 for every pixel with inc=1 (read-modify-write).
//   * On a `swap` pulse the banks exchange roles. The finished bank is scanned bin by bin:
//     the cumulative sum finds the median, and each bin is cleared (written 0) as it is read,
//     so the bank is empty again when its turn to accumulate comes.
//   * Median = smallest y whose cumulative count >= (total+1)/2   (lower median).
//     med_total == 0 means the group was empty (med_y is then 0).
// y must change on every clock while accumulating (it does: y counts 0,1,2,... along a scan
// line), so two consecutive increments never hit the same bin and no forwarding logic is needed.
// The scan takes NBINS+2 clocks and must finish before the next swap (else `overrun` sticks at 1).
module hist_median #(
    parameter NBINS = 48,
    parameter AW    = 8,         // bin address width      (NBINS <= 2**AW)
    parameter CW    = 16,        // bits per bin counter
    parameter TW    = 24         // bits of the total counter
)(
    input  wire          clk,
    input  wire          rst,
    input  wire [AW-1:0] y,           // bin address (position along the scan line)
    input  wire          inc,         // 1 = count this pixel
    input  wire          swap,        // 1-clock pulse: close the group
    output reg           med_valid,   // 1-clock pulse when med_y / med_total are ready
    output reg  [AW-1:0] med_y,
    output reg  [TW-1:0] med_total,
    output reg           overrun
);
    // two banks, zero at power-up
    reg [CW-1:0] mem0 [0:NBINS-1];
    reg [CW-1:0] mem1 [0:NBINS-1];
    integer i;
    initial for (i = 0; i < NBINS; i = i + 1) begin mem0[i] = 0; mem1[i] = 0; end

    reg          acc_bank;            // bank that accumulates now (the other one is scanned)
    reg [TW-1:0] tot_acc;             // pixels counted in the current group

    // ---------------- accumulate pipeline ----------------
    // stage A (clock t)  : read hist[y]
    // stage B (clock t+1): write hist[y] <= value + 1
    reg [CW-1:0] rd0, rd1;
    reg [AW-1:0] yd1;
    reg          incd1, bankd1;

    // ---------------- scan pipeline ----------------
    reg          scan_active;
    reg [AW-1:0] scan_a, scan_a1;
    reg          scan_v1, scan_bank1;
    reg [TW-1:0] half, cum, tot_done;
    reg          found;
    reg [AW-1:0] med_r;

    // read addresses: the accumulating bank is addressed by y, the other one by the scanner
    wire [AW-1:0] ra0 = (acc_bank == 1'b0) ? y : scan_a;
    wire [AW-1:0] ra1 = (acc_bank == 1'b1) ? y : scan_a;
    always @(posedge clk) begin
        rd0 <= mem0[ra0];
        rd1 <= mem1[ra1];
    end

    // write ports: accumulation write wins, otherwise the scan clears
    wire [CW-1:0] acc_old = bankd1 ? rd1 : rd0;
    wire          accw0 = incd1  && (bankd1 == 1'b0);
    wire          accw1 = incd1  && (bankd1 == 1'b1);
    wire          clrw0 = scan_v1 && (scan_bank1 == 1'b0);
    wire          clrw1 = scan_v1 && (scan_bank1 == 1'b1);
    always @(posedge clk) if (accw0 | clrw0) mem0[accw0 ? yd1 : scan_a1] <= accw0 ? acc_old + 1'b1 : {CW{1'b0}};
    always @(posedge clk) if (accw1 | clrw1) mem1[accw1 ? yd1 : scan_a1] <= accw1 ? acc_old + 1'b1 : {CW{1'b0}};

    // median logic (scan stage 2: data of bin scan_a1 is in rd0/rd1)
    wire [CW-1:0] scan_data = scan_bank1 ? rd1 : rd0;
    wire [TW-1:0] cum_nxt   = cum + scan_data;
    wire          hit       = !found && (cum_nxt >= half);
    wire [AW-1:0] med_nxt   = hit ? scan_a1 : med_r;

    always @(posedge clk) begin
        if (rst) begin
            acc_bank <= 1'b0; tot_acc <= 0; incd1 <= 1'b0; bankd1 <= 1'b0; yd1 <= 0;
            scan_active <= 1'b0; scan_a <= 0; scan_a1 <= 0; scan_v1 <= 1'b0; scan_bank1 <= 1'b0;
            half <= 0; cum <= 0; tot_done <= 0; found <= 1'b0; med_r <= 0;
            med_valid <= 1'b0; med_y <= 0; med_total <= 0; overrun <= 1'b0;
        end else begin
            med_valid <= 1'b0;

            // ---- accumulate ----
            yd1    <= y;
            incd1  <= inc;
            bankd1 <= acc_bank;
            if (inc) tot_acc <= tot_acc + 1'b1;

            // ---- scan stage 1: issue read ----
            scan_v1    <= scan_active;
            scan_a1    <= scan_a;
            scan_bank1 <= ~acc_bank;
            if (scan_active) begin
                if (scan_a == NBINS-1) scan_active <= 1'b0;
                else                   scan_a <= scan_a + 1'b1;
            end

            // ---- scan stage 2: cumulative sum, median, clear ----
            if (scan_v1) begin
                cum <= cum_nxt;
                if (hit) begin found <= 1'b1; med_r <= scan_a1; end
                if (scan_a1 == NBINS-1) begin
                    med_valid <= 1'b1;
                    med_y     <= med_nxt;
                    med_total <= tot_done;
                end
            end

            // ---- swap: close the group, start scanning the finished bank ----
            if (swap) begin
                if (scan_active || scan_v1) overrun <= 1'b1;
                acc_bank    <= ~acc_bank;
                tot_done    <= tot_acc;
                tot_acc     <= 0;
                half        <= (tot_acc + 1'b1) >> 1;
                cum         <= 0;
                found       <= 1'b0;
                med_r       <= 0;
                scan_active <= 1'b1;
                scan_a      <= 0;
            end
        end
    end
endmodule
