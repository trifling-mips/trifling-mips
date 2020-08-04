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
    WB_IDLE,
    WB_WAIT_AWREADY,
    WB_WRITE,
    WB_WAIT_BVALID
} wb_state_t;

`endif
