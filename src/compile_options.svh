`ifndef COMPILE_OPTIONS_SVH
`define COMPILE_OPTIONS_SVH

/**
    Options to control optional components to be compiled
    These options are used to speed up compilation when debugging
**/

// enable all func unit
`define COMPILE_FULL_M

`ifdef COMPILE_FULL_M
    `define COMPILE_FULL    1
`else
    `define COMPILE_FULL    0
`endif

`define CPU_MMU_ENABLED    `COMPILE_FULL 

// can change value
// num of LSU resv
`define N_RESV_LSU      3
// num of tlb entries
`define N_TLB_ENTRIES   32

// can undefine
// whether enable victim cache in write_buffer
`define VICTIM_CACHE_ENABLE

// cannot change
// enable axi3 interface
`define AXI3_IF_EN

`endif
