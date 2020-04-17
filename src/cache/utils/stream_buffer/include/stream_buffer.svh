`ifndef STREAM_BUFFER_SVH
`define STREAM_BUFFER_SVH

/*
    This header defines common data structrue & constants in stream_buffer module
*/

// cache defs
`include "cache_defs.svh"

// data structrue
typedef enum logic [2:0] {
    SB_IDLE,
    SB_WAIT_AXI_READY,
    SB_RECEIVING,
    SB_FLUSH_WAIT_AXI_READY,
    SB_FLUSH_RECEIVING
} sb_state_t;

`endif
