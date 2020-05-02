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
typedef logic [7:0]     uint8_t;
typedef logic [15:0]    uint16_t;
typedef logic [31:0]    uint32_t;
typedef logic [63:0]    uint64_t;
typedef uint32_t        virt_t;
typedef uint32_t        phys_t;

// interface of I$ and CPU
// I$ is 1-stage
interface cpu_ibus_if();
    // inv_icache
    logic inv;                  // inv_icache
    phys_t inv_addr;
    // control signals
    logic ready, valid, read;   // ready  & valid signal from icache
    // read signals
    virt_t vaddr;               // read vaddr
    phys_t paddr, paddr_plus1;  // read paddr, delay one peroid
    uint32_t rddata;            // read data

    modport master (
        input ready, rddata, valid,
        output read, vaddr, paddr, paddr_plus1, inv, inv_addr
    );

    modport slave (
        output ready, rddata, valid,
        input read, vaddr, paddr, paddr_plus1, inv, inv_addr
    );

endinterface

// interface for D$ and CPU
// D$ is 1-stage
typedef struct packed {
    virt_t vaddr;
    phys_t paddr;        // aligned in 4-bytes
    // byteenable[i] corresponds to wrdata[(i + 1) * 8 - 1 : i * 8]
    logic [$bits(uint32_t) / $bits(uint8_t) - 1:0] be;
    uint32_t wrdata;
    logic read, write, uncached, inv;
} dcache_req_t;
typedef struct packed {
    uint32_t rddata;
    logic valid;
} dcache_resp_t;
interface cpu_dbus_if();
    // control signals
    // for D$
    logic ready;
    // lsu_req
    dcache_req_t dcache_req;
    dcache_resp_t dcache_resp;

    modport master (
        output dcache_req,
        input ready, dcache_resp
    );

    modport slave (
        input dcache_req,
        output ready, dcache_resp
    );

endinterface

// interface for AXI3 read
typedef struct packed {
    // ar
    uint32_t                    araddr;
    logic   [3 :0]              arlen;
    logic   [2 :0]              arsize;
    logic   [1 :0]              arburst;
    logic                       arlock;
    logic   [3 :0]              arcache;
    logic   [2 :0]              arprot;
    logic                       arvalid;
    // r
    logic                       rready;
} axi3_rd_req_t;
typedef struct packed {
    // ar
    logic                       arready;
    // r
    uint32_t                    rdata;
    logic   [1 :0]              rresp;
    logic                       rlast;
    logic                       rvalid;
} axi3_rd_resp_t;
interface axi3_rd_if #(
    parameter   BUS_WIDTH   =   4
) (
);
    // ar
    logic   [BUS_WIDTH - 1:0]   arid;
    // r
    logic   [BUS_WIDTH - 1:0]   rid;

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
    uint32_t                    awaddr;
    logic   [3 :0]              awlen;
    logic   [2 :0]              awsize;
    logic   [1 :0]              awburst;
    logic                       awlock;
    logic   [3 :0]              awcache;
    logic   [2 :0]              awprot;
    logic                       awvalid;
    // w
    uint32_t                    wdata;
    logic   [3 :0]              wstrb;
    logic                       wlast;
    logic                       wvalid;
    // b
    logic                       bready;
} axi3_wr_req_t;
typedef struct packed {
    // aw
    logic                       awready;
    // w
    logic                       wready;
    // b
    logic   [1 :0]              bresp;
    logic                       bvalid;
} axi3_wr_resp_t;
interface axi3_wr_if #(
    parameter   BUS_WIDTH   =   4
) (
);
    // aw
    logic   [BUS_WIDTH - 1:0]   awid;
    // w
    logic   [BUS_WIDTH - 1:0]   wid;
    // b
    logic   [BUS_WIDTH - 1:0]   bid;

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

// debug_req
typedef struct packed {
    virt_t vaddr;
    uint32_t regs_wrdata;
    logic [$bits(uint32_t)/$bits(uint8_t)-1:0] regs_wbe;
    reg_addr_t regs_waddr;
} debug_req_t;

`endif
