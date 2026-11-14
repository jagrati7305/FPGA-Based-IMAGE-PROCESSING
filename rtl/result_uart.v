// result_uart.v : captures one frame of results and sends it to the PC over UART.
//
// Packet (all bytes, little endian):
//   A5 5A | frame_id | weight[31:0] | sil_median_y | sil_count[23:0] | xor_count[23:0]
//   | exp_flags (bit0 = exposure up, bit1 = exposure down) | NLINES[15:0]
//   | NLINES x { start, end } | checksum (XOR of every byte from frame_id up to the last data byte)
// Length = 18 + 2*NLINES bytes.
// The UART is slower than the camera, so only frames that begin while the transmitter is idle
// are captured (the others are skipped). SKIP_FRAMES frames after reset are ignored.
module result_uart #(
    parameter NLINES       = 256,
    parameter CLKS_PER_BIT = 108,
    parameter SKIP_FRAMES  = 1
)(
    input  wire        clk,
    input  wire        rst,
    // from edge_detect
    input  wire        line_valid,
    input  wire [8:0]  line_start,
    input  wire [8:0]  line_end,
    input  wire        weight_valid,
    input  wire [31:0] weight,
    // from the two histogram paths
    input  wire        sil_valid,
    input  wire [7:0]  sil_y,
    input  wire [23:0] sil_total,
    input  wire        xor_valid,
    input  wire [23:0] xor_total,
    input  wire [1:0]  exp_flags,
    output wire        tx,
    output wire        busy
);
    localparam TOTAL = 18 + 2*NLINES;

    // ---------------- capture ----------------
    reg [15:0] mem [0:NLINES-1];                     // {end, start} per line
    reg [15:0] lcnt;                                 // line index inside the frame
    reg [7:0]  frames_done;
    reg        capturing, got_w, got_s, got_x;
    reg [31:0] w_l;  reg [7:0] sy_l;  reg [23:0] st_l, xt_l;  reg [1:0] ef_l;
    reg [7:0]  frame_id;

    localparam S_IDLE=3'd0, S_PREP=3'd1, S_RD1=3'd2, S_RD2=3'd3, S_SEND=3'd4, S_GAP=3'd5, S_WAITB=3'd6;
    reg [2:0]  state;
    wire       arm = line_valid && (lcnt == 0) && !capturing && (state == S_IDLE)
                     && (frames_done >= SKIP_FRAMES);

    always @(posedge clk) if (line_valid && (capturing || arm))
        mem[lcnt] <= {line_end[7:0], line_start[7:0]};

    // ---------------- serializer ----------------
    reg [15:0] idx;
    reg [15:0] ram_addr, ram_q;
    reg [7:0]  cur, chk;
    reg        tx_start;
    reg [7:0]  tx_data;
    wire       tx_busy;
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .clk(clk), .rst(rst), .data(tx_data), .start(tx_start), .busy(tx_busy), .tx(tx));

    reg [7:0] hdr;
    always @* begin
        case (idx[4:0])
            5'd0:  hdr = 8'hA5;
            5'd1:  hdr = 8'h5A;
            5'd2:  hdr = frame_id;
            5'd3:  hdr = w_l[7:0];
            5'd4:  hdr = w_l[15:8];
            5'd5:  hdr = w_l[23:16];
            5'd6:  hdr = w_l[31:24];
            5'd7:  hdr = sy_l;
            5'd8:  hdr = st_l[7:0];
            5'd9:  hdr = st_l[15:8];
            5'd10: hdr = st_l[23:16];
            5'd11: hdr = xt_l[7:0];
            5'd12: hdr = xt_l[15:8];
            5'd13: hdr = xt_l[23:16];
            5'd14: hdr = {6'b0, ef_l};
            5'd15: hdr = NLINES[7:0];
            default: hdr = NLINES[15:8];             // idx 16
        endcase
    end

    assign busy = (state != S_IDLE);

    always @(posedge clk) begin
        if (rst) begin
            lcnt <= 0; frames_done <= 0; capturing <= 1'b0;
            got_w <= 1'b0; got_s <= 1'b0; got_x <= 1'b0;
            w_l <= 0; sy_l <= 0; st_l <= 0; xt_l <= 0; ef_l <= 0; frame_id <= 0;
            state <= S_IDLE; idx <= 0; ram_addr <= 0; ram_q <= 0; cur <= 0; chk <= 0;
            tx_start <= 1'b0; tx_data <= 0;
        end else begin
            tx_start <= 1'b0;

            // ---- line counter / capture bookkeeping ----
            if (line_valid) lcnt <= (lcnt == NLINES-1) ? 16'd0 : lcnt + 1'b1;
            if (arm) capturing <= 1'b1;
            if (weight_valid) begin
                if (frames_done != 8'hFF) frames_done <= frames_done + 1'b1;
                if (capturing) begin w_l <= weight; got_w <= 1'b1; end
            end
            if (sil_valid && capturing) begin sy_l <= sil_y; st_l <= sil_total; got_s <= 1'b1; end
            if (xor_valid && capturing) begin xt_l <= xor_total;                got_x <= 1'b1; end

            case (state)
                S_IDLE: if (got_w && got_s && got_x) begin      // whole frame captured -> send it
                    ef_l <= exp_flags; capturing <= 1'b0;
                    got_w <= 1'b0; got_s <= 1'b0; got_x <= 1'b0;
                    idx <= 0; chk <= 0; state <= S_PREP;
                end
                S_PREP: begin
                    if (idx >= 17 && idx < 17 + 2*NLINES) begin // line data: fetch from RAM
                        ram_addr <= (idx - 17) >> 1;
                        state <= S_RD1;
                    end else begin
                        cur   <= (idx == TOTAL-1) ? chk : hdr;
                        state <= S_SEND;
                    end
                end
                S_RD1: begin ram_q <= mem[ram_addr]; state <= S_RD2; end
                S_RD2: begin cur <= idx[0] ? ram_q[7:0] : ram_q[15:8]; state <= S_SEND; end  // odd idx = start
                S_SEND: if (!tx_busy) begin
                    tx_data  <= cur;
                    tx_start <= 1'b1;
                    if (idx >= 2 && idx < TOTAL-1) chk <= chk ^ cur;
                    state <= S_GAP;
                end
                S_GAP: state <= S_WAITB;                         // let busy rise
                S_WAITB: if (!tx_busy) begin
                    if (idx == TOTAL-1) begin frame_id <= frame_id + 1'b1; state <= S_IDLE; end
                    else begin idx <= idx + 1'b1; state <= S_PREP; end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
