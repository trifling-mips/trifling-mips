`ifndef MMU_SVH
`define MMU_SVH

/*
    This header defines common data structrue & funcs in mmu module
*/

// cpu defs
`include "cpu_defs.svh"

// funcs
`define DEF_FUNC_IS_VADDR_MAPPED function logic is_vaddr_mapped ( \
    input   virt_t  vaddr \
); \
    // useg (0xx), kseg2 (110), kseg3 (111) \
    return (~vaddr[31] || vaddr[31:30] = 2'b11); \
endfunction
`define DEF_FUNC_IS_VADDR_UNCACHED function logic is_vaddr_uncached ( \
    input   virt_t  vaddr, \
    input   logic   kseg0_uncached \
); \
    return vaddr[31:29] == 3'b101 || kseg0_uncached && vaddr[31:29] == 3'b100; \
endfunction

`endif

