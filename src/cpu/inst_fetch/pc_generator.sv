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
    // output
    output  virt_t  pc,
    output  virt_t  npc     // for icache fetch
);

always_comb begin
    npc = pc;
    // default
    npc = {pc[$bits(virt_t) - 1:LBITS_PC] + 1, {LBITS_PC{1'b0}}};
end

always_ff @ (posedge clk) begin
    if (rst) begin
        pc <= {BOOT_VEC[$bits(virt_t) - 1:LBITS_PC] - 1, {LBITS_PC{1'b0}}};
    end else if (ready) begin
        pc <= npc;
    end
end

endmodule
