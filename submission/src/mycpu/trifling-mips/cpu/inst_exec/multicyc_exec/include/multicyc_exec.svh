`ifndef MULTICYC_EXEC_SVH
`define MULTICYC_EXEC_SVH

/*
    This header defines common data structrue & constants in multicyc_exec module
*/

// inst_exec defs
`include "inst_exec.svh"

typedef enum logic[0:0] {
    ME_IDLE,
    ME_WAIT
} me_state_t;

`endif
