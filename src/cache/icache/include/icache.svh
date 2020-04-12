`ifndef ICACHE_SVH
`define ICACHE_SVH

/*
    This header defines common data structrue & funcs in icache module
*/

// cache defs
`include "cache_defs.svh"

// funcs
`define DEF_STRUCT_TAG_T typedef struct packed { \
    logic valid; \
    logic [TAG_WIDTH - 1:0] tag; \
} tag_t;

typedef enum logic [1:0] {
    ICACHE_IDLE,
    ICACHE_FETCH,
    ICACHE_PREFETCH_LOAD,
    ICACHE_RESET
} icache_state_t;

`endif
