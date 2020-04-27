// inst_fetch
`include "inst_fetch.svh"

module inst_fetch #(
    parameter   BOOT_VEC    =   32'hbfc00000,
    parameter   N_ISSUE     =   1
) (
    // external signals
    input   logic   clk,
    input   logic   rst,
    // ready from icache
    input   logic   ibus_ready,
    // branch resolved
    input   branch_resolved_t   resolved_branch,
    // except req
    input   except_req_t        except_req,
    // output
    output  virt_t  pc,
    output  virt_t  npc,    // for icache fetch
    // icache resp
    input   logic       ibus_valid,
    input   uint32_t    ibus_rddata,
    // inst_fetch pipe
    output  pipe_if_t   pipe_if,
    // hand_shake if
    hand_shake_if.master    hand_shake_ifid
);

logic ready, pipe_flush;
assign pipe_flush = except_req.valid | resolved_branch.taken;
assign ready = (ibus_ready & hand_shake_ifid.ready) | pipe_flush;
// inst pc_generator
pc_generator #(
    .BOOT_VEC(BOOT_VEC),
    .N_ISSUE(N_ISSUE)
) pc_generator_inst (
    .*
);

// pipe if
always_ff @ (posedge clk) begin
    if (rst | pipe_flush) begin
        pipe_if               <= '0;
        hand_shake_ifid.valid <= 1'b0;
    end else if (hand_shake_ifid.ready) begin
        pipe_if.vaddr         <= pc;
        pipe_if.inst          <= ibus_rddata;
        hand_shake_ifid.valid <= ibus_valid;
    end
end

// inst bpu
// TODO

endmodule
