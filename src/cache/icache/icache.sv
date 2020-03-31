// i$ for inst cache
`include "icache.svh"

module icache #(
	parameter	DATA_WIDTH	=	32,		// single issue
	parameter	LINE_WIDTH	=	256,
	parameter	SET_ASSOC	=	4,
	parameter	CACHE_SIZE	=	16 * 1024 * 8,
	parameter	ARID		=	0
) (
	// external signals
	input	logic	clk,
	input	logic	rst,
	// invalidation requests
	input	logic			inv_icache,
	input	logic	[31:0]	inv_addr,
	// CPU signals
	cpu_ibus_if.slave	ibus,
	// AXI3 signals
	axi3_rd_if.master	axi3_rd_if
);

localparam int unsigned LINE_NUM	= CACHE_SIZE / LINE_WIDTH;
localparam int unsigned GROUP_NUM   = LINE_NUM / SET_ASSOC;
localparam int unsigned DATA_PER_LINE = LINE_WIDTH / DATA_WIDTH;
localparam int unsigned DATA_BYTE_OFFSET = $clog2(DATA_WIDTH / 8);
localparam int unsigned LINE_BYTE_OFFSET = $clog2(LINE_WIDTH / 8);
localparam int unsigned INDEX_WIDTH = $clog2(GROUP_NUM);
localparam int unsigned TAG_WIDTH   = $bits(phys_t) - INDEX_WIDTH - LINE_BYTE_OFFSET;
localparam int unsigned LABEL_WIDTH = INDEX_WIDTH + TAG_WIDTH;

// define all data structs & funcs
`DEF_STRUCT_TAG_T
`DEF_STRUCT_INDEX_T
`DEF_STRUCT_LABEL_T
`DEF_STRUCT_OFFSET_T
`DEF_STRUCT_LINE_T
`DEF_FUNC_GET_TAG
`DEF_FUNC_GET_INDEX
`DEF_FUNC_GET_LABEL
`DEF_FUNC_GET_OFFSET

// stage 1(before pipe 1)
index_t stage1_tag_raddr;
// pipe 1(tag access)
// ram req for tag
tag_t [SET_ASSOC - 1:0] pipe1_tag_rdata1, pipe1_tag_rdata2;
// status reg
logic pipe1_read;
phys_t pipe1_addr;
// index invalidation signals
logic pipe1_inv;
index_t pipe1_inv_index;
// repl
logic [GROUP_NUM - 1:0][$clog2(SET_ASSOC) - 1:0] pipe1_repl_index;
// prefetch
label_t pipe1_sb_label_o;
logic [LINE_WIDTH - 1:0] pipe1_sb_line;
logic pipe1_sb_line_vld;
// stage 2(pipe 1 - 2)
// state
icache_state_t stage2_state, stage2_state_n;
// invalidate counter, only use after rst
index_t stage2_inv_cnt, stage2_inv_cnt_n;
// check cache miss
phys_t stage2_addr_plus1;
logic stage2_inv_rtag1, stage2_inv_rtag2;
logic stage2_cache_miss, stage2_cache_miss_plus1;
logic [SET_ASSOC-1:0] stage2_hit, stage2_hit_plus1;
logic stage2_prefetch_hit, stage2_prefetch_hit_plus1;
// ram req for tag
tag_t stage2_tag_wdata;
logic [SET_ASSOC - 1:0] stage2_tag_we;
// ram req for data
line_t stage2_data_wdata;
logic [SET_ASSOC-1:0] stage2_data_we;
index_t stage2_data_raddr, stage2_ram_waddr;
// repl
logic [$clog2(SET_ASSOC) - 1:0] stage2_assoc_waddr, stage2_repl_index_waddr;
// prefetch
label_t stage2_sb_label_i;
logic stage2_sb_label_i_rdy;
// pipe 2(data access)
// ram req for tag & data
logic [SET_ASSOC-1:0] pipe2_hit;
line_t [SET_ASSOC-1:0] pipe2_data_rdata;
phys_t pipe2_addr;
logic pipe2_data_rdata_vld;
// stage 3(pipe 2 - 3)
logic [DATA_WIDTH - 1:0] stage3_data_rdata;
// pipe 3(result drive)
logic [DATA_WIDTH - 1:0] pipe3_data_rdata;
logic pipe3_data_rdata_vld;

// stage 1
assign stage1_tag_raddr = get_index(ibus.addr);

// pipe 1
always_ff @ (posedge clk) begin
	if (rst) begin
		pipe1_addr <= '0;
		pipe1_read <= 1'b0;
		pipe1_inv  <= 1'b0;
		pipe1_inv_index <= '0;
	end else if (~ibus.stall) begin
		// data before pipe1 has been updated to next pipe
		pipe1_addr <= ibus.addr;
		pipe1_read <= ibus.read & ~ibus.flush_1;
		pipe1_inv  <= inv_icache;
		pipe1_inv_index <= get_index(inv_addr);
	end
end

