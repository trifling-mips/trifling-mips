// except
`include "inst_exec.svh"

module except #(
    parameter   N_ISSUE     =   1
) (
    // external signals
    input   logic   rst,
    // exception (not sync)
    input   pipe_id_t[N_ISSUE-1:0]      pipe_id,
    input   pipe_ex_t[N_ISSUE-1:0]      pipe_ex,
    // cp0 regs & interrupt_req
    input  cp0_regs_t   cp0_regs,
    input  logic [7:0]  interrupt_req,
    // except_req
    output except_req_t except_req
);

logic interrupt_occur, pipe_id_valid_concat;
always_comb begin
    pipe_id_valid_concat = 1'b0;
    for (int i = 0; i < N_ISSUE; ++i)
        pipe_id_valid_concat |= pipe_id[i].valid;
end
assign interrupt_occur = (
    // TODO: check whether DM bit in debug is zero
    cp0_regs.status.ie
    && ~cp0_regs.status.exl
    && ~cp0_regs.status.erl
    && interrupt_req != 8'b0
    && pipe_id_valid_concat
    `ifdef FPU_ENABLED
    && ~(pipe_ex[0].exception.op == OP_LDC1B || pipe_ex[0].exception.op == OP_SDC1B)
    `endif
);

logic tlb_refill;
`ifdef COMPILE_FULL_M
assign tlb_refill = pipe_ex[0].exception.valid ? pipe_ex[0].exception.tlb_refill : pipe_ex[1].exception.tlb_refill;
`else
assign tlb_refill = 1'b0;
`endif
assign except_req.eret = pipe_ex[0].exception.eret;
always_comb begin
    if (interrupt_occur) begin
        except_req.valid = 1'b1;
        except_req.code  = EXCCODE_INT;
        except_req.extra = '0;
        except_req.pc    = pipe_ex[0].exception.pc;
        except_req.delayslot   = 1'b0;
    end else begin
        except_req.valid = pipe_ex[0].exception.valid | except_req.eret;
        except_req.code  = pipe_ex[0].exception.exc_code;
        except_req.extra = pipe_ex[0].exception.extra;
        except_req.pc    = pipe_ex[0].exception.pc;
        except_req.delayslot   = pipe_ex[0].exception.delayslot;
    end

    except_req.valid &= ~rst;

    if (except_req.eret) begin
        if(cp0_regs.status.erl)
            except_req.except_vec = cp0_regs.error_epc;
        else except_req.except_vec = cp0_regs.epc;
    end else begin
        logic [11:0] offset;
        if (cp0_regs.status.exl == 1'b0) begin
            `ifdef COMPILE_FULL_M
            if(tlb_refill && (except_req.code == EXCCODE_TLBL || except_req.code == EXCCODE_TLBS))
                offset = 12'h000;
            else 
            `endif
            if(except_req.code == EXCCODE_INT && cp0_regs.cause.iv)
                offset = 12'h200;
            else offset = 12'h180;
        end else begin
            offset = 12'h180;
        end

        if(cp0_regs.status.bev)
            except_req.except_vec = 32'hbfc00200 + offset;
        else except_req.except_vec = { cp0_regs.ebase[31:12], offset };
    end
end

endmodule
