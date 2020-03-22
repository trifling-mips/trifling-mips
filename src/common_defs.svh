`ifndef COMMON_DEFS_SVH
`define COMMON_DEFS_SVH

/*
	This header defines common data structrue & constants in the whole soc
*/

// project configuration
`default_nettype wire
`timescale 1ns / 1ps

// compile_options
`include "compile_options.svh"

// data formats
typedef logic [7:0]		uint8_t;
typedef logic [15:0]	uint16_t;
typedef logic [31:0]	uint32_t;
typedef logic [63:0]	uint64_t;
typedef uint32_t		virt_t;
typedef uint32_t		phys_t;

`define AXI3_IF_EN

`ifdef AXI3_IF_EN
// interface for AXI3 read
typedef struct packed {
	// ar
	uint32_t					araddr;
	logic	[3 :0]				arlen;
	logic	[2 :0]				arsize;
	logic	[1 :0]				arburst;
	logic						arlock;
	logic	[3 :0]				arcache;
	logic	[2 :0]				arprot;
	logic						arvalid;
	// r
	logic						rready;
} axi3_rd_req_t;
typedef struct packed {
	// ar
	logic						arready;
	// r
	uint32_t					rdata;
	logic	[1 :0]				rresp;
	logic						rlast;
	logic						rvalid;
} axi3_rd_resp_t;
interface axi3_rd_if #(
	parameter	BUS_WIDTH	=	4
) (
);
	// ar
	logic	[BUS_WIDTH - 1:0]	arid;
	// r
	logic	[BUS_WIDTH - 1:0]	rid;

	axi3_rd_req_t axi3_rd_req;
	axi3_rd_resp_t axi3_rd_resp;

	modport master (
		output axi3_rd_req, arid,
		input axi3_rd_resp, rid
	);

	modport slave (
		input axi3_rd_req, arid,
		output axi3_rd_resp, rid
	);

endinterface

// interface for AXI3 write
typedef struct packed {
	// aw
	uint32_t					awaddr;
	logic	[3 :0]				awlen;
	logic	[2 :0]				awsize;
	logic	[1 :0]				awburst;
	logic						awlock;
	logic	[3 :0]				awcache;
	logic	[2 :0]				awprot;
	logic						awvalid;
	// w
	uint32_t					wdata;
	logic	[3 :0]				wstrb;
	logic						wlast;
	logic						wvalid;
	// b
	logic						bready;
} axi3_wr_req_t;
typedef struct packed {
	// aw
	logic						awready;
	// w
	logic						wready;
	// b
	logic	[1 :0]				bresp;
	logic						bvalid;
} axi3_wr_resp_t;
interface axi3_wr_if #(
	parameter	BUS_WIDTH	=	4
) (
);
	// aw
	logic	[BUS_WIDTH - 1:0]	awid;
	// w
	logic	[BUS_WIDTH - 1:0]	wid;
	// b
	logic	[BUS_WIDTH - 1:0]	bid;

	axi3_wr_req_t axi3_wr_req;
	axi3_wr_resp_t axi3_wr_resp;

	modport master (
		output axi3_wr_req, awid, wid,
		input axi3_wr_resp, bid
	);

	modport slave (
		input axi3_wr_req, awid, wid,
		output axi3_wr_resp, bid
	);

endinterface
`endif

`endif
