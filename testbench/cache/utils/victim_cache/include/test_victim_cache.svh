`ifndef TEST_VICTIM_CACHE_SVH
`define TEST_VICTIM_CACHE_SVH

/*
    This header defines common constants in test_vc module
*/

// testbench_defs
`include "testbench_defs.svh"

`ifdef PATH_PREFIX
`undef PATH_PREFIX
`endif
`define PATH_PREFIX "testbench/cache/utils/victim_cache/testcases/"
`DEF_FUNC_GET_PATH

`endif
