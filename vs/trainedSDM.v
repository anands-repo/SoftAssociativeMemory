`timescale 1ns / 1ps
module trainedSDM #(
    parameter BIT_WIDTH              = 512,
    parameter BIT_WIDTH_SIZE         = 9,
    parameter THRESHOLD              = 32,
    parameter HYSTERISIS             = 3,
    parameter COUNTER_WIDTH          = 8,
    parameter NUM_LOCATIONS          = 1024,
    parameter NUM_LOCATIONS_BIT_SIZE = 10
) (
    input clk,
    input rstb,
    input [BIT_WIDTH - 1 : 0] address,
    input valid,
    input wnr,
 
    output readValid,
    output readSuccess,
    output [BIT_WIDTH - 1 : 0] data
);

//Internal registers/wires
wire [NUM_LOCATIONS - 1 : 0]             hit;
wire [NUM_LOCATIONS - 1 : 0]             decisionValid;
wire [NUM_LOCATIONS - 1 : 0]             decisionSuccess;
wire [NUM_LOCATIONS - 1 : 0]             otherHit;
wire [NUM_LOCATIONS - 1 : 0]             setAddress;
wire [NUM_LOCATIONS - 1 : 0]             moreThanOneHit;
wire [BIT_WIDTH - 1 : 0]                 datac[0 : NUM_LOCATIONS - 1];
wire [NUM_LOCATIONS : 0]                 locationEmpty;
wire [NUM_LOCATIONS - 1 : 0]             locationStrong;

//Read valid of the memory and success
assign readValid   = |decisionValid; //All cells give their decision
assign readSuccess = (|hit) & (~|moreThanOneHit) & (|(decisionSuccess & decisionValid & ~locationEmpty));

//Combine read data
genvar p, q, r;
generate
    wire [NUM_LOCATIONS - 1 : 0] dataTranspose[0 : BIT_WIDTH - 1];
    for (p = 0; p < NUM_LOCATIONS; p = p + 1) begin:dataOuter
        for (q = 0; q < BIT_WIDTH; q = q + 1) begin:dataInner
            assign dataTranspose[q][p] = datac[p][q];
        end
    end
    for (r = 0; r < BIT_WIDTH; r = r + 1) begin:genData
        assign data[r] = |dataTranspose[r];
    end
endgenerate

//Allocating address to the MSB storage location in the absence of a hit signal.
genvar m;
generate
    assign locationEmpty[NUM_LOCATIONS] = 1'b0;
    for (m = 0; m < NUM_LOCATIONS; m = m + 1) begin:addressSetLoop
        assign setAddress[m] =  ~(|hit) & locationEmpty[m] & ~(|locationEmpty[NUM_LOCATIONS : m + 1]) & readValid; //Hit signals are valid this cycle
    end
endgenerate

//Instanciate the memory cells
genvar cells;
generate
    for (cells = 0; cells < NUM_LOCATIONS; cells = cells + 1) begin:memoryCells
        memCell #(
            .BIT_WIDTH(BIT_WIDTH),
            .LOG_BIT_SIZE(BIT_WIDTH_SIZE),
            .THRESHOLD(THRESHOLD),
            .HYSTERISIS(HYSTERISIS),
            .COUNTER_WIDTH(COUNTER_WIDTH)
        ) memcell (
            .clk(clk),
            .rstb(rstb),
            .address(address),
            .valid(valid),
            .wnr(wnr),
            .setAddress(setAddress[cells]),
            .otherHit(otherHit[cells]),
            .rdata(datac[cells]),
            .decisionValid(decisionValid[cells]),
            .decisionSuccess(decisionSuccess[cells]),
            .locationStrong(locationStrong[cells]),
            .locationEmpty(locationEmpty[cells]),
            .hit(hit[cells])
        );
    end
endgenerate

//Generate otherHit
genvar k;
generate
    for (k = 0; k < NUM_LOCATIONS; k = k + 1) begin:otherHitGenerate
        wire [NUM_LOCATIONS - 1 : 0] maskedHits;
        if (k == 0) begin:zeroCaseSpecialCase
            assign maskedHits = {hit[NUM_LOCATIONS - 1 : 1], 1'b0};
        end
        else if (k == NUM_LOCATIONS - 1) begin:MSBCaseSpecialCase
            assign maskedHits = {1'b0, hit[NUM_LOCATIONS - 2 : 0]};
        end
        else begin:allOtherCases
            assign maskedHits = {hit[NUM_LOCATIONS - 1 : k + 1], 1'b0, hit[k - 1 : 0]};
        end
        assign otherHit[k] = |maskedHits; //Re-wiring and ORing
    end
endgenerate

//Indicates that any hit and any other hit have occurred at the same time
assign moreThanOneHit = otherHit & hit;

endmodule
