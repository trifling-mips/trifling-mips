// cpu core
`include "cpu_defs.svh"

module cpu_core #(
    // common parameter
    parameter   N_ISSUE         =   1,
    parameter   N_TLB_ENTRIES   =   32,
    // parameter for icache
    parameter   LINE_WIDTH  =   256,
    // parameter for inst_fetch
    parameter   BOOT_VEC    =   32'hbfc00000,
    // parameter for inst_decode
    parameter   WRITE_PORTS =   1,
    parameter   READ_PORTS  =   2,
    parameter   N_REG       =   32,
    // parameter for mmu
    parameter   MMU_ENABLED     =   0,
    parameter   N_INST_CHANNEL  =   `N_INST_CHANNEL     // for paddr_plus
) (
    // external signals
    input   logic   clk,
    input   logic   rst,
    // interrupt
    input  cpu_interrupt_t  interrupt,
    // bus
    cpu_ibus_if.master  ibus,
    cpu_dbus_if.master  dbus,
    // debug req
    output  debug_req_t debug_req
);

// define interface for inst_fetch
logic if_ready_i, if_ready_o, if_ibus_ready, if_ibus_valid;
branch_resolved_t if_resolved_branch;
except_req_t if_except_req;
virt_t if_pc;
mmu_resp_t[N_INST_CHANNEL-1:0] if_mmu_iaddr_resp;
pipe_if_t if_pipe_if;
// define interface for inst_decode
logic id_ibus_valid, id_ready_i, id_ready_o;
uint32_t id_ibus_rddata;
except_req_t id_except_req;
pipe_if_t id_pipe_if;
pipe_id_t id_pipe_id, id_pipe_id_n;
pipe_ex_t id_pipe_ex;
pipe_wb_t id_pipe_wb;
// define interface for mmu
logic[7:0] mmu_asid;
logic mmu_kseg0_uncached, mmu_is_user_mode;
virt_t[N_INST_CHANNEL-1:0] mmu_inst_vaddr;
mmu_resp_t[N_INST_CHANNEL-1:0] mmu_inst_resp;
virt_t[N_ISSUE-1:0] mmu_data_vaddr;
mmu_resp_t[N_ISSUE-1:0] mmu_data_resp;
// tlb signals (temp unused)
tlb_index_t mmu_tlbrw_index;
logic mmu_tlbrw_we;
tlb_entry_t mmu_tlbrw_wrdata;
tlb_entry_t mmu_tlbrw_rddata;
uint32_t mmu_tlbp_entry_hi, mmu_tlbp_index;
// define interface for cp0
cp0_rreq_t cp0_cp0_rreq;
uint32_t cp0_cp0_rddata;
cp0_wreq_t cp0_cp0_wreq;
except_req_t  cp0_except_req_i;
logic[7:0] cp0_interrupt_flag;
cp0_regs_t cp0_cp0_regs;
logic[7:0] cp0_asid;
logic cp0_user_mode, cp0_kseg0_uncached, cp0_timer_int;
// tlb signals (temp unused)
logic cp0_tlbr_req;
tlb_entry_t cp0_tlbr_res;
logic cp0_tlbp_req;
uint32_t cp0_tlbp_res;
logic cp0_tlbwr_req;
tlb_entry_t cp0_tlbrw_wrdata;
// define interface for except
pipe_id_t[N_ISSUE-1:0] except_pipe_id;
pipe_ex_t[N_ISSUE-1:0] except_pipe_ex;
cp0_regs_t except_cp0_regs;
logic[7:0] except_interrupt_req;
except_req_t except_except_req;
// define interface for inst_exec
logic ex_ibus_valid, ex_ready_i, ex_ready_o;
except_req_t ex_except_req;
uint32_t ex_cp0_rddata;
pipe_id_t ex_pipe_id;
pipe_ex_t ex_pipe_ex_n, ex_pipe_ex;
mmu_resp_t ex_mmu_daddr_resp;
// define interface for inst_wb
logic wb_dbus_ready;
dcache_resp_t wb_dcache_resp;
logic wb_ready_i, wb_ready_o;
pipe_ex_t wb_pipe_ex;
pipe_wb_t wb_pipe_wb_n, wb_pipe_wb;

