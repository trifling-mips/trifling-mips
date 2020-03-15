`ifndef COMMON_DEFS_SVH
`define COMMON_DEFS_SVH

/*
	This header defines common data structrue & constants in the whole soc
*/

// project configuration
`default_nettype wire
`timescale 1ns / 1ps

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
interface #(
	parameter	BUS_WIDTH	=	4
) axi3_rd_if (
);
	// ar
	logic	[BUS_WIDTH - 1:0]	arid;
	uint32_t					araddr;
	logic	[3 :0]				arlen;
	logic	[2 :0]				arsize;
	logic	[1 :0]				arburst;
	logic						arlock;
	logic	[3 :0]				arcache;
	logic	[2 :0]				arprot;
	logic						arvalid;
	logic						arready;
	// r
	logic	[BUS_WIDTH - 1:0]	rid;
	logic						rready;
	uint32_t					rdata;
	logic	[1 :0]				rresp;
	logic						rlast;
	logic						rvalid;

	modport master (
		// ar
		output arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arvalid;
		input arready;
		// r
		output rready;
		input rid, rdata, rresp, rlast, rvalid;
	);

	modport slave (
		// ar
		input arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot, arvalid;
		output arready;
		// r
		input rready;
		output rid, rdata, rresp, rlast, rvalid;
	);

endinterface

// interface for AXI3 write
interface #(
	parameter	BUS_WIDTH	=	4
) axi3_wr_if (
);
	// aw
	logic	[BUS_WIDTH - 1:0]	awid;
	uint32_t					awaddr;
	logic	[3 :0]				awlen;
	logic	[2 :0]				awsize;
	logic	[1 :0]				awburst;
	logic						awlock;
	logic	[3 :0]				awcache;
	logic	[2 :0]				awprot;
	logic						awvalid;
	logic						awready;
	// w
	logic	[BUS_WIDTH - 1:0]	wid;
	uint32_t					wdata;
	logic	[3 :0]				wstrb;
	logic						wlast;
	logic						wvalid;
	logic						wready;
	// b
	logic	[BUS_WIDTH - 1:0]	bid;
	logic						bready;
	logic	[1 :0]				bresp;
	logic						bvalid;

	modport master (
		// aw
		output awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awvalid;
		input awready;
		// w
		output wid, wdata, wstrb, wlast, wvalid;
		input wready;
		// b
		output bready;
		input bid, bresp, bvalid;
	);

	modport slave (
		// aw
		input awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awvalid;
		output awready;
		// w
		input wid, wdata, wstrb, wlast, wvalid;
		output wready;
		// b
		input bready;
		output bid, bresp, bvalid;
	);

endinterface
`endif

`endif
