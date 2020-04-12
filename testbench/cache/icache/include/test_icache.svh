`ifndef TEST_ICACHE_SVH
`define TEST_ICACHE_SVH

/*
	This header defines common constants in test_icache module
*/

// testbench_defs
`include "testbench_defs.svh"

// whether use common testcases
// `define TEST_ICACHE_COMMON_TESTCASES

`ifdef PATH_PREFIX
`undef PATH_PREFIX
`endif
`ifndef TEST_ICACHE_COMMON_TESTCASES
`define PATH_PREFIX "testbench/cache/icache/testcases/"
`else
`define PATH_PREFIX "testbench/cache/testcases/"
`endif
`DEF_FUNC_GET_PATH

`endif
