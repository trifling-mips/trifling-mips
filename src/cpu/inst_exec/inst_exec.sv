// inst_exec
`include "inst_exec.svh"

module inst_exec #(
    // local parameter
    localparam  DATA_WIDTH      = $bits(uint32_t)
) (
    // external signals
    input   logic   clk,
    input   logic   rst,
    // ready
    input   logic   ready_i,
    output  logic   ready_o,
    // except_req
    input   except_req_t    except_req,
    // dcache_resp
    input   logic           dbus_ready,
    input   dcache_resp_t   dcache_resp,
    // cp0 rd resp
    input   uint32_t    cp0_rddata,
    // pipe_id
    input   pipe_id_t   pipe_id,
    // pipe_ex
    output  pipe_ex_t   pipe_ex_n,      // not sync
    output  pipe_ex_t   pipe_ex,
    // mmu result
    input   mmu_resp_t  mmu_daddr_resp
);

// define funcs
`DEF_FUNC_LOAD_SEL

// define interface for hilo
logic hilo_we;
uint64_t hilo_wrdata, hilo_rddata;
// define interface for branch_resolver
branch_resolved_t resolved_branch;
// define interface for multicyc_exec
multicyc_resp_t multicyc_resp;
multicyc_req_t  multicyc_req;

// define inner signals
oper_t op;
virt_t pc_vaddr;
exception_t ex;
uint32_t exec_ret, reg0, reg1, inst;
assign reg0     = pipe_id.regs_rddata0;
assign reg1     = pipe_id.regs_rddata1;
assign op       = pipe_id.decode_resp.op;
assign inst     = pipe_id.inst_fetch.inst;
assign pc_vaddr = pipe_id.inst_fetch.vaddr;

// unsigned register arithmetic
uint32_t add_u, sub_u;
assign add_u = reg0 + reg1;
assign sub_u = reg0 - reg1;

// overflow checking
logic ov_add, ov_sub;
assign ov_add = (reg0[31] == reg1[31]) & (reg0[31] ^ add_u[31]);
assign ov_sub = (reg0[31] ^ reg1[31]) & (reg0[31] ^ sub_u[31]);

// comparsion
logic signed_lt, unsigned_lt;
assign signed_lt = (reg0[31] != reg1[31]) ? reg0[31] : sub_u[31];
assign unsigned_lt = (reg0 < reg1);

