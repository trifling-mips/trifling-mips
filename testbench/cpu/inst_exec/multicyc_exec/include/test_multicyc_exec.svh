`ifndef TEST_MULTICYC_EXEC_SVH
`define TEST_MULTICYC_EXEC_SVH

/*
    This header defines common constants in test_multicyc_exec module
*/

// test_cpu
`include "test_cpu.svh"

`ifdef PATH_PREFIX
`undef PATH_PREFIX
`endif
`define PATH_PREFIX "testbench/cpu/inst_exec/multicyc_exec/testcases/"
`DEF_FUNC_GET_PATH

`endif
