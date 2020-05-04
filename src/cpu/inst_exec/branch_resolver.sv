// branch resolver
`include "inst_exec.svh"

module branch_resolver #(

) (
    // regs data
    input   uint32_t    reg0,
    input   uint32_t    reg1,
    // pipe_id
    input   pipe_id_t   pipe_id,
    // branch_resolved
    output branch_resolved_t    resolved_branch
);

/* resolve branch */
logic reg_equal;
assign reg_equal  = (reg0 == reg1);

assign resolved_branch.valid   = pipe_id.valid & pipe_id.decode_resp.is_controlflow;

always_comb begin
    unique case (pipe_id.decode_resp.op)
        OP_BLTZ, OP_BLTZAL: resolved_branch.taken = reg0[31];
        OP_BGEZ, OP_BGEZAL: resolved_branch.taken = ~reg0[31];
        OP_BEQ:  resolved_branch.taken = reg_equal;
        OP_BNE:  resolved_branch.taken = ~reg_equal;
        OP_BLEZ: resolved_branch.taken = reg_equal | reg0[31];
        OP_BGTZ: resolved_branch.taken = ~reg_equal & ~reg0[31];
        OP_JAL, OP_JALR: resolved_branch.taken = 1'b1;

        `ifdef FPU_ENABLED
        OP_BC1: resolved_branch.taken = fcc_match;
        `endif

        default: resolved_branch.taken = 1'b0;
    endcase

    unique case (pipe_id.decode_resp.op)
        `ifdef FPU_ENABLED
        OP_BC1,
        `endif

        OP_BLTZ, OP_BLTZAL, OP_BGEZ, OP_BGEZAL,
        OP_BEQ,  OP_BNE,    OP_BLEZ, OP_BGTZ: begin
            resolved_branch.target = pipe_id.decode_resp.default_jump_i;
        end
        OP_JAL:  begin
            resolved_branch.target = pipe_id.decode_resp.default_jump_j;
        end
        OP_JALR: begin
            resolved_branch.target = reg0;
        end
        default: begin
            resolved_branch.target     = '0;
        end
    endcase
end

endmodule
