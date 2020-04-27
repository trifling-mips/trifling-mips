// decode branch
`include "decode.svh"

module decode_branch #(

) (
    input   uint32_t    inst,
    output  logic       is_branch,
    output  logic       is_return,
    output  logic       is_call,
    output  logic       is_jump_r,
    output  logic       is_jump_i
);

logic [5:0] opcode;
// get opcode
assign opcode = inst[31:26];

assign is_jump_r = (opcode == 6'b0 && inst[5:1] == 5'b00100);
assign is_jump_i = (opcode[5:1] == 5'b00001);       // J, JAL
assign is_branch = (
    // BEQ (000100), BNE (000101), BLEZ (000110), BGTZ (000111)
    opcode[5:2] == 4'b0001
    // BLTZ (00000), BGEZ (00001), BLTZAL (10000), BGEZAL (10001)
    || opcode == 6'b000001 && inst[19:17] == 3'b0
    `ifdef FPU_ENABLED
        || opcode == 6'b010001 && inst[25:21] == 5'b01000 && ~inst[17]
    `endif
);
assign is_call   = (
    is_jump_r && (inst[15:11] == 5'd31)                 // JALR reg, $31
    || opcode == 6'b000011                              // JAL
    || opcode == 6'b000001 && inst[20:17] == 4'b1000    // BLTZAL, BGEZAL
);
assign is_return = (
    inst[31:21] == 11'b000000_11111 && inst[5:0] == 6'b001000   // JR $31
    || is_jump_r && inst[25:21] == 5'd31                        // JALR $31, reg
);

endmodule
