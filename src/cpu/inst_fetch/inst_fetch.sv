// inst_fetch
`include "inst_fetch.svh"

module inst_fetch #(
    parameter   BOOT_VEC    =   32'hbfc00000,
    parameter   N_ISSUE     =   1
) (
    // external signals
    input   logic   clk,
    input   logic   rst,
    // ready from id stage
    input   logic   ready_i,
    output  logic   ready_o,
    // ready from icache
    input   logic   ibus_ready,
    // branch resolved
    input   branch_resolved_t   resolved_branch,
    // except req
    input   except_req_t        except_req,
    // output
    output  virt_t  pc,
    // mmu iaddt resp
    input   mmu_resp_t  mmu_iaddr_resp,
    // icache resp
    input   logic       ibus_valid,
    // inst_fetch pipe
    output  pipe_if_t   pipe_if
);

logic update, branch_flow, branch_stall, pipe_if_flush;
assign branch_flow = (resolved_branch.taken && ibus_valid);
assign branch_stall= (resolved_branch.taken && ~ibus_valid);
assign pipe_if_flush = except_req.valid | branch_flow;
assign update = (ibus_ready & ready_i) | pipe_if_flush;
// inst pc_generator
pc_generator #(
    .BOOT_VEC(BOOT_VEC),
    .N_ISSUE(N_ISSUE)
) pc_generator_inst (
    .*
);

// address_exception
address_exception_t address_exception;
assign address_exception.illegal = mmu_iaddr_resp.illegal;
assign address_exception.miss    = mmu_iaddr_resp.miss;
assign address_exception.invalid = mmu_iaddr_resp.inv;
// pipe if
always_ff @ (posedge clk) begin
    if (rst | pipe_if_flush) begin
        pipe_if       <= '0;
    end else if (ready_i | branch_stall) begin
        pipe_if.vaddr <= pc;
        pipe_if.paddr <= mmu_iaddr_resp.paddr;
        pipe_if.valid <= 1'b1;
        pipe_if.iaddr_ex <= address_exception & {$bits(address_exception_t){ibus_valid}};
    end
end

// set ready_o
assign ready_o = pipe_if.valid;

// inst bpu
// TODO

endmodule
