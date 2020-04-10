// tlb
`include "mmu.svh"

module tlb #(
    parameter   N_ISSUE         =   1,
    parameter   N_TLB_ENTRIES   =   32
) (
    // external signals
    input   logic       clk,
    input   logic       rst,
    // from cp0
    input   logic   [7:0]   asid,
    // for inst
    input   virt_t          inst_vaddr,
    output  tlb_resp_t      inst_resp,
    // for data
    input   virt_t      [N_ISSUE - 1:0] data_vaddr,
    output  tlb_resp_t  [N_ISSUE - 1:0] data_resp,
    // for TLBR/TLBWI/TLBWR
    input   tlb_index_t tlbrw_index,
    input   logic       tlbrw_we,
    input   tlb_entry_t tlbrw_wrdata,
    output  tlb_entry_t tlbrw_rddata,
    // for TLBP
    input   uint32_t    tlbp_entry_hi,
    output  uint32_t    tlbp_index
);

tlb_resp_t tlbp_resp;
tlb_entry_t [N_TLB_ENTRIES - 1:0] entries, entries_n;
assign tlbrw_rddata = entries[tlbrw_index];

// update next
generate for (genvar i = 0; i < N_TLB_ENTRIES; ++i) begin : gen_tlb
    always_comb begin
        entries_n[i] = entries[i];
        if (tlbrw_we && (i == tlbrw_index)) entries_n[i] = tlbrw_wrdata;
    end
end endgenerate
// update entries
always_ff @ (posedge clk) begin
    if (rst) begin
        entries <= '0;
    end else begin
        entries <= entries_n;
    end
end

// gen tlb_lookup
// for inst
tlb_lookup #(
    .N_TLB_ENTRIES(N_TLB_ENTRIES)
) inst_lookup (
    .entries,
    .vaddr(inst_vaddr),
    .asid,
    .resp(inst_resp)
);
// for data
for (genvar i = 0; i < N_ISSUE; ++i) begin : gen_data_lookup
    tlb_lookup #(
        .N_TLB_ENTRIES(N_TLB_ENTRIES)
    ) data_lookup (
        .entries,
        .vaddr(data_vaddr[i]),
        .asid,
        .resp(data_resp[i])
    );
end
// for TLBP
tlb_lookup #(
    .N_TLB_ENTRIES(N_TLB_ENTRIES)
) tlbp_lookup (
    .entries,
    .vaddr(tlbp_entry_hi),
    .asid(tlbp_entry_hi[7:0]),      // will rename later
    .resp(tlbp_resp)
);
assign tlbp_index = {
    tlbp_resp.miss,
    {($bits(uint32_t) - $clog2(N_TLB_ENTRIES) - 1){1'b0}},
    tlbp_resp.index
};

endmodule

