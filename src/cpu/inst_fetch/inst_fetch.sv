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
    input   logic   ready,
    // output
    output  virt_t  pc,
    output  virt_t  npc     // for icache fetch
);

// inst pc_generator
pc_generator #(
    .BOOT_VEC(BOOT_VEC),
    .N_ISSUE(N_ISSUE)
) pc_generator_inst (
    .*
);

// inst bpu
// TODO

endmodule
