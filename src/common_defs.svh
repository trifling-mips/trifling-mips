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
// interface for AXI3
interface axi3_if();
	// ar
	uint32_t		araddr;
	logic	[3 :0]	arlen;
	logic	[2 :0]	arsize;
	logic	[1 :0]	arburst;
	logic			arlock;
	logic	[3 :0]	arcache;
	logic	[2 :0]	arprot;
	logic			arvalid;
	logic			arready;
	// r
	logic			rready;
	uint32_t		rdata;
	logic	[1 :0]	rresp;
	logic			rlast;
	logic			rvalid;
	// aw
	uint32_t		awaddr;
	logic	[3 :0]	awlen;
	logic	[2 :0]	awsize;
	logic	[1 :0]	awburst;
	logic			awlock;
	logic	[3 :0]	awcache;
	logic	[2 :0]	awprot;
	logic			awvalid;
	logic			awready;
	// w
	uint32_t		wdata;
	logic	[3 :0]	wstrb;
	logic			wlast;
	logic			wvalid;
	logic			wready;
	// b
	logic			bready;
	logic	[1 :0]	bresp;
	logic			bvalid;

	modport master (
		// ar
		output araddr, arlen, arsize, arburst, arlock, arcache, arprot, arvalid;
		input arready;
		// r
		output rready;
		input rdata, rresp, rlast, rvalid;
		// aw
		output awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awvalid;
		input awready;
		// w
		output wdata, wstrb, wlast, wvalid;
		input wready;
		// b
		output bready;
		input bresp, bvalid;
	);

	modport slave (
		// ar
		input araddr, arlen, arsize, arburst, arlock, arcache, arprot, arvalid;
		output arready;
		// r
		input rready;
		output rdata, rresp, rlast, rvalid;
		// aw
		input awaddr, awlen, awsize, awburst, awlock, awcache, awprot, awvalid;
		output awready;
		// w
		input wdata, wstrb, wlast, wvalid;
		output wready;
		// b
		input bready;
		output bresp, bvalid;
	);

endinterface
`endif

`endif
