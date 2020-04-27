// decoder
`include "decode.svh"

module decoder #(

) (
    input  virt_t          vaddr,
    input  uint32_t        inst,
    output decoder_resp_t  decoder_resp
);

// setup instruction fields
logic [5:0] opcode, func;
reg_addr_t rs, rt, rd;
assign opcode    = inst[31:26];
assign rs        = inst[25:21];
assign rt        = inst[20:16];
assign rd        = inst[15:11];
assign funct     = inst[5:0];
`ifdef FPU_ENABLED
reg_addr_t fs, ft, fd;
assign ft = inst[20:16];
assign fs = inst[15:11];
assign fd = inst[10:6];
`endif

// set default jump & branch target
virt_t pc_plus4;
assign pc_plus4 = vaddr + 32'd4;
assign decoder_resp.default_jump_i = pc_plus4
       + { { 14{inst[15]} }, inst[15:0], 2'b0 };
assign decoder_resp.default_jump_j = {
       pc_plus4[31:28], inst[25:0], 2'b0
};

// decode branch
logic is_branch, is_jump_i, is_jump_r, is_call, is_return;
// inst decode_branch
decode_branch #(
) decode_branch_inst (
    .*
);
// set cf
always_comb begin
    unique casez( { is_branch, is_return, is_call, is_jump_i | is_jump_r } )
        4'b1???: decoder_resp.cf = ControlFlow_Branch;
        4'b01??: decoder_resp.cf = ControlFlow_Return;
        4'b001?: decoder_resp.cf = ControlFlow_Call;
        4'b0001: decoder_resp.cf = ControlFlow_Jump;
        default: decoder_resp.cf = ControlFlow_None;
    endcase
end

always_comb begin
    decoder_resp.rs1        = '0;
    decoder_resp.rs2        = '0;
    decoder_resp.rd         = '0;
    `ifdef FPU_ENABLED
    // TODO
    `endif
    decoder_resp.op         = OP_SLL;
    decoder_resp.use_imm    = 1'b0;
    decoder_resp.imm_signed = 1'b1;
    decoder_resp.is_load    = 1'b0;
    decoder_resp.is_store   = 1'b0;
    decoder_resp.is_controlflow = is_branch | is_jump_i | is_jump_r;

    unique casez(opcode)
        6'b000000: begin    // SPECIAL (Reg-Reg)
            decoder_resp.rs1 = rs;
            decoder_resp.rs2 = rt;
            decoder_resp.rd  = rd;
            unique case(funct)
                /* shift */
                6'b000000: decoder_resp.op = OP_SLL;
                6'b000010: decoder_resp.op = OP_SRL;
                6'b000011: decoder_resp.op = OP_SRA;
                6'b000100: decoder_resp.op = OP_SLLV;
                6'b000110: decoder_resp.op = OP_SRLV;
                6'b000111: decoder_resp.op = OP_SRAV;
                /* unconditional jump (reg) */
                6'b001000: decoder_resp.op = OP_JALR;
                6'b001001: decoder_resp.op = OP_JALR;
                `ifdef COMPILE_FULL_M
                /* conditional move */
                6'b001011: decoder_resp.op = OP_MOVN;
                6'b001010: decoder_resp.op = OP_MOVZ;
                `endif
                /* breakpoint and syscall */
                6'b001100: decoder_resp.op = OP_SYSCALL;
                6'b001101: decoder_resp.op = OP_BREAK;
                `ifdef COMPILE_FULL_M
                /* sync */
                6'b001111: decoder_resp.op = OP_SLL;
                `endif
                /* HI/LO move */
                6'b010000: decoder_resp.op = OP_MFHI;
                6'b010001: decoder_resp.op = OP_MTHI;
                6'b010010: decoder_resp.op = OP_MFLO;
                6'b010011: decoder_resp.op = OP_MTLO;
                /* multiplication and division */
                6'b011000: decoder_resp.op = OP_MULT;
                6'b011001: decoder_resp.op = OP_MULTU;
                6'b011010: decoder_resp.op = OP_DIV;
                6'b011011: decoder_resp.op = OP_DIVU;
                /* add and substract */
                6'b100000: decoder_resp.op = OP_ADD;
                6'b100001: decoder_resp.op = OP_ADDU;
                6'b100010: decoder_resp.op = OP_SUB;
                6'b100011: decoder_resp.op = OP_SUBU;
                /* logical */
                6'b100100: decoder_resp.op = OP_AND;
                6'b100101: decoder_resp.op = OP_OR;
                6'b100110: decoder_resp.op = OP_XOR;
                6'b100111: decoder_resp.op = OP_NOR;
                /* compare and set */
                6'b101010: decoder_resp.op = OP_SLT;
                6'b101011: decoder_resp.op = OP_SLTU;
                `ifdef FPU_ENABLED
                /* FPU conditional move */
                6'b000001: begin
                    decoder_resp.op  = OP_MOVCI;
                    decoder_resp.rs2 = '0;
                end
                `endif
                `ifdef COMPILE_FULL_M
                /* trap */
                6'b110000: decoder_resp.op = OP_TGE;
                6'b110001: decoder_resp.op = OP_TGEU;
                6'b110010: decoder_resp.op = OP_TLT;
                6'b110011: decoder_resp.op = OP_TLTU;
                6'b110100: decoder_resp.op = OP_TEQ;
                6'b110110: decoder_resp.op = OP_TNE;
                `endif
                default:   decoder_resp.op = OP_INVALID;
            endcase
        end

        `ifdef COMPILE_FULL_M
        6'b011100: begin    // SPECIAL2 (Reg-Reg)
            decoder_resp.rs1 = rs;
            decoder_resp.rs2 = rt;
            decoder_resp.rd  = rd;
            unique case(funct)
                6'b000000: decoder_resp.op = OP_MADD;
                6'b000001: decoder_resp.op = OP_MADDU;
                6'b000100: decoder_resp.op = OP_MSUB;
                6'b000101: decoder_resp.op = OP_MSUBU;
                6'b000010: decoder_resp.op = OP_MUL;
                6'b100000: decoder_resp.op = OP_CLZ;
                6'b100001: decoder_resp.op = OP_CLO;
                default:   decoder_resp.op = OP_INVALID;
            endcase
        end
        `endif

        6'b000001: begin    // REGIMM (Reg-Imm)
            decoder_resp.rs1 = rs;
            decoder_resp.rd  = (instr[20:17] == 4'b1000) ? 5'd31 : 5'd0;
            decoder_resp.use_imm = 1'b1;
            unique case(instr[20:16])
                `ifdef COMPILE_FULL_M
                /* trap */
                5'b01000: decoder_resp.op = OP_TGE;
                5'b01001: decoder_resp.op = OP_TGEU;
                5'b01010: decoder_resp.op = OP_TLT;
                5'b01011: decoder_resp.op = OP_TLTU;
                5'b01100: decoder_resp.op = OP_TEQ;
                5'b01110: decoder_resp.op = OP_TNE;
                `endif
                /* branch */
                5'b00000: decoder_resp.op = OP_BLTZ;
                5'b00001: decoder_resp.op = OP_BGEZ;
                5'b10000: decoder_resp.op = OP_BLTZAL;
                5'b10001: decoder_resp.op = OP_BGEZAL;
                default:  decoder_resp.op = OP_INVALID;
            endcase
        end

        6'b0001??: begin    // branch (Reg-Imm)
            decoder_resp.rs1 = rs;
            decoder_resp.rs2 = rt;
            unique case(opcode[1:0])
                2'b00: decoder_resp.op = OP_BEQ;
                2'b01: decoder_resp.op = OP_BNE;
                2'b10: decoder_resp.op = OP_BLEZ;
                2'b11: decoder_resp.op = OP_BGTZ;
            endcase
        end

        6'b001???: begin    // logic and arithmetic (Reg-Imm)
            decoder_resp.rs1 = rs;
            decoder_resp.rd  = rt;
            decoder_resp.use_imm      = 1'b1;
            decoder_resp.imm_signed   = ~opcode[2];
            unique case(opcode[2:0])
                3'b100: decoder_resp.op = OP_AND;
                3'b101: decoder_resp.op = OP_OR;
                3'b110: decoder_resp.op = OP_XOR;
                3'b111: decoder_resp.op = OP_LUI;
                3'b000: decoder_resp.op = OP_ADD;
                3'b001: decoder_resp.op = OP_ADDU;
                3'b010: decoder_resp.op = OP_SLT;
                3'b011: decoder_resp.op = OP_SLTU;
            endcase
        end

        6'b100???: begin    // load (Reg-Imm)
            decoder_resp.rs1     = rs;
            decoder_resp.rs2     = (opcode[1:0] == 2'b10) ? rt : '0;
            decoder_resp.rd      = rt;
            decoder_resp.is_load = 1'b1;
            unique case(opcode[2:0])
                3'b000: decoder_resp.op = OP_LB;
                3'b001: decoder_resp.op = OP_LH;
                `ifdef COMPILE_FULL_M
                3'b010: decoder_resp.op = OP_LWL;
                `endif
                3'b011: decoder_resp.op = OP_LW;
                3'b100: decoder_resp.op = OP_LBU;
                3'b101: decoder_resp.op = OP_LHU;
                `ifdef COMPILE_FULL_M
                3'b110: decoder_resp.op = OP_LWR;
                `endif
                3'b111: decoder_resp.op = OP_INVALID;
            endcase
        end

        6'b101???: begin // store (Reg-Imm)
            decoder_resp.rs1      = rs;
            decoder_resp.rs2      = rt;
            decoder_resp.is_store = 1'b1;
            unique case(opcode[2:0])
                3'b000:  decoder_resp.op = OP_SB;
                3'b001:  decoder_resp.op = OP_SH;
                `ifdef COMPILE_FULL_M
                3'b010:  decoder_resp.op = OP_SWL;
                `endif
                3'b011:  decoder_resp.op = OP_SW;
                `ifdef COMPILE_FULL_M
                3'b110:  decoder_resp.op = OP_SWR;
                3'b111:  decoder_resp.op = OP_CACHE;
                `endif
                default: decoder_resp.op = OP_INVALID;
            endcase
        end

        `ifdef COMPILE_FULL_M
        6'b110000: begin    // load linked word (Reg-Imm)
            decoder_resp.rs1     = rs;
            decoder_resp.rd      = rt;
            decoder_resp.op      = OP_LL;
            decoder_resp.is_load = 1'b1;
        end

        6'b111000: begin    // store conditional word (Reg-Imm)
            decoder_resp.rs1      = rs;
            decoder_resp.rs2      = rt;
            decoder_resp.rd       = rt;
            decoder_resp.op       = OP_SC;
            decoder_resp.is_store = 1'b1;
        end

        6'b110011: begin    // prefetch
            decoder_resp.op = OP_SLL;
        end
        `endif
        
        6'b00001?: begin // jump and link
            decoder_resp.rd  = {$bits(reg_addr_t){opcode[0]}};
            decoder_resp.op  = OP_JAL;
        end

        6'b010000: begin // COP0
            unique case(instr[25:21])
                5'b00000: begin
                    decoder_resp.op = OP_MFC0;
                    decoder_resp.rd = rt;
                end
                5'b00100: begin
                    decoder_resp.op  = OP_MTC0;
                    decoder_resp.rs1 = rt;
                end
                5'b10000: begin
                    unique case(instr[5:0])
                        `ifdef COMPILE_FULL_M
                        6'b000001: decoder_resp.op = OP_TLBR;
                        6'b000010: decoder_resp.op = OP_TLBWI;
                        6'b000110: decoder_resp.op = OP_TLBWR;
                        6'b001000: decoder_resp.op = OP_TLBP;
                        6'b100000: decoder_resp.op = OP_SLL;  // wait
                        `endif
                        6'b011000: decoder_resp.op = OP_ERET;
                        default: decoder_resp.op = OP_INVALID;
                    endcase
                end
                default: decoder_resp.op = OP_INVALID;
            endcase
        end

`ifdef FPU_ENABLED
        6'b110101: begin
            decoder_resp.op      = OP_LDC1A;
            decoder_resp.rs1     = rs;
            decoder_resp.fd      = ft;
            decoder_resp.fpu_we  = 1'b1;
            decoder_resp.is_load = 1'b1;
            decoder_resp.is_fpu  = 1'b1;
        end

        6'b111101: begin
            decoder_resp.op       = OP_SDC1A;
            decoder_resp.rs1      = rs;
            decoder_resp.fs2      = ft;
            decoder_resp.is_store = 1'b1;
            decoder_resp.is_fpu   = 1'b1;
        end

        6'b110001: begin
            decoder_resp.op      = OP_LWC1;
            decoder_resp.rs1     = rs;
            decoder_resp.fd      = ft;
            decoder_resp.fpu_we  = 1'b1;
            decoder_resp.is_load = 1'b1;
            decoder_resp.is_fpu  = 1'b1;
        end

        6'b111001: begin
            decoder_resp.op       = OP_SWC1;
            decoder_resp.rs1      = rs;
            decoder_resp.fs2      = ft;
            decoder_resp.is_store = 1'b1;
            decoder_resp.is_fpu   = 1'b1;
        end

        6'b010001: begin  // COP1
            decoder_resp.is_fpu = 1'b1;
            unique case(instr[25:21])
                5'b00000: begin
                    decoder_resp.op  = OP_MFC1;
                    decoder_resp.rd  = rt;
                    decoder_resp.fs1 = instr[15:11];
                end
                5'b00010: begin
                    decoder_resp.op  = OP_CFC1;
                    decoder_resp.rd  = rt;
                end
                5'b00100: begin
                    decoder_resp.op  = OP_MTC1;
                    decoder_resp.rs1 = rt;
                    decoder_resp.fd  = instr[15:11];
                    decoder_resp.fpu_we = 1'b1;
                end
                5'b00110: begin
                    decoder_resp.op  = OP_CTC1;
                    decoder_resp.rs1 = rt;
                    decoder_resp.fcsr_we = 1'b1;
                end
                5'b01000: begin
                    decoder_resp.op  = OP_BC1;
                    decoder_resp.is_controlflow = 1'b1;
                end
                5'b10000: begin // fmt = S
                    decoder_resp.fs1 = fs;
                    decoder_resp.fs2 = ft;
                    decoder_resp.fd  = fd;
                    decoder_resp.fpu_we  = 1'b1;
                    decoder_resp.fcsr_we = 1'b1;
                    decoder_resp.is_fpu_multicyc = 1'b1;
                    unique casez(instr[5:0])
                        6'b000000: decoder_resp.op = OP_FPU_ADD;
                        6'b000001: decoder_resp.op = OP_FPU_SUB;
                        6'b000010: decoder_resp.op = OP_FPU_MUL;
                        6'b000011: decoder_resp.op = OP_FPU_DIV;
                        6'b000100: decoder_resp.op = OP_FPU_SQRT;
                        6'b000101: decoder_resp.op = OP_FPU_ABS;
                        6'b000111: decoder_resp.op = OP_FPU_NEG;
                        6'b001100: decoder_resp.op = OP_FPU_ROUND;
                        6'b001101: decoder_resp.op = OP_FPU_TRUNC;
                        6'b001110: decoder_resp.op = OP_FPU_CEIL;
                        6'b001111: decoder_resp.op = OP_FPU_FLOOR;
                        6'b100100: decoder_resp.op = OP_FPU_CVTW;
                        6'b000110: begin
                            decoder_resp.op = OP_FPU_MOV;
                            decoder_resp.is_fpu_multicyc = 1'b0;
                        end
                        6'b010001: begin
                            decoder_resp.op = OP_FPU_CMOV;
                            decoder_resp.fs2 = '0;
                            decoder_resp.is_fpu_multicyc = 1'b0;
                        end
                        6'b01001?: begin
                            decoder_resp.op = OP_FPU_CMOV;
                            decoder_resp.rs2 = rt;
                            decoder_resp.fs2 = '0;
                            decoder_resp.is_fpu_multicyc = 1'b0;
                        end
                        6'b11????: begin
                            decoder_resp.op = OP_FPU_COND;
                            decoder_resp.fd = '0;
                            decoder_resp.fpu_we = 1'b0;
                        end
                        default: begin
                            decoder_resp.op = OP_INVALID;
                            decoder_resp.fcsr_we = 1'b0;
                            decoder_resp.fpu_we  = 1'b0;
                            decoder_resp.is_fpu_multicyc = 1'b0;
                        end
                    endcase
                end
                5'b10100: begin // fmt = W
                    decoder_resp.fs1 = fs;
                    decoder_resp.fs2 = ft;
                    decoder_resp.fd  = fd;
                    decoder_resp.fpu_we  = 1'b1;
                    decoder_resp.fcsr_we = 1'b1;
                    decoder_resp.is_fpu_multicyc = 1'b1;
                    unique casez(instr[5:0])
                        6'b100000: decoder_resp.op = OP_FPU_CVTS;
                        default: begin
                            decoder_resp.op = OP_INVALID;
                            decoder_resp.fcsr_we = 1'b0;
                            decoder_resp.fpu_we  = 1'b0;
                            decoder_resp.is_fpu_multicyc = 1'b0;
                        end
                    endcase
                end
                default: decoder_resp.op = OP_INVALID;
            endcase
        end
`endif

`ifdef ASIC_ENABLED
        6'b010010: begin // COP2
            unique case(instr[25:21])
                5'b00000: begin
                    decoder_resp.op = OP_MFC2;
                    decoder_resp.rd = rt;
                end
                5'b00100: begin
                    decoder_resp.op  = OP_MTC2;
                    decoder_resp.rs1 = rt;
                end
                default: decoder_resp.op = OP_INVALID;
            endcase
        end
`endif

        default: decoder_resp.op = OP_INVALID;
    endcase
end
endmodule
