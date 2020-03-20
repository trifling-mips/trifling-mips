`ifndef STREAM_BUFFER_SVH
`define STREAM_BUFFER_SVH

/*
	This header defines common data structrue & constants in stream_buffer module
*/

// cache defs
`include "cache_defs.svh"

// data structrue
typedef enum logic [1:0] {
	IDLE,
	WAIT_AXI_READY,
	RECEIVING,
	FINISH
} state_t;

`endif