// inner signals
logic[7:0] interrupt_flag_n, interrupt_flag, interrupt_req;
assign interrupt_flag_n = {
    cp0_timer_int,
    interrupt[4:0],
    cp0_cp0_regs.cause.ip[1:0]
};
always_ff @ (posedge clk) begin
    if (rst) interrupt_flag <= '0;
    else     interrupt_flag <= interrupt_flag_n;
end
assign interrupt_req = interrupt_flag & cp0_cp0_regs.status.im;

// inst inst_fetch
inst_fetch #(
    .BOOT_VEC       ( BOOT_VEC          ),
    .N_ISSUE        ( N_ISSUE           ),
    .N_INST_CHANNEL ( N_INST_CHANNEL    )
) inst_fetch_inst (
    // external signals
    .clk,
    .rst,
    // ready from id stage
    .ready_i        ( if_ready_i        ),
    .ready_o        ( if_ready_o        ),
    // ready from icache
    .ibus_ready     ( if_ibus_ready     ),
    // branch resolved
    .resolved_branch( if_resolved_branch),
    // except req
    .except_req     ( if_except_req     ),
    // output
    .pc             ( if_pc             ),
    // mmu iaddr resp
    .mmu_iaddr_resp ( if_mmu_iaddr_resp ),
    // icache resp
    .ibus_valid     ( if_ibus_valid     ),
    // inst_fetch pipe
    .pipe_if        ( if_pipe_if        )
);
assign if_ibus_ready    = ibus.ready;
assign if_ibus_valid    = ibus.valid;
assign if_ready_i       = id_ready_o;
assign if_resolved_branch   = ex_pipe_ex_n.resolved_branch;
assign if_except_req    = except_except_req;
assign if_mmu_iaddr_resp= mmu_inst_resp;

// inst inst_decode
inst_decode #(
    .WRITE_PORTS    ( WRITE_PORTS   ),
    .READ_PORTS     ( READ_PORTS    ),
    .N_ISSUE        ( N_ISSUE       ),
    .N_REG          ( N_REG         )
) inst_decode_inst (
    // external signals
    .clk,
    .rst,
    // valid from ibus
    .ibus_valid     ( id_ibus_valid     ),
    .ibus_rddata    ( id_ibus_rddata    ),
    // ready from ex stage & ready to if stage
    .ready_i        ( id_ready_i        ),
    .ready_o        ( id_ready_o        ),
    // except_req
    .except_req     ( id_except_req     ),
    // pipe_if
    .pipe_if        ( id_pipe_if        ),
    // pipe_id
    .pipe_id_n      ( id_pipe_id_n      ),
    .pipe_id        ( id_pipe_id        ),
    // pipe_ex & pipe_wb (not sync)
    .pipe_ex        ( id_pipe_ex        ),
    .pipe_wb        ( id_pipe_wb        )
);
assign id_ibus_valid    = ibus.valid;
assign id_ibus_rddata   = ibus.rddata;
assign id_ready_i       = ex_ready_o;
assign id_except_req    = except_except_req;
assign id_pipe_if       = if_pipe_if;
assign id_pipe_ex       = ex_pipe_ex_n;
assign id_pipe_wb       = wb_pipe_wb_n;

