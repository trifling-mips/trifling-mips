// inst_fetch
`include "inst_fetch.svh"

module inst_fetch #(
    parameter   BOOT_VEC        =   32'hbfc00000,
    parameter   N_ISSUE         =   1,
    parameter   N_INST_CHANNEL  =   2
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
    input   mmu_resp_t [N_INST_CHANNEL - 1:0]   mmu_iaddr_resp,
    // icache resp
    input   logic       ibus_valid,
    // inst_fetch pipe
    output  pipe_if_t   pipe_if
);

logic update, branch_flow, pipe_if_flush;
assign branch_flow = (resolved_branch.taken && resolved_branch.valid) && ibus_valid;
assign pipe_if_flush = except_req.valid || branch_flow;
assign update = (ibus_ready && ready_i) || pipe_if_flush;
// inst pc_generator
pc_generator #(
    .BOOT_VEC(BOOT_VEC),
    .N_ISSUE(N_ISSUE)
) pc_generator_inst (
    .*
);

// address_exception
address_exception_t address_exception;
assign address_exception.illegal = mmu_iaddr_resp[0].illegal;
assign address_exception.miss    = mmu_iaddr_resp[0].miss;
assign address_exception.invalid = mmu_iaddr_resp[0].inv;
// set pipe_if_n
pipe_if_t pipe_if_n;
always_comb begin
    // default
    pipe_if_n = pipe_if;
    // set new value
    pipe_if_n.valid          = 1'b1;
    pipe_if_n.mmu_iaddr_resp = mmu_iaddr_resp;
    pipe_if_n.iaddr_ex       = address_exception;
end
// pipe if
always_ff @ (posedge clk) begin
    if (rst || pipe_if_flush) begin
        pipe_if <= '0;
    end else if (ready_i && ibus_ready) begin
        pipe_if <= pipe_if_n;
    end
end

// set ready_o
assign ready_o = pipe_if.valid;

// inst bpu
// TODO

endmodule