// count leading bits
uint32_t clz_cnt, clo_cnt;
`ifdef COMPILE_FULL_M
count_bit #(

) count_clz (
    .bit_val(1'b0   ),
    .val    (reg0   ),
    .count  (clz_cnt)
);

count_bit #(

) count_clo (
    .bit_val(1'b1   ),
    .val    (reg0   ),
    .count  (clo_cnt)
);
`else
assign clo_cnt = '0;
assign clz_cnt = '0;
`endif

// setup hilo request
assign hilo_we    = (
    op == OP_MADD || op == OP_MADDU || op == OP_MSUB || op == OP_MSUBU
    || op == OP_MULT || op == OP_MULTU || op == OP_DIV || op == OP_DIVU
    || op == OP_MTHI || op == OP_MTLO);
assign hilo_wrdata = multicyc_resp.hilo;

// setup execution result
always_comb begin
    exec_ret = '0;
    unique case(op)
        /* logical instructions */
        OP_LUI: exec_ret = { inst[15:0], 16'b0 };
        OP_AND: exec_ret = reg0 & reg1;
        OP_OR:  exec_ret = reg0 | reg1;
        OP_XOR: exec_ret = reg0 ^ reg1;
        OP_NOR: exec_ret = ~(reg0 | reg1);

        /* add and subtract */
        OP_ADD, OP_ADDU: exec_ret = add_u;
        OP_SUB, OP_SUBU: exec_ret = sub_u;

        `ifdef COMPILE_FULL_M
        /* bits counting */
        OP_CLZ: exec_ret = clz_cnt;
        OP_CLO: exec_ret = clo_cnt;
        `endif

        `ifdef COMPILE_FULL_M
        /* move instructions */
        `ifdef FPU_ENABLED
            OP_MOVCI,
        `endif
        OP_MOVZ, OP_MOVN: exec_ret = reg1;
        `endif
        OP_MFHI: exec_ret = hilo_rddata[63:32];
        OP_MFLO: exec_ret = hilo_rddata[31:0];

        `ifdef COMPILE_FULL_M
        /* multi-cycle */
        OP_MUL: exec_ret = multicyc_reg;
        `endif

        /* jump instructions */
        OP_JAL, OP_BLTZAL, OP_BGEZAL, OP_JALR:
            exec_ret = pc_vaddr + 32'd8;

        /* shift instructions */
        OP_SLL:  exec_ret = reg1 << inst[10:6];
        OP_SLLV: exec_ret = reg1 << reg0[4:0];
        OP_SRL:  exec_ret = reg1 >> inst[10:6];
        OP_SRLV: exec_ret = reg1 >> reg0[4:0];
        OP_SRA:  exec_ret = $signed(reg1) >>> inst[10:6];
        OP_SRAV: exec_ret = $signed(reg1) >>> reg0[4:0];

        /* compare and set */
        OP_SLTU: exec_ret = { 30'b0, unsigned_lt };
        OP_SLT:  exec_ret = { 30'b0, signed_lt   };

        `ifdef COMPILE_FULL_M
        /* conditional store */
        OP_SC:   exec_ret = llbit_value;
        `endif

        /* read coprocessers */
        OP_MFC0: exec_ret = cp0_rddata;

        `ifdef FPU_ENABLED
        OP_MFC1: exec_ret = data.fpu_reg1;
        OP_CFC1: begin
            unique case(instr[15:11])
                5'd0:  exec_ret = 32'h00010000;
                5'd25: exec_ret = { 24'b0, data.fpu_fcsr.fcc };
                5'd26: exec_ret = { 14'b0, data.fpu_fcsr.cause,
                    5'b0, data.fpu_fcsr.flags[4:0], 2'b0 };
                5'd28: exec_ret = { 20'b0, data.fpu_fcsr.enables[4:0],
                    4'b0, data.fpu_fcsr.fs, data.fpu_fcsr.rm };
                5'd31: exec_ret = { data.fpu_fcsr.fcc[7:1], data.fpu_fcsr.fs,
                    data.fpu_fcsr.fcc[0], 5'b0, data.fpu_fcsr.cause,
                    data.fpu_fcsr.enables[4:0], data.fpu_fcsr.flags[4:0], data.fpu_fcsr.rm };
                default: exec_ret = 32'b0;
            endcase
        end
        `endif

        `ifdef ASIC_ENABLED
        OP_MFC2: exec_ret = asic_rdata;
        `endif

        default: exec_ret = '0;
    endcase
end

/* exception */
logic trap_valid, daddr_unaligned, invalid_inst;
virt_t mmu_vaddr;
assign mmu_vaddr = pipe_id.dcache_req.vaddr;
always_comb begin
    `ifdef COMPILE_FULL_M
    unique case (op)
        OP_TEQ:  trap_valid = (reg1 == reg2);
        OP_TNE:  trap_valid = (reg1 != reg2);
        OP_TGE:  trap_valid = ~signed_lt;
        OP_TLT:  trap_valid = signed_lt;
        OP_TGEU: trap_valid = ~unsigned_lt;
        OP_TLTU: trap_valid = unsigned_lt;
        default: trap_valid = 1'b0;
    endcase
    `else
    trap_valid = '0;
    `endif
    unique case (op)
        `ifdef FPU_ENABLED
        OP_SDC1A, OP_LDC1A:
            daddr_unaligned = |mmu_vaddr[2:0];
        OP_SWC1, OP_LWC1,
        `endif

        `ifdef COMPILE_FULL_M
        OP_LL, OP_SC,
        `endif
        OP_LW, OP_SW:
            daddr_unaligned = mmu_vaddr[0] | mmu_vaddr[1];
        OP_LH, OP_LHU, OP_SH:
            daddr_unaligned = mmu_vaddr[0];
        default: daddr_unaligned = 1'b0;
    endcase
end

// ( illegal | unaligned, miss | invalid )
logic [1:0] ex_if;  // exception in IF
assign ex_if = {
    pipe_id.inst_fetch.iaddr_ex.illegal | |pipe_id.inst_fetch.vaddr[1:0],
    pipe_id.inst_fetch.iaddr_ex.miss | pipe_id.inst_fetch.iaddr_ex.invalid
};

