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

// interface of I$ and CPU
// I$ is 1-stage
interface cpu_ibus_if();
    // inv_icache
    logic inv;                  // inv_icache
    phys_t inv_addr;
	// control signals
	logic ready, valid;	        // ready  & valid signal from icache
	// read signals
	virt_t vaddr;		        // read vaddr
    phys_t paddr, paddr_plus1;  // read paddr, delay one peroid
	uint32_t rddata;	        // read data

	modport master (
		input ready, rddata, valid
		output vaddr, paddr, paddr_plus1
	);

	modport slave 
		output ready, rddata, valid
		input vaddr, paddr, paddr_plus1
	);

endinterface

// interface for D$ and CPU
// D$ is 3-stage pipelined
typedef struct packed {
	logic [$clog2(`N_RESV_LSU):0] lsu_idx;
	phys_t addr;		// aligned in 4-bytes
	// byteenable[i] corresponds to wrdata[(i + 1) * 8 - 1 : i * 8]
	logic [$bits(uint32_t) / $bits(uint8_t) - 1:0] be;
	uint32_t wrdata;
	logic read, write, uncached;
} lsu_req;
typedef struct packed {
	logic [$clog2(`N_RESV_LSU):0] lsu_idx;
	uint32_t rddata;
	logic rddata_vld;
} lsu_resp;
interface cpu_dbus_if();
	// control signals
	// for D$
	logic stall, inv_dcache;
	// for I$
	logic inv_icache;
	// lsu_req
	lsu_req lsu_req;
	lsu_resp lsu_resp, lsu_uncached_resp;

	modport master (
		output inv_dcache, inv_icache, lsu_req,
		input stall, lsu_resp, lsu_uncached_resp
	);

	modport slave (
		input inv_dcache, inv_icache, lsu_req,
		output stall, lsu_resp, lsu_uncached_resp
	);

endinterface

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