// inst mmu
mmu #(
    .MMU_ENABLED    ( MMU_ENABLED       ),
    .N_INST_CHANNEL ( N_INST_CHANNEL    ),
    .N_ISSUE        ( N_ISSUE           ),
    .N_TLB_ENTRIES  ( N_TLB_ENTRIES     )
) mmu_inst (
    // external signals
    .clk,
    .rst,
    // from cp0
    .asid           ( mmu_asid          ),
    .kseg0_uncached ( mmu_kseg0_uncached),
    .is_user_mode   ( mmu_is_user_mode  ),
    // for inst
    .inst_vaddr     ( mmu_inst_vaddr    ),
    .inst_resp      ( mmu_inst_resp     ),
    // for data
    .data_vaddr     ( mmu_data_vaddr    ),
    .data_resp      ( mmu_data_resp     ),
    // for TLBR/TLBWI/TLBWR
    .tlbrw_index    ( mmu_tlbrw_index   ),
    .tlbrw_we       ( mmu_tlbrw_we      ),
    .tlbrw_wrdata   ( mmu_tlbrw_wrdata  ),
    .tlbrw_rddata   ( mmu_tlbrw_rddata  ),
    // for TLBP
    .tlbp_entry_hi  ( mmu_tlbp_entry_hi ),
    .tlbp_index     ( mmu_tlbp_index    )
);
assign mmu_asid             = cp0_asid;
assign mmu_kseg0_uncached   = cp0_kseg0_uncached;
assign mmu_is_user_mode     = cp0_user_mode;
assign mmu_inst_vaddr[0]    = if_pc;
assign mmu_inst_vaddr[1]    = if_pc + (1 << $clog2(LINE_WIDTH / 8));
assign mmu_data_vaddr[0]    = id_pipe_id.dcache_req.vaddr;
// tlb signals (temp unused)
assign mmu_tlbrw_index      = '0;
assign mmu_tlbrw_we         = 1'b0;
assign mmu_tlbrw_wrdata     = '0;
assign mmu_tlbp_entry_hi    = '0;

// inst cp0
cp0 #(
    .N_TLB_ENTRIES  ( N_TLB_ENTRIES )
) cp0_inst (
    // external signals
    .clk,
    .rst,
    // CP0 req
    .cp0_rreq       ( cp0_cp0_rreq      ),
    .cp0_rddata     ( cp0_cp0_rddata    ),
    .cp0_wreq       ( cp0_cp0_wreq      ),
    // EXCEPT req & INT flag
    .except_req_i   ( cp0_except_req_i  ),
    .interrupt_flag ( cp0_interrupt_flag),
    // TLB req
    `ifdef COMPILE_FULL_M
    .tlbr_req       ( cp0_tlbr_req      ),
    .tlbr_res       ( cp0_tlbr_res      ),
    .tlbp_req       ( cp0_tlbp_req      ),
    .tlbp_res       ( cp0_tlbp_res      ),
    .tlbwr_req      ( cp0_tlbwr_req     ),
    .tlbrw_wrdata   ( cp0_tlbrw_wrdata  ),
    `endif
    // control output
    .cp0_regs       ( cp0_cp0_regs      ),
    .asid           ( cp0_asid          ),
    .user_mode      ( cp0_user_mode     ),
    .kseg0_uncached ( cp0_kseg0_uncached),
    .timer_int      ( cp0_timer_int     )
);
assign cp0_cp0_rreq     = id_pipe_id.cp0_rreq;
assign cp0_cp0_wreq     = ex_pipe_ex_n.cp0_wreq;
assign cp0_except_req_i = except_except_req;
assign cp0_interrupt_flag   = interrupt_flag;
// tlb signals (temp unused)
assign cp0_tlbr_req     = '0;
assign cp0_tlbr_res     = '0;
assign cp0_tlbp_req     = '0;
assign cp0_tlbp_res     = '0;
assign cp0_tlbwr_req    = '0;

// inst except
except #(
    .N_ISSUE    ( N_ISSUE   )
) except_inst (
    // external signals
    .rst,
    // exception (not sync)
    .pipe_id        ( except_pipe_id        ),
    .pipe_ex        ( except_pipe_ex        ),
    // cp0 regs & interrupt_req
    .cp0_regs       ( except_cp0_regs       ),
    .interrupt_req  ( except_interrupt_req  ),
    // except_req
    .except_req     ( except_except_req     )
);
assign except_pipe_id       = id_pipe_id;
assign except_pipe_ex[0]    = ex_pipe_ex_n;
// need to be modified
for (genvar i = 1; i < N_ISSUE; ++i)
    assign except_pipe_ex[i]  = '0;
