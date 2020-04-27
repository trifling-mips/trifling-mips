// pc_generator
`include "inst_fetch.svh"

module pc_generator #(
    parameter   BOOT_VEC    =   32'hbfc00000,
    parameter   N_ISSUE     =   1,
    // local parameter
    localparam  LBITS_PC    =   $clog2(N_ISSUE) + 2
) (
    // external signals
    input   logic   clk,
    input   logic   rst,
    // ready from icache
    input   logic   ready,
    // branch resolved
    input   branch_resolved_t   resolved_branch,
    // except req
    input   except_req_t        except_req,
    // output
    output  virt_t  pc,
    output  virt_t  npc     // for icache fetch
);

// set npc
virt_t pc_n;
assign npc = ready ? pc_n : pc;
always_comb begin
    pc_n = pc;
    // default
    pc_n = {pc[$bits(virt_t) - 1:LBITS_PC] + 1, {LBITS_PC{1'b0}}};
    // branch resolved, temp unuse resolved_branch.valid(always not taken)
    if (resolved_branch.taken) pc_n = resolved_branch.target;
    // except
    if (except_req.valid) pc_n = except_req.except_vec;
end

always_ff @ (posedge clk) begin
    if (rst) begin
        pc <= {BOOT_VEC[$bits(virt_t) - 1:LBITS_PC] - 1, {LBITS_PC{1'b0}}};
    end else if (ready) begin
        pc <= pc_n;
    end
end

endmodule
