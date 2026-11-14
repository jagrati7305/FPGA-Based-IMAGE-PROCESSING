// closing1x9_bin.v
// Binary closing with a 1x9 line element = dilation (OR of 9) then erosion (AND of 9).
// Row blanking between rows must be >= 8 clocks. Latency = 10 clocks.
module closing1x9_bin (
    input  wire clk,
    input  wire rst,
    input  wire bin_in,
    input  wire valid_in,
    output wire bin_out,
    output wire valid_out
);
    reg [7:0] sr_b;       // bin_in history   (8 flip-flops)
    reg       d_reg;      // dilated bit
    reg [7:0] sr_d;       // dilated history  (8 flip-flops)
    reg       e_reg;      // eroded bit
    reg [9:0] vpipe;      // valid delay = 10

    wire b      = bin_in & valid_in;           // blanking -> 0 (neutral for OR)
    wire d_next = b | (|sr_b);                 // 9-input OR
    wire e_next = d_reg & (&sr_d);             // 9-input AND

    always @(posedge clk) begin
        if (rst) begin
            sr_b <= 0; d_reg <= 0; sr_d <= 0; e_reg <= 0; vpipe <= 0;
        end else begin
            sr_b  <= {sr_b[6:0], b};
            d_reg <= d_next;
            sr_d  <= {sr_d[6:0], d_reg};
            e_reg <= e_next;
            vpipe <= {vpipe[8:0], valid_in};
        end
    end

    assign valid_out = vpipe[9];
    assign bin_out   = e_reg & vpipe[9];
endmodule