assign except_cp0_regs      = cp0_cp0_regs;
assign except_interrupt_req = interrupt_req;

// inst inst_exec
inst_exec #(

) inst_exec_inst (
    // external signals
    .clk,
    .rst,
    // ready from ibus
    .ibus_valid     ( ex_ibus_valid     ),
    // ready
    .ready_i        ( ex_ready_i        ),
    .ready_o        ( ex_ready_o        ),
    // except_req
    .except_req     ( ex_except_req     ),
    // cp0 rd resp
    .cp0_rddata     ( ex_cp0_rddata     ),
    // pipe_id
    .pipe_id        ( ex_pipe_id        ),
    // pipe_ex
    .pipe_ex_n      ( ex_pipe_ex_n      ),      // not sync
    .pipe_ex        ( ex_pipe_ex        ),
    // mmu result
    .mmu_daddr_resp ( ex_mmu_daddr_resp )
);
assign ex_ibus_valid    = ibus.valid;
assign ex_ready_i       = wb_ready_o;
assign ex_except_req    = except_except_req;
assign ex_cp0_rddata    = cp0_cp0_rddata;
assign ex_pipe_id       = id_pipe_id;
assign ex_mmu_daddr_resp= mmu_data_resp[0];

// inst inst_wb
inst_wb #(

) inst_wb_inst (
    // external signals
    .clk,
    .rst,
    // ready from dbus
    .dbus_ready     ( wb_dbus_ready     ),
    // dcache_resp
    .dcache_resp    ( wb_dcache_resp    ),
    // ready
    .ready_i        ( wb_ready_i        ),    // cons 1'b1
    .ready_o        ( wb_ready_o        ),
    // pipe_ex
    .pipe_ex        ( wb_pipe_ex        ),
    // pipe_wb
    .pipe_wb_n      ( wb_pipe_wb_n      ),
    .pipe_wb        ( wb_pipe_wb        )
);
assign wb_dbus_ready    = dbus.ready;
assign wb_dcache_resp   = dbus.dcache_resp;
assign wb_ready_i       = 1'b1;
assign wb_pipe_ex       = ex_pipe_ex;

// set ibus
assign ibus.read        = 1'b1;
assign ibus.inv         = 1'b0;
assign ibus.inv_addr    = '0;
assign ibus.vaddr       = if_pc;
assign ibus.paddr       = if_pipe_if.mmu_iaddr_resp[0].paddr;
assign ibus.paddr_plus1 = if_pipe_if.mmu_iaddr_resp[1].paddr;
// set dbus
assign dbus.dcache_req.vaddr    = id_pipe_id.dcache_req.vaddr;
assign dbus.dcache_req.be       = ex_pipe_ex.dcache_req.be;
assign dbus.dcache_req.wrdata   = id_pipe_id.dcache_req.wrdata;
assign dbus.dcache_req.read     = (id_pipe_id.dcache_req.read && id_pipe_id.valid && ~ex_except_req.valid) && wb_ready_o;
assign dbus.dcache_req.write    = (id_pipe_id.dcache_req.write && id_pipe_id.valid && ~ex_except_req.valid) && wb_ready_o;
assign dbus.dcache_req.inv      = (id_pipe_id.dcache_req.inv && id_pipe_id.valid && ~ex_except_req.valid) && wb_ready_o;
assign dbus.dcache_req.paddr    = ex_pipe_ex.dcache_req.paddr;
assign dbus.dcache_req.uncached = ex_pipe_ex.dcache_req.uncached;
// set debug_req
assign debug_req        = wb_pipe_wb.debug_req;

endmodule
