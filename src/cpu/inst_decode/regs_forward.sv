// regs forward
`include "inst_decode.svh"

module regs_forward #(
    parameter   READ_PORTS  =   2,
    parameter   WRITE_PORTS =   1
) (
    // read from regs
    input   reg_addr_t[READ_PORTS-1:0]  regs_raddr_i,
    input   uint32_t[READ_PORTS-1:0]    regs_rddata_i,
    // data from exe & wb (not sync)
    input   pipe_ex_t                   pipe_ex,
    input   pipe_wb_t                   pipe_wb,
    // output
    output  uint32_t[READ_PORTS-1:0]    regs_rddata_o,
    output  logic                       stall_o
);

always_comb begin
    // set default
    stall_o = 1'b0;
    for (int i = 0; i < READ_PORTS; ++i)
        regs_rddata_o[i] = regs_rddata_i[i];

    // forward from exe & wb
    for (int i = 0; i < READ_PORTS; ++i) begin
        for (int j = 0; j < WRITE_PORTS; ++j) begin
            if (pipe_wb.regs_wreq.we && pipe_wb.regs_wreq.waddr == regs_raddr_i[i])
                regs_rddata_o[i] = pipe_wb.regs_wreq.wrdata;
            if (pipe_ex.regs_wreq.we && pipe_ex.regs_wreq.waddr == regs_raddr_i[i])
                regs_rddata_o[i] = pipe_ex.regs_wreq.wrdata;
        end
    end

    // gen stall_o
    for (int i = 0; i < READ_PORTS; ++i)
        for (int j = 0; j < WRITE_PORTS; ++j)
            if (pipe_ex.dcache_req.read && pipe_ex.regs_wreq.waddr == regs_raddr_i[i])
                stall_o = 1'b1;
end

endmodule
