// inst_mem
`include "inst_mem.svh"

module inst_mem #(

) (
    // external signals
    input   logic   clk,
    input   logic   rst,
    // ready from dbus
    input   logic   dbus_ready,
    // ready
    input   logic   ready_i,
    output  logic   ready_o,
    // pipe_ex
    input   pipe_ex_t   pipe_ex,
    // pipe_mm
    output  pipe_mm_t   pipe_mm_n,
    output  pipe_mm_t   pipe_mm
);

// set ready
assign ready_o = ready_i && (
    dbus_ready
);
// set pipe_mm_n.valid
assign pipe_mm_n.valid           = ready_o & pipe_ex.valid;
// set pipe_mm_n.inst_fetch
assign pipe_mm_n.inst_fetch      = pipe_ex.inst_fetch;
// set pipe_mm_n.regs_wreq
assign pipe_mm_n.regs_wreq.we    = (pipe_ex.regs_wreq.we || pipe_ex.dcache_req.read) && (~pipe_ex.exception.valid && pipe_ex.valid);
assign pipe_mm_n.regs_wreq.waddr = pipe_ex.regs_wreq.waddr;
assign pipe_mm_n.regs_wreq.wrdata= pipe_ex.regs_wreq.wrdata;
// set pipe_mm_n.dcache_req
assign pipe_mm_n.dcache_req      = pipe_ex.dcache_req;
// set pipe_mm_n.decode_resp
assign pipe_mm_n.decode_resp     = pipe_ex.decode_resp;
// set pipe_mm
always_ff @ (posedge clk) begin
    if (rst)
        pipe_mm <= '0;
    else if (ready_i)
        pipe_mm <= pipe_mm_n;
end

endmodule
