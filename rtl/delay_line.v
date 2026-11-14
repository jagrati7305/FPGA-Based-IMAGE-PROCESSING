// delay_line.v
// Delays a WIDTH-bit bus by exactly DELAY clocks (DELAY >= 2) using a circular buffer.
// One read + one write per clock on the same address -> infers a single block RAM
// (read-first mode), so a delay of thousands of clocks costs almost nothing.
// INIT_ONES = 1 : buffer powers up filled with 1s (needed by erosion), else 0s.
module delay_line #(
    parameter WIDTH     = 2,
    parameter DELAY     = 330,       // clocks
    parameter PW        = 16,        // pointer width: DELAY-1 must fit
    parameter INIT_ONES = 0
)(
    input  wire             clk,
    input  wire [WIDTH-1:0] din,
    output reg  [WIDTH-1:0] dout
);
    localparam DEPTH = DELAY - 1;          // buffer depth; +1 clock for the read register

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [PW-1:0]    ptr = 0;
    integer i;
    initial begin
        dout = INIT_ONES ? {WIDTH{1'b1}} : {WIDTH{1'b0}};
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = INIT_ONES ? {WIDTH{1'b1}} : {WIDTH{1'b0}};
    end

    always @(posedge clk) begin
        dout     <= mem[ptr];              // old value (written DEPTH clocks ago)
        mem[ptr] <= din;                   // new value
        ptr      <= (ptr == DEPTH-1) ? {PW{1'b0}} : ptr + 1'b1;
    end
endmodule
