`timescale 1ns / 1ps
module noiseGenerator (
    input clk,
    input rstb,
    output reg [7 : 0] noise
);

//Generate 10 random bits
reg [7 : 0] randomBits[0 : 7];
integer noiseSeed = 0;

integer frequency = 40;
initial begin
    if ($test$plusargs("frequency")) $value$plusargs("frequency=%d", frequency);
    if ($test$plusargs("noise")) $value$plusargs("noise=%d", noiseSeed);
end

always @(negedge clk or negedge rstb) begin
    if (~rstb) begin
        randomBits[0] <= 8'b0;
        randomBits[1] <= 8'b0;
        randomBits[2] <= 8'b0;
        randomBits[3] <= 8'b0;
        randomBits[4] <= 8'b0;
        randomBits[5] <= 8'b0;
        randomBits[6] <= 8'b0;
        randomBits[7] <= 8'b0;
    end
    else begin
        randomBits[0] = $random(noiseSeed);
        randomBits[1] = $random(noiseSeed);
        randomBits[2] = $random(noiseSeed);
        randomBits[3] = $random(noiseSeed);
        randomBits[4] = $random(noiseSeed);
        randomBits[5] = $random(noiseSeed);
        randomBits[6] = $random(noiseSeed);
        randomBits[7] = $random(noiseSeed);
    end
end

always @(posedge clk or negedge rstb) begin
    if (~rstb) begin
        noise <= 8'b0;
    end
    else begin
        noise[0] <= randomBits[0] < frequency;
        noise[1] <= randomBits[1] < frequency;
        noise[2] <= randomBits[2] < frequency;
        noise[3] <= randomBits[3] < frequency;
        noise[4] <= randomBits[4] < frequency;
        noise[5] <= randomBits[5] < frequency;
        noise[6] <= randomBits[6] < frequency;
        noise[7] <= randomBits[7] < frequency;
    end
end

endmodule
