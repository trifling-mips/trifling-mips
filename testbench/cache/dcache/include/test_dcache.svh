`ifndef TEST_DCACHE_SVH
`define TEST_DCACHE_SVH

/*
	This header defines common constants in test_dcache module
*/

// testbench_defs
`include "testbench_defs.svh"

`ifdef PATH_PREFIX
`undef PATH_PREFIX
`endif
`define PATH_PREFIX "testbench/cache/testcases/"
`DEF_FUNC_GET_PATH

typedef enum logic [1:0] {
	READ,
	WRITE,
	INV,
	NOP
} req_type_t;

`endif