// stage 2
// stage 2 stream_buffer for cache_prefetch
// for data_vld will delay one period, maybe try to modify it.
// define interface
// inst stream_buffer
stream_buffer #(
	.LINE_WIDTH(LINE_WIDTH),
	.ARID(ARID)
) icache_prefetch (
	.label_i(stage2_sb_label_i),
	.label_i_rdy(stage2_sb_label_i_rdy),
	.label_o(pipe1_sb_label_o),
	.data(pipe1_sb_line),
	.data_vld(pipe1_sb_line_vld),
	.*
);
// check cache_miss
for(genvar i = 0; i < SET_ASSOC; ++i) begin : gen_icache_hit
	assign stage2_hit[i] = pipe1_tag_rdata1[i].valid & (get_tag(pipe1_addr) == pipe1_tag_rdata1[i].tag);
end
assign stage2_cache_miss = ~(|stage2_hit) & pipe1_read;
assign stage2_prefetch_hit = (pipe1_sb_label_o == get_label(pipe1_addr)) & pipe1_read;
// next line
assign stage2_addr_plus1 = pipe1_addr + (1'b1 << LINE_BYTE_OFFSET);
for(genvar i = 0; i < SET_ASSOC; ++i) begin : gen_icache_hit_plus1
	assign stage2_hit_plus1[i] = pipe1_tag_rdata2[i].valid & (get_tag(stage2_addr_plus1) == pipe1_tag_rdata2[i].tag);
end
assign stage2_cache_miss_plus1 = ~(|stage2_hit_plus1) & pipe1_read & ~stage2_inv_rtag2;		// after tag write, inv rtag2
assign stage2_prefetch_hit_plus1 = (pipe1_sb_label_o == get_label(stage2_addr_plus1)) & pipe1_read;
// repl
assign stage2_repl_index_waddr = pipe1_repl_index[get_index(pipe1_addr)];
always_comb begin
	stage2_assoc_waddr = stage2_repl_index_waddr;
	for(int i = 0; i < SET_ASSOC; ++i) begin
		if(~pipe1_tag_rdata1[i].valid) stage2_assoc_waddr = i;	// ibus.stall still 1
	end
end
// state
always_comb begin
	stage2_state_n = stage2_state;
	unique case (stage2_state)
		ICACHE_IDLE:
			if (~stage2_cache_miss) begin
				// cache hit
				stage2_state_n = ICACHE_IDLE;
			end else if (~stage2_prefetch_hit) begin
				// none hit, start a new req
				// BOOT_ADDR cannot be 00000000
				stage2_state_n = ICACHE_WAIT_COMMIT;
			end else if (~pipe1_sb_line_vld) begin
				// prefetch hit, on transfering
				stage2_state_n = ICACHE_FETCH;
			end else if (~stage2_inv_rtag1) begin
				// prefetch hit, move line_data
				stage2_state_n = ICACHE_PREFETCH_LOAD;
			end
		ICACHE_WAIT_COMMIT: begin
			if (pipe1_sb_label_o == get_label(pipe1_addr)) begin
				// req accept
				stage2_state_n = ICACHE_FETCH;
			end

			if (ibus.flush_2) stage2_state_n = ICACHE_IDLE;
		end
		ICACHE_FETCH: begin
			if (pipe1_sb_line_vld) begin
				// fetch complete
				stage2_state_n = ICACHE_IDLE;
			end

			if (ibus.flush_2) stage2_state_n = ICACHE_IDLE;
		end
		ICACHE_PREFETCH_LOAD: stage2_state_n = ICACHE_IDLE;
		ICACHE_INVALIDATING:
			if(&stage2_inv_cnt) stage2_state_n = ICACHE_IDLE;
	endcase
end
// prefetch signals
always_comb begin
	stage2_sb_label_i = '0;
	stage2_sb_label_i_rdy = 1'b0;
	case (stage2_state)
		ICACHE_IDLE:
			if (stage2_cache_miss && ~stage2_prefetch_hit) begin
				// fetch
				stage2_sb_label_i = get_label(pipe1_addr);
				stage2_sb_label_i_rdy = 1'b1;
			end else if (stage2_cache_miss_plus1 & ~stage2_prefetch_hit_plus1) begin
				// prefetch, not check whether sb is busy(ignore)
				stage2_sb_label_i = get_label(pipe1_addr) + 1;
				stage2_sb_label_i_rdy = 1'b1;
			end
		ICACHE_WAIT_COMMIT:
			if (pipe1_sb_label_o == get_label(pipe1_addr)) begin
				// sb has accept req
			end else begin
				// fetch
				stage2_sb_label_i = get_label(pipe1_addr);
				stage2_sb_label_i_rdy = 1'b1;
			end
	endcase
end
// ram req for tag & data
assign stage2_tag_wdata.valid = stage2_state != ICACHE_INVALIDATING && ~pipe1_inv;
assign stage2_tag_wdata.tag   = get_tag(pipe1_addr);
assign stage2_data_wdata      = pipe1_sb_line;
assign stage2_data_raddr      = get_index(pipe1_addr);
always_comb begin
	stage2_tag_we    = '0;
	stage2_ram_waddr = get_index(ibus.addr) + 1;		// fetch line_plus1
	stage2_data_we   = '0;

	stage2_inv_cnt_n   = '0;
	case (stage2_state)
		ICACHE_FETCH:
			if (pipe1_sb_line_vld) begin
				// fetch complete
				stage2_tag_we[stage2_assoc_waddr] = 1'b1;
				stage2_data_we[stage2_assoc_waddr] = 1'b1;
				stage2_ram_waddr = get_index(pipe1_addr);
			end
		ICACHE_PREFETCH_LOAD: begin
			stage2_tag_we[stage2_assoc_waddr] = 1'b1;
			stage2_data_we[stage2_assoc_waddr] = 1'b1;
		end
		ICACHE_INVALIDATING: begin
			stage2_inv_cnt_n = stage2_inv_cnt + 1;
			stage2_tag_we    = '1;
			stage2_ram_waddr = stage2_inv_cnt;
		end
	endcase

	// inv
	if(pipe1_inv) begin
		stage2_tag_we    = '1;
		stage2_ram_waddr = pipe1_inv_index;
	end
end
// invalidate counter, only use after rst & state
always_ff @ (posedge clk) begin
	if (rst) begin
		stage2_state     <= ICACHE_INVALIDATING;
		stage2_inv_cnt   <= '0;
		stage2_inv_rtag1 <= '0;
		stage2_inv_rtag2 <= '0;
	end else begin
		stage2_state     <= stage2_state_n;
		stage2_inv_cnt   <= stage2_inv_cnt_n;
		stage2_inv_rtag1 <= |stage2_tag_we;		// if we write tag ram, inv next rtag1
		stage2_inv_rtag2 <= |stage2_tag_we;		// if we write tag ram, inv next rtag2
	end
end
// pipe 2(data access)
always_ff @ (posedge clk) begin
	if (rst) begin
		pipe2_data_rdata_vld <= '0;
	end else begin
		// pipe has been stall at pipe1
		pipe2_addr           <= pipe1_addr;
		pipe2_hit            <= stage2_hit;		// after fetch, should not hit
		pipe2_data_rdata_vld <= pipe1_read & ~ibus.flush_2 & ~ibus.stall;		// stall pipe 1 -> 2
	end
end
// stage 3(pipe 2 - 3)
always_comb begin
	stage3_data_rdata = '0;
	for(int i = 0; i < SET_ASSOC; ++i) begin
		stage3_data_rdata |= {DATA_WIDTH{pipe2_hit[i]}} & pipe2_data_rdata[i][get_offset(pipe2_addr)];
	end

	if (~|pipe2_hit) stage3_data_rdata = stage2_data_wdata[get_offset(pipe2_addr)];		// sb_line hold 2 period
end
// pipe 3(result drive)
always_ff @ (posedge clk) begin
	if (rst) begin
		pipe3_data_rdata_vld <= 1'b0;
	end else begin
		// pipe has been stall at pipe1
		pipe3_data_rdata_vld <= pipe2_data_rdata_vld & ~ibus.flush_3;		// not stall pipe 2 -> 3
		pipe3_data_rdata     <= stage3_data_rdata;
	end
end

// ibus control signals
assign ibus.stall = (stage2_state_n != ICACHE_IDLE) && pipe1_read || (stage2_state == ICACHE_INVALIDATING);
assign ibus.ready = stage2_state != ICACHE_INVALIDATING;
// ibus data signals
assign ibus.rddata = pipe3_data_rdata;
assign ibus.rddata_vld = pipe3_data_rdata_vld;

// generate block RAMs
for(genvar i = 0; i < SET_ASSOC; ++i) begin : gen_icache_mem
	dual_port_lutram #(
		.SIZE(GROUP_NUM),
		.dtype(tag_t)
	) mem_tag (
		.clk,
		.rst,

		.ena	(1'b1					),
		.wea	(stage2_tag_we[i]		),
		.addra	(stage2_ram_waddr		),
		.dina	(stage2_tag_wdata		),
		.douta	(pipe1_tag_rdata2[i]	),

		.enb	(1'b1					),
		.addrb	(stage1_tag_raddr		),
		.doutb	(pipe1_tag_rdata1[i]	)
	);

	dual_port_ram #(
		.SIZE(GROUP_NUM),
		.dtype(line_t)
	) mem_data (
		.clk,
		.rst,

		.ena	(1'b1					),
		.wea	(stage2_data_we[i]		),
		.addra	(stage2_ram_waddr		),
		.dina	(stage2_data_wdata		),
		.douta	(						),

		.enb	(1'b1					),
		.web	(1'b0					),
		.addrb	(stage2_data_raddr		),
		.dinb	(						),
		.doutb	(pipe2_data_rdata[i]	)
	);
end

// generate PLRU
for(genvar i = 0; i < GROUP_NUM; ++i) begin: gen_plru
	plru #(
		.SET_ASSOC (SET_ASSOC)
	) plru_inst (
		.clk,
		.rst,
		.access		(stage2_hit),
		.update		((~ibus.stall) && (~pipe1_inv) && i[INDEX_WIDTH-1:0] == get_index(pipe1_addr)),
		.repl_index	(pipe1_repl_index[i])
	);
end

endmodule
