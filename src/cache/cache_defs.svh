`ifndef CACHE_DEFS_SVH
`define CACHE_DEFS_SVH

/*
	This header defines common data structrue & funcs in cache module
*/

// common defs
`include "common_defs.svh"

// data struct
`define DEF_STRUCT_TAG_T typedef struct packed { \
	logic valid; \
	logic [TAG_WIDTH - 1:0] tag; \
} tag_t;
`define DEF_STRUCT_LINE_T typedef logic [DATA_PER_LINE - 1:0][DATA_WIDTH - 1:0] line_t;
`define DEF_STRUCT_INDEX_T typedef logic [INDEX_WIDTH - 1:0] index_t;
`define DEF_STRUCT_OFFSET_T typedef logic [LINE_BYTE_OFFSET - DATA_BYTE_OFFSET - 1:0] offset_t;

// func
`define DEF_FUNC_GET_INDEX function index_t get_index( input phys_t addr ); \
	return addr[LINE_BYTE_OFFSET + INDEX_WIDTH - 1 : LINE_BYTE_OFFSET]; \
endfunction
`define DEF_FUNC_GET_TAG function logic [TAG_WIDTH - 1:0] get_tag( input phys_t addr ); \
	return addr[31 : LINE_BYTE_OFFSET + INDEX_WIDTH]; \
endfunction
`define DEF_FUNC_GET_OFFSET function offset_t get_offset( input phys_t addr ); \
	return addr[LINE_BYTE_OFFSET - 1 : DATA_BYTE_OFFSET]; \
endfunction

`endif
