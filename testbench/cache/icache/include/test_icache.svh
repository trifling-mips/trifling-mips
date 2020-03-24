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

`define DEF_FUNC_GET_REQ function logic [ADDR_WIDTH - 1:0] get_req( \
	input integer freq \
); \
	logic [ADDR_WIDTH - 1:0] req; \
 \
	if (!$feof(freq)) begin \
		$fscanf(freq, "%x\n", req); \
		return req; \
	end else begin \
		$display("[Error] get_req failed!"); \
		$stop; \
	end \
endfunction

`endif
