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
    // ready from icache
    input   logic   ibus_ready,
    // branch resolved
    input   branch_resolved_t   resolved_branch,
    // except req
    input   except_req_t        except_req,
    // output
    output  virt_t  pc,
    output  virt_t  npc,    // for icache fetch
    // mmu iaddt resp
    input   mmu_resp_t  mmu_iaddr_resp,
    // icache resp
    input   logic       ibus_valid,
    input   uint32_t    ibus_rddata,
    // inst_fetch pipe
    output  pipe_if_t   pipe_if,
    output  logic       pipe_if_flush
);

logic ready;
assign pipe_if_flush = except_req.valid | resolved_branch.taken;
assign ready = (ibus_ready & ready_i) | pipe_if_flush;
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
    end else if (ready_i) begin
        pipe_if.vaddr <= pc;
        pipe_if.inst  <= ibus_rddata & {$bits(uint32_t){ibus_valid}};
        pipe_if.valid <= ibus_valid;
        pipe_if.iaddr_ex <= address_exception & {$bits(address_exception_t){ibus_valid}};
    end
end

// inst bpu
// TODO

endmodule
