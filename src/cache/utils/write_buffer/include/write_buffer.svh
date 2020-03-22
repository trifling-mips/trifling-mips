`ifndef WRITE_BUFFER_SVH
`define WRITE_BUFFER_SVH

/*
	This header defines common data structrue & constants in write_buffer module
*/

// cache defs
`include "cache_defs.svh"

// whether enable victim cache
// remove to compile_options.svh
// `define VICTIM_CACHE_ENABLE

// data structrue
typedef enum logic [2:0] {
	IDLE,
	WAIT_AWREADY,
	WRITE,
	WAIT_BVALID
} state_t;

`endif
