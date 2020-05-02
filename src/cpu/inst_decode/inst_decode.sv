// inst_decode
`include "inst_decode.svh"

module inst_decode #(
    // common parameter
    parameter   WRITE_PORTS =   1,
    parameter   READ_PORTS  =   2,
    parameter   N_ISSUE     =   1,
    // parameter for regfile
    parameter   N_REG       =   32
) (
    // external signals
    input   logic   clk,
    input   logic   rst,
    // ready from ex stage & ready to if stage
    input   logic   ready_i,
    output  logic   ready_o,
    // pipe_if
    input   pipe_if_t   pipe_if,
    input   logic       pipe_if_flush,
    // pipe_id
    output  pipe_id_t   pipe_id_n,      // not sync
    output  pipe_id_t   pipe_id,
    // pipe_ex (not sync)
    input   pipe_ex_t   pipe_ex
);

// define interface for decoder
virt_t vaddr;
uint32_t inst;
decoder_resp_t decoder_resp;
// define interface for regfile
regs_wreq_t[WRITE_PORTS-1:0] regs_wreq;
reg_addr_t[READ_PORTS-1:0] regs_raddr;
uint32_t[READ_PORTS-1:0] regs_rddata;
// define interface for regs_forward
reg_addr_t[READ_PORT-1:0] regs_raddr_i;
uint32_t[READ_PORT-1:0] regs_rddata_i;
uint32_t[READ_PORT-1:0] regs_rddata_o;
// define interface for resolve_delayslot
pipe_id_t[N_ISSUE - 1:0] rd_pipe_id;
logic[N_ISSUE - 1:0] rd_resolved_delayslot;

// decoder
decoder #(
) decoder_inst (
    .vaddr,
    .inst,
    .decoder_resp
);
assign vaddr = pipe_if.vaddr;
assign inst  = pipe_if.inst;

// regfile
regfile #(
    .N_REG(N_REG),
    .WRITE_PORTS(WRITE_PORTS),
    .READ_PORTS(READ_PORTS)
) regfile_inst (
    // external signals
    .clk,
    .rst,
    // wr & rd signals
    .regs_wreq,
    .regs_raddr,
    .regs_rddata
);
// need to be modified
assign regs_raddr[0] = decoder_resp.rs1;
assign regs_raddr[1] = decoder_resp.rs2;
assign regs_wreq     = pipe_ex.regs_wreq;

// regs_forward
regs_forward #(
    .READ_PORT(READ_PORT),
    .WRITE_PORT(WRITE_PORT)
) regs_forward_inst (
    // read from regs
    .regs_raddr_i,
    .regs_rddata_i,
    // data from exe (not sync)
    .pipe_ex,
    // output
    .regs_rddata_o
);
// need to be modified
assign regs_raddr_i[0] = decoder_resp.rs1;
assign regs_raddr_i[1] = decoder_resp.rs2;
assign regs_rddata_i   = regs_rddata;

// resolve_delayslot
resolve_delayslot #(
    .N_ISSUE(N_ISSUE)
) resolve_delayslot_inst (
    // external signals
    .clk,
    .rst,
    // flush signals (same as pipe_ifid's flush)
    .flush(pipe_if_flush),
    // resolve delayslot
    .pipe_id(rd_pipe_id),
    .resolved_delayslot(rd_resolved_delayslot)
);
// need to be modified
assign rd_pipe_id[0] = pipe_id_n;

// set pipe_id_n
assign pipe_id_n.valid              = pipe_if.valid;
// need to be modified
assign pipe_id_n.regs_rddata0       = regs_rddata_o[0];
assign pipe_id_n.regs_rddata1       = regs_rddata_o[1];
assign pipe_id_n.cp0_rreq.raddr     = decoder_resp.rs2;
assign pipe_id_n.cp0_rreq.rsel      = pipe_if.inst[2:0];
assign pipe_id_n.decode_resp        = decoder_resp;
// need to be modified
assign pipe_id_n.delayslot          = rd_resolved_delayslot[0];
assign pipe_id_n.dcache_req.vaddr   = regs_rddata_o[0] + {{16{pipe_if.inst[15]}}, pipe_if.inst[15:0]};
// need to be modified
assign pipe_id_n.dcache_req.be      = decoder_resp.be;
assign pipe_id_n.dcache_req.wrdata  = pipe_id_n.regs_rddata1;
assign pipe_id_n.dcache_req.read    = decoder_resp.is_load;
assign pipe_id_n.dcache_req.write   = decoder_resp.is_store;
assign pipe_id_n.dcache_req.uncached= 1'b0;     // unused
assign pipe_id_n.dcache_req.inv     = 1'b0;     // temp not support

// update pipe_id
always_ff @ (posedge clk) begin
    if (rst)
        pipe_id <= '0;
    else
        pipe_id <= pipe_id_n;
end

endmodule