// ( trap, break, syscall, overflow, privilege )
logic [4:0] ex_ex;  // exception in EX
assign ex_ex = {
    trap_valid,     // if not COMPILE_FULL_M, always 1'b0
    op == OP_BREAK,
    op == OP_SYSCALL,
    ((op == OP_ADD) & ov_add) | ((op == OP_SUB) & ov_sub),
    `ifdef COMPILE_FULL_M
    data.decoded.is_priv & is_usermode
    `ifdef FPU_ENABLED
    | pipe_id.decode_resp.is_fpu & ~fpu_valid
    `endif
    `else
    1'b0
    `endif
};
assign invalid_inst = (op == OP_INVALID);

logic mem_tlbex, mem_addrex;
`ifdef COMPILE_FULL_M
assign mem_tlbex  = (mmu_daddr_resp.miss | mmu_daddr_resp.invalid) & ~mem_addrex;
`else
assign mem_tlbex = 1'b0;
`endif
assign mem_addrex = mmu_daddr_resp.illegal | daddr_unaligned;
// ( addrex_r, addrex_w, tlbex_r, tlbex_w, readonly )
logic [4:0] ex_mm;  // exception in MEM
assign ex_mm = {
    mem_addrex & pipe_id.dcache_req.read,
    mem_addrex & pipe_id.dcache_req.write,
    mem_tlbex & pipe_id.dcache_req.read,
    mem_tlbex & pipe_id.dcache_req.write,
    ~mmu_daddr_resp.dirty & pipe_id.dcache_req.write
};

always_comb begin
    ex = '0;
    ex.pc    = pipe_id.inst_fetch.vaddr;
    ex.valid = ((|ex_if) | invalid_inst | (|ex_ex) | (|ex_mm)) & pipe_id.valid;
    ex.tlb_refill = mmu_daddr_resp.miss & ~mem_addrex;
    ex.delayslot  = pipe_id.delayslot;
    ex.eret       = (op == OP_ERET);
    if (|ex_if) begin
        ex.extra = pipe_id.inst_fetch.vaddr;
        unique casez (ex_if)
            2'b1?: ex.exc_code = EXCCODE_ADEL;

            `ifdef COMPILE_FULL_M
            2'b01: begin
                ex.tlb_refill = pipe_id.inst_fetch.iaddr_ex.miss;
                ex.exc_code   = EXCCODE_TLBL;
            end
            `endif

            default:;
        endcase
    end else if (invalid_inst) begin
        ex.exc_code = EXCCODE_RI;
    end else if (|ex_ex) begin
        unique case (ex_ex)
            `ifdef COMPILE_FULL_M
            5'b10000: ex.exc_code = EXCCODE_TR;
            `endif

            5'b01000: ex.exc_code = EXCCODE_BP;
            5'b00100: ex.exc_code = EXCCODE_SYS;
            5'b00010: ex.exc_code = EXCCODE_OV;

            `ifdef COMPILE_FULL_M
            5'b00001: begin
                ex.exc_code = EXCCODE_CpU;
                `ifdef FPU_ENABLED
                if (pipe_id.decode_resp.is_fpu & ~fpu_valid)
                    ex.extra = 1;
                `endif
            end
            `endif

            default:;
        endcase
    end else if (|ex_mm) begin
        ex.extra = pipe_id.dcache_req.vaddr;
        unique casez (ex_mm)
            5'b1????: ex.exc_code = EXCCODE_ADEL;
            5'b01???: ex.exc_code = EXCCODE_ADES;

            `ifdef COMPILE_FULL_M
            5'b001??: begin
                ex.tlb_refill = mmu_daddr_resp.miss;
                ex.exc_code   = EXCCODE_TLBL;
            end
            5'b0001?: begin
                ex.tlb_refill = mmu_daddr_resp.miss;
                ex.exc_code   = EXCCODE_TLBS;
            end
            5'b00001: ex.exc_code = EXCCODE_MOD;
            `endif

            default:;
        endcase
    end
end

// set ready
logic branch_stall;
assign branch_stall = resolved_branch.taken && ~ready_i;
assign ready_o = (
    dbus_ready && multicyc_resp.ready
) && ~branch_stall;
// pipe_ex_flush
logic pipe_ex_flush;
assign pipe_ex_flush = except_req.valid;
// set valid
assign pipe_ex_n.valid              = ready_o;
// set be
always_comb begin
    pipe_ex_n.be = '0;
    unique case (pipe_id.decode_resp.op)
        OP_LW, OP_SW: pipe_ex_n.be = '1;
        OP_LH, OP_LHU, OP_SH: 
            unique case (pipe_id.dcache_req.vaddr[1:0])
                2'b00: pipe_ex_n.be = 4'b0011;
                2'b10: pipe_ex_n.be = 4'b1100;
                default: pipe_ex_n.be = '0;
            endcase
        OP_LB, OP_LBU, OP_SB:
            unique case (pipe_id.dcache_req.vaddr[1:0])
                2'b00: pipe_ex_n.be = 4'b0001;
                2'b01: pipe_ex_n.be = 4'b0010;
                2'b10: pipe_ex_n.be = 4'b0100;
                2'b11: pipe_ex_n.be = 4'b1000;
                default: pipe_ex_n.be = '0;
            endcase
        default: pipe_ex_n.be = '0;
    endcase
end
// set cp0_wreq
assign pipe_ex_n.cp0_wreq.we        = (op == OP_MTC0) & pipe_id.valid & ~pipe_ex_flush;
assign pipe_ex_n.cp0_wreq.waddr     = pipe_id.cp0_rreq.raddr;
assign pipe_ex_n.cp0_wreq.wsel      = pipe_id.cp0_rreq.rsel;
assign pipe_ex_n.cp0_wreq.wrdata    = reg0;
// set except_req
assign pipe_ex_n.exception          = ex;
// set branch_resolved
assign pipe_ex_n.resolved_branch    = resolved_branch;
// set regs_wreq
assign pipe_ex_n.regs_wreq.we       = (
    op == OP_LUI
    || op == OP_AND
    || op == OP_OR
    || op == OP_XOR
    || op == OP_NOR
    || op == OP_ADD
    || op == OP_ADDU
    || op == OP_SUB
    || op == OP_SUBU
    || op == OP_MFHI
    || op == OP_MFLO
    || op == OP_JAL
    || op == OP_BLTZAL
    || op == OP_BGEZAL
    || op == OP_JALR
    || op == OP_SLL
    || op == OP_SLLV
    || op == OP_SRL
    || op == OP_SRLV
    || op == OP_SRA
    || op == OP_SRAV
    || op == OP_SLTU
    || op == OP_SLT
    || op == OP_MFC0
    || pipe_id.decode_resp.is_load
) & pipe_id.valid & ~pipe_ex_flush;
assign pipe_ex_n.regs_wreq.waddr = pipe_id.decode_resp.rd;
assign pipe_ex_n.regs_wreq.wrdata= pipe_id.decode_resp.is_load ? load_sel(dcache_resp.rddata, pipe_id.dcache_req.vaddr, pipe_id.decode_resp.op) : exec_ret;
// set pipe_ex_n.debug_req
assign pipe_ex_n.debug_req.vaddr = pipe_id.inst_fetch.vaddr;
assign pipe_ex_n.debug_req.regs_wrdata = pipe_ex_n.regs_wreq.wrdata;
assign pipe_ex_n.debug_req.regs_wbe = ((
    op == OP_LUI
    || op == OP_AND
    || op == OP_OR
    || op == OP_XOR
    || op == OP_NOR
    || op == OP_ADD
    || op == OP_ADDU
    || op == OP_SUB
    || op == OP_SUBU
    || op == OP_MFHI
    || op == OP_MFLO
    || op == OP_JAL
    || op == OP_BLTZAL
    || op == OP_BGEZAL
    || op == OP_JALR
    || op == OP_SLL
    || op == OP_SLLV
    || op == OP_SRL
    || op == OP_SRLV
    || op == OP_SRA
    || op == OP_SRAV
    || op == OP_SLTU
    || op == OP_SLT
    || op == OP_MFC0
) ? '1 : ({4{pipe_id.decode_resp.is_load}} & pipe_ex_n.be)) & {4{pipe_id.valid}};
assign pipe_ex_n.debug_req.regs_waddr = pipe_id.decode_resp.rd;
// update pipe_ex
always_ff @ (posedge clk) begin
    if (rst | pipe_ex_flush) begin
        pipe_ex <= '0;
    end else if (ready_o) begin
        pipe_ex <= pipe_ex_n;
    end else begin
        pipe_ex <= '0;
    end
end

// inst hilo
hilo #(

) hilo_inst (
    // external signals
    .clk,
    .rst,
    // wr & rd req
    .we     (hilo_we    ),
    .wrdata (hilo_wrdata),
    .rddata (hilo_rddata)
);

// inst branch_resolver
branch_resolver #(

) branch_resolver_inst (
    // regs data
    .reg0,
    .reg1,
    // pipe_id
    .pipe_id,
    // branch_resolved
    .resolved_branch
);

// inst multicyc_exec
multicyc_exec #(

) multicyc_exec_inst (
    // external signals
    .clk,
    . rst,
    // multicyc_req & multicyc_resp
    .multicyc_req,
    .multicyc_resp
);
assign multicyc_req.op          = pipe_id.decode_resp.op;
assign multicyc_req.reg0        = pipe_id.regs_rddata0;
assign multicyc_req.reg1        = pipe_id.regs_rddata1;
assign multicyc_req.is_multicyc = pipe_id.decode_resp.is_multicyc;
assign multicyc_req.hilo        = hilo_rddata;

endmodule
