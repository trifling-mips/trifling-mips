// cache controller
`include "cache_defs.svh"

module cache_controller #(
    // common parameter
    parameter   BUS_WIDTH               =   4,
    // ICACHE parameter
    parameter   ICACHE_DATA_WIDTH           =   32,     // single issue
    parameter   ICACHE_LINE_WIDTH           =   256,
    parameter   ICACHE_SET_ASSOC            =   4,
    parameter   ICACHE_CACHE_SIZE           =   16 * 1024 * 8,
    parameter   ICACHE_ARID                 =   0,
    // DCACHE parameter
    parameter   DCACHE_DATA_WIDTH           =   32, 
    parameter   DCACHE_LINE_WIDTH           =   256, 
    parameter   DCACHE_SET_ASSOC            =   4,
    parameter   DCACHE_CACHE_SIZE           =   16 * 1024 * 8,
    parameter   DCACHE_VICTIM_CACHE_ENABLED =   1,
    parameter   DCACHE_WB_LINE_DEPTH        =   8,
    parameter   DCACHE_AID                  =   1,
    // parameter for dcache_pass
    parameter   DCACHE_PASS_DATA_DEPTH      =   8,
    parameter   DCACHE_PASS_AID             =   2
) (
    // external signals
    input   logic   clk,
    input   logic   rst,
    // bus
    cpu_ibus_if.slave   ibus,
    cpu_dbus_if.slave   dbus,
    // AXI signals
    // icache
    axi3_rd_if.master   axi3_rd_if_icached,
    axi3_wr_if.master   axi3_wr_if_icached,     // unused
    // dcache
    // cached
    axi3_rd_if.master   axi3_rd_if_dcached,
    axi3_wr_if.master   axi3_wr_if_dcached,
    // uncached
    axi3_rd_if.master   axi3_rd_if_duncached,
    axi3_wr_if.master   axi3_wr_if_duncached
);

// icache inst
icache #(
    .DATA_WIDTH ( ICACHE_DATA_WIDTH ),      // single issue
    .LINE_WIDTH ( ICACHE_LINE_WIDTH ),
    .SET_ASSOC  ( ICACHE_SET_ASSOC  ),
    .CACHE_SIZE ( ICACHE_CACHE_SIZE ),
    .ARID       ( ICACHE_ARID       )
) icache_inst (
    // external signals
    .clk,
    .rst,
    // CPU signals
    .ibus,
    // AXI3 signals
    .axi3_rd_if ( axi3_rd_if_icached    )
);

// dcache inst
dcache #(
    .BUS_WIDTH  ( BUS_WIDTH         ),
    .DATA_WIDTH ( DCACHE_DATA_WIDTH ), 
    .LINE_WIDTH ( DCACHE_LINE_WIDTH ), 
    .SET_ASSOC  ( DCACHE_SET_ASSOC  ),
    .CACHE_SIZE ( DCACHE_CACHE_SIZE ),
    .VICTIM_CACHE_ENABLED   ( DCACHE_VICTIM_CACHE_ENABLED   ),
    .WB_LINE_DEPTH          ( DCACHE_WB_LINE_DEPTH          ),
    .AID        ( DCACHE_AID        ),
    // parameter for dcache_pass
    .PASS_DATA_DEPTH        ( DCACHE_PASS_DATA_DEPTH        ),
    .PASS_AID   ( DCACHE_PASS_AID   )
) dcache_inst (
    // external signals
    .clk,
    .rst,
    // CPU signals
    .dbus,
    // AXI signals
    // cached
    .axi3_rd_if         ( axi3_rd_if_dcached    ),
    .axi3_wr_if         ( axi3_wr_if_dcached    ),
    // uncached
    .axi3_rd_if_uncached( axi3_rd_if_duncached  ),
    .axi3_wr_if_uncached( axi3_wr_if_duncached  )
);

endmodule
