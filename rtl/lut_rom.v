module lut_rom #(parameter FILE = "data/lut.hex")(
    input  wire clk,
    input  wire [7:0] pix_in, input wire valid_in,
    output reg  [7:0] pix_out, output reg valid_out);
    reg [7:0] rom [0:255];
    initial $readmemh(FILE, rom);
    always @(posedge clk) begin
        pix_out   <= rom[pix_in];
        valid_out <= valid_in;
    end
endmodule
