`timescale 1ns / 1ps
module symbolGenerator (
    input clk,
    input rstb,
    output reg [7 : 0] symbol 
);

reg [7 : 0] allAddresses[0 : 3];
reg [1 : 0] addressBits;
integer seed = 0;

initial begin
    allAddresses[0] = 8'b11111111;
    allAddresses[1] = 8'b11110000;
    allAddresses[2] = 8'b11001100;
    allAddresses[3] = 8'b10101010;
    if ($test$plusargs("seed")) begin
        $value$plusargs("seed=%d", seed);
        $display("Found random seed passed to the simulator: %d", seed);
    end
end

always @(posedge clk or negedge rstb) begin
    if (~rstb) addressBits <= 2'b0;
    else addressBits       <= $random(seed);
end

always @(posedge clk or negedge rstb) begin
    if (~rstb) begin
        symbol <= 8'b0;
    end
    else begin
        symbol <= allAddresses[addressBits];
    end
end

endmodule

