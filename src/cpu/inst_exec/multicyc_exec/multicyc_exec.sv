// multicyc_exec
`include "multicyc_exec.svh"

module multicyc_exec #(
    // local parameter
    localparam int DIV_CYC = 36,
    localparam int MUL_CYC = 1
) (
    // external signals
    input   logic   clk,
    input   logic   rst,
    // multicyc_req & multicyc_resp
    input   multicyc_req_t  multicyc_req,
    output  multicyc_resp_t multicyc_resp
);

// record multicyc_req
multicyc_req_t pipe_multicyc_req;
// state
me_state_t state, state_n;
// hilo
uint64_t hilo_o, hilo_ret;

// update state_n
logic data_ready;
always_comb begin
    state_n = state;
    unique case (state)
        ME_IDLE:   if (multicyc_req.is_multicyc) state_n = ME_WAIT;
        ME_WAIT:   if (data_ready) state_n = ME_IDLE;
    endcase
end
// update state
always_ff @ (posedge clk) begin
    if (rst)
        state <= ME_IDLE;
    else
        state <= state_n;
end
// update hilo_o
always_ff @ (posedge clk) begin
    if (rst) begin
        hilo_o <= '0;
    end else if (state == ME_WAIT) begin
        hilo_o <= hilo_ret;
    end
end

/* read operands */
// pipe_multicyc_req conclude reg0, reg1, op, hilo
always_ff @(posedge clk) begin
    if(rst) begin
        pipe_multicyc_req <= '0;
    end else if (state == ME_IDLE) begin
        pipe_multicyc_req <= multicyc_req;
    end
end

/* cycle control */
logic [DIV_CYC:0] cyc_stage, cyc_stage_n;
// update cyc_stage_n
always_comb begin
    unique case (state)
        ME_IDLE: begin
            unique case (multicyc_req.op)
                 `ifdef COMPILE_FULL_M
                OP_MADD, OP_MADDU, OP_MSUB, OP_MSUBU, OP_MUL,
                `endif
                OP_MULT, OP_MULTU:
                    cyc_stage_n = 1 << MUL_CYC;
                OP_DIV, OP_DIVU:
                    cyc_stage_n = 1 << DIV_CYC;
                OP_MTHI, OP_MTLO:
                    cyc_stage_n = 1;
                default:
                    cyc_stage_n = '0;
            endcase
        end
        ME_WAIT: cyc_stage_n = cyc_stage >> 1;
        default: cyc_stage_n = '0;
    endcase
end
// update cyc_stage
always_ff @ (posedge clk) begin
    if (rst)
        cyc_stage <= 0;
    else
        cyc_stage <= cyc_stage_n;
end
// set data_ready
assign data_ready = cyc_stage[0];

/* signed setting */
logic is_signed, negate_result;
assign is_signed = (
    `ifdef COMPILE_FULL_M
    pipe_multicyc_req.op == OP_MADD ||
    pipe_multicyc_req.op == OP_MSUB ||
    pipe_multicyc_req.op == OP_MUL  ||
    `endif
    pipe_multicyc_req.op == OP_MULT ||
    pipe_multicyc_req.op == OP_DIV
);
// calculate mul
assign negate_result = is_signed && (pipe_multicyc_req.reg0[31] ^ pipe_multicyc_req.reg1[31]);
uint32_t abs_reg0, abs_reg1;
assign abs_reg0 = (is_signed && pipe_multicyc_req.reg0[31]) ? -pipe_multicyc_req.reg0 : pipe_multicyc_req.reg0;
assign abs_reg1 = (is_signed && pipe_multicyc_req.reg1[31]) ? -pipe_multicyc_req.reg1 : pipe_multicyc_req.reg1;
// pipe absmul
uint64_t pipe_absmul;
always_ff @ (posedge clk) begin
    if(rst) begin
        pipe_absmul <= '0;
    end else begin
        pipe_absmul <= abs_reg0 * abs_reg1;
    end
end
/* multiply(stage 1) */
uint64_t mul_result;
assign mul_result = negate_result ? -pipe_absmul : pipe_absmul;

/* division */
uint32_t abs_quotient, abs_remainder;
uint32_t div_quotient, div_remainder;

/* Note that the document of MIPS32 says if the divisor is zero,
 * the result is UNDEFINED. */
div_uu #(
    .z_width(64)
) div_uu_inst (
    .clk,
    .ena(pipe_multicyc_req.op == OP_DIV || pipe_multicyc_req.op == OP_DIVU),
    .z( { 32'b0, abs_reg0 } ),
    .d(abs_reg1),
    .q(abs_quotient),
    .s(abs_remainder),
    .div0(),
    .ovf()
);

/* |b| = |aq| + |r|
 *   1) b > 0, a < 0 ---> b = (-a)(-q) + r
 *   2) b < 0, a > 0 ---> -b = a(-q) + (-r) */
assign div_quotient  = negate_result ? -abs_quotient : abs_quotient;
assign div_remainder = (is_signed && (pipe_multicyc_req.reg0[31] ^ abs_remainder[31])) ? -abs_remainder : abs_remainder;

/* set result */
always_comb begin
    unique case (pipe_multicyc_req.op)
        `ifdef COMPILE_FULL_M
        OP_MADDU, OP_MADD: hilo_ret = pipe_multicyc_req.hilo + mul_result;
        OP_MSUBU, OP_MSUB: hilo_ret = pipe_multicyc_req.hilo - mul_result;
        `endif

        OP_MULT, OP_MULTU: hilo_ret = mul_result;
        OP_DIV, OP_DIVU: hilo_ret = { div_remainder, div_quotient };
        OP_MTLO: hilo_ret = { pipe_multicyc_req.hilo[63:32], pipe_multicyc_req.reg0 };
        OP_MTHI: hilo_ret = { pipe_multicyc_req.reg0, pipe_multicyc_req.hilo[31:0]  };
        default: hilo_ret = pipe_multicyc_req.hilo;
    endcase
end

// set multicyc_resp.ready
assign multicyc_resp.ready = state_n == ME_IDLE;
// set multicyc_resp
assign multicyc_resp.valid = multicyc_resp.ready && pipe_multicyc_req.is_multicyc;
assign multicyc_resp.hilo  = hilo_ret;

endmodule
