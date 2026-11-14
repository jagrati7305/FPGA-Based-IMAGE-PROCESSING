module exposure_control #(parameter CNT_W = 16)(
    input  wire clk, rst,
    input  wire [7:0] pix,
    input  wire valid, frame_start,
    output reg  exp_inc, exp_dec);
    reg [CNT_W-1:0] cnt192, cnt248;
    wire ge192 = valid & (&pix[7:6]);
    wire ge248 = valid & (&pix[7:3]);
    always @(posedge clk) begin
        if (rst) begin cnt192<=0; cnt248<=0; exp_inc<=0; exp_dec<=0; end
        else if (frame_start) begin
            exp_inc <= ~cnt192[CNT_W-1];
            exp_dec <=  cnt248[CNT_W-1];
            cnt192 <= 0; cnt248 <= 0;
        end else begin
            if (ge192 && !cnt192[CNT_W-1]) cnt192 <= cnt192 + 1'b1;
            if (ge248 && !cnt248[CNT_W-1]) cnt248 <= cnt248 + 1'b1;
        end
    end
endmodule
