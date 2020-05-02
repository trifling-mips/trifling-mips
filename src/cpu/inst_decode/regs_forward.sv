// regs forward
`include "inst_decode.svh"

module regs_forward #(
    parameter   READ_PORT   =   2,
    parameter   WRITE_PORT  =   1
) (
    // read from regs
    input   reg_addr_t[READ_PORT-1:0]   regs_raddr_i,
    input   uint32_t[READ_PORT-1:0]     regs_rddata_i,
    // data from exe (not sync)
    input   pipe_ex_t                   pipe_ex,
    // output
    output  uint32_t[READ_PORT-1:0]     regs_rddata_o
);

always_comb begin
    // set default
    for (int i = 0; i < READ_PORT; ++i)
        regs_rddata_o[i] = regs_rddata_i[i];

    // forward from exe
    for (int i = 0; i < READ_PORT; ++i)
        for (int j = 0; j < WRITE_PORT; ++j)
            if (pipe_ex.regs_wreq[j].we && pipe_ex.regs_wreq[j].waddr == regs_raddr_i[i])
                regs_rddata_o[i] = pipe_ex.regs_wreq[j].wrdata;
end

endmodule
