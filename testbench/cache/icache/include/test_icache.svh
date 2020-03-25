`ifndef TEST_ICACHE_SVH
`define TEST_ICACHE_SVH

/*
	This header defines common constants in test_icache module
*/

// testbench_defs
`include "testbench_defs.svh"

`ifdef PATH_PREFIX
`undef PATH_PREFIX
`endif
`define PATH_PREFIX "testbench/cache/icache/testcases/"
`DEF_FUNC_GET_PATH

`endif
