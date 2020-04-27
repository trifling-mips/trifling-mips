`ifndef COMPILE_OPTIONS_SVH
`define COMPILE_OPTIONS_SVH

/**
    Options to control optional components to be compiled
    These options are used to speed up compilation when debugging
**/

// enable all func unit
// `define COMPILE_FULL_M

`ifdef COMPILE_FULL_M
    `define COMPILE_FULL    1
`else
    `define COMPILE_FULL    0
`endif

`define CPU_MMU_ENABLED     `COMPILE_FULL

`ifdef COMPILE_FULL_M
    `define FPU_ENABLED
    `define ASIC_ENABLED
`endif

// can change value
// num of tlb entries
`define N_TLB_ENTRIES   32
// num of regs in rf
`define N_REG           32
// whether enable victim cache in write_buffer
`define VICTIM_CACHE_ENABLED    1
// cache parameter
`define ICACHE_LINE_WIDTH    256
`define ICACHE_SET_ASSOC     4
`define ICACHE_SIZE          16 * 1024 * 8
`define DCACHE_LINE_WIDTH    256
`define DCACHE_SET_ASSOC     2
`define DCACHE_SIZE          8 * 1024 * 8

// can undefine

// cannot change
// enable icache_prefetch
`define ICACHE_PREFETCH_ENABLED

`endif
