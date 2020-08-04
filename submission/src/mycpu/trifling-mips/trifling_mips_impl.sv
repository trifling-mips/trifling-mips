// trifling_mips_impl
`include "common_defs.svh"

module trifling_mips_impl #(
    // common parameter
    parameter   BUS_WIDTH   =   4,
    // parameter for cache_controller
    parameter   ICACHE_DATA_WIDTH           =   32,     // single issue
    parameter   ICACHE_LINE_WIDTH           =   `ICACHE_LINE_WIDTH,
    parameter   ICACHE_SET_ASSOC            =   `ICACHE_SET_ASSOC,
    parameter   ICACHE_CACHE_SIZE           =   `ICACHE_SIZE,
    parameter   ICACHE_ARID                 =   0,
    parameter   DCACHE_DATA_WIDTH           =   32, 
    parameter   DCACHE_LINE_WIDTH           =   `DCACHE_LINE_WIDTH, 
    parameter   DCACHE_SET_ASSOC            =   `DCACHE_SET_ASSOC,
    parameter   DCACHE_CACHE_SIZE           =   `DCACHE_SIZE,
    parameter   DCACHE_VICTIM_CACHE_ENABLED =   1,
    parameter   DCACHE_WB_LINE_DEPTH        =   8,
    parameter   DCACHE_AID                  =   1,
    parameter   DCACHE_PASS_DATA_DEPTH      =   8,
    parameter   DCACHE_PASS_AID             =   2,
    // parameter for cpu_core
    parameter   N_ISSUE         =   1,
    parameter   N_TLB_ENTRIES   =   32,
    // parameter for icache
    parameter   LINE_WIDTH  =   ICACHE_LINE_WIDTH,
    // parameter for inst_fetch
    parameter   BOOT_VEC    =   32'hbfc00000,
    // parameter for inst_decode
    parameter   WRITE_PORTS =   1,
    parameter   READ_PORTS  =   2,
    parameter   N_REG       =   32,
    // parameter for mmu
    parameter   MMU_ENABLED     =   0,
    parameter   N_INST_CHANNEL  =   2
) (
    // external signals
    input   wire    aclk,
    input   wire    rst_n,
    // interrupt
    input   wire[4:0]   interrupt,

    // icache
    // AXI AR signals
    output wire [BUS_WIDTH - 1 :0] icache_arid   ,
    output wire [31:0]             icache_araddr ,
    output wire [3 :0]             icache_arlen  ,
    output wire [2 :0]             icache_arsize ,
    output wire [1 :0]             icache_arburst,
    output wire [1 :0]             icache_arlock ,
    output wire [3 :0]             icache_arcache,
    output wire [2 :0]             icache_arprot ,
    output wire                    icache_arvalid,
    input  wire                    icache_arready,
    // AXI R signals
    input  wire [BUS_WIDTH - 1 :0] icache_rid    ,
    input  wire [31:0]             icache_rdata  ,
    input  wire [1 :0]             icache_rresp  ,
    input  wire                    icache_rlast  ,
    input  wire                    icache_rvalid ,
    output wire                    icache_rready ,
    // AXI AW signals
    output wire [BUS_WIDTH - 1 :0] icache_awid   ,
    output wire [31:0]             icache_awaddr ,
    output wire [3 :0]             icache_awlen  ,
    output wire [2 :0]             icache_awsize ,
    output wire [1 :0]             icache_awburst,
    output wire [1 :0]             icache_awlock ,
    output wire [3 :0]             icache_awcache,
    output wire [2 :0]             icache_awprot ,
    output wire                    icache_awvalid,
    input  wire                    icache_awready,
    // AXI W signals
    output wire [BUS_WIDTH - 1 :0] icache_wid    ,
    output wire [31:0]             icache_wdata  ,
    output wire [3 :0]             icache_wstrb  ,
    output wire                    icache_wlast  ,
    output wire                    icache_wvalid ,
    input  wire                    icache_wready ,
    // AXI B signals
    input  wire [BUS_WIDTH - 1 :0] icache_bid    ,
    input  wire [1 :0]             icache_bresp  ,
    input  wire                    icache_bvalid ,
    output wire                    icache_bready ,

    // dcache
    // AXI AR signals
    output wire [BUS_WIDTH - 1 :0] dcache_arid   ,
    output wire [31:0]             dcache_araddr ,
    output wire [3 :0]             dcache_arlen  ,
    output wire [2 :0]             dcache_arsize ,
    output wire [1 :0]             dcache_arburst,
    output wire [1 :0]             dcache_arlock ,
    output wire [3 :0]             dcache_arcache,
    output wire [2 :0]             dcache_arprot ,
    output wire                    dcache_arvalid,
    input  wire                    dcache_arready,
    // AXI R signals
    input  wire [BUS_WIDTH - 1 :0] dcache_rid    ,
    input  wire [31:0]             dcache_rdata  ,
    input  wire [1 :0]             dcache_rresp  ,
    input  wire                    dcache_rlast  ,
    input  wire                    dcache_rvalid ,
    output wire                    dcache_rready ,
    // AXI AW signals
    output wire [BUS_WIDTH - 1 :0] dcache_awid   ,
    output wire [31:0]             dcache_awaddr ,
    output wire [3 :0]             dcache_awlen  ,
    output wire [2 :0]             dcache_awsize ,
    output wire [1 :0]             dcache_awburst,
    output wire [1 :0]             dcache_awlock ,
    output wire [3 :0]             dcache_awcache,
    output wire [2 :0]             dcache_awprot ,
    output wire                    dcache_awvalid,
    input  wire                    dcache_awready,
    // AXI W signals
    output wire [BUS_WIDTH - 1 :0] dcache_wid    ,
    output wire [31:0]             dcache_wdata  ,
    output wire [3 :0]             dcache_wstrb  ,
    output wire                    dcache_wlast  ,
    output wire                    dcache_wvalid ,
    input  wire                    dcache_wready ,
    // AXI B signals
    input  wire [BUS_WIDTH - 1 :0] dcache_bid    ,
    input  wire [1 :0]             dcache_bresp  ,
    input  wire                    dcache_bvalid ,
    output wire                    dcache_bready ,

    // uncached
    // AXI AR signals
    output wire [BUS_WIDTH - 1 :0] duncache_arid   ,
    output wire [31:0]             duncache_araddr ,
    output wire [3 :0]             duncache_arlen  ,
    output wire [2 :0]             duncache_arsize ,
    output wire [1 :0]             duncache_arburst,
    output wire [1 :0]             duncache_arlock ,
    output wire [3 :0]             duncache_arcache,
    output wire [2 :0]             duncache_arprot ,
    output wire                    duncache_arvalid,
    input  wire                    duncache_arready,
    // AXI R signals
    input  wire [BUS_WIDTH - 1 :0] duncache_rid    ,
    input  wire [31:0]             duncache_rdata  ,
    input  wire [1 :0]             duncache_rresp  ,
    input  wire                    duncache_rlast  ,
    input  wire                    duncache_rvalid ,
    output wire                    duncache_rready ,
    // AXI AW signals
    output wire [BUS_WIDTH - 1 :0] duncache_awid   ,
    output wire [31:0]             duncache_awaddr ,
    output wire [3 :0]             duncache_awlen  ,
    output wire [2 :0]             duncache_awsize ,
    output wire [1 :0]             duncache_awburst,
    output wire [1 :0]             duncache_awlock ,
    output wire [3 :0]             duncache_awcache,
    output wire [2 :0]             duncache_awprot ,
    output wire                    duncache_awvalid,
    input  wire                    duncache_awready,
    // AXI W signals
    output wire [BUS_WIDTH - 1 :0] duncache_wid    ,
    output wire [31:0]             duncache_wdata  ,
    output wire [3 :0]             duncache_wstrb  ,
    output wire                    duncache_wlast  ,
    output wire                    duncache_wvalid ,
    input  wire                    duncache_wready ,
    // AXI B signals
    input  wire [BUS_WIDTH - 1 :0] duncache_bid    ,
    input  wire [1 :0]             duncache_bresp  ,
    input  wire                    duncache_bvalid ,
    output wire                    duncache_bready,

    // debug signals
    output wire [31:0] debug_wb_pc      ,
    output wire [3 :0] debug_wb_rf_wen  ,
    output wire [4 :0] debug_wb_rf_wnum ,
    output wire [31:0] debug_wb_rf_wdata
);

// init bus_if & debug_req
cpu_ibus_if ibus();
cpu_dbus_if dbus();
debug_req_t debug_req;

// set debug_req
assign debug_wb_pc      = debug_req.vaddr;
assign debug_wb_rf_wen  = debug_req.regs_wbe;
assign debug_wb_rf_wnum = debug_req.regs_waddr;
assign debug_wb_rf_wdata= debug_req.regs_wrdata;

// set clk & rst
wire clk = aclk;
// synchronize reset
logic [2:0] sync_rst;
always_ff @ (posedge clk) begin
    sync_rst <= { sync_rst[1:0], ~rst_n };
end
wire rst = sync_rst[2];

// pack AXI signals
// icache
// cached
axi3_rd_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_rd_if_icached();
axi3_wr_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_wr_if_icached();      // unused
// dcache
// cached
axi3_rd_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_rd_if_dcached();
axi3_wr_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_wr_if_dcached();
// uncached
axi3_rd_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_rd_if_duncached();
axi3_wr_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_wr_if_duncached();

// icached
assign icache_arid    = axi3_rd_if_icached.arid;
assign icache_araddr  = axi3_rd_if_icached.axi3_rd_req.araddr;
assign icache_arlen   = axi3_rd_if_icached.axi3_rd_req.arlen;
assign icache_arsize  = axi3_rd_if_icached.axi3_rd_req.arsize;
assign icache_arburst = axi3_rd_if_icached.axi3_rd_req.arburst;
assign icache_arlock  = axi3_rd_if_icached.axi3_rd_req.arlock;
assign icache_arcache = axi3_rd_if_icached.axi3_rd_req.arcache;
assign icache_arprot  = axi3_rd_if_icached.axi3_rd_req.arprot;
assign icache_arvalid = axi3_rd_if_icached.axi3_rd_req.arvalid;
assign icache_rready  = axi3_rd_if_icached.axi3_rd_req.rready;
assign icache_awid    = axi3_wr_if_icached.awid;
assign icache_awaddr  = axi3_wr_if_icached.axi3_wr_req.awaddr;
assign icache_awlen   = axi3_wr_if_icached.axi3_wr_req.awlen;
assign icache_awsize  = axi3_wr_if_icached.axi3_wr_req.awsize;
assign icache_awburst = axi3_wr_if_icached.axi3_wr_req.awburst;
assign icache_awlock  = axi3_wr_if_icached.axi3_wr_req.awlock;
assign icache_awcache = axi3_wr_if_icached.axi3_wr_req.awcache;
assign icache_awprot  = axi3_wr_if_icached.axi3_wr_req.awprot;
assign icache_awvalid = axi3_wr_if_icached.axi3_wr_req.awvalid;
assign icache_wid     = axi3_wr_if_icached.wid;
assign icache_wdata   = axi3_wr_if_icached.axi3_wr_req.wdata;
assign icache_wstrb   = axi3_wr_if_icached.axi3_wr_req.wstrb;
assign icache_wlast   = axi3_wr_if_icached.axi3_wr_req.wlast;
assign icache_wvalid  = axi3_wr_if_icached.axi3_wr_req.wvalid;
assign icache_bready  = axi3_wr_if_icached.axi3_wr_req.bready;
assign axi3_rd_if_icached.axi3_rd_resp.arready = icache_arready;
assign axi3_rd_if_icached.rid                  = icache_rid;
assign axi3_rd_if_icached.axi3_rd_resp.rdata   = icache_rdata;
assign axi3_rd_if_icached.axi3_rd_resp.rresp   = icache_rresp;
assign axi3_rd_if_icached.axi3_rd_resp.rlast   = icache_rlast;
assign axi3_rd_if_icached.axi3_rd_resp.rvalid  = icache_rvalid;
assign axi3_wr_if_icached.axi3_wr_resp.awready = icache_awready;
assign axi3_wr_if_icached.axi3_wr_resp.wready  = icache_wready;
assign axi3_wr_if_icached.bid                  = icache_bid;
assign axi3_wr_if_icached.axi3_wr_resp.bresp   = icache_bresp;
assign axi3_wr_if_icached.axi3_wr_resp.bvalid  = icache_bvalid;

// dcached
assign dcache_arid    = axi3_rd_if_dcached.arid;
assign dcache_araddr  = axi3_rd_if_dcached.axi3_rd_req.araddr;
assign dcache_arlen   = axi3_rd_if_dcached.axi3_rd_req.arlen;
assign dcache_arsize  = axi3_rd_if_dcached.axi3_rd_req.arsize;
assign dcache_arburst = axi3_rd_if_dcached.axi3_rd_req.arburst;
assign dcache_arlock  = axi3_rd_if_dcached.axi3_rd_req.arlock;
assign dcache_arcache = axi3_rd_if_dcached.axi3_rd_req.arcache;
assign dcache_arprot  = axi3_rd_if_dcached.axi3_rd_req.arprot;
assign dcache_arvalid = axi3_rd_if_dcached.axi3_rd_req.arvalid;
assign dcache_rready  = axi3_rd_if_dcached.axi3_rd_req.rready;
assign dcache_awid    = axi3_wr_if_dcached.awid;
assign dcache_awaddr  = axi3_wr_if_dcached.axi3_wr_req.awaddr;
assign dcache_awlen   = axi3_wr_if_dcached.axi3_wr_req.awlen;
assign dcache_awsize  = axi3_wr_if_dcached.axi3_wr_req.awsize;
assign dcache_awburst = axi3_wr_if_dcached.axi3_wr_req.awburst;
assign dcache_awlock  = axi3_wr_if_dcached.axi3_wr_req.awlock;
assign dcache_awcache = axi3_wr_if_dcached.axi3_wr_req.awcache;
assign dcache_awprot  = axi3_wr_if_dcached.axi3_wr_req.awprot;
assign dcache_awvalid = axi3_wr_if_dcached.axi3_wr_req.awvalid;
assign dcache_wid     = axi3_wr_if_dcached.wid;
assign dcache_wdata   = axi3_wr_if_dcached.axi3_wr_req.wdata;
assign dcache_wstrb   = axi3_wr_if_dcached.axi3_wr_req.wstrb;
assign dcache_wlast   = axi3_wr_if_dcached.axi3_wr_req.wlast;
assign dcache_wvalid  = axi3_wr_if_dcached.axi3_wr_req.wvalid;
assign dcache_bready  = axi3_wr_if_dcached.axi3_wr_req.bready;
assign axi3_rd_if_dcached.axi3_rd_resp.arready = dcache_arready;
assign axi3_rd_if_dcached.rid                  = dcache_rid;
assign axi3_rd_if_dcached.axi3_rd_resp.rdata   = dcache_rdata;
assign axi3_rd_if_dcached.axi3_rd_resp.rresp   = dcache_rresp;
assign axi3_rd_if_dcached.axi3_rd_resp.rlast   = dcache_rlast;
assign axi3_rd_if_dcached.axi3_rd_resp.rvalid  = dcache_rvalid;
assign axi3_wr_if_dcached.axi3_wr_resp.awready = dcache_awready;
assign axi3_wr_if_dcached.axi3_wr_resp.wready  = dcache_wready;
assign axi3_wr_if_dcached.bid                  = dcache_bid;
assign axi3_wr_if_dcached.axi3_wr_resp.bresp   = dcache_bresp;
assign axi3_wr_if_dcached.axi3_wr_resp.bvalid  = dcache_bvalid;

// duncached
assign duncache_arid    = axi3_rd_if_duncached.arid;
assign duncache_araddr  = axi3_rd_if_duncached.axi3_rd_req.araddr;
assign duncache_arlen   = axi3_rd_if_duncached.axi3_rd_req.arlen;
assign duncache_arsize  = axi3_rd_if_duncached.axi3_rd_req.arsize;
assign duncache_arburst = axi3_rd_if_duncached.axi3_rd_req.arburst;
assign duncache_arlock  = axi3_rd_if_duncached.axi3_rd_req.arlock;
assign duncache_arcache = axi3_rd_if_duncached.axi3_rd_req.arcache;
assign duncache_arprot  = axi3_rd_if_duncached.axi3_rd_req.arprot;
assign duncache_arvalid = axi3_rd_if_duncached.axi3_rd_req.arvalid;
assign duncache_rready  = axi3_rd_if_duncached.axi3_rd_req.rready;
assign duncache_awid    = axi3_wr_if_duncached.awid;
assign duncache_awaddr  = axi3_wr_if_duncached.axi3_wr_req.awaddr;
assign duncache_awlen   = axi3_wr_if_duncached.axi3_wr_req.awlen;
assign duncache_awsize  = axi3_wr_if_duncached.axi3_wr_req.awsize;
assign duncache_awburst = axi3_wr_if_duncached.axi3_wr_req.awburst;
assign duncache_awlock  = axi3_wr_if_duncached.axi3_wr_req.awlock;
assign duncache_awcache = axi3_wr_if_duncached.axi3_wr_req.awcache;
assign duncache_awprot  = axi3_wr_if_duncached.axi3_wr_req.awprot;
assign duncache_awvalid = axi3_wr_if_duncached.axi3_wr_req.awvalid;
assign duncache_wid     = axi3_wr_if_duncached.wid;
assign duncache_wdata   = axi3_wr_if_duncached.axi3_wr_req.wdata;
assign duncache_wstrb   = axi3_wr_if_duncached.axi3_wr_req.wstrb;
assign duncache_wlast   = axi3_wr_if_duncached.axi3_wr_req.wlast;
assign duncache_wvalid  = axi3_wr_if_duncached.axi3_wr_req.wvalid;
assign duncache_bready  = axi3_wr_if_duncached.axi3_wr_req.bready;
assign axi3_rd_if_duncached.axi3_rd_resp.arready = duncache_arready;
assign axi3_rd_if_duncached.rid                  = duncache_rid;
assign axi3_rd_if_duncached.axi3_rd_resp.rdata   = duncache_rdata;
assign axi3_rd_if_duncached.axi3_rd_resp.rresp   = duncache_rresp;
assign axi3_rd_if_duncached.axi3_rd_resp.rlast   = duncache_rlast;
assign axi3_rd_if_duncached.axi3_rd_resp.rvalid  = duncache_rvalid;
assign axi3_wr_if_duncached.axi3_wr_resp.awready = duncache_awready;
assign axi3_wr_if_duncached.axi3_wr_resp.wready  = duncache_wready;
assign axi3_wr_if_duncached.bid                  = duncache_bid;
assign axi3_wr_if_duncached.axi3_wr_resp.bresp   = duncache_bresp;
assign axi3_wr_if_duncached.axi3_wr_resp.bvalid  = duncache_bvalid;

// inst cache_controller
cache_controller #(
    .BUS_WIDTH                      (BUS_WIDTH          ),
    .ICACHE_DATA_WIDTH              (ICACHE_DATA_WIDTH  ),     // single issue
    .ICACHE_LINE_WIDTH              (ICACHE_LINE_WIDTH  ),
    .ICACHE_SET_ASSOC               (ICACHE_SET_ASSOC   ),
    .ICACHE_CACHE_SIZE              (ICACHE_CACHE_SIZE  ),
    .ICACHE_ARID                    (ICACHE_ARID        ),
    .DCACHE_DATA_WIDTH              (DCACHE_DATA_WIDTH  ), 
    .DCACHE_LINE_WIDTH              (DCACHE_LINE_WIDTH  ), 
    .DCACHE_SET_ASSOC               (DCACHE_SET_ASSOC   ),
    .DCACHE_CACHE_SIZE              (DCACHE_CACHE_SIZE  ),
    .DCACHE_VICTIM_CACHE_ENABLED    (DCACHE_VICTIM_CACHE_ENABLED    ),
    .DCACHE_WB_LINE_DEPTH           (DCACHE_WB_LINE_DEPTH           ),
    .DCACHE_AID                     (DCACHE_AID         ),
    .DCACHE_PASS_DATA_DEPTH         (DCACHE_PASS_DATA_DEPTH         ),
    .DCACHE_PASS_AID                (DCACHE_PASS_AID                )
) cache_controller_inst (
    // external signals
    .clk,
    .rst,
    // bus
    .ibus,
    .dbus,
    // AXI signals
    // icache
    .axi3_rd_if_icached,
    .axi3_wr_if_icached,     // unused
    // dcache
    // cached
    .axi3_rd_if_dcached,
    .axi3_wr_if_dcached,
    // uncached
    .axi3_rd_if_duncached,
    .axi3_wr_if_duncached
);

// inst cpu_core
cpu_core #(
    .N_ISSUE         (N_ISSUE       ),
    .N_TLB_ENTRIES   (N_TLB_ENTRIES ),
    .LINE_WIDTH      (LINE_WIDTH    ),
    .BOOT_VEC        (BOOT_VEC      ),
    .WRITE_PORTS     (WRITE_PORTS   ),
    .READ_PORTS      (READ_PORTS    ),
    .N_REG           (N_REG         ),
    .MMU_ENABLED     (MMU_ENABLED   ),
    .N_INST_CHANNEL  (N_INST_CHANNEL)
) cpu_core_inst (
    // external signals
    .clk,
    .rst,
    // interrupt
    .interrupt,
    // bus
    .ibus,
    .dbus,
    // debug_req
    .debug_req
);

endmodule
