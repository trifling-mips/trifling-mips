`ifndef TOMASULO_STRUCT_SVH
`define TOMASULO_STRUCT_SVH

/*
	This header defines struct of tomasulo
*/

// common defs
`include "cpu_defs.svh"

// reservation station struct
typedef struct packed {
	logic busy;
	logic [$clog(`N_RES_STAT) - 1:0] Vj, Vk;
	uint32_t Qj, Qk;
} res_stat;

`define N_RES_STAT_MULDIV	2
typedef struct packed {
	res_stat common;
	logic Op;
} res_stat_muldiv;

`define N_RES_STAT_CAL		3
typedef struct packed {
	res_stat common;
	logic[2:0] Op;
} res_stat_cal;

`define N_RES_STAT_LS		3
typedef struct packed {
	res_stat common;
	logic Op;
	uint32_t A;
} res_stat_ls;

`define N_RES_STAT		(`N_RES_STAT_MULDIV + `N_RES_STAT_CAL + `N_RES_STAT_LS)

// gpr struct
`define N_REG			32
typedef struct packed {
	logic [$clog(`N_RES_STAT) - 1:0] Qi;
	uint32_t value;
} gpr_entry;

// cdb entry interface
interface cdb_entry (

);
	logic [$clog(`N_RES_STAT) - 1:0] label;
	uint32_t data;
	logic valid;

	modport master (
		output label, data, valid;
	);

	modport slave (
		input label, data, valid;
	);

endinterface

`endif
