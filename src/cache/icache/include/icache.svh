`ifndef ICACHE_SVH
`define ICACHE_SVH

/*
	This header defines common data structrue & funcs in icache module
*/

// cache defs
`include "cache_defs.svh"

typedef enum logic [2:0] {
	ICACHE_IDLE,
	ICACHE_WAIT_COMMIT,
	ICACHE_FETCH,
	ICACHE_PREFETCH_LOAD,
	ICACHE_INVALIDATING
} icache_state_t;

`endif
