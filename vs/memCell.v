`timescale 1ps / 1ps
module memCell #(
    parameter BIT_WIDTH            = 512,
    parameter LOG_BIT_SIZE         = 9,
    parameter THRESHOLD            = 32,
    parameter HYSTERISIS           = 8,
    parameter HYSTERISIS_THRESHOLD = 25,
    parameter COUNTER_WIDTH        = 8
) (
    input clk,
    input rstb,
    input [BIT_WIDTH - 1 : 0] address,
    input valid,
    input wnr,
    input setAddress,
    input otherHit,

    output [BIT_WIDTH - 1 : 0] rdata,
    output decisionValid,
    output decisionSuccess,
    output reg locationEmpty,
    output locationStrong,
    output hit
);

//Internal registers
reg [BIT_WIDTH - 1 : 0]                    softLocation;
reg [1 : 0]                                state;
wire                                       hammingDistanceReady;
wire                                       wnrDelayed;
wire                                       hammingHit;
reg                                        rdMemDelayed;
wire [BIT_WIDTH - 1 : 0]                   addressPipelined;
reg [BIT_WIDTH - 1 : 0]                    addressDelayed;
wire [BIT_WIDTH - 1 : 0]                   decisionPerBit;
reg [COUNTER_WIDTH * BIT_WIDTH - 1 : 0]    mem;
reg [COUNTER_WIDTH * BIT_WIDTH - 1 : 0]    new_data;
wire                                       modifyMem;
wire [BIT_WIDTH - 1 : 0]                   strength;
wire                                       locationStrong;

//Do hamming distance calculation
hammingDistance #(
    .BIT_WIDTH(BIT_WIDTH),
    .LOG_BIT_SIZE(LOG_BIT_SIZE),
    .THRESHOLD(THRESHOLD),
    .PIPELINE_PROFILE(0),
    .NUM_PIPELINE_STAGES(0)
) distance (
    .clk(clk),
    .rstb(rstb),
    .valid(valid),
    .wnr(wnr),
    .vector(address),
    .address(softLocation),
    .decisionReady(hammingDistanceReady),
    .wnrDelayed(wnrDelayed),
    .hit(hammingHit),
    .addressPipelined(addressPipelined)
);

//Hit
assign hit           = hammingHit & ~locationEmpty;
assign decisionValid = hammingDistanceReady;

//Indicate whether the location is empty or not
always @(posedge clk or negedge rstb) begin
    if (~rstb) begin
        locationEmpty <= 1'b1;
    end
    else begin
        if (setAddress) begin
            locationEmpty <= 1'b0;
        end
        else begin
            if (hit & otherHit & hammingDistanceReady & wnrDelayed & ~(&strength)) locationEmpty <= 1'b1; //Location is empty when others have a hit too
        end
    end
end

//Read memory in the case of a unique hit or in the case of setAddress command input
assign modifyMem = setAddress | ((hit & ~otherHit) & wnrDelayed & hammingDistanceReady);

//Write to memory
always @(posedge clk) begin
    if (modifyMem) begin
        mem <= new_data;
    end
end

//Strength of the storage
genvar k;
generate
    for (k = 0; k < BIT_WIDTH; k = k + 1) begin:strengthLoop
        assign strength[k] = mem[(k + 1) * COUNTER_WIDTH - 1] ? -mem[(k + 1) * COUNTER_WIDTH - 1 : k * COUNTER_WIDTH] >= HYSTERISIS : mem[(k + 1) * COUNTER_WIDTH - 1 : k * COUNTER_WIDTH] >= HYSTERISIS;
    end
endgenerate

//Set the right type of data
genvar l;
generate
    for (l = 0; l < BIT_WIDTH; l = l + 1) begin:writeDataLoop
        wire [7 : 0] negMemContents = ~mem[(l + 1) * COUNTER_WIDTH - 1 : l * COUNTER_WIDTH] + {{(COUNTER_WIDTH - 2){1'b0}}, 2'b10};
        always @* begin
            if (setAddress) begin
                new_data[(l + 1) * COUNTER_WIDTH - 1 : l * COUNTER_WIDTH] <= addressPipelined[l] ? {{(COUNTER_WIDTH - 1){1'b0}}, 1'b1} : {(COUNTER_WIDTH){1'b1}}; //First time set
            end
            else begin
                if (addressPipelined[l]) begin
                    if ((~mem[(l + 1) *COUNTER_WIDTH - 1]) && (mem[(l + 1) * COUNTER_WIDTH - 1 : l * COUNTER_WIDTH] + {{(COUNTER_WIDTH - 1){1'b0}}, 1'b1} > HYSTERISIS_THRESHOLD)) begin
                        new_data[(l + 1) * COUNTER_WIDTH - 1 : l * COUNTER_WIDTH] <= HYSTERISIS_THRESHOLD;
                    end
                    else begin
                        new_data[(l + 1) * COUNTER_WIDTH - 1 : l * COUNTER_WIDTH] <= mem[(l + 1) * COUNTER_WIDTH - 1: l * COUNTER_WIDTH] + 1;
                    end
                end
                else begin
                    if ((mem[(l + 1) * COUNTER_WIDTH - 1]) && (negMemContents > HYSTERISIS_THRESHOLD)) begin
                        new_data[(l + 1) * COUNTER_WIDTH - 1 : l * COUNTER_WIDTH] <= -HYSTERISIS_THRESHOLD;
                    end
                    else begin
                        new_data[(l + 1) * COUNTER_WIDTH - 1 : l * COUNTER_WIDTH] <= mem[(l + 1) * COUNTER_WIDTH - 1: l * COUNTER_WIDTH] - 1;
                    end
                end
            end
        end

        //Update the soft-address
        always @(posedge clk or negedge rstb) begin
            if (~rstb) begin
                softLocation[l] <= 1'b0;
            end
            else begin
                if (setAddress) begin
                    softLocation[l] <= addressPipelined[l]; //In the same cycle as "hit"
                end
                else begin
                    if (modifyMem) begin //Adapt address when writing to memory
                        softLocation[l] <=  (~new_data[(l + 1) * COUNTER_WIDTH - 1]) && new_data[(l + 1) * COUNTER_WIDTH - 1 : l * COUNTER_WIDTH] >= HYSTERISIS ? 1'b1 : 
                                          (new_data[(l + 1) * COUNTER_WIDTH - 1]) && -new_data[(l + 1) * COUNTER_WIDTH - 1 : l * COUNTER_WIDTH] >= HYSTERISIS ? 1'b0 :
                                           softLocation[l];
                    end
                end
            end
        end

        //Are we beyond the hysterisis number?
        assign decisionPerBit[l] = mem[(l + 1) * COUNTER_WIDTH - 1] ? (-mem[(l + 1) * COUNTER_WIDTH - 1 : l * COUNTER_WIDTH] >= HYSTERISIS) :
                                                                          mem[(l + 1) * COUNTER_WIDTH - 1 : l * COUNTER_WIDTH] >= HYSTERISIS;
        assign rdata[l]          = ~mem[(l + 1) * COUNTER_WIDTH - 1] & hit & decisionValid; //Send the sign bit invert
    end
endgenerate

assign decisionSuccess = &decisionPerBit;

`ifdef VERIFICATION
wire [7:0] m7 = mem[8 * COUNTER_WIDTH - 1 : 7 * COUNTER_WIDTH];
wire [7:0] m6 = mem[7 * COUNTER_WIDTH - 1 : 6 * COUNTER_WIDTH];
wire [7:0] m5 = mem[6 * COUNTER_WIDTH - 1 : 5 * COUNTER_WIDTH];
wire [7:0] m4 = mem[5 * COUNTER_WIDTH - 1 : 4 * COUNTER_WIDTH];
wire [7:0] m3 = mem[4 * COUNTER_WIDTH - 1 : 3 * COUNTER_WIDTH];
wire [7:0] m2 = mem[3 * COUNTER_WIDTH - 1 : 2 * COUNTER_WIDTH];
wire [7:0] m1 = mem[2 * COUNTER_WIDTH - 1 : 1 * COUNTER_WIDTH];
wire [7:0] m0 = mem[1 * COUNTER_WIDTH - 1 : 0 * COUNTER_WIDTH];
wire [7:0] negM0 = writeDataLoop[0].negMemContents;
wire [7:0] negM1 = writeDataLoop[1].negMemContents;
wire [7:0] negM2 = writeDataLoop[2].negMemContents;
wire [7:0] negM3 = writeDataLoop[3].negMemContents;
wire [7:0] negM4 = writeDataLoop[4].negMemContents;
wire [7:0] negM5 = writeDataLoop[5].negMemContents;
wire [7:0] negM6 = writeDataLoop[6].negMemContents;
wire [7:0] negM7 = writeDataLoop[7].negMemContents;
`endif

endmodule
