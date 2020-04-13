`ifndef TEST_ICACHE_SVH
`define TEST_ICACHE_SVH

/*
	This header defines common constants & funcs in test_icache module
*/

// testbench_defs
`include "testbench_defs.svh"

// whether use common testcases
`define TEST_ICACHE_COMMON_TESTCASES

`ifdef PATH_PREFIX
`undef PATH_PREFIX
`endif
`ifndef TEST_ICACHE_COMMON_TESTCASES
`define PATH_PREFIX "testbench/cache/icache/testcases/"
`else
`define PATH_PREFIX "testbench/cache/testcases/"
`endif
`DEF_FUNC_GET_PATH

// struct
typedef enum logic [1:0] {
	READ,
	WRITE,
	INV,
	NOP
} req_type_t;

// funcs
`define DEF_FUNC_MUX_BE function logic [DATA_WIDTH - 1:0] mux_be( \
	input logic [DATA_WIDTH - 1:0] rdata, \
	input logic [DATA_WIDTH - 1:0] wdata, \
	input logic [(DATA_WIDTH / $bits(uint8_t)) - 1:0] sel \
); \
	uint8_t [(DATA_WIDTH / $bits(uint8_t)) - 1:0] r_data, w_data, mux_data; \
 \
	// reshape \
	assign r_data = rdata; \
	assign w_data = wdata; \
	// select \
	for (integer i = 0; i < (DATA_WIDTH / $bits(uint8_t)); i++) \
		mux_data[i] = sel[i] ? w_data[i] : r_data[i]; \
 \
	return mux_data; \
 \
endfunction

`endif
