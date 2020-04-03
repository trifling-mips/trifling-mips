// d$ for data cache
`include "dcache.svh"

module dcache #(
	parameter	BUS_WIDTH		=	4,
	parameter	DATA_WIDTH		=	32, 
	parameter	LINE_WIDTH		=	256, 
	parameter	SET_ASSOC		=	4,
	parameter	CACHE_SIZE		=	16 * 1024 * 8,
	parameter	WB_LINE_DEPTH	=	8,
	parameter	AID				=	1,
	// parameter for dcache_pass
	parameter	PASS_DATA_DEPTH	=	8,
	parameter	PASS_AID		=	2
) (
	// external signals
	input	logic	clk,
	input	logic	rst,
	// CPU signals
	cpu_dbus_if.slave	dbus,
	// AXI signals
	// cached
	axi3_rd_if.master	axi3_rd_if,
	axi3_wr_if.master	axi3_wr_if,
	// uncached
	axi3_rd_if.master	axi3_rd_if_uncached,
	axi3_wr_if.master	axi3_wr_if_uncached
);

localparam int unsigned LINE_NUM    = CACHE_SIZE / LINE_WIDTH;
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
`DEF_FUNC_MUX_BE
`DEF_FUNC_MUX_TAG

// stage 1(before pipe 1)
index_t stage1_tag_raddr;
// pipe 1(tag access)
// dbus req
lsu_req pipe1_req;
logic pipe1_inv;
// ram req for tag, tag_rdata1 -> curr_addr's tag, tag_rdata2 -> plus1'tag
tag_t [SET_ASSOC - 1:0] pipe1_tag_rdata1, pipe1_tag_rdata2;
// repl
logic [GROUP_NUM - 1:0][$clog2(SET_ASSOC) - 1:0] pipe1_repl_index;
// prefetch
label_t pipe1_sb_label_o;
logic [LINE_WIDTH - 1:0] pipe1_sb_line;
logic pipe1_sb_line_vld, pipe1_sb_label_o_vld;
// dcache_pass, should be stage2
logic pipe1_dp_full;
// write_buffer
logic pipe1_wb_full;
// forward stage2_tag_wdata
tag_t pipe1_tag_wdata;
logic [SET_ASSOC - 1:0] pipe1_tag_we;
label_t pipe1_tag_wlabel;
// stage 2(pipe 1 - 2)
// state
dcache_state_t stage2_state, stage2_state_n;
// for inv & refill
logic [$clog2(SET_ASSOC)-1:0] stage2_assoc_cnt, stage2_assoc_cnt_n;
// invalidate counter, only use after rst
index_t stage2_inv_cnt, stage2_inv_cnt_n;
// check cache miss
phys_t stage2_addr_plus1;
logic stage2_inv_rtag2;
logic stage2_cache_miss, stage2_cache_miss_plus1, stage2_wtag_last;
logic [SET_ASSOC-1:0] stage2_hit_rd, stage2_hit_fr, stage2_hit, stage2_hit_plus1;
logic stage2_prefetch_hit, stage2_prefetch_hit_plus1;
// ram req for tag
index_t stage2_tag_waddr;
tag_t stage2_tag_wdata;
tag_t [SET_ASSOC - 1:0] stage2_tag_rdata1, stage2_tag_rdata1_n, stage2_tag_mux, stage2_tag_mux_n, stage2_tag_mux_r, stage2_tag_mux_r_n;
logic [SET_ASSOC - 1:0] stage2_tag_we;
logic stage2_assoc_pushed, stage2_need_push, stage2_need_push_n;
// ram req for data
index_t stage2_data_raddr;
// repl
logic [$clog2(SET_ASSOC) - 1:0] stage2_assoc_waddr, stage2_repl_index_waddr;
// prefetch
label_t stage2_sb_label_i;
logic stage2_sb_label_i_rdy;
// dcache_pass
lsu_req stage2_dp_req;
logic stage2_dp_push;
// write_buffer
logic stage2_wb_push, stage2_wb_pushed, stage2_wb_query_found, stage2_wb_query_on_pop;
label_t stage2_wb_plabel, stage2_wb_query_label;
line_t stage2_wb_pdata;
logic [LINE_WIDTH / DATA_WIDTH - 1:0][DATA_WIDTH - 1:0] stage2_wb_query_rdata, stage2_wb_query_wdata;
logic [LINE_WIDTH / DATA_WIDTH - 1:0][DATA_WIDTH / $bits(uint8_t) - 1:0] stage2_wb_query_wbe;
logic stage2_wb_write, stage2_wb_written, stage2_wb_query_found_wb, stage2_wb_clear;
// line_recv, buffer for prefetch & wb_fifo
logic [LINE_WIDTH / DATA_WIDTH - 1:0][DATA_WIDTH - 1:0] stage2_line_recv, stage2_line_recv_n;
// pipe 2(data access)
// ram req for tag & data
logic [SET_ASSOC-1:0] pipe2_hit, pipe2_hit_n;
line_t [SET_ASSOC-1:0] pipe2_data_rdata;
// wb_query
logic [LINE_WIDTH / DATA_WIDTH - 1:0][DATA_WIDTH - 1:0] pipe2_wb_query_rdata;
logic pipe2_wb_query_found_non_pop;		// for pipe2_req.write
// uncached & read in lsu_req unused
lsu_req pipe2_req ,pipe2_req_n;
logic pipe2_rm_wr, pipe2_rm_wr_n;
// stage 3(pipe 2 - 3)
logic [LINE_WIDTH / DATA_WIDTH - 1:0][DATA_WIDTH - 1:0] stage3_data_ram, stage3_data_mux, stage3_data_wdata;
logic [DATA_WIDTH - 1:0] stage3_data_rdata;
logic [SET_ASSOC-1:0] stage3_data_we;
index_t stage3_data_waddr;
label_t stage3_data_wlabel;
// pipe 3(result drive)
lsu_resp pipe3_resp;
// dcache_pass
lsu_resp pipe3_dp_resp;
// record last write
logic pipe3_data_write;
label_t pipe3_data_wlabel;
line_t pipe3_data_wdata;

// stage 1(before pipe 1)
assign stage1_tag_raddr = get_index(dbus.lsu_req.addr);

// pipe 1(tag access)
always_ff @ (posedge clk) begin
	if (rst) begin
		// dbus req
		pipe1_inv <= 1'b0;
		pipe1_req <= '0;
	end else if (~dbus.stall) begin
		// data before pipe1 has been updated to next pipe
		// dbus req
		pipe1_inv <= dbus.inv_dcache;
		pipe1_req <= dbus.lsu_req;
	end
end

// stage 2(pipe 1 - 2)
// stage 2 stream_buffer for cache_prefetch
// for data_vld will delay one period, maybe try to modify it.
// define interface
// inst stream_buffer
stream_buffer #(
	.LINE_WIDTH(LINE_WIDTH),
	.ARID(AID)
) icache_prefetch (
	.label_i(stage2_sb_label_i),
	.label_i_rdy(stage2_sb_label_i_rdy),
	.inv(pipe1_inv),
	.label_o(pipe1_sb_label_o),
	.label_o_vld(pipe1_sb_label_o_vld),
	.data(pipe1_sb_line),
	.data_vld(pipe1_sb_line_vld),
	.*
);
// stage 2 dcache_pass for uncached req
dcache_pass #(
	.DATA_WIDTH(DATA_WIDTH),
	.ARID(PASS_AID),
	.AWID(PASS_AID),
	.DATA_DEPTH(PASS_DATA_DEPTH)
) dcache_pass_inst (
	.axi3_rd_if			(axi3_rd_if_uncached),
	.axi3_wr_if			(axi3_wr_if_uncached),
	.lsu_uncached_req	(stage2_dp_req		),
	.push				(stage2_dp_push		),
	.full				(pipe1_dp_full		),
	.lsu_uncached_resp	(pipe3_dp_resp		),		// uncached load donot use be
	.*
);
// stage 2 write_buffer for cache_wb
write_buffer #(
	.LINE_WIDTH(LINE_WIDTH),
	`ifdef VICTIM_CACHE_ENABLE
	.LINE_DEPTH(WB_LINE_DEPTH),
	`endif
	.AWID(AID)
) write_buffer_inst (
	.pline			({stage2_wb_plabel, stage2_wb_pdata}),
	.full			(pipe1_wb_full						),
	.push			(stage2_wb_push						),
	.pushed			(stage2_wb_pushed					),
	.query_label	(stage2_wb_query_label				),
	.query_found	(stage2_wb_query_found				),
	.query_on_pop	(stage2_wb_query_on_pop				),
	.query_wdata	(stage2_wb_query_wdata				),
	.query_rdata	(stage2_wb_query_rdata				),
	.query_wbe		(stage2_wb_query_wbe				),
	.write			(stage2_wb_write					),
	.written		(stage2_wb_written					),
	.query_found_wb	(stage2_wb_query_found_wb			),
	.clear			(stage2_wb_clear					),
	.*
);
// write_buffer
assign stage2_wb_query_wdata = pipe1_req.wrdata;
assign stage2_wb_query_wbe   = pipe1_req.be;
assign stage2_wb_query_label = get_label(pipe1_req.addr);
// not always write, only hit & non_pop can write, if cache hit both write
assign stage2_wb_write       = pipe1_req.write & (stage2_wb_query_found & ~stage2_wb_query_on_pop);
// check cache_miss
// addr's tag was written in last period
assign stage2_wtag_last = (get_label(pipe1_req.addr) == pipe1_tag_wlabel);
// hit from rddata
for (genvar i = 0; i < SET_ASSOC; ++i) begin : gen_dcache_hit_rd
	assign stage2_hit_rd[i] = pipe1_tag_rdata1[i].valid & (get_tag(pipe1_req.addr) == pipe1_tag_rdata1[i].tag);
end
// hit from forward
assign stage2_hit_fr = pipe1_tag_we & {SET_ASSOC{(pipe1_tag_wdata.valid & stage2_wtag_last)}};
assign stage2_hit = stage2_hit_rd | stage2_hit_fr;
assign stage2_cache_miss = ~(|stage2_hit) & ((pipe1_req.read | pipe1_req.write) & ~pipe1_req.uncached);
assign stage2_prefetch_hit = (pipe1_sb_label_o == get_label(pipe1_req.addr) && pipe1_sb_label_o_vld) & ((pipe1_req.read | pipe1_req.write) & ~pipe1_req.uncached);
// next line
assign stage2_addr_plus1 = pipe1_req.addr + (1'b1 << LINE_BYTE_OFFSET);
for (genvar i = 0; i < SET_ASSOC; ++i) begin : gen_dcache_hit_plus1
	assign stage2_hit_plus1[i] = pipe1_tag_rdata2[i].valid & (get_tag(stage2_addr_plus1) == pipe1_tag_rdata2[i].tag);
end
assign stage2_cache_miss_plus1 = ~(|stage2_hit_plus1) & ((pipe1_req.read | pipe1_req.write) & ~pipe1_req.uncached) & ~stage2_inv_rtag2;		// after tag write, inv rtag2
assign stage2_prefetch_hit_plus1 = (pipe1_sb_label_o == get_label(stage2_addr_plus1) && pipe1_sb_label_o_vld) & ((pipe1_req.read | pipe1_req.write) & ~pipe1_req.uncached);
// repl
assign stage2_repl_index_waddr = pipe1_repl_index[get_index(pipe1_req.addr)];
always_comb begin
	stage2_assoc_waddr = stage2_repl_index_waddr;
	for (int i = 0; i < SET_ASSOC; ++i) begin
		// if last period write tag, for we use lut store tag, do matter, pipe1_tag_rdata1 is not updated, use stage2_tag_mux
		if (~stage2_tag_mux[i].valid) stage2_assoc_waddr = i;
	end
end
// state
always_comb begin
	stage2_state_n = stage2_state;
	case (stage2_state)
		DCACHE_IDLE: begin
			// none hit, start a new req
			if (stage2_cache_miss && (~stage2_prefetch_hit || ~pipe1_sb_line_vld)) stage2_state_n = DCACHE_FETCH;
			// prefetch hit, move line_data
			if (stage2_cache_miss && stage2_prefetch_hit && pipe1_sb_line_vld) stage2_state_n = DCACHE_PREFETCH_LOAD;
			// found in wb on pop / found on wb
			if (stage2_cache_miss && (stage2_wb_query_found_wb || stage2_wb_query_on_pop)) stage2_state_n = DCACHE_WAIT_WB;
			// uncached req && dp is full
			if (pipe1_req.uncached && ~(stage2_dp_push && pipe1_dp_full)) stage2_state_n = DCACHE_WAIT_UNCACHED;
			// inv dcache
			if (pipe1_inv) stage2_state_n = DCACHE_INVALIDATING;
		end
		DCACHE_FETCH: begin
			// fetch complete && wb_line pused
			if (pipe1_sb_line_vld && stage2_prefetch_hit && stage2_assoc_pushed) stage2_state_n = DCACHE_IDLE;
			// fetch complete && wb_line not pused
			if (pipe1_sb_line_vld && stage2_prefetch_hit && ~stage2_assoc_pushed) stage2_state_n = DCACHE_WAIT_WB;
		end
		DCACHE_WAIT_UNCACHED:
			// uncached_req pushed, when wait_uncached always setup stage2_dp_push
			if (~(stage2_dp_push && pipe1_dp_full)) stage2_state_n = DCACHE_IDLE;
		DCACHE_WAIT_WB:
			// wb_line pushed, when pushed need wtag & wdata
			if (stage2_assoc_pushed) stage2_state_n = DCACHE_IDLE;
		DCACHE_PREFETCH_LOAD:
			// prefetch hit && wb_line not pused
			if (~stage2_assoc_pushed) stage2_state_n = DCACHE_WAIT_WB;
			// no need wait one period for last write(both need stage3_data_we)
			// stage3_data_we is set in DCACHE_PREFETCH_LOAD, stage3 flow
			else stage2_state_n = DCACHE_IDLE;
		DCACHE_INVALIDATING:
			// all assoc pushed, confirm wb
			if (&stage2_assoc_cnt && ~(stage2_wb_push && pipe1_wb_full)) stage2_state_n = DCACHE_WAIT_INVALIDATING;
		DCACHE_WAIT_INVALIDATING:
			// all clear
			if (stage2_wb_clear) stage2_state_n = DCACHE_IDLE;
		DCACHE_RESET: if (&stage2_inv_cnt) stage2_state_n = DCACHE_IDLE;
	endcase
end
// prefetch signals
always_comb begin
	stage2_sb_label_i = '0;
	stage2_sb_label_i_rdy = 1'b0;
	case (stage2_state)
		DCACHE_IDLE:
			if (stage2_cache_miss && ~stage2_prefetch_hit) begin
				// fetch
				stage2_sb_label_i = get_label(pipe1_req.addr);
				stage2_sb_label_i_rdy = 1'b1;
			end else if (stage2_cache_miss_plus1 & ~stage2_prefetch_hit_plus1) begin
				// prefetch, not check whether sb is busy(ignore)
				stage2_sb_label_i = get_label(pipe1_req.addr) + 1;
				stage2_sb_label_i_rdy = 1'b1;
			end
		DCACHE_FETCH:
			if (~stage2_prefetch_hit) begin
				// fetch
				stage2_sb_label_i = get_label(pipe1_req.addr);
				stage2_sb_label_i_rdy = 1'b1;
			end
	endcase
end
// uncached_req
assign stage2_dp_req = pipe1_req;
assign stage2_dp_push = (pipe1_req.read | pipe1_req.write) & pipe1_req.uncached;
// data req
assign stage2_data_raddr = get_index(pipe1_req.addr);
// ram req for tag
assign stage2_tag_wdata.dirty = pipe1_req.write;
assign stage2_tag_wdata.valid = (stage2_state != DCACHE_INVALIDATING) && (stage2_state != DCACHE_RESET);
assign stage2_tag_wdata.tag   = get_tag(pipe1_req.addr);
assign stage2_assoc_pushed    = ~stage2_need_push || ~(stage2_wb_push && pipe1_wb_full);
// mux pipe1_tag_rdata1 & pipe1_tag_wdata
assign stage2_tag_mux   = (stage2_state == DCACHE_IDLE) ? stage2_tag_mux_n : stage2_tag_mux_r;
assign stage2_tag_mux_n = mux_tag(pipe1_tag_rdata1, pipe1_tag_wdata, {SET_ASSOC{stage2_wtag_last}} & pipe1_tag_we);
always_ff @ (posedge clk) begin
	if (rst) begin
		stage2_tag_mux_r <= '0;
	end else begin
		stage2_tag_mux_r <= stage2_tag_mux_r_n;
	end
end
always_comb begin
	stage2_tag_rdata1_n = stage2_tag_rdata1;
	stage2_need_push_n  = stage2_need_push;
	stage2_tag_mux_r_n  = stage2_tag_mux_r;

	stage2_wb_push      = 1'b0;
	stage2_wb_plabel    = {stage2_tag_rdata1[stage2_assoc_waddr].tag, get_index(pipe1_req.addr)};
	stage2_wb_pdata     = pipe2_data_rdata[stage2_assoc_waddr];
	case (stage2_state)
		DCACHE_IDLE: begin
			// should cause fetch / prefetch_load / wait_wb, maybe need wb
			// ~stage2_inv_rtag1 avoid wtag because of right after fetch, old rtag looks non_hit, but new will hit
			// cannot push now, for pipe2_data_rdata is not valid
			if (stage2_cache_miss && ~(stage2_wb_query_found && ~stage2_wb_query_on_pop) && ~pipe1_req.uncached && ~pipe1_inv) begin
				// if last period write tag, for we use lut store tag, do matter, pipe1_tag_rdata1 is not updated, use stage2_tag_mux
				stage2_need_push_n  = stage2_tag_mux[stage2_assoc_waddr].valid && stage2_tag_mux[stage2_assoc_waddr].dirty;
				stage2_tag_rdata1_n = stage2_tag_mux;
				stage2_tag_mux_r_n  = stage2_tag_mux_n;
			end
			// inv need wb all assoc way
			if (pipe1_inv) begin
				stage2_tag_rdata1_n = stage2_tag_mux;
				stage2_tag_mux_r_n  = stage2_tag_mux_n;
			end
		end
		DCACHE_FETCH, DCACHE_PREFETCH_LOAD, DCACHE_WAIT_WB: begin
			if (stage2_need_push) stage2_wb_push   = 1'b1;
			// when data_rddata, this line is on write
			if (stage2_wb_plabel == pipe3_data_wlabel && pipe3_data_write) stage2_wb_pdata = pipe3_data_wdata;
			// if stage 3 write this line, forward stage3_data_wdata(last one prepare to write this line)
			if (stage2_wb_plabel == get_label(pipe2_req.addr) && pipe2_req.write) stage2_wb_pdata = stage3_data_wdata;
			if (~(stage2_wb_push && pipe1_wb_full)) stage2_need_push_n = 1'b0;
		end
		DCACHE_INVALIDATING: begin
			stage2_wb_push      = stage2_tag_rdata1[stage2_assoc_cnt].valid && stage2_tag_rdata1[stage2_assoc_cnt].dirty;
			stage2_wb_plabel    = {stage2_tag_rdata1[stage2_assoc_cnt].tag, get_index(pipe1_req.addr)};
			stage2_wb_pdata     = pipe2_data_rdata[stage2_assoc_cnt];
			// only first period of inv, can cause data-collision of pipe2_data_rdata
			if (~|stage2_assoc_cnt && (stage2_wb_plabel == pipe3_data_wlabel && pipe3_data_write)) stage2_wb_pdata = pipe3_data_wdata;
			// if stage 3 write this line, forward stage3_data_wdata
			if (~|stage2_assoc_cnt && (stage2_wb_plabel == get_label(pipe2_req.addr) && pipe2_req.write)) stage2_wb_pdata = stage3_data_wdata;
		end
	endcase
end
// when stall pipeline, record stage2_tag_mux && stage2_need_push
always_ff @ (posedge clk) begin
	if (rst) begin
		stage2_tag_rdata1 <= '0;
		stage2_need_push  <= 1'b0;
	end else begin
		stage2_tag_rdata1 <= stage2_tag_rdata1_n;
		stage2_need_push  <= stage2_need_push_n;
	end
end
// stage2_line_recv
always_comb begin
	stage2_line_recv_n = stage2_line_recv;
	case (stage2_state)
		DCACHE_IDLE: begin
			// prefetch hit, move line_data, even prefetch hit, data maybe too old
			if (stage2_cache_miss && stage2_prefetch_hit && pipe1_sb_line_vld) stage2_line_recv_n = pipe1_sb_line;
			// found in wb found_on_wb / wb_on_pop, newest
			if (stage2_cache_miss && (stage2_wb_query_found_wb || stage2_wb_query_on_pop)) stage2_line_recv_n = stage2_wb_query_rdata;
		end
	endcase
end
always_ff @ (posedge clk) begin
	if (rst) begin
		stage2_line_recv <= '0;
	end else begin
		stage2_line_recv <= stage2_line_recv_n;
	end
end
// ram we
always_comb begin
	stage2_tag_we      = '0;
	stage2_tag_waddr   = get_index(dbus.lsu_req.addr) + 1;	// fetch line_plus1
	stage3_data_we     = '0;
	stage3_data_waddr  = '0;
	stage3_data_wdata  = stage3_data_mux;					// normal write
	stage3_data_wlabel = '0;

	pipe2_hit_n        = stage2_hit;

	stage2_inv_cnt_n   = stage2_inv_cnt;
	stage2_assoc_cnt_n = stage2_assoc_cnt;
	case (stage2_state)
		DCACHE_IDLE: begin
			if (pipe1_inv) stage2_assoc_cnt_n = '0;
			// normal write
			if (|pipe2_hit && pipe2_req.write) begin
				stage3_data_we     = pipe2_hit;
				stage3_data_waddr  = get_index(pipe2_req.addr);
				stage3_data_wlabel = get_label(pipe2_req.addr);
				stage3_data_wdata[get_offset(pipe2_req.addr)] = mux_be(
					stage3_data_wdata[get_offset(pipe2_req.addr)],
					pipe2_req.wrdata,
					pipe2_req.be
				);
			end
			// normal write
			if (|stage2_hit && pipe1_req.write) begin
				stage2_tag_we      = stage2_hit;
				stage2_tag_waddr   = get_index(pipe1_req.addr);
			end
		end
		DCACHE_FETCH:
			if (pipe1_sb_line_vld && stage2_prefetch_hit && stage2_assoc_pushed) begin
				stage3_data_we[stage2_assoc_waddr] = 1'b1;
				stage3_data_waddr  = get_index(pipe1_req.addr);
				stage3_data_wlabel = get_label(pipe1_req.addr);
				stage3_data_wdata  = pipe1_sb_line;
				stage2_tag_we[stage2_assoc_waddr] = 1'b1;
				stage2_tag_waddr   = get_index(pipe1_req.addr);
				pipe2_hit_n[stage2_assoc_waddr]   = 1'b1;
			end
		DCACHE_PREFETCH_LOAD, DCACHE_WAIT_WB:
			if (stage2_assoc_pushed) begin
				stage3_data_we[stage2_assoc_waddr] = 1'b1;
				stage3_data_waddr  = get_index(pipe1_req.addr);
				stage3_data_wlabel = get_label(pipe1_req.addr);
				stage3_data_wdata  = stage2_line_recv;
				stage2_tag_we[stage2_assoc_waddr] = 1'b1;
				stage2_tag_waddr   = get_index(pipe1_req.addr);
				pipe2_hit_n[stage2_assoc_waddr]   = 1'b1;
			end
		DCACHE_RESET: begin
			stage2_inv_cnt_n = stage2_inv_cnt + 1;
			stage2_tag_we    = '1;
			stage2_tag_waddr = stage2_inv_cnt;
		end
		DCACHE_INVALIDATING: begin
			pipe2_hit_n      = '0;
			stage2_tag_waddr = get_index(pipe1_req.addr);
			if (~(stage2_wb_push && pipe1_wb_full)) begin
				stage2_tag_we[stage2_assoc_cnt] = 1'b1;
				stage2_assoc_cnt_n = stage2_assoc_cnt + 1;
			end
		end
	endcase
end
// stage2_ff
always_ff @ (posedge clk) begin
	if (rst) begin
		stage2_state     <= DCACHE_RESET;
		stage2_inv_cnt   <= '0;
		stage2_assoc_cnt <= '0;
		stage2_inv_rtag2 <= 1'b0;
		// forward stage2_tag_wdata
		pipe1_tag_wdata     <= '0;
		pipe1_tag_we        <= '0;
		pipe1_tag_wlabel    <= '0;
	end else begin
		stage2_state     <= stage2_state_n;
		stage2_inv_cnt   <= stage2_inv_cnt_n;
		stage2_assoc_cnt <= stage2_assoc_cnt_n;
		// if stage2_inv_rtag1 is 1, stage2_cache_miss should occur
		stage2_inv_rtag2 <= |stage2_tag_we;
		// forward stage2_tag_wdata
		pipe1_tag_wdata     <= stage2_tag_wdata;
		pipe1_tag_we        <= stage2_tag_we;
		pipe1_tag_wlabel    <= {stage2_tag_wdata.tag, get_index(pipe1_req.addr)};
	end
end
// pipe 2(data access)
always_comb begin
	pipe2_req_n    = pipe1_req;
	pipe2_rm_wr_n  = pipe1_inv;		// if not record inv, use 1'b0
	// cache miss, but wb hit & can write, no need write cache
	if (~|stage2_hit && stage2_wb_write) begin
		pipe2_req_n.write = 1'b0;
		pipe2_rm_wr_n     = 1'b1;
	end
	if (pipe1_req.uncached) begin
		pipe2_req_n.read  = 1'b0;
		pipe2_req_n.write = 1'b0;
	end
end
always_ff @ (posedge clk) begin
	if (rst || dbus.stall) begin		// stall pipe 1 -> 2
		pipe2_hit   <= '0;
		pipe2_req   <= '0;
		pipe2_rm_wr <= 1'b0;
	end else begin
		pipe2_hit   <= pipe2_hit_n;
		pipe2_req   <= pipe2_req_n;
		pipe2_rm_wr <= pipe2_rm_wr_n;
	end
end
// wb_query
always_ff @ (posedge clk) begin
	if (rst) begin
		pipe2_wb_query_rdata <= '0;
		pipe2_wb_query_found_non_pop <= 1'b0;
	end else begin
		pipe2_wb_query_rdata <= stage2_wb_query_rdata;
		// if query_on_pop, should fetch this line from wb
		// used in stage3_data_mux
		pipe2_wb_query_found_non_pop <= stage2_wb_query_found & ~stage2_wb_query_on_pop;
	end
end
// stage 3(pipe 2 - 3)
always_comb begin
	stage3_data_ram = '0;
	for (int i = 0; i < SET_ASSOC; ++i)
		stage3_data_ram |= {LINE_WIDTH{pipe2_hit[i]}} & pipe2_data_rdata[i];
end
always_comb begin
	stage3_data_mux = stage3_data_ram;
	// if found in wb & pipe2_hit is 0000, cache should hold newest data
	if (pipe2_wb_query_found_non_pop & ~|pipe2_hit) stage3_data_mux = pipe2_wb_query_rdata;
	// if write this one last period, means stage3_data_ram is xxxxxxxx
	if (get_label(pipe2_req.addr) == pipe3_data_wlabel && pipe3_data_write) stage3_data_mux = pipe3_data_wdata;
end
assign stage3_data_rdata = stage3_data_mux[get_offset(pipe2_req.addr)];
// pipe 3(result drive)
always_ff @ (posedge clk) begin
	if (rst) begin
		pipe3_resp <= '0;
	end else begin
		pipe3_resp.lsu_idx    <= pipe2_req.lsu_idx;
		pipe3_resp.rddata     <= stage3_data_rdata;
		pipe3_resp.rddata_vld <= (pipe2_req.read | pipe2_req.write) | pipe2_rm_wr;
	end
end
// record last write
always_ff @ (posedge clk) begin
	if (rst) begin
		pipe3_data_write  <= 1'b0;
		pipe3_data_wlabel <= '0;
		pipe3_data_wdata  <= '0;
	end else begin
		pipe3_data_write  <= |stage3_data_we;
		pipe3_data_wlabel <= stage3_data_wlabel;
		pipe3_data_wdata  <= stage3_data_wdata;
	end
end

// dbus control signals
assign dbus.stall = stage2_state_n != DCACHE_IDLE;
// dbus resp signals
assign dbus.lsu_resp          = pipe3_resp;
assign dbus.lsu_uncached_resp = pipe3_dp_resp;

// generate block RAMs
for (genvar i = 0; i < SET_ASSOC; ++i) begin : gen_icache_mem
	dual_port_lutram #(
		.SIZE(GROUP_NUM),
		.dtype(tag_t)
	) mem_tag (
		.clk,
		.rst,

		.ena	(1'b1					),
		.wea	(stage2_tag_we[i]		),
		.addra	(stage2_tag_waddr		),
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
		.wea	(stage3_data_we[i]		),
		.addra	(stage3_data_waddr		),
		.dina	(stage3_data_wdata		),
		.douta	(						),

		.enb	(1'b1					),
		.web	(1'b0					),
		.addrb	(stage2_data_raddr		),
		.dinb	(						),
		.doutb	(pipe2_data_rdata[i]	)
	);
end

// generate PLRU
for (genvar i = 0; i < GROUP_NUM; ++i) begin: gen_plru
	plru #(
		.SET_ASSOC (SET_ASSOC)
	) plru_inst (
		.clk,
		.rst,
		.access		(pipe2_hit_n),		// stage2_hit
		.update		((~dbus.stall) && (~pipe1_inv) && i[INDEX_WIDTH-1:0] == get_index(pipe1_req.addr)),
		.repl_index	(pipe1_repl_index[i])
	);
end

endmodule
