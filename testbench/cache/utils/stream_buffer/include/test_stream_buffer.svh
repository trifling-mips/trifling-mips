`ifndef TEST_STREAM_BUFFER_SVH
`define TEST_STREAM_BUFFER_SVH

/*
	This header defines common constants in test_sb module
*/

// testbench_defs
`include "testbench_defs.svh"

`ifdef PATH_PREFIX
`undef PATH_PREFIX
`endif
`define PATH_PREFIX "testbench/cache/utils/stream_buffer/testcases/"
`DEF_FUNC_GET_PATH

`define DEF_FUNC_GET_REQ function phys_t get_req( \
	input integer freq \
); \
	phys_t req; \
 \
	if (!$feof(freq)) begin \
		$fscanf(freq, "%x\n", req); \
		return req[LABEL_WIDTH - 1:0]; \
	end else begin \
		$display("[Error] get_req failed!"); \
		$stop; \
	end \
endfunction

`endif
