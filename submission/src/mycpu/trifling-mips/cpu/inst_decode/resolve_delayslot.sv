// resolve_delayslot
`include "inst_decode.svh"

module resolve_delayslot #(
    parameter   N_ISSUE     =   1
) (
    // external signals
    input   logic   clk,
    input   logic   rst,
    // flush signals
    input   logic   flush,
    // stall signals
    input   logic   stall,
    // resolve delayslot
    input   pipe_id_t[N_ISSUE - 1:0]    pipe_id,        // from inst_decoder's output(pipe_id_n), before sync
    output  logic[N_ISSUE - 1:0]        resolved_delayslot
);

logic wait_delayslot, wait_delayslot_n;
logic [N_ISSUE - 1:0] is_controlflow;

for (genvar i = 0; i < N_ISSUE; ++i) begin : gen_cf
    assign is_controlflow[i] = pipe_id[i].valid & pipe_id[i].decode_resp.is_controlflow;
end

// set resolved_delayslot
assign resolved_delayslot[0] = wait_delayslot & pipe_id[0].valid;
for(genvar i = 1; i < N_ISSUE; ++i) begin : gen_rd
    assign resolved_delayslot[i] = is_controlflow[i - 1] & pipe_id[i].valid;
end

// update wait_delayslot
always_comb begin
    wait_delayslot_n = is_controlflow[N_ISSUE - 1];
    for (int i = 0; i < N_ISSUE - 1; ++i)
        wait_delayslot_n |= is_controlflow[i] & ~pipe_id[i + 1].valid;
end

always_ff @ (posedge clk) begin
    if (rst | flush)
        wait_delayslot <= 1'b0;
    else if (~stall)
        wait_delayslot <= wait_delayslot_n;
end

endmodule
