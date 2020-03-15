`ifndef CACHE_DEFS_SVH
`define CACHE_DEFS_SVH

/*
	This header defines common data structrue & funcs in cache module
*/

// common defs
`include "common_defs.svh"

// define for parameter
`define DATA_WIDTH			DATA_WIDTH
`define TAG_WIDTH			TAG_WIDTH
`define INDEX_WIDTH			INDEX_WIDTH
`define DATA_PER_LINE		DATA_PER_LINE
`define LINE_BYTE_OFFSET	LINE_BYTE_OFFSET
`define DATA_BYTE_OFFSET	DATA_BYTE_OFFSET

// data struct
typedef struct packed {
	logic valid;
	logic [`TAG_WIDTH - 1:0] tag;
} tag_t;
typedef logic [`DATA_PER_LINE - 1:0][`DATA_WIDTH - 1:0] line_t;
typedef logic [`INDEX_WIDTH - 1:0] index_t;
typedef logic [`LINE_BYTE_OFFSET - `DATA_BYTE_OFFSET - 1:0] offset_t;

// func
function index_t get_index( input phys_t addr );
	return addr[`LINE_BYTE_OFFSET + `INDEX_WIDTH - 1 : `LINE_BYTE_OFFSET];
endfunction
function logic [`TAG_WIDTH - 1:0] get_tag( input phys_t addr );
	return addr[31 : `LINE_BYTE_OFFSET + `INDEX_WIDTH];
endfunction
function offset_t get_offset( input phys_t addr );
	return addr[`LINE_BYTE_OFFSET - 1 : `DATA_BYTE_OFFSET];
endfunction

`endif
