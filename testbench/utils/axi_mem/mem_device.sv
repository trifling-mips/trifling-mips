// mem_device
`include "testbench_defs.svh"

module mem_device #(
    parameter   BUS_WIDTH   =   4,
    parameter   ADDR_WIDTH  =   16,
    parameter   DATA_WIDTH  =   32
) (
    input   logic   clk,
    input   logic   rst,
    axi3_wr_if.slave    axi3_wr_if,
    axi3_rd_if.slave    axi3_rd_if
);

axi_ram #(
    .DATA_WIDTH (DATA_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH),
    .ID_WIDTH   (BUS_WIDTH)
) ram (
    .clk,
    .rst,

    // axi3_wr_if
    .s_axi_awid     (axi3_wr_if.awid                        ),
    .s_axi_awaddr   (axi3_wr_if.axi3_wr_req.awaddr          ),
    .s_axi_awlen    ({4'b0000, axi3_wr_if.axi3_wr_req.awlen}),
    .s_axi_awsize   (axi3_wr_if.axi3_wr_req.awsize          ),
    .s_axi_awburst  (axi3_wr_if.axi3_wr_req.awburst         ),
    .s_axi_awlock   (axi3_wr_if.axi3_wr_req.awlock          ),
    .s_axi_awcache  (axi3_wr_if.axi3_wr_req.awcache         ),
    .s_axi_awprot   (axi3_wr_if.axi3_wr_req.awprot          ),
    .s_axi_awvalid  (axi3_wr_if.axi3_wr_req.awvalid         ),
    .s_axi_awready  (axi3_wr_if.axi3_wr_resp.awready        ),
    .s_axi_wdata    (axi3_wr_if.axi3_wr_req.wdata           ),
    .s_axi_wstrb    (axi3_wr_if.axi3_wr_req.wstrb           ),
    .s_axi_wlast    (axi3_wr_if.axi3_wr_req.wlast           ),
    .s_axi_wvalid   (axi3_wr_if.axi3_wr_req.wvalid          ),
    .s_axi_wready   (axi3_wr_if.axi3_wr_resp.wready         ),
    .s_axi_bid      (axi3_wr_if.bid                         ),
    .s_axi_bresp    (axi3_wr_if.axi3_wr_resp.bresp          ),
    .s_axi_bvalid   (axi3_wr_if.axi3_wr_resp.bvalid         ),
    .s_axi_bready   (axi3_wr_if.axi3_wr_req.bready          ),
    // axi3_rd_if
    .s_axi_arid     (axi3_rd_if.arid                        ),
    .s_axi_araddr   (axi3_rd_if.axi3_rd_req.araddr          ),
    .s_axi_arlen    ({4'b0000, axi3_rd_if.axi3_rd_req.arlen}),
    .s_axi_arsize   (axi3_rd_if.axi3_rd_req.arsize          ),
    .s_axi_arburst  (axi3_rd_if.axi3_rd_req.arburst         ),
    .s_axi_arlock   (axi3_rd_if.axi3_rd_req.arlock          ),
    .s_axi_arcache  (axi3_rd_if.axi3_rd_req.arcache         ),
    .s_axi_arprot   (axi3_rd_if.axi3_rd_req.arprot          ),
    .s_axi_arvalid  (axi3_rd_if.axi3_rd_req.arvalid         ),
    .s_axi_arready  (axi3_rd_if.axi3_rd_resp.arready        ),
    .s_axi_rid      (axi3_rd_if.rid                         ),
    .s_axi_rdata    (axi3_rd_if.axi3_rd_resp.rdata          ),
    .s_axi_rresp    (axi3_rd_if.axi3_rd_resp.rresp          ),
    .s_axi_rlast    (axi3_rd_if.axi3_rd_resp.rlast          ),
    .s_axi_rvalid   (axi3_rd_if.axi3_rd_resp.rvalid         ),
    .s_axi_rready   (axi3_rd_if.axi3_rd_req.rready          )
);

endmodule
