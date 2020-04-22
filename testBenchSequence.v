`timescale 1ns / 1ps
`define VERIFICATION
module testBench;

reg clk                 = 0;
reg rstb                = 0;
wire [7 : 0] symbol;
wire [7 : 0] noisySymbol;

always #5 clk = ~clk;

initial begin
    rstb = 1'b0;
    repeat (5) @(posedge clk);
    rstb <= 1'b1;

    repeat (1000) @(posedge clk);
    $finish;
end

symbolGenerator symbolG (
    .clk(clk),
    .rstb(rstb),
    .symbol(symbol)
);

channel chan (
    .clk(clk),
    .rstb(rstb),
    .symbol(symbol),
    .noisySymbol(noisySymbol)
);

trainedSDM #(
    .BIT_WIDTH(32),
    .BIT_WIDTH_SIZE(5),
    .THRESHOLD(2),
    .HYSTERISIS(4),
    .COUNTER_WIDTH(8),
    .NUM_LOCATIONS(4),
    .NUM_LOCATIONS_BIT_SIZE(2)
) sdm (
    .clk(clk),
    .rstb(rstb),
    .address(noisySymbol),
    .valid(1'b1),
    .wnr(1'b1),
    .readValid(readValid),
    .readSuccess(readSuccess),
    .data(data)
);

initial begin
    $shm_open("waves.shm");
    $shm_probe("AC");
end

endmodule
