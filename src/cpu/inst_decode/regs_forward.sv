// regs forward
`include "inst_decode.svh"

module regs_forward #(
    parameter   READ_PORTS  =   2,
    parameter   WRITE_PORTS =   1
) (
    // read from regs
    input   reg_addr_t[READ_PORTS-1:0]  regs_raddr_i,
    input   uint32_t[READ_PORTS-1:0]    regs_rddata_i,
    // data from exe (not sync)
    input   pipe_ex_t                   pipe_ex,
    // output
    output  uint32_t[READ_PORTS-1:0]    regs_rddata_o
);

always_comb begin
    // set default
    for (int i = 0; i < READ_PORTS; ++i)
        regs_rddata_o[i] = regs_rddata_i[i];

    // forward from exe
    for (int i = 0; i < READ_PORTS; ++i)
        for (int j = 0; j < WRITE_PORTS; ++j)
            if (pipe_ex.regs_wreq.we && pipe_ex.regs_wreq.waddr == regs_raddr_i[i])
                regs_rddata_o[i] = pipe_ex.regs_wreq.wrdata;
end

endmodule
