// cp0
`include "cp0.svh"

module cp0 #(
    parameter   N_TLB_ENTRIES   =   32,
    // local parameter
    localparam  TLB_WIDTH       =   $clog2(N_TLB_ENTRIES)
) (
    // external signals
    input   logic   clk,
    input   logic   rst,
    // CP0 req
    input   cp0_rreq_t      cp0_rreq,
    output  uint32_t        cp0_rddata,
    input   cp0_wreq_t      cp0_wreq,
    // EXCEPT req & INT flag
    input   except_req_t    except_req_i,
    input   logic [7:0]     interrupt_flag,
    // TLB req
    `ifdef COMPILE_FULL_M
    input   logic           tlbr_req,
    input   tlb_entry_t     tlbr_res,
    input   logic           tlbp_req,
    input   uint32_t        tlbp_res,
    input   logic           tlbwr_req,
    output  tlb_entry_t     tlbrw_wrdata,
    `endif
    // control output
    output  cp0_regs_t      cp0_regs,
    output  logic [7:0]     asid,
    output  logic           user_mode,
    output  logic           kseg0_uncached,
    output  logic           timer_int
);

// cp0_regs
cp0_regs_t cp0_regs_n;

// set control output
`ifdef COMPILE_FULL_M
assign asid           = cp0_regs.entry_hi[7:0];
assign user_mode      = (cp0_regs.status[4:1] == 4'b1000);
assign kseg0_uncached = (cp0_regs.config0[2:0] == 3'd2);
`else
assign asid           = '0;
assign user_mode      = 1'b0;
assign kseg0_uncached = 1'b0;
`endif

`ifdef COMPILE_FULL_M
// set tlbrw_wrdata
assign tlbrw_wrdata.vpn2 = cp0_regs.entry_hi[31:13];
assign tlbrw_wrdata.asid = cp0_regs.entry_hi[7:0];
assign tlbrw_wrdata.pfn1 = cp0_regs.entry_lo1[29:6];
assign tlbrw_wrdata.c1   = cp0_regs.entry_lo1[5:3];
assign tlbrw_wrdata.d1   = cp0_regs.entry_lo1[2];
assign tlbrw_wrdata.v1   = cp0_regs.entry_lo1[1];
assign tlbrw_wrdata.pfn0 = cp0_regs.entry_lo0[29:6];
assign tlbrw_wrdata.c0   = cp0_regs.entry_lo0[5:3];
assign tlbrw_wrdata.d0   = cp0_regs.entry_lo0[2];
assign tlbrw_wrdata.v0   = cp0_regs.entry_lo0[1];
assign tlbrw_wrdata.G    = cp0_regs.entry_lo0[0] & cp0_regs.entry_lo1[0];
`endif

// set cp0_rddata
always_comb begin
    if (cp0_rreq.rsel == 3'd0) begin
        unique case (cp0_rreq.raddr)
            `ifdef COMPILE_FULL_M
            5'd0:  cp0_rddata = cp0_regs.index;
            5'd1:  cp0_rddata = cp0_regs.random;
            5'd2:  cp0_rddata = cp0_regs.entry_lo0;
            5'd3:  cp0_rddata = cp0_regs.entry_lo1;
            5'd4:  cp0_rddata = cp0_regs.context_;
            5'd5:  cp0_rddata = cp0_regs.page_mask;
            5'd6:  cp0_rddata = cp0_regs.wired;
            `endif

            5'd8:  cp0_rddata = cp0_regs.bad_vaddr;
            5'd9:  cp0_rddata = cp0_regs.count;

            `ifdef COMPILE_FULL_M
            5'd10: cp0_rddata = cp0_regs.entry_hi;
            5'd11: cp0_rddata = cp0_regs.compare;
            `endif

            5'd12: cp0_rddata = cp0_regs.status;
            5'd13: cp0_rddata = cp0_regs.cause;
            5'd14: cp0_rddata = cp0_regs.epc;

            `ifdef COMPILE_FULL_M
            5'd15: cp0_rddata = cp0_regs.prid;
            5'd16: cp0_rddata = cp0_regs.config0;
            `endif

            default: cp0_rddata = '0;
        endcase
    `ifdef COMPILE_FULL_M
    end else if (cp0_rreq.rsel == 3'd1) begin
        unique case(raddr)
            5'd15: cp0_rddata = cp0_regs.ebase;
            5'd16: cp0_rddata = cp0_regs.config1;
            default: cp0_rddata = '0;
        endcase
    `endif
    end else begin
        cp0_rddata = 32'b0;
    end
end

`ifdef COMPILE_FULL_M
// set default cp0_reg
uint32_t config0_default, config1_default, prid_default;
// set config0_default
assign config0_default = {
    1'b1,   // M, config1 not implemented
    21'b0,
    3'b1,   // MMU Type ( Standard TLB )
    4'b0,
    3'd3
};
localparam int IC_SET_PER_WAY = $clog2(`ICACHE_SIZE / `ICACHE_SET_ASSOC / `ICACHE_LINE_WIDTH / 64);
localparam int IC_LINE_SIZE   = $clog2(`ICACHE_LINE_WIDTH / 32) + 1;
localparam int IC_ASSOC       = `ICACHE_SET_ASSOC - 1;
localparam int DC_SET_PER_WAY = $clog2(`DCACHE_SIZE / `DCACHE_SET_ASSOC / `DCACHE_LINE_WIDTH / 64);
localparam int DC_LINE_SIZE   = $clog2(`DCACHE_LINE_WIDTH / 32) + 1;
localparam int DC_ASSOC       = `DCACHE_SET_ASSOC - 1;
`ifdef FPU_ENABLED
localparam logic FPU_ENABLED  = 1'b1;
`else
localparam logic FPU_ENABLED  = 1'b0;
`endif
// set config1_default
assign config1_default = {
    1'b0,
    6'd15,
    IC_SET_PER_WAY[2:0],
    IC_LINE_SIZE[2:0],
    IC_ASSOC[2:0],
    DC_SET_PER_WAY[2:0],
    DC_LINE_SIZE[2:0],
    DC_ASSOC[2:0],
    6'd0,
    FPU_ENABLED
};
// set prid_default
assign prid_default = {8'b0, 8'b1, 16'h8000};
`endif

// update cp0_regs
always_ff @ (posedge clk) begin
    if (rst) begin
        `ifdef COMPILE_FULL_M
        cp0_regs.index     <= '0;
        cp0_regs.random    <= N_TLB_ENTRIES - 1;
        cp0_regs.entry_lo0 <= '0;
        cp0_regs.entry_lo1 <= '0;
        cp0_regs.context_  <= '0;
        cp0_regs.page_mask <= '0;
        cp0_regs.wired     <= '0;
        `endif

        cp0_regs.bad_vaddr <= '0;
        cp0_regs.count     <= '0;

        `ifdef COMPILE_FULL_M
        cp0_regs.entry_hi  <= '0;
        cp0_regs.compare   <= '0;
        `endif

        `ifdef FPU_ENABLED
        cp0_regs.status    <= 32'b0011_0000_0100_0000_0000_0000_0000_0000;
        `else
        cp0_regs.status    <= 32'b0001_0000_0100_0000_0000_0000_0000_0000;
        `endif
        cp0_regs.cause     <= '0;
        cp0_regs.epc       <= '0;

        `ifdef COMPILE_FULL_M
        cp0_regs.error_epc <= '0;
        cp0_regs.ebase     <= 32'h80000000;
        cp0_regs.config0   <= config0_default;
        cp0_regs.config1   <= config1_default;
        cp0_regs.prid      <= prid_default;
        `endif
    end else begin
        cp0_regs <= cp0_regs_n;
    end
end

// set timer_int
`ifdef COMPILE_FULL_M
always_ff @ (posedge clk) begin
    if (rst)
        timer_int <= 1'b0;
    else if (cp0_regs.compare != 32'b0 && cp0_regs.compare == cp0_regs.count)
        timer_int <= 1'b1;
    else if(cp0_wreq.we && cp0_wreq.wsel == 3'b0 && cp0_wreq.waddr == 5'd11)
        timer_int <= 1'b0;
end
`else
assign timer_int = 1'b0;
`endif

// handle cp0_wreq
uint32_t wrdata;
assign wrdata = cp0_wreq.wrdata;
// generate 1/2 x clk
logic count_switch;
always_ff @ (posedge clk) begin
    if (rst) count_switch <= 1'b0;
    else count_switch <= ~count_switch;
end
// update cp0_regs_n
always_comb begin
    // cp0_regs default
    cp0_regs_n = cp0_regs;
    cp0_regs_n.count  = cp0_regs.count + count_switch;

    `ifdef COMPILE_FULL_M
    cp0_regs_n.random[TLB_WIDTH-1:0] = cp0_regs.random[TLB_WIDTH-1:0] + tlbwr_req;
    if((&cp0_regs.random[TLB_WIDTH-1:0]) & tlbwr_req)
        cp0_regs_n.random = cp0_regs.wired;
    `endif

    cp0_regs_n.cause.ip[7:2] = interrupt_flag[7:2];

    /* write register (WB stage) */
    if(cp0_wreq.we) begin
        if(cp0_wreq.wsel == 3'b0) begin
            case(cp0_wreq.waddr)
                `ifdef COMPILE_FULL_M
                5'd0:  cp0_regs_n.index[TLB_WIDTH-1:0] = wrdata[TLB_WIDTH-1:0];
                5'd2:  cp0_regs_n.entry_lo0 = wrdata[29:0];
                5'd3:  cp0_regs_n.entry_lo1 = wrdata[29:0];
                5'd4:  cp0_regs_n.context_[31:23] = wrdata[31:23];
                5'd6:  begin
                    cp0_regs_n.random = N_TLB_ENTRIES - 1;
                    cp0_regs_n.wired[TLB_WIDTH-1:0] = wrdata[TLB_WIDTH-1:0];
                end
                `endif

                5'd9:  cp0_regs_n.count = wrdata;

                `ifdef COMPILE_FULL_M
                5'd10: begin
                    cp0_regs_n.entry_hi[31:13] = wrdata[31:13];
                    cp0_regs_n.entry_hi[7:0] = wrdata[7:0];
                end
                5'd11: cp0_regs_n.compare = wrdata;
                `endif

                5'd12: begin
                    cp0_regs_n.status.cu0 = wrdata[28];

                    `ifdef FPU_ENABLED
                    cp0_regs_n.status.cu1 = wrdata[29];
                    `endif

                    `ifdef COMPILE_FULL_M
                    cp0_regs_n.status.bev = wrdata[22];     // for loongson
                    `endif

                    cp0_regs_n.status.im = wrdata[15:8];
                    cp0_regs_n.status.um = wrdata[4];

                    `ifdef COMPILE_FULL_M
                    cp0_regs_n.status[2:0] = wrdata[2:0];  // ERL/EXL/IE
                    `else
                    cp0_regs_n.status[1:0] = wrdata[1:0];  // EXL/IE
                    `endif
                end
                5'd13: begin
                    cp0_regs_n.cause.iv = wrdata[23];
                    cp0_regs_n.cause.ip[1:0] = wrdata[9:8];
                end
                5'd14: cp0_regs_n.epc = wrdata;

                `ifdef COMPILE_FULL_M
                5'd16: cp0_regs_n.config0[2:0] = wrdata[2:0];
                `endif
            endcase
        `ifdef COMPILE_FULL_M
        end else if(cp0_wreq.wsel == 3'b1) begin
            if(cp0_wreq.waddr == 5'd15)
                cp0_regs_n.ebase[29:12] = wrdata[29:12];
        `endif
        end
    end

    `ifdef COMPILE_FULL_M
    /* TLBR/TLBP instruction (WB stage) */
    // tlbr_req
    if(tlbr_req) begin
        cp0_regs_n.entry_hi[31:13] = tlbr_res.vpn2;
        cp0_regs_n.entry_hi[7:0]   = tlbr_res.asid;
        cp0_regs_n.entry_lo1 = {
            2'b0, tlbr_res.pfn1, tlbr_res.c1,
            tlbr_res.d1, tlbr_res.v1, tlbr_res.G };
        cp0_regs_n.entry_lo0 = {
            2'b0, tlbr_res.pfn0, tlbr_res.c0,
            tlbr_res.d0, tlbr_res.v0, tlbr_res.G };
    end
    // tlbp_req
    if(tlbp_req) cp0_regs_n.index = tlbp_res;
    `endif

    /* exception (MEM stage) */
    if (except_req_i.valid) begin
        if (except_req_i.eret) begin
            `ifdef COMPILE_FULL_M
            if(cp0_regs_n.status.erl)
                cp0_regs_n.status.erl = 1'b0;
            else 
            `endif
            cp0_regs_n.status.exl = 1'b0;
        end else begin
            if (cp0_regs_n.status.exl == 1'b0) begin
                if (except_req_i.delayslot) begin
                    cp0_regs_n.epc = except_req_i.pc - 32'h4;
                    cp0_regs_n.cause.bd = 1'b1;
                end else begin
                    cp0_regs_n.epc = except_req_i.pc;
                    cp0_regs_n.cause.bd = 1'b0;
                end
            end

            cp0_regs_n.status.exl = 1'b1;
            cp0_regs_n.cause.exc_code = except_req_i.code;

            `ifdef COMPILE_FULL_M
            if(except_req_i.code == EXCCODE_CpU)
                cp0_regs_n.cause.ce = except_req_i.extra[1:0];
            `endif

            if(except_req_i.code == EXCCODE_ADEL || except_req_i.code == EXCCODE_ADES) begin
                cp0_regs_n.bad_vaddr = except_req_i.extra;
            `ifdef COMPILE_FULL_M
            end else if(except_req_i.code == EXCCODE_TLBL || except_req_i.code == EXCCODE_TLBS || except_req_i.code == EXCCODE_MOD) begin
                cp0_regs_n.bad_vaddr = except_req_i.extra;
                cp0_regs_n.context_[22:4] = except_req_i.extra[31:13];      // context.bad_vpn2
                cp0_regs_n.entry_hi[31:13] = except_req_i.extra[31:13];     // entry_hi.vpn2
            `endif
            end
        end
    end
end

endmodule
