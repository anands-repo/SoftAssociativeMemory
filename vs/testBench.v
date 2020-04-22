`timescale 1ns / 1ps
`define VERIFICATION
module testBench;

reg clk                 = 0;
reg rstb                = 0;
wire [7 : 0] symbol;
wire [7 : 0] noisySymbol;
reg pass = 1;
reg valid = 0;
reg wnr = 0;

always #5 clk = ~clk;

always @(posedge clk or negedge rstb) begin
    if (~rstb) begin
        valid <= 1'b0;
        wnr <= 1'b0;
    end
    else begin
        valid <= 1'b1;
        wnr <= 1'b1;
    end
end

initial begin
    rstb = 1'b0;
    repeat (5) @(posedge clk);
    rstb <= 1'b1;

    repeat (1000) @(posedge clk);
    //Check all the addresses
    if (!((testBench.sdm.memoryCells[0].memcell.softLocation[7:0] == 'hff) ||
        (testBench.sdm.memoryCells[1].memcell.softLocation[7:0] == 'hff) ||
        (testBench.sdm.memoryCells[2].memcell.softLocation[7:0] == 'hff) ||
        (testBench.sdm.memoryCells[3].memcell.softLocation[7:0] == 'hff) 
       )) begin
        pass = 0;
    end
    if (!((testBench.sdm.memoryCells[0].memcell.softLocation[7:0] == 'hf0) ||
        (testBench.sdm.memoryCells[1].memcell.softLocation[7:0] == 'hf0) ||
        (testBench.sdm.memoryCells[2].memcell.softLocation[7:0] == 'hf0) ||
        (testBench.sdm.memoryCells[3].memcell.softLocation[7:0] == 'hf0) 
       )) begin
        pass = 0;
    end
    if (!((testBench.sdm.memoryCells[0].memcell.softLocation[7:0] == 'haa) ||
        (testBench.sdm.memoryCells[1].memcell.softLocation[7:0] == 'haa) ||
        (testBench.sdm.memoryCells[2].memcell.softLocation[7:0] == 'haa) ||
        (testBench.sdm.memoryCells[3].memcell.softLocation[7:0] == 'haa) 
       )) begin
        pass = 0;
    end
    if (!((testBench.sdm.memoryCells[0].memcell.softLocation[7:0] == 'hcc) ||
        (testBench.sdm.memoryCells[1].memcell.softLocation[7:0] == 'hcc) ||
        (testBench.sdm.memoryCells[2].memcell.softLocation[7:0] == 'hcc) ||
        (testBench.sdm.memoryCells[3].memcell.softLocation[7:0] == 'hcc) 
       )) begin
        pass = 0;
    end
    if (!((testBench.sdm.memoryCells[3].memcell.strength[7:0] == 'hff) &&
          (testBench.sdm.memoryCells[2].memcell.strength[7:0] == 'hff) &&
          (testBench.sdm.memoryCells[1].memcell.strength[7:0] == 'hff) &&
          (testBench.sdm.memoryCells[0].memcell.strength[7:0] == 'hff) 
    )) pass = 0;
    if (pass) $display("Test Passed Simulation!!!");
    else $display("Test Failed Simulation!!!");
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
    .BIT_WIDTH(8),
    .BIT_WIDTH_SIZE(3),
    .THRESHOLD(2),
    .HYSTERISIS(4),
    .COUNTER_WIDTH(8),
    .NUM_LOCATIONS(4),
    .NUM_LOCATIONS_BIT_SIZE(2)
) sdm (
    .clk(clk),
    .rstb(rstb),
    .address(noisySymbol),
    .valid(valid),
    .wnr(wnr),
    .readValid(readValid),
    .readSuccess(readSuccess),
    .data(data)
);

initial begin
    //$shm_open("waves.shm");
    //$shm_probe("AC");
end

endmodule
