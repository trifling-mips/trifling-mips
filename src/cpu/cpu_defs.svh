`ifndef CPU_DEFS_SVH
`define CPU_DEFS_SVH

/*
	This header defines common data structrue & constants in cpu module
*/

// common defs
`include "common_defs.svh"

// MMU/TLB
typedef logic [$clog2(`N_TLB_ENTRIES) - 1:0] tlb_index_t;
typedef struct packed {
    phys_t paddr;
    tlb_index_t index;
    logic miss, dirty, valid;
    logic [2:0] cache_flag;
} tlb_resp_t;
typedef struct packed {
    logic [2:0] c0, c1;
    logic [7:0] asid;
    logic [18:0] vpn2;
    logic [23:0] pfn0, pfn1;
    logic [11:0] mask;
    logic d1, v1, d0, v0;
    logic G;
} tlb_entry_t;

typedef struct packed {
    phys_t paddr;
    virt_t vaddr;
    logic uncached;
    logic inv, miss, dirty, illegal;
} mmu_resp_t;

`endif
