`ifndef TEST_WRITE_BUFFER_SVH
`define TEST_WRITE_BUFFER_SVH

/*
	This header defines common constants in test_wb module
*/

// testbench_defs
`include "testbench_defs.svh"

`ifdef PATH_PREFIX
`undef PATH_PREFIX
`endif
`define PATH_PREFIX "testbench/cache/utils/write_buffer/testcases/"
`DEF_FUNC_GET_PATH

`endif
