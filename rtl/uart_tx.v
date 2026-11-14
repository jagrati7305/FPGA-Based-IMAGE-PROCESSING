// uart_tx.v : 8N1 transmitter. Pulse `start` for one clock while `busy` is 0.
module uart_tx #(parameter CLKS_PER_BIT = 108)(
    input  wire       clk, rst,
    input  wire [7:0] data,
    input  wire       start,
    output reg        busy,
    output reg        tx
);
    reg [15:0] cnt;
    reg [3:0]  bitn;
    reg [8:0]  sh;                                   // {stop, d7..d0}
    always @(posedge clk) begin
        if (rst) begin busy <= 1'b0; tx <= 1'b1; cnt <= 0; bitn <= 0; sh <= 9'h1FF; end
        else if (!busy) begin
            tx <= 1'b1;
            if (start) begin
                busy <= 1'b1; tx <= 1'b0;            // start bit
                sh <= {1'b1, data}; bitn <= 0; cnt <= 0;
            end
        end else begin
            if (cnt == CLKS_PER_BIT-1) begin
                cnt <= 0;
                if (bitn == 4'd9) begin busy <= 1'b0; tx <= 1'b1; end
                else begin tx <= sh[0]; sh <= {1'b1, sh[8:1]}; bitn <= bitn + 1'b1; end
            end else cnt <= cnt + 1'b1;
        end
    end
endmodule
