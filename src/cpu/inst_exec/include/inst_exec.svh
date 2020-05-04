`ifndef INST_EXEC_SVH
`define INST_EXEC_SVH

/*
    This header defines common data structrue & constants in inst_exec module
*/

// cpu defs
`include "cpu_defs.svh"

// funcs
`define DEF_FUNC_LOAD_SEL function uint32_t load_sel( \
    input uint32_t dcache_rddata, \
    input virt_t vaddr, \
    oper_t op \
); \
    logic[1:0] vaddr_offset; \
    uint8_t dcache_rddata_b; \
    uint16_t dcache_rddata_h; \
    uint32_t dcache_rddata_bs, dcache_rddata_bu, dcache_rddata_hs, dcache_rddata_hu; \
    uint32_t rddata; \
 \
    vaddr_offset     = vaddr[1:0]; \
    dcache_rddata_b  = dcache_rddata >> ($bits(uint8_t) * vaddr_offset); \
    dcache_rddata_h  = dcache_rddata >> ($bits(uint8_t) * vaddr_offset); \
    dcache_rddata_bs = {{$bits(uint32_t)-$bits(uint8_t){dcache_rddata_b[$bits(uint8_t)-1]}}, dcache_rddata_b}; \
    dcache_rddata_bu = {{$bits(uint32_t)-$bits(uint8_t){1'b0}}, dcache_rddata_b}; \
    dcache_rddata_hs = {{$bits(uint32_t)-$bits(uint16_t){dcache_rddata_h[$bits(uint16_t)-1]}}, dcache_rddata_h}; \
    dcache_rddata_hu = {{$bits(uint32_t)-$bits(uint16_t){1'b0}}, dcache_rddata_h}; \
 \
    rddata = ( \
        {$bits(uint32_t){(op == OP_LW)}} & dcache_rddata \
        | {$bits(uint32_t){(op == OP_LH)}} & dcache_rddata_hs \
        | {$bits(uint32_t){(op == OP_LHU)}} & dcache_rddata_hu \
        | {$bits(uint32_t){(op == OP_LB)}} & dcache_rddata_bs \
        | {$bits(uint32_t){(op == OP_LBU)}} & dcache_rddata_bu \
    ); \
    return rddata; \
 \
endfunction

`endif
