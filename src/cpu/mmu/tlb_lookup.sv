// tlb lookup
`include "mmu.svh"

module tlb_lookup #(
    parameter   N_TLB_ENTRIES   =   32
) (
    // from tlb entries
    input   tlb_entry_t [N_TLB_ENTRIES - 1:0]   entries,
    // tlb_lookup req
    input   virt_t          vaddr,
    input   logic   [7:0]   asid,
    // tlb_lookup resp
    output  tlb_resp_t      resp
);

logic [$clog2(N_TLB_ENTRIES) - 1:0] matched_index;
logic [N_TLB_ENTRIES - 1:0] matched;
tlb_entry_t matched_entry;
logic matched_sel;

assign matched_entry = entries[matched_index];
assign matched_sel   = (vaddr[24:12] & {matched_entry.mask, 1'b1}) != (vaddr[24:12] & {1'b0, matched_entry.mask});

for (genvar i = 0; i < N_TLB_ENTRIES; ++i) begin : gen_tlb_lookup_matched
    assign matched[i] = ((vaddr[31:13] & ~entries[i].mask) == (entries[i].vpn2 & ~entries[i].mask)) && (entries[i].G || entries[i].asid == asid);
end

always_comb begin
    matched_index = '0;
    for (int i = N_TLB_ENTRIES; i >= 0; --i)
        if (matched[i]) matched_index = i;
end

// set output
assign resp.miss        = (matched == '0);
assign resp.index       = matched_index;
assign resp.paddr[11:0] = vaddr[11:0];
always_comb begin
    if (matched_sel) begin
        resp.dirty        = matched_entry.d1;
		resp.valid        = matched_entry.v1;
		resp.cache_flag   = matched_entry.c1;
		resp.paddr[31:12] = matched_entry.pfn1[19:0];
    end else begin
        resp.dirty        = matched_entry.d0;
		resp.valid        = matched_entry.v0;
		resp.cache_flag   = matched_entry.c0;
		resp.paddr[31:12] = matched_entry.pfn0[19:0];
    end
end

endmodule

