`ifndef COMPILE_OPTIONS_SVH
`define COMPILE_OPTIONS_SVH

/**
	Options to control optional components to be compiled
	These options are used to speed up compilation when debugging
**/

// can change value
// num of LSU resv
`define N_RESV_LSU	3

// can undefine
// whether enable victim cache in write_buffer
`define VICTIM_CACHE_ENABLE

// cannot change
// enable axi3 interface
`define AXI3_IF_EN

`endif
