`ifndef CPU_DEFS_SVH
`define CPU_DEFS_SVH

/*
    This header defines common data structrue & constants in cpu module
*/

// common defs
`include "common_defs.svh"

typedef logic [$clog2(`N_REG)-1:0] reg_addr_t;
typedef logic [4:0] cpu_interrupt_t;

// funcs
`define DEF_FUNC_MUX_BE function logic [DATA_WIDTH - 1:0] mux_be( \
    input logic [DATA_WIDTH - 1:0] rdata, \
    input logic [DATA_WIDTH - 1:0] wdata, \
    input logic [(DATA_WIDTH / $bits(uint8_t)) - 1:0] sel \
); \
    uint8_t [(DATA_WIDTH / $bits(uint8_t)) - 1:0] r_data, w_data, mux_data; \
 \
    // reshape \
    assign r_data = rdata; \
    assign w_data = wdata; \
    // select \
    for (integer i = 0; i < (DATA_WIDTH / $bits(uint8_t)); i++) \
        mux_data[i] = sel[i] ? w_data[i] : r_data[i]; \
 \
    return mux_data; \
 \
endfunction

// hand_shake signals
interface hand_shake_if();
    // hand shake signals
    logic ready, valid;

    modport master (
        output valid,
        input ready
    );

    modport slave (
        input valid,
        output ready
    );

endinterface

// DECODE
// operator
typedef enum logic [6:0] {
    /* shift */
    OP_SLL, OP_SRL, OP_SRA, OP_SLLV, OP_SRLV, OP_SRAV,
    /* unconditional jump (reg) */
    OP_JALR,
    /* conditional move */
    OP_MOVN, OP_MOVZ,
    /* breakpoint and syscall */
    OP_SYSCALL, OP_BREAK,
    /* HI/LO move */
    OP_MFHI, OP_MFLO, OP_MTHI, OP_MTLO,
    /* multiplication and division */
    OP_MULT, OP_MULTU, OP_DIV, OP_DIVU,
    OP_MADD, OP_MADDU, OP_MSUB, OP_MSUBU, OP_MUL,
    /* add and substract */
    OP_ADD, OP_ADDU, OP_SUB, OP_SUBU,
    /* logical */
    OP_AND, OP_OR, OP_XOR, OP_NOR,
    /* compare and set */
    OP_SLT, OP_SLTU,
    /* trap */
    OP_TGE, OP_TGEU, OP_TLT, OP_TLTU, OP_TEQ, OP_TNE,
    /* count bits */
    OP_CLZ, OP_CLO,
    /* branch */
    OP_BLTZ, OP_BGEZ, OP_BLTZAL, OP_BGEZAL,
    OP_BEQ, OP_BNE, OP_BLEZ, OP_BGTZ,
    /* set */
    OP_LUI,
    /* load */
    OP_LB, OP_LH, OP_LWL, OP_LW, OP_LBU, OP_LHU, OP_LWR,
    /* store */
    OP_SB, OP_SH, OP_SWL, OP_SW, OP_SWR,
    /* LL/SC */
    OP_LL, OP_SC,
    /* long jump */
    OP_JAL,
    /* privileged instructions */
    OP_CACHE, OP_ERET, OP_MFC0, OP_MTC0,
    OP_TLBP, OP_TLBR, OP_TLBWI, OP_TLBWR, OP_WAIT,
    /* ASIC */
    `ifdef ASIC_ENABLED
        OP_MFC2, OP_MTC2,
    `endif
    /* FPU */
    `ifdef FPU_ENABLED
        OP_MFC1, OP_MTC1, OP_CFC1, OP_CTC1,
        OP_BC1,
        OP_MOVCI,
        OP_LWC1, OP_SWC1,
        OP_LDC1A, OP_SDC1A, OP_LDC1B, OP_SDC1B,
        OP_FPU_ADD, OP_FPU_SUB, OP_FPU_COND, OP_FPU_NEG,
        OP_FPU_MUL, OP_FPU_DIV, OP_FPU_SQRT, OP_FPU_ABS,
        OP_FPU_CVTW, OP_FPU_CVTS,
        OP_FPU_TRUNC, OP_FPU_ROUND,
        OP_FPU_CEIL, OP_FPU_FLOOR,
        OP_FPU_MOV, OP_FPU_CMOV,
    `endif
    /* invalid */
    OP_INVALID
} oper_t;
// control flow type
typedef enum logic [2:0] {
    ControlFlow_None,
    ControlFlow_Jump,
    ControlFlow_Branch,
    ControlFlow_Call,
    ControlFlow_Return
} controlflow_t;

// decode instruction
typedef struct packed {
    reg_addr_t   rs1;
    reg_addr_t   rs2;
    reg_addr_t   rd;
    `ifdef FPU_ENABLED
        reg_addr_t   fs1;
        reg_addr_t   fs2;
        reg_addr_t   fd;
        logic        fpu_we;
        logic        fcsr_we;
        logic        is_fpu;
        logic        is_fpu_multicyc;
    `endif
    oper_t       op;
    controlflow_t cf;       // controlflow type
    virt_t default_jump_i;
    virt_t default_jump_j;
    logic  imm_signed;      // use sign-extened immediate
    logic  use_imm;         // use immediate as reg2
    logic  is_controlflow;  // controlflow maybe changed
    logic  is_multicyc;     // need multicyc_exec
    logic  is_load;         // load data
    logic  is_store;        // store data
    logic[$bits(uint32_t)/$bits(uint8_t)-1:0] be;
} decoder_resp_t;

// Exception
typedef enum logic [4:0] {
    EXCCODE_INT,    // interrupt
    EXCCODE_MOD,    // TLB modification exception
    EXCCODE_TLBL,   // TLB exception (load or instruction fetch)
    EXCCODE_TLBS,   // TLB exception (store)
    EXCCODE_ADEL,   // address exception (load or instruction fetch)
    EXCCODE_ADES,   // address exception (store)
    EXCCODE_INV_06, // invalid exccode(5'h06)
    EXCCODE_INV_07, // invalid exccode(5'h07)
    EXCCODE_SYS,    // syscall
    EXCCODE_BP,     // breakpoint
    EXCCODE_RI,     // reserved instruction exception
    EXCCODE_CpU,    // coprocesser unusable exception
    EXCCODE_OV,     // overflow
    EXCCODE_TR,     // trap
    EXCCODE_INV_0e, // invalid exccode(5'h0e)
    EXCCODE_FPE,    // floating point exception
    EXCCODE_INV_10, // invalid exccode(5'h10)
    EXCCODE_INV_11, // invalid exccode(5'h11)
    EXCCODE_INV_12, // invalid exccode(5'h12)
    EXCCODE_INV_13, // invalid exccode(5'h13)
    EXCCODE_INV_14, // invalid exccode(5'h14)
    EXCCODE_INV_15, // invalid exccode(5'h15)
    EXCCODE_INV_16, // invalid exccode(5'h16)
    EXCCODE_INV_17, // invalid exccode(5'h17)
    EXCCODE_INV_18, // invalid exccode(5'h18)
    EXCCODE_INV_19, // invalid exccode(5'h19)
    EXCCODE_INV_1a, // invalid exccode(5'h1a)
    EXCCODE_INV_1b, // invalid exccode(5'h1b)
    EXCCODE_INV_1c, // invalid exccode(5'h1c)
    EXCCODE_INV_1d, // invalid exccode(5'h1d)
    EXCCODE_INV_1e, // invalid exccode(5'h1e)
    EXCCODE_INV_1f  // invalid exccode(5'h1f)
} except_code_t;
typedef struct packed {
    logic valid, delayslot, eret;
    except_code_t code;
    virt_t pc, except_vec;
    uint32_t extra;
} except_req_t;
// address exception
typedef struct packed {
    logic miss, illegal, invalid;
} address_exception_t;
typedef struct packed {
    logic valid;
    except_code_t exc_code;
    logic tlb_refill;
    uint32_t extra;
    oper_t op;
    virt_t pc;
    logic delayslot, eret;
} exception_t;

// CP0
// CP0 request
typedef struct packed {
    reg_addr_t  raddr;
    logic [2:0] rsel;
} cp0_rreq_t;
typedef struct packed {
    logic       we;
    reg_addr_t  waddr;
    logic [2:0] wsel;
    uint32_t    wrdata;
} cp0_wreq_t;
// CP0 registers
typedef struct packed {
    logic cu3, cu2, cu1, cu0;
    logic rp, fr, re, mx;
    logic px, bev, ts, sr;
    logic nmi, zero;
    logic [1:0] impl;
    logic [7:0] im;
    logic kx, sx, ux, um;
    logic r0, erl, exl, ie;
} cp0_status_t;
typedef struct packed {
    logic bd, zero30;
    logic [1:0] ce;
    logic [3:0] zero27_24;
    logic iv, wp;
    logic [5:0] zero21_16;
    logic [7:0] ip;
    logic zero7;
    except_code_t exc_code;
    logic [1:0] zero1_0;
} cp0_cause_t;
typedef struct packed {
    uint32_t ebase, config1;
    /* The order of the following registers is important.
     * DO NOT change them. New registers must be added 
     * BEFORE this comment
     */
    /* primary 32 registers (sel = 0) */
    uint32_t
        desave,     error_epc,      tag_hi,     tag_lo,
        cache_err,  err_ctl,        perf_cnt,   depc,
        debug,      impl_lfsr32,    reserved21, reserved20,
        watch_hi,   watch_lo,       ll_addr,    config0,
        prid,       epc;
    cp0_cause_t cause;
    cp0_status_t status;
    uint32_t
        compare,    entry_hi,       count,      bad_vaddr,
        reserved7,  wired,          page_mask,  context_,
        entry_lo1,  entry_lo0,      random,     index;
} cp0_regs_t;

// regs req
typedef struct packed {
    logic we;
    uint32_t wrdata;
    reg_addr_t waddr;
} regs_wreq_t;

// INST_FETCH
typedef struct packed {
    // Are we recognize this instruction as a controlflow?
    logic valid;
    // change the pipeline
    logic taken;
    // target pc
    virt_t target;
} branch_resolved_t;

// MULTICYC_EXEC
typedef struct packed {
    oper_t op;
    logic is_multicyc;
    uint64_t hilo;
    uint32_t reg0, reg1;
} multicyc_req_t;
typedef struct packed {
    // valid == ready
    logic ready, valid;
    uint64_t hilo;
} multicyc_resp_t;

// MMU/TLB
typedef logic [$clog2(`N_TLB_ENTRIES) - 1:0] tlb_index_t;
typedef struct packed {
    phys_t paddr;
    tlb_index_t index;
    logic miss, dirty, valid;
    logic [2:0] cache_flag;
} tlb_resp_t;
typedef struct packed {
    logic [2:0] c0, c1;
    logic [7:0] asid;
    logic [18:0] vpn2;
    logic [23:0] pfn0, pfn1;
    logic [11:0] mask;
    logic d1, v1, d0, v0;
    logic G;
} tlb_entry_t;

typedef struct packed {
    phys_t paddr;
    virt_t vaddr;
    logic uncached;
    logic inv, miss, dirty, illegal;
} mmu_resp_t;

// pipe struct
typedef struct packed {
    logic valid;
    uint32_t inst;
    virt_t vaddr;
    address_exception_t iaddr_ex;
} pipe_if_t;
typedef struct packed {
    logic valid;
    // pipe_if signals
    pipe_if_t inst_fetch;
    // inst decode
    decoder_resp_t decode_resp;
    logic delayslot;
    // cp0 read req
    cp0_rreq_t cp0_rreq;
    // dcache req
    dcache_req_t dcache_req;
    // regs req (data from regfile at rs & rt)
    uint32_t regs_rddata0, regs_rddata1;
} pipe_id_t;
typedef struct packed {
    logic valid;
    // cp0 req
    cp0_wreq_t cp0_wreq;
    // except req
    exception_t exception;
    // branch resolved
    branch_resolved_t resolved_branch;
    // regs write req (only one write port for each pipe_ex)
    regs_wreq_t regs_wreq;
    // for debug
    debug_req_t debug_req;
} pipe_ex_t;

`endif
