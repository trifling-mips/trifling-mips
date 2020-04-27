module regfile #(
    parameter   N_REG       =   32,
    parameter   WRITE_PORTS =   1,
    parameter   READ_PORTS  =   2,
    // local parameter
    localparam  ZERO_KEEP   =   1
) (
    // external signals
    input       clk,
    input       rst,

    // wr & rd signals
    input   logic[WRITE_PORTS-1:0]                      we,
    input   uint32_t[WRITE_PORTS-1:0]                   wrdata,
    input   reg_addr_t[WRITE_PORTS-1:0]                 waddr,
    input   reg_addr_t[READ_PORTS-1:0]                  raddr,
    output  uint32_t[READ_PORTS-1:0]                    rddata
);

// exclude reg0
uint32_t[N_REG - 1:ZERO_KEEP] regs, regs_n;

// read data
for(genvar i = 0; i < READ_PORTS; ++i) begin : gen_rd_regfile
    assign rdata[i] = raddr[i] == ZERO_KEEP - 1 ? 0 : regs[raddr[i]];
end

// write data
always_comb begin
    regs_n = regs;
    for (int i = ZERO_KEEP; i < N_REG; ++i)
        for (int j = 0; j < WRITE_PORTS - 1; ++j)
            if(we[j] && waddr[j] == i) regs_n[i] = wrdata[j];
end

// update regs
always_ff @ (posedge clk) begin
    if (rst) regs <= '0;
    else regs <= regs_n;
end

endmodule
