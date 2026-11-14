// hist_path.v : XOR + position counter + group control + hist_median
//   flag = raw_bin ^ clean_bin   (FLAG_SEL=0)  pixels changed by the opening/closing
//        = clean_bin             (FLAG_SEL=1)  the cleaned stripe itself
//   A pixel is counted when valid & flag & ce  (ce = range enable from edge detection later)
//   GROUP_FRAME=1 : one histogram per frame (OH scan lines);  0 : one histogram per scan line
// raw_bin/clean_bin/valid must already be aligned (raw_bin = output of the delay block).
module hist_path #(
    parameter OW          = 48,      // scan-line length (= number of bins)
    parameter OH          = 64,      // scan lines per frame
    parameter AW          = 8,
    parameter GROUP_FRAME = 1,
    parameter FLAG_SEL    = 0
)(
    input  wire          clk,
    input  wire          rst,
    input  wire          raw_bin,
    input  wire          clean_bin,
    input  wire          valid,
    input  wire          ce,
    output wire          med_valid,
    output wire [AW-1:0] med_y,
    output wire [23:0]   med_total,
    output wire          overrun
);
    wire flag = FLAG_SEL ? clean_bin : (raw_bin ^ clean_bin);

    reg          vprev;
    reg [AW-1:0] ycnt;
    reg [15:0]   lines;
    wire         first    = valid & ~vprev;
    wire [AW-1:0] y       = first ? {AW{1'b0}} : ycnt;
    wire         line_end = vprev & ~valid;
    wire         swap     = GROUP_FRAME ? (line_end && lines == OH-1) : line_end;

    always @(posedge clk) begin
        if (rst) begin vprev <= 1'b0; ycnt <= 0; lines <= 0; end
        else begin
            vprev <= valid;
            if (valid) ycnt <= y + 1'b1;
            if (line_end) lines <= (lines == OH-1) ? 16'd0 : lines + 1'b1;
        end
    end

    hist_median #(.NBINS(OW), .AW(AW)) u_hist (
        .clk(clk), .rst(rst), .y(y), .inc(valid & flag & ce), .swap(swap),
        .med_valid(med_valid), .med_y(med_y), .med_total(med_total), .overrun(overrun));
endmodule
