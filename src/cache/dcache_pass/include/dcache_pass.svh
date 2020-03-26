`ifndef DCACHE_PASS_SVH
`define DCACHE_PASS_SVH

/*
	This header defines common data structrue & constants in dcache_pass module
*/

// cache defs
`include "cache_defs.svh"

// whether enable victim cache
// remove to compile_options.svh
// `define VICTIM_CACHE_ENABLE

// data structrue
typedef enum logic [2:0] {
	DP_IDLE,
	DP_WAIT_AWREADY,
	DP_WRITE,
	DP_WAIT_BVALID,
	DP_WAIT_ARREADY,
	DP_READ
} dp_state_t;

`endif
