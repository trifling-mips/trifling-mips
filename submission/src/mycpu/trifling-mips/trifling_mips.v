// this file is only a Verilog wrapper of TriflingMIPS CPU in SoC block design
// for SystemVerilog file cannot be used as modules in BDs

module trifling_mips #(
    // common parameter
    parameter   BUS_WIDTH   =   4
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

// inst trifling_mips_impl
trifling_mips_impl #(

) trifling_mips_impl_inst (
    // external signals
    .aclk       ( aclk      ),
    .rst_n      ( rst_n     ),
    // interrupt
    .interrupt  ( interrupt ),

    // icache
    // AXI AR signals
    .icache_arid    ( icache_arid   ),
    .icache_araddr  ( icache_araddr ),
    .icache_arlen   ( icache_arlen  ),
    .icache_arsize  ( icache_arsize ),
    .icache_arburst ( icache_arburst),
    .icache_arlock  ( icache_arlock ),
    .icache_arcache ( icache_arcache),
    .icache_arprot  ( icache_arprot ),
    .icache_arvalid ( icache_arvalid),
    .icache_arready ( icache_arready),
    // AXI R signals
    .icache_rid     ( icache_rid    ),
    .icache_rdata   ( icache_rdata  ),
    .icache_rresp   ( icache_rresp  ),
    .icache_rlast   ( icache_rlast  ),
    .icache_rvalid  ( icache_rvalid ),
    .icache_rready  ( icache_rready ),
    // AXI AW signals
    .icache_awid    ( icache_awid   ),
    .icache_awaddr  ( icache_awaddr ),
    .icache_awlen   ( icache_awlen  ),
    .icache_awsize  ( icache_awsize ),
    .icache_awburst ( icache_awburst),
    .icache_awlock  ( icache_awlock ),
    .icache_awcache ( icache_awcache),
    .icache_awprot  ( icache_awprot ),
    .icache_awvalid ( icache_awvalid),
    .icache_awready ( icache_awready),
    // AXI W signals
    .icache_wid     ( icache_wid    ),
    .icache_wdata   ( icache_wdata  ),
    .icache_wstrb   ( icache_wstrb  ),
    .icache_wlast   ( icache_wlast  ),
    .icache_wvalid  ( icache_wvalid ),
    .icache_wready  ( icache_wready ),
    // AXI B signals
    .icache_bid     ( icache_bid    ),
    .icache_bresp   ( icache_bresp  ),
    .icache_bvalid  ( icache_bvalid ),
    .icache_bready  ( icache_bready ),

    // dcache
    // AXI AR signals
    .dcache_arid    ( dcache_arid   ),
    .dcache_araddr  ( dcache_araddr ),
    .dcache_arlen   ( dcache_arlen  ),
    .dcache_arsize  ( dcache_arsize ),
    .dcache_arburst ( dcache_arburst),
    .dcache_arlock  ( dcache_arlock ),
    .dcache_arcache ( dcache_arcache),
    .dcache_arprot  ( dcache_arprot ),
    .dcache_arvalid ( dcache_arvalid),
    .dcache_arready ( dcache_arready),
    // AXI R signals
    .dcache_rid     ( dcache_rid    ),
    .dcache_rdata   ( dcache_rdata  ),
    .dcache_rresp   ( dcache_rresp  ),
    .dcache_rlast   ( dcache_rlast  ),
    .dcache_rvalid  ( dcache_rvalid ),
    .dcache_rready  ( dcache_rready ),
    // AXI AW signals
    .dcache_awid    ( dcache_awid   ),
    .dcache_awaddr  ( dcache_awaddr ),
    .dcache_awlen   ( dcache_awlen  ),
    .dcache_awsize  ( dcache_awsize ),
    .dcache_awburst ( dcache_awburst),
    .dcache_awlock  ( dcache_awlock ),
    .dcache_awcache ( dcache_awcache),
    .dcache_awprot  ( dcache_awprot ),
    .dcache_awvalid ( dcache_awvalid),
    .dcache_awready ( dcache_awready),
    // AXI W signals
    .dcache_wid     ( dcache_wid    ),
    .dcache_wdata   ( dcache_wdata  ),
    .dcache_wstrb   ( dcache_wstrb  ),
    .dcache_wlast   ( dcache_wlast  ),
    .dcache_wvalid  ( dcache_wvalid ),
    .dcache_wready  ( dcache_wready ),
    // AXI B signals
    .dcache_bid     ( dcache_bid    ),
    .dcache_bresp   ( dcache_bresp  ),
    .dcache_bvalid  ( dcache_bvalid ),
    .dcache_bready  ( dcache_bready ),

    // uncached
    // AXI AR signals
    .duncache_arid    ( duncache_arid   ),
    .duncache_araddr  ( duncache_araddr ),
    .duncache_arlen   ( duncache_arlen  ),
    .duncache_arsize  ( duncache_arsize ),
    .duncache_arburst ( duncache_arburst),
    .duncache_arlock  ( duncache_arlock ),
    .duncache_arcache ( duncache_arcache),
    .duncache_arprot  ( duncache_arprot ),
    .duncache_arvalid ( duncache_arvalid),
    .duncache_arready ( duncache_arready),
    // AXI R signals
    .duncache_rid     ( duncache_rid    ),
    .duncache_rdata   ( duncache_rdata  ),
    .duncache_rresp   ( duncache_rresp  ),
    .duncache_rlast   ( duncache_rlast  ),
    .duncache_rvalid  ( duncache_rvalid ),
    .duncache_rready  ( duncache_rready ),
    // AXI AW signals
    .duncache_awid    ( duncache_awid   ),
    .duncache_awaddr  ( duncache_awaddr ),
    .duncache_awlen   ( duncache_awlen  ),
    .duncache_awsize  ( duncache_awsize ),
    .duncache_awburst ( duncache_awburst),
    .duncache_awlock  ( duncache_awlock ),
    .duncache_awcache ( duncache_awcache),
    .duncache_awprot  ( duncache_awprot ),
    .duncache_awvalid ( duncache_awvalid),
    .duncache_awready ( duncache_awready),
    // AXI W signals
    .duncache_wid     ( duncache_wid    ),
    .duncache_wdata   ( duncache_wdata  ),
    .duncache_wstrb   ( duncache_wstrb  ),
    .duncache_wlast   ( duncache_wlast  ),
    .duncache_wvalid  ( duncache_wvalid ),
    .duncache_wready  ( duncache_wready ),
    // AXI B signals
    .duncache_bid     ( duncache_bid    ),
    .duncache_bresp   ( duncache_bresp  ),
    .duncache_bvalid  ( duncache_bvalid ),
    .duncache_bready  ( duncache_bready ),

    // debug signals
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

endmodule
