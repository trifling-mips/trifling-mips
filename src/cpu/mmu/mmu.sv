// mmu(memory map unit)
`include "mmu.svh"

module mmu #(
    // parameter for ctrl
    parameter   MMU_ENABLED =   1,
    // parameter for cfg
    parameter   N_ISSUE     =   1,   // temp support single-issue
    parameter   N_TLB_ENTRIES   =   32
) (
    // external signals
    input   logic           clk,
    input   logic           rst,
    // from cp0
    input   logic   [7:0]   asid,
    input   logic           kseg0_uncached,
    input   logic           is_user_mode,
    // for inst
    input   virt_t          inst_vaddr,
    output  mmu_resp_t      inst_resp,
    // for data
    input   virt_t      [N_ISSUE - 1:0] data_vaddr,
    output  mmu_resp_t  [N_ISSUE - 1:0] data_resp,
    // for TLBR/TLBWI/TLBWR
    input   tlb_index_t     tlbrw_index,
    input   logic           tlbrw_we,
    input   tlb_entry_t     tlbrw_wrdata,
    output  tlb_entry_t     tlbrw_rddata,
    // for TLBP
    input   uint32_t        tlbp_entry_hi,
    output  uint32_t        tlbp_index
);

// define funcs
`define DEF_FUNC_IS_VADDR_MAPPED
`define DEF_FUNC_IS_VADDR_UNCACHED

generate if (MMU_ENABLED) begin : gen_mmu_enabled_code
    logic inst_mapped;
    logic [N_ISSUE - 1:0] data_mapped;
    tlb_resp_t inst_tlb_resp;
    tlb_resp_t [N_ISSUE - 1:0] data_tlb_resp;

    assign inst_mapped        = is_vaddr_mapped(inst_vaddr);
    assign inst_resp.miss     = (inst_mapped & inst_tlb_result.miss);
    assign inst_resp.illegal  = (is_user_mode & inst_vaddr[31]);
    assign inst_resp.inv      = (inst_mapped & ~inst_tlb_resp.valid);
    assign inst_resp.uncached = is_vaddr_uncached(inst_vaddr);
    assign inst_resp.paddr    = inst_mapped ? inst_tlb_resp.paddr : {3'b0, inst_vaddr[28:0]};
    assign inst_resp.vaddr    = inst_vaddr;

    // note that dirty = 1 when writable
    for (genvar i = 0; i < N_ISSUE; ++i) begin : gen_data_resp
        assign data_mapped[i]        = is_vaddr_mapped(data_vaddr[i]);
        assign data_resp[i].uncached = is_vaddr_uncached(data_vaddr[i]) | (data_mapped[i] && data_tlb_resp[i].cache_flag == 3'd2);
        assign data_resp[i].dirty    = (~data_mapped[i] | data_tlb_resp[i].dirty);
        assign data_resp[i].miss     = (data_mapped[i] & data_tlb_resp[i].miss);
        assign data_resp[i].illegal  = (is_user_mode & data_vaddr[i][31]);
        assign data_resp[i].inv      = (data_mapped[i] & ~data_tlb_resp[i].valid);
        assign data_resp[i].paddr    = data_mapped[i] ? data_tlb_resp[i].paddr : {3'b0, data_vaddr[i][28:0]};
        assign data_resp[i].vaddr    = data_vaddr[i];
    end

    // inst tlb
    tlb #(
        .N_ISSUE(N_ISSUE),
        .N_TLB_ENTRIES(N_TLB_ENTRIES)
    ) tlb_inst (
        .clk,
        .rst,
        .asid,
        .inst_vaddr,
        .inst_resp(inst_tlb_resp),
        .data_vaddr,
        .data_resp(data_tlb_resp),
        .tlbrw_index,
        .tlbrw_we,
        .tlbrw_wrdata,
        .tlbrw_rddata,
        .tlbp_entry_hi,
        .tlbp_index
    );
end else begin : gen_mmu_disabled_code
    always_comb begin
        inst_resp = '0;
        inst_resp.dirty = 1'b0;
        inst_resp.paddr = {3'b0, inst_vaddr[28:0]};
        for (int i = 0; i < N_ISSUE; ++i) begin
            data_resp[i] = '0;
            data_resp[i].dirty    = 1'b1;
            data_resp[i].uncached = is_vaddr_uncached(data_vaddr[i]);
            data_resp[i].paddr    = {3'b0, data_vaddr[i][28:0]};
        end
    end
end endgenerate

endmodule

