`ifndef TEST_REPL_SVH
`define TEST_REPL_SVH

/*
	This header defines common constants in test_repl module
*/

// testbench_defs
`include "testbench_defs.svh"

`ifdef PATH_PREFIX
`undef PATH_PREFIX
`endif
`define PATH_PREFIX "testbench/cache/repl/testcases/"
`DEF_FUNC_GET_PATH

`define TEST_REPL_TARGET "plru"

`endif
