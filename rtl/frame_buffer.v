// frame_buffer.v
// Ping-pong frame buffer. Writes the incoming raster stream into one bank while
// the other bank (the previous, complete frame) is read out.
//   TRANSPOSE = 1 : read column by column (output row = input column)
//   TRANSPOSE = 0 : read in the same raster order (pure one-frame delay)
// The read side inserts its own blanking of OB clocks after each output row.
module frame_buffer #(
    parameter W         = 64,     // input image width
    parameter H         = 48,     // input image height
    parameter TRANSPOSE = 1,
    parameter OB        = 16,     // blanking clocks between output rows (>= 8)
    parameter AW        = 20,     // address width  (2*W*H must fit)
    parameter CW        = 11      // counter width  (>= max(W,H)+OB)
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] pix_in,
    input  wire       valid_in,
    output wire [7:0] pix_out,
    output wire       valid_out
);
    localparam WH     = W*H;
    localparam OW     = TRANSPOSE ? H : W;   // output row length
    localparam OH     = TRANSPOSE ? W : H;   // number of output rows
    localparam STRIDE = TRANSPOSE ? W : 1;   // address step between output pixels

    // ---------------- memory: two banks in one array ----------------
    reg [7:0] mem [0:2*WH-1];

    // ---------------- write side ----------------
    reg [AW-1:0] wr_addr;
    reg          wr_bank;
    wire frame_done = valid_in && (wr_addr == WH-1);

    always @(posedge clk)                       // no reset -> infers block RAM
        if (valid_in) mem[(wr_bank ? WH : 0) + wr_addr] <= pix_in;

    always @(posedge clk) begin
        if (rst) begin
            wr_addr <= 0;
            wr_bank <= 1'b0;
        end else if (valid_in) begin
            if (wr_addr == WH-1) begin
                wr_addr <= 0;
                wr_bank <= ~wr_bank;            // swap banks
            end else
                wr_addr <= wr_addr + 1'b1;
        end
    end

    // ---------------- read side ----------------
    reg          rd_active, rd_bank, rd_en_d;
    reg [CW-1:0] rx, ry;                        // position in the output frame
    reg [AW-1:0] rd_addr, row_base;
    reg [7:0]    rd_data;

    wire rd_en = rd_active && (rx < OW);        // 1 during real pixels
    wire [AW-1:0] next_base = TRANSPOSE ? row_base + 1'b1 : row_base + W;

    always @(posedge clk)                       // synchronous read -> block RAM
        rd_data <= mem[(rd_bank ? WH : 0) + rd_addr];

    always @(posedge clk) begin
        if (rst) begin
            rd_active <= 1'b0; rd_bank <= 1'b0; rd_en_d <= 1'b0;
            rx <= 0; ry <= 0; rd_addr <= 0; row_base <= 0;
        end else begin
            rd_en_d <= rd_en;
            if (frame_done) begin               // a full frame just got written
                rd_active <= 1'b1;
                rd_bank   <= wr_bank;           // read the bank being closed
                rx <= 0; ry <= 0; rd_addr <= 0; row_base <= 0;
            end else if (rd_active) begin
                // position counters
                if (rx == OW+OB-1) begin
                    rx <= 0;
                    if (ry == OH-1) rd_active <= 1'b0;
                    else            ry <= ry + 1'b1;
                end else
                    rx <= rx + 1'b1;
                // address generator (only while a real pixel is being fetched)
                if (rx < OW) begin
                    if (rx == OW-1) begin
                        rd_addr  <= next_base;
                        row_base <= next_base;
                    end else
                        rd_addr <= rd_addr + STRIDE;
                end
            end
        end
    end

    assign valid_out = rd_en_d;
    assign pix_out   = rd_en_d ? rd_data : 8'd0;
endmodule
