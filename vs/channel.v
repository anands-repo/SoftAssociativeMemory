`timescale 1ns / 1ps
module channel (
    input clk,
    input rstb,
    input [7 : 0] symbol,
    output [7 : 0] noisySymbol
);

wire [7 : 0] noise;

noiseGenerator noiseGen (
    .clk(clk),
    .rstb(rstb),
    .noise(noise)
);

assign noisySymbol = noise ^ symbol;

endmodule
