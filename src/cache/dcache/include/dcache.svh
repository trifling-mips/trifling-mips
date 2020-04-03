`ifndef DCACHE_SVH
`define DCACHE_SVH

/*
	This header defines common data structrue & funcs in dcache module
*/

// cache defs
`include "cache_defs.svh"

// funcs
`define DEF_STRUCT_TAG_T typedef struct packed { \
	logic valid; \
	logic dirty; \
	logic [TAG_WIDTH - 1:0] tag; \
} tag_t;

typedef enum logic [2:0] {
	DCACHE_IDLE,
	DCACHE_WAIT_WB,
	DCACHE_WAIT_UNCACHED,
	DCACHE_FETCH,
	DCACHE_PREFETCH_LOAD,
	DCACHE_INVALIDATING,
	DCACHE_WAIT_INVALIDATING,
	DCACHE_RESET
} dcache_state_t;

`endif
