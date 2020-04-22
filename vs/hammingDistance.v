`timescale 1ns / 1ps
//Zero means match, 1 means mismatch. XOR would help.
module hammingDistance #(
    parameter BIT_WIDTH                      = 512,
    parameter LOG_BIT_SIZE                   = 9,
    parameter THRESHOLD                      = 32,
    parameter PIPELINE_PROFILE               = {LOG_BIT_SIZE{1'b0}}, //No pipelines
    parameter NUM_PIPELINE_STAGES            = 0
) (
    input clk,
    input rstb,
    input valid,
    input wnr,
    input [BIT_WIDTH - 1 : 0] vector,
    input [BIT_WIDTH - 1 : 0] address,
    output [BIT_WIDTH - 1 : 0] addressPipelined,
    output decisionReady,
    output wnrDelayed,
    output hit
);

//Implement pipelined valid and ready
genvar p;
generate
    if (NUM_PIPELINE_STAGES > 0) begin:pipelineStages
        reg [1 : 0] pipe[0 : NUM_PIPELINE_STAGES - 1];
        reg [BIT_WIDTH - 1 : 0] addressPipeline[0 : NUM_PIPELINE_STAGES - 1];
        for (p = 0; p < NUM_PIPELINE_STAGES; p = p + 1) begin:pipeStages
            always @(posedge clk or negedge rstb) begin
                if (~rstb) begin
                    pipe[p] <= 2'b0;
                    addressPipeline[p] <= {BIT_WIDTH{1'b0}};
                end
                else begin
                    pipe[p] <= (p == 0) ? {valid, wnr} : pipe[p - 1];
                    addressPipeline[p] <= (p == 0) ? vector : addressPipelined[p - 1];
                end
            end
        end
        assign {decisionReady, wnrDelayed} = pipe[NUM_PIPELINE_STAGES - 1];
        assign addressPipelined = addressPipeline[NUM_PIPELINE_STAGES - 1];
    end
    else begin:noPipelineStages
        assign {decisionReady, wnrDelayed} = {valid, wnr};
        assign addressPipelined = vector;
    end
endgenerate

genvar k, l, m;
generate
    for (k = 0; k <= LOG_BIT_SIZE; k = k + 1) begin:hammingLoop //hammingLoop[k]
        reg [k : 0] sums[0 : BIT_WIDTH/{1'b1, {(k){1'b0}}} - 1]; //Exponentially increasing size of sums, and decreasing number of sums
        if (k == 0) begin:zeroCaseSpecialCase
            for (l = 0; l < BIT_WIDTH/{1'b1, {(k){1'b0}}}; l = l + 1) begin:innerLoop
                if (PIPELINE_PROFILE[0] == 0) begin
                    always@* sums[l] <= vector[l] ^ address[l];
                end
                else begin
                    always @(posedge clk or negedge rstb) begin
                        if (~rstb) begin
                            sums[l] <= {BIT_WIDTH/{1'b1, {(k){1'b0}}}{1'b0}};
                        end
                        else begin
                            sums[l] <= vector[l] ^ address[l];
                        end
                    end
                end
            end
        end
        else begin:allOtherCases
            for (m = 0; m < BIT_WIDTH/{1'b1, {(k){1'b0}}}; m = m + 1) begin:innerLoop
                if (PIPELINE_PROFILE[k] == 0) begin
                    always@* sums[m] = hammingLoop[k - 1].sums[2 * (m + 1) - 1] + hammingLoop[k - 1].sums[2 * m]; 
                end
                else begin
                    always @(posedge clk or negedge rstb) begin
                        if (~rstb) begin
                            sums[m] <= {BIT_WIDTH/{1'b1, {(k){1'b0}}}{1'b0}};
                        end
                        else begin
                            sums[m] <= hammingLoop[k - 1].sums[2 * (m + 1) - 1] + hammingLoop[k - 1].sums[2 * m]; 
                        end
                    end
                end
            end
        end
    end
endgenerate

//Address within threshold => its a "hit"
assign hit = hammingLoop[LOG_BIT_SIZE].sums[0] <= THRESHOLD;

endmodule
