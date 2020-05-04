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
    // except_req
    input   except_req_t    except_req,
    // pipe_if
    input   pipe_if_t   pipe_if,
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
reg_addr_t[READ_PORTS-1:0] regs_raddr_i;
uint32_t[READ_PORTS-1:0] regs_rddata_i;
uint32_t[READ_PORTS-1:0] regs_rddata_o;
// define interface for resolve_delayslot
logic d_flush, rd_stall;
pipe_id_t[N_ISSUE - 1:0] rd_pipe_id;
logic[N_ISSUE - 1:0] rd_resolved_delayslot;

// inner signals
logic pipe_id_flush;
assign pipe_id_flush = except_req.valid;

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
    .READ_PORTS(READ_PORTS),
    .WRITE_PORTS(WRITE_PORTS)
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
    // flush
    .flush(rd_flush),
    // stall signals
    .stall(rd_stall),
    // resolve delayslot
    .pipe_id(rd_pipe_id),
    .resolved_delayslot(rd_resolved_delayslot)
);
assign rd_flush = pipe_id_flush;
assign rd_stall = ~ready_i || ~pipe_if.valid;
// need to be modified
assign rd_pipe_id[0] = pipe_id_n;
for (genvar i = 1; i < N_ISSUE; ++i)
    assign rd_pipe_id[i] = '0;

// set pipe_id_n
assign pipe_id_n.valid              = pipe_if.valid;
// need to be modified
assign pipe_id_n.regs_rddata0       = regs_rddata_o[0];
assign pipe_id_n.regs_rddata1       = decoder_resp.use_imm ? (decoder_resp.imm_signed ?
                                    {{$bits(uint32_t)-16{pipe_if.inst[15]}}, pipe_if.inst[15:0]} :
                                    {{$bits(uint32_t)-16{1'b0}}, pipe_if.inst[15:0]}) :
                                    regs_rddata_o[1];
assign pipe_id_n.cp0_rreq.raddr     = pipe_if.inst[15:11];
assign pipe_id_n.cp0_rreq.rsel      = pipe_if.inst[2:0];
assign pipe_id_n.decode_resp        = decoder_resp;
// need to be modified
assign pipe_id_n.delayslot          = rd_resolved_delayslot[0];
assign pipe_id_n.inst_fetch         = pipe_if;
assign pipe_id_n.dcache_req.vaddr   = regs_rddata_o[0] + {{16{pipe_if.inst[15]}}, pipe_if.inst[15:0]};
assign pipe_id_n.dcache_req.paddr   = '0;
// need to be modified
assign pipe_id_n.dcache_req.be      = '0;
assign pipe_id_n.dcache_req.wrdata  = pipe_id_n.regs_rddata1;
assign pipe_id_n.dcache_req.read    = decoder_resp.is_load;
assign pipe_id_n.dcache_req.write   = decoder_resp.is_store;
assign pipe_id_n.dcache_req.uncached= 1'b0;     // unused
assign pipe_id_n.dcache_req.cancel  = 1'b0;     // unused
assign pipe_id_n.dcache_req.inv     = 1'b0;     // temp not support

// set ready_o
assign ready_o = ready_i;

// update pipe_id
always_ff @ (posedge clk) begin
    if (rst | pipe_id_flush)
        pipe_id <= '0;
    else if (ready_i)
        pipe_id <= pipe_id_n;
end

endmodule
