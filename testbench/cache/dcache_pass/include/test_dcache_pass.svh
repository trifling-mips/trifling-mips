`ifndef TEST_DCACHE_PASS_SVH
`define TEST_DCACHE_PASS_SVH

/*
	This header defines common constants in test_dcache_pass module
*/

// testbench_defs
`include "testbench_defs.svh"

`ifdef PATH_PREFIX
`undef PATH_PREFIX
`endif
`define PATH_PREFIX "testbench/cache/dcache_pass/testcases/"
`DEF_FUNC_GET_PATH

`endif
