// inst_wb
`include "inst_wb.svh"

module inst_wb #(

) (
    // external signals
    input   logic   clk,
    input   logic   rst,
    // dcache_resp
    input   dcache_resp_t   dcache_resp,
    // ready
    input   logic   ready_i,    // cons 1'b1
    output  logic   ready_o,
    // pipe_mm
    input   pipe_mm_t   pipe_mm,
    // pipe_wb
    output  pipe_wb_t   pipe_wb_n,
    output  pipe_wb_t   pipe_wb
);

// local parameter
localparam DATA_WIDTH = $bits(uint32_t);

// define funcs
`DEF_FUNC_LOAD_SEL

// set ready
assign ready_o = ready_i;
// set pipe_wb_n.valid
assign pipe_wb_n.valid           = ready_o & pipe_mm.valid;
// set pipe_wb_n.regs_wreq
assign pipe_wb_n.regs_wreq.we    = pipe_mm.regs_wreq.we;
assign pipe_wb_n.regs_wreq.waddr = pipe_mm.regs_wreq.waddr;
assign pipe_wb_n.regs_wreq.wrdata= pipe_mm.dcache_req.read ? load_sel(dcache_resp.rddata, pipe_mm.dcache_req.vaddr, pipe_mm.decode_resp.op) : pipe_mm.regs_wreq.wrdata;
// set pipe_wb_n.debug_req
assign pipe_wb_n.debug_req.vaddr = pipe_mm.inst_fetch.mmu_iaddr_resp[0].vaddr;
assign pipe_wb_n.debug_req.regs_wrdata = pipe_wb_n.regs_wreq.wrdata;
assign pipe_wb_n.debug_req.regs_wbe = ((
    pipe_mm.regs_wreq.we
) ? '1 : ({4{pipe_mm.dcache_req.read}} & pipe_mm.dcache_req.be)) & {4{pipe_mm.valid}};
assign pipe_wb_n.debug_req.regs_waddr = pipe_wb_n.regs_wreq.waddr;
// update pipe_wb
always_ff @ (posedge clk) begin
    if (rst) begin
        pipe_wb <= '0;
    end else if (ready_o) begin
        pipe_wb <= pipe_wb_n;
    end else begin
        pipe_wb <= '0;
    end
end

endmodule
