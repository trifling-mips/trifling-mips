// d$ for data cache
`include "dcache.svh"

module dcache #(
    parameter   BUS_WIDTH               =   4,
    parameter   DATA_WIDTH              =   32, 
    parameter   LINE_WIDTH              =   256, 
    parameter   SET_ASSOC               =   4,
    parameter   CACHE_SIZE              =   16 * 1024 * 8,
    parameter   VICTIM_CACHE_ENABLED    =   1,
    parameter   WB_LINE_DEPTH           =   8,
    parameter   AID                     =   1,
    // parameter for dcache_pass
    parameter   PASS_DATA_DEPTH         =   8,
    parameter   PASS_AID                =   2
) (
    // external signals
    input   logic   clk,
    input   logic   rst,
    // CPU signals
    cpu_dbus_if.slave   dbus,
    // AXI signals
    // cached
    axi3_rd_if.master   axi3_rd_if,
    axi3_wr_if.master   axi3_wr_if,
    // uncached
    axi3_rd_if.master   axi3_rd_if_uncached,
    axi3_wr_if.master   axi3_wr_if_uncached
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

// stage 0(before pipe 0)
index_t stage0_ram_raddr;
// pipe 0(tag access & data access)
// dcache_req
dcache_req pipe0_req, pipe0_req_n;
// ram req for tag, tag_rdata -> curr_addr's tag, rm prefetch
tag_t [SET_ASSOC - 1:0] pipe0_tag_rddata;
line_t [SET_ASSOC - 1:0] pipe0_data_rddata;
// repl
logic [GROUP_NUM - 1:0][$clog2(SET_ASSOC) - 1:0] pipe0_repl_index;
// prefetch
label_t pipe0_sb_label_o;
logic pipe0_sb_label_o_vld;
logic [LINE_WIDTH - 1:0] pipe0_sb_line;
logic [(LINE_WIDTH / DATA_WIDTH) - 1:0] pipe0_sb_line_vld;
// dcache_pass, should be stage1
logic pipe0_dp_full;
// write_buffer
logic pipe0_wb_full;
// stage 1(pipe 0 - 1)
// state
dcache_state_t stage1_state, stage1_state_n;
// for inv & refill
logic [$clog2(SET_ASSOC)-1:0] stage1_assoc_cnt, stage1_assoc_cnt_n;
// invalidate counter, only use after rst
index_t stage1_inv_cnt, stage1_inv_cnt_n;
// check cache miss
logic stage1_cache_miss;
logic [SET_ASSOC-1:0] stage1_hit_rd, stage1_hit_fr, stage1_hit;
logic stage1_prefetch_hit;
// ram req for tag
index_t stage1_tag_waddr;
tag_t stage1_tag_wrdata;
logic [SET_ASSOC-1:0] stage1_tag_whit;
tag_t [SET_ASSOC - 1:0] stage1_tag_mux, stage1_tag_rddata, stage1_tag_rddata_n;
logic [LINE_WIDTH / DATA_WIDTH - 1:0][DATA_WIDTH - 1:0] stage1_data_mux, stage1_data_ram;
logic [SET_ASSOC - 1:0] stage1_tag_we;
logic stage1_assoc_pushed, stage1_need_push, stage1_need_push_n;
// repl
logic [$clog2(SET_ASSOC) - 1:0] stage1_assoc_waddr, stage1_repl_index_waddr;
// prefetch
label_t stage1_sb_label_i;
logic stage1_sb_label_i_rdy, stage1_sb_inv;
// dcache_pass
dcache_req stage1_dp_req;
logic stage1_dp_push;
// write_buffer
logic stage1_wb_push, stage1_wb_pushed, stage1_wb_query_found, stage1_wb_query_on_pop;
label_t stage1_wb_plabel, stage1_wb_query_label;
line_t stage1_wb_pdata;
logic [LINE_WIDTH / DATA_WIDTH - 1:0][DATA_WIDTH - 1:0] stage1_wb_query_rddata, stage1_wb_query_wrdata;
logic [LINE_WIDTH / DATA_WIDTH - 1:0][DATA_WIDTH / $bits(uint8_t) - 1:0] stage1_wb_query_wbe;
logic stage1_wb_write, stage1_wb_written, stage1_wb_query_found_wb, stage1_wb_clear;
// line_recv, buffer for prefetch & wb_fifo
logic [LINE_WIDTH / DATA_WIDTH - 1:0][DATA_WIDTH - 1:0] stage1_line_recv, stage1_line_recv_n;
// stage 1 resp
dcache_resp stage1_resp, stage1_dp_resp;
// pipe 1(tag update)
// forward stage1_tag_wdata
tag_t pipe1_tag_wrdata;
logic [SET_ASSOC - 1:0] pipe1_tag_we;
index_t pipe1_tag_waddr;
// ram req for tag & data
logic [SET_ASSOC-1:0] pipe1_hit, pipe1_hit_n;
logic [LINE_WIDTH / DATA_WIDTH - 1:0][DATA_WIDTH - 1:0] pipe1_data_rddata;
// uncached & read in dcache_req unused
dcache_req pipe1_req, pipe1_req_n;
// stage 2(pipe 1 - 2)
logic [LINE_WIDTH / DATA_WIDTH - 1:0][DATA_WIDTH - 1:0] stage2_data_wrdata;
logic [SET_ASSOC-1:0] stage2_data_we;
index_t stage2_data_waddr;
label_t stage2_data_wlabel;
// pipe 2(result drive)
// record last write
logic pipe2_data_write;
label_t pipe2_data_wlabel;
line_t pipe2_data_wrdata;

// stage 1(before pipe 1)
assign stage0_ram_raddr = dbus.ready ? get_index(dbus.dcache_req.vaddr) : get_index(dbus.dcache_req.paddr);

// pipe 1(tag access & data access)
always_comb begin
    pipe0_req_n = pipe0_req;
    if (dbus.ready) pipe0_req_n = dbus.dcache_req;
    else pipe0_req_n.paddr = dbus.dcache_req.paddr;
end
// store pipe0_req, pipe0_req.paddr is previous
always_ff @ (posedge clk) begin
    if (rst) begin
        pipe0_req <= '0;
    end else begin
        // data before pipe1 has been updated to next pipe
        pipe0_req <= pipe0_req_n;
    end
end

// stage 1(pipe 0 - 1)
// write_buffer
assign stage1_wb_query_wrdata = pipe0_req.wrdata;
assign stage1_wb_query_wbe    = pipe0_req.be;
assign stage1_wb_query_label  = get_label(dbus.dcache_req.paddr);
// not always write, only hit & non_pop can write, if cache hit both write
assign stage1_wb_write        = pipe0_req.write & (stage1_wb_query_found & ~stage1_wb_query_on_pop);
// check cache_miss
// hit from rddata
for (genvar i = 0; i < SET_ASSOC; ++i) begin : gen_dcache_hit_rd
    assign stage1_hit_rd[i] = pipe0_tag_rddata[i].valid & (get_tag(dbus.dcache_req.paddr) == pipe0_tag_rddata[i].tag);
end
// hit from forward
// addr's tag was written in last period
assign stage1_tag_whit = pipe1_tag_we & {SET_ASSOC{(get_index(dbus.dcache_req.paddr) == pipe1_tag_waddr) & (get_tag(dbus.dcache_req.paddr) == pipe1_tag_wrdata.tag)}};
assign stage1_hit_fr   = {SET_ASSOC{pipe1_tag_wrdata.valid}} & stage1_tag_whit;
assign stage1_hit      = |stage1_tag_whit ? stage1_hit_fr : stage1_hit_rd;
assign stage1_cache_miss = ~(|stage1_hit) & ((pipe0_req.read | pipe0_req.write) & ~dbus.dcache_req.uncached);
assign stage1_prefetch_hit = (pipe0_sb_label_o == get_label(dbus.dcache_req.paddr) & pipe0_sb_label_o_vld) & ((pipe0_req.read | pipe0_req.write) & ~dbus.dcache_req.uncached);
// no prefetch
// repl
assign stage1_repl_index_waddr = pipe0_repl_index[get_index(pipe0_req.vaddr)];
always_comb begin
    stage1_assoc_waddr = stage1_repl_index_waddr;
    for (int i = 0; i < SET_ASSOC; ++i) begin
        // if last period write tag, for we use lut store tag, do matter, pipe1_tag_rdata1 is not updated, use stage2_tag_mux
        if (~stage1_tag_mux[i].valid) stage1_assoc_waddr = i;
    end
end
// data mux
always_comb begin
    stage1_data_ram = '0;
    for (int i = 0; i < SET_ASSOC; ++i)
        stage1_data_ram |= {LINE_WIDTH{stage1_hit[i]}} & pipe0_data_rddata[i];
end
always_comb begin
    stage1_data_mux = stage1_data_ram;
    // if found in wb & pipe2_hit is 0000, cache should hold newest data
    if ((stage1_wb_query_found & ~stage1_wb_query_on_pop) & ~|stage1_hit) stage1_data_mux = stage1_wb_query_rddata;
    // if write this one last period, means stage3_data_ram is xxxxxxxx
    if (get_label(dbus.dcache_req.paddr) == pipe2_data_wlabel && pipe2_data_write) stage1_data_mux = pipe2_data_wrdata;
    // if write this one last period, means stage3_data_ram is xxxxxxxx
    if (get_label(dbus.dcache_req.paddr) == stage2_data_wlabel && |stage2_data_we) stage1_data_mux = stage2_data_wrdata;
end
// state
always_comb begin
    stage1_state_n = stage1_state;
    case (stage1_state)
        DCACHE_IDLE: begin
            // none hit, start a new req
            if (stage1_cache_miss) stage1_state_n = DCACHE_FETCH;
            // found in wb on pop / found on wb
            if (stage1_cache_miss && (stage1_wb_query_found_wb || stage1_wb_query_on_pop)) stage1_state_n = DCACHE_WAIT_WB;
            // uncached load req
            if (dbus.dcache_req.uncached && pipe0_req.read) stage1_state_n = DCACHE_UNCACHED_LOAD;
            // uncached req && dp is full
            if (dbus.dcache_req.uncached && (stage1_dp_push && pipe0_dp_full)) stage1_state_n = DCACHE_WAIT_UNCACHED;
            // inv dcache
            if (pipe0_req.inv) stage1_state_n = DCACHE_INVALIDATING;
        end
        DCACHE_FETCH: begin
            // fetch complete && wb_line pused
            if (&pipe0_sb_line_vld && stage1_prefetch_hit && stage1_assoc_pushed) stage1_state_n = DCACHE_IDLE;
            // fetch complete && wb_line not pused
            if (&pipe0_sb_line_vld && stage1_prefetch_hit && ~stage1_assoc_pushed) stage1_state_n = DCACHE_WAIT_WB;
        end
        DCACHE_UNCACHED_LOAD:
            // only uncached load can set resp.valid as 1, means load complete
            if (stage1_dp_resp.valid) stage1_state_n = DCACHE_IDLE;
        DCACHE_WAIT_UNCACHED: begin
            // uncached_req pushed, when wait_uncached always setup stage2_dp_push
            if (~(stage1_dp_push && pipe0_dp_full) & ~pipe0_req.read) stage1_state_n = DCACHE_IDLE;
            // uncached load req, need wait dp clear
            if (~(stage1_dp_push && pipe0_dp_full) & pipe0_req.read) stage1_state_n = DCACHE_UNCACHED_LOAD;
        end
        DCACHE_WAIT_WB:
            // wb_line pushed, when pushed need wtag & wdata
            if (stage1_assoc_pushed) stage1_state_n = DCACHE_IDLE;
        DCACHE_INVALIDATING:
            // all assoc pushed, confirm wb
            if (&stage1_assoc_cnt && ~(stage1_wb_push && pipe0_wb_full)) stage1_state_n = DCACHE_WAIT_INVALIDATING;
        DCACHE_WAIT_INVALIDATING:
            // all clear
            if (stage1_wb_clear) stage1_state_n = DCACHE_IDLE;
        DCACHE_RESET: if (&stage1_inv_cnt) stage1_state_n = DCACHE_IDLE;
    endcase
end
// prefetch signals
assign stage1_sb_inv = pipe0_req.inv;
always_comb begin
    stage1_sb_label_i = '0;
    stage1_sb_label_i_rdy = 1'b0;
    case (stage1_state)
        DCACHE_IDLE:
            if (stage1_cache_miss && ~stage1_prefetch_hit) begin
                // fetch
                stage1_sb_label_i = get_label(dbus.dcache_req.paddr);
                stage1_sb_label_i_rdy = 1'b1;
            end
            // no prefetch
        DCACHE_FETCH:
            if (~stage1_prefetch_hit) begin
                // fetch
                stage1_sb_label_i = get_label(pipe0_req.paddr);
                stage1_sb_label_i_rdy = 1'b1;
            end
    endcase
end
// uncached_req
always_comb begin
    stage1_dp_req       = pipe0_req;
    stage1_dp_req.paddr = dbus.dcache_req.paddr;
end
// when waiting uncached load to execute, cannot issue push
assign stage1_dp_push = (pipe0_req.read | pipe0_req.write) & dbus.dcache_req.uncached & (stage1_state != DCACHE_UNCACHED_LOAD);
// ram req for tag
assign stage1_tag_wrdata.dirty = pipe0_req.write;
assign stage1_tag_wrdata.valid = (stage1_state != DCACHE_INVALIDATING) && (stage1_state != DCACHE_RESET);
assign stage1_tag_wrdata.tag   = get_tag(dbus.dcache_req.paddr);
assign stage1_assoc_pushed     = ~stage1_need_push || ~(stage1_wb_push && pipe0_wb_full);
// mux pipe0_tag_rddata & pipe1_tag_wrdata
assign stage1_tag_mux   = mux_tag(pipe0_tag_rddata, pipe1_tag_wrdata, stage1_tag_whit);
always_comb begin
    // use stage1_tag_rddata to reduce fanout of stage1_tag_mux
    stage1_tag_rddata_n = stage1_tag_rddata;
    stage1_need_push_n  = stage1_need_push;

    stage1_wb_push      = 1'b0;
    stage1_wb_plabel    = {stage1_tag_rddata[stage1_assoc_waddr].tag, get_index(pipe0_req.paddr)};
    stage1_wb_pdata     = pipe0_data_rddata[stage1_assoc_waddr];
    case (stage1_state)
        DCACHE_IDLE: begin
            // should cause fetch / prefetch_load / wait_wb, maybe need wb
            // ~stage2_inv_rtag1 avoid wtag because of right after fetch, old rtag looks non_hit, but new will hit
            // cannot push now, for pipe2_data_rdata is not valid
            if (stage1_cache_miss && ~(stage1_wb_query_found && ~stage1_wb_query_on_pop) && ~dbus.dcache_req.uncached && ~pipe0_req.inv) begin
                // if last period write tag, for we use lut store tag, do matter, pipe1_tag_rdata1 is not updated, use stage2_tag_mux
                stage1_need_push_n  = stage1_tag_mux[stage1_assoc_waddr].valid && stage1_tag_mux[stage1_assoc_waddr].dirty;
                stage1_tag_rddata_n = stage1_tag_mux;
            end
            // inv need wb all assoc way
            if (pipe0_req.inv) begin
                stage1_tag_rddata_n = stage1_tag_mux;
            end
        end
        DCACHE_FETCH, DCACHE_WAIT_WB: begin
            if (stage1_need_push) stage1_wb_push   = 1'b1;
            // when data_rddata, this line is on write
            if (stage1_wb_plabel == pipe2_data_wlabel && pipe2_data_write) stage1_wb_pdata = pipe2_data_wrdata;
            // if stage 3 write this line, forward stage3_data_wdata(last one prepare to write this line)
            if (stage1_wb_plabel == get_label(pipe1_req.paddr) && pipe1_req.write) stage1_wb_pdata = stage2_data_wrdata;
            if (~(stage1_wb_push && pipe0_wb_full)) stage1_need_push_n = 1'b0;
        end
        DCACHE_INVALIDATING: begin
            stage1_wb_push      = stage1_tag_rddata[stage1_assoc_cnt].valid && stage1_tag_rddata[stage1_assoc_cnt].dirty;
            stage1_wb_plabel    = {stage1_tag_rddata[stage1_assoc_cnt].tag, get_index(pipe0_req.paddr)};
            stage1_wb_pdata     = pipe0_data_rddata[stage1_assoc_cnt];
            // only first period of inv, can cause data-collision of pipe2_data_rdata
            if (~|stage1_assoc_cnt && (stage1_wb_plabel == pipe2_data_wlabel && pipe2_data_write)) stage1_wb_pdata = pipe2_data_wrdata;
            // if stage 3 write this line, forward stage3_data_wdata
            if (~|stage1_assoc_cnt && (stage1_wb_plabel == get_label(pipe1_req.paddr) && pipe1_req.write)) stage1_wb_pdata = stage2_data_wrdata;
        end
    endcase
end
// when stall pipeline, record stage1_tag_mux && stage1_need_push
always_ff @ (posedge clk) begin
    if (rst) begin
        stage1_tag_rddata <= '0;
        stage1_need_push  <= 1'b0;
    end else begin
        stage1_tag_rddata <= stage1_tag_rddata_n;
        stage1_need_push  <= stage1_need_push_n;
    end
end
// stage1_line_recv
always_comb begin
    stage1_line_recv_n = stage1_line_recv;
    case (stage1_state)
        DCACHE_IDLE: begin
            // prefetch hit, move line_data, even prefetch hit, data maybe too old
            // if (stage1_cache_miss && stage1_prefetch_hit && pipe0_sb_line_vld) stage1_line_recv_n = pipe0_sb_line;
            // no prefetch
            // found in wb found_on_wb / wb_on_pop, newest
            if (stage1_cache_miss && (stage1_wb_query_found_wb || stage1_wb_query_on_pop)) stage1_line_recv_n = stage1_wb_query_rddata;
        end
    endcase
end
always_ff @ (posedge clk) begin
    if (rst) begin
        stage1_line_recv <= '0;
    end else begin
        stage1_line_recv <= stage1_line_recv_n;
    end
end
// ram we
always_comb begin
    stage1_tag_we      = '0;
    stage1_tag_waddr   = '0;    // no prefetch
    stage2_data_we     = '0;
    stage2_data_waddr  = '0;
    stage2_data_wrdata = pipe1_data_rddata;       // normal write
    stage2_data_wlabel = '0;

    pipe1_hit_n        = stage1_hit;

    stage1_inv_cnt_n   = stage1_inv_cnt;
    stage1_assoc_cnt_n = stage1_assoc_cnt;
    case (stage1_state)
        DCACHE_IDLE: begin
            if (pipe0_req.inv) stage1_assoc_cnt_n = '0;
            // normal write
            if (|pipe1_hit && pipe1_req.write) begin
                stage2_data_we     = pipe1_hit;
                stage2_data_waddr  = get_index(pipe1_req.paddr);
                stage2_data_wlabel = get_label(pipe1_req.paddr);
                stage2_data_wrdata[get_offset(pipe1_req.paddr)] = mux_be(
                    pipe1_data_rddata[get_offset(pipe1_req.paddr)],
                    pipe1_req.wrdata,
                    pipe1_req.be
                );
            end
            // normal write
            if (|stage1_hit && pipe0_req.write) begin
                stage1_tag_we      = stage1_hit;
                stage1_tag_waddr   = get_index(pipe0_req.vaddr);
            end
        end
        DCACHE_FETCH:
            if (&pipe0_sb_line_vld && stage1_prefetch_hit && stage1_assoc_pushed) begin
                stage2_data_we[stage1_assoc_waddr] = 1'b1;
                stage2_data_waddr  = get_index(pipe0_req.paddr);
                stage2_data_wlabel = get_label(pipe0_req.paddr);
                stage2_data_wrdata = pipe0_sb_line;
                stage1_tag_we[stage1_assoc_waddr] = 1'b1;
                stage1_tag_waddr   = get_index(pipe0_req.paddr);
                pipe1_hit_n[stage1_assoc_waddr]   = 1'b1;
            end
        DCACHE_WAIT_WB:
            if (stage1_assoc_pushed) begin
                stage2_data_we[stage1_assoc_waddr] = 1'b1;
                stage2_data_waddr  = get_index(pipe0_req.paddr);
                stage2_data_wlabel = get_label(pipe0_req.paddr);
                stage2_data_wrdata = stage1_line_recv;
                stage1_tag_we[stage1_assoc_waddr] = 1'b1;
                stage1_tag_waddr   = get_index(pipe0_req.paddr);
                pipe1_hit_n[stage1_assoc_waddr]   = 1'b1;
            end
        DCACHE_RESET: begin
            stage1_inv_cnt_n = stage1_inv_cnt + 1;
            stage1_tag_we    = '1;
            stage1_tag_waddr = stage1_inv_cnt;
        end
        DCACHE_INVALIDATING: begin
            pipe1_hit_n      = '0;
            stage1_tag_waddr = get_index(pipe0_req.paddr);
            if (~(stage1_wb_push && pipe0_wb_full)) begin
                stage1_tag_we[stage1_assoc_cnt] = 1'b1;
                stage1_assoc_cnt_n = stage1_assoc_cnt + 1;
            end
        end
    endcase
end
// stage1_ff
always_ff @ (posedge clk) begin
    if (rst) begin
        stage1_state     <= DCACHE_RESET;
        stage1_inv_cnt   <= '0;
        stage1_assoc_cnt <= '0;
    end else begin
        stage1_state     <= stage1_state_n;
        stage1_inv_cnt   <= stage1_inv_cnt_n;
        stage1_assoc_cnt <= stage1_assoc_cnt_n;
    end
end
// pipe 1(data driver)
// forward stage1_tag_wrdata
always_ff @ (posedge clk) begin
    if (rst) begin
        pipe1_tag_wrdata <= '0;
        pipe1_tag_we     <= '0;
        pipe1_tag_waddr  <= '0;
    end else begin
        pipe1_tag_wrdata <= stage1_tag_wrdata;
        pipe1_tag_we     <= stage1_tag_we;
        pipe1_tag_waddr  <= get_index(pipe0_req.vaddr);
    end
end
always_comb begin
    pipe1_req_n       = pipe0_req;
    pipe1_req_n.paddr = dbus.dcache_req.paddr;
    // cache miss, but wb hit & can write, no need write cache
    if (~|stage1_hit && stage1_wb_write) begin
        pipe1_req_n.write = 1'b0;
    end
    if (dbus.dcache_req.uncached) begin
        pipe1_req_n.read  = 1'b0;
        pipe1_req_n.write = 1'b0;
    end
end
always_ff @ (posedge clk) begin
    if (rst || ~dbus.ready) begin       // stall pipe 0 -> 1
        pipe1_hit   <= '0;
        pipe1_req   <= '0;
        pipe1_data_rddata <= '0;
    end else begin
        pipe1_hit   <= pipe1_hit_n;
        pipe1_req   <= pipe1_req_n;
        pipe1_data_rddata <= stage1_data_mux;
    end
end
// stage 2(pipe 1 - 2)
// is already handled in stage2_data_we
// pipe 2(extra pipe)
// record last write
always_ff @ (posedge clk) begin
    if (rst) begin
        pipe2_data_write  <= 1'b0;
        pipe2_data_wlabel <= '0;
        pipe2_data_wrdata <= '0;
    end else begin
        pipe2_data_write  <= |stage2_data_we;
        pipe2_data_wlabel <= stage2_data_wlabel;
        pipe2_data_wrdata <= stage2_data_wrdata;
    end
end

// stage 1 resp
assign stage1_resp.rddata = stage1_data_mux[get_offset(pipe0_req.vaddr)];
assign stage1_resp.valid  = dbus.ready & pipe0_req.read;
// dbus control signals
assign dbus.ready = stage1_state_n == DCACHE_IDLE;
// dbus resp signals
assign dbus.dcache_resp = dbus.dcache_req.uncached ? stage1_dp_resp : stage1_resp;

// stage 1 stream_buffer for cache_prefetch
// for data_vld will delay one period, maybe try to modify it.
// define interface
// inst stream_buffer
stream_buffer #(
    .LINE_WIDTH(LINE_WIDTH),
    .ARID(AID)
) icache_prefetch (
    .label_i        (stage1_sb_label_i      ),
    .label_i_rdy    (stage1_sb_label_i_rdy  ),
    .inv            (stage1_sb_inv          ),
    .label_o        (pipe0_sb_label_o       ),
    .label_o_vld    (pipe0_sb_label_o_vld   ),
    .data           (pipe0_sb_line          ),
    .data_vld       (pipe0_sb_line_vld      ),
    .write          (1'b0                   ),
    .written        (                       ),
    .hit            (1'b0                   ),
    .was_hit        (                       ),
    .*
);
// stage 1 dcache_pass for uncached req
dcache_pass #(
    .DATA_WIDTH(DATA_WIDTH),
    .ARID(PASS_AID),
    .AWID(PASS_AID),
    .DATA_DEPTH(PASS_DATA_DEPTH)
) dcache_pass_inst (
    .axi3_rd_if             (axi3_rd_if_uncached),
    .axi3_wr_if             (axi3_wr_if_uncached),
    .dcache_uncached_req    (stage1_dp_req      ),
    .push                   (stage1_dp_push     ),
    .full                   (pipe0_dp_full      ),
    .dcache_uncached_resp   (stage1_dp_resp     ),      // uncached load donot use be
    .*
);
// stage 1 write_buffer for cache_wb
write_buffer #(
    .LINE_WIDTH(LINE_WIDTH),
    .VICTIM_CACHE_ENABLED(VICTIM_CACHE_ENABLED),
    .LINE_DEPTH(WB_LINE_DEPTH),
    .AWID(AID)
) write_buffer_inst (
    .pline          ({stage1_wb_plabel, stage1_wb_pdata}),
    .full           (pipe0_wb_full                      ),
    .push           (stage1_wb_push                     ),
    .pushed         (stage1_wb_pushed                   ),
    .query_label    (stage1_wb_query_label              ),
    .query_found    (stage1_wb_query_found              ),
    .query_on_pop   (stage1_wb_query_on_pop             ),
    .query_wdata    (stage1_wb_query_wrdata             ),
    .query_rdata    (stage1_wb_query_rddata             ),
    .query_wbe      (stage1_wb_query_wbe                ),
    .write          (stage1_wb_write                    ),
    .written        (stage1_wb_written                  ),
    .query_found_wb (stage1_wb_query_found_wb           ),
    .clear          (stage1_wb_clear                    ),
    .*
);

// generate block RAMs
for (genvar i = 0; i < SET_ASSOC; ++i) begin : gen_icache_mem
    dual_port_lutram #(
        .SIZE(GROUP_NUM),
        .dtype(tag_t)
    ) mem_tag (
        .clk,
        .rst,

        .ena    (1'b1                   ),
        .wea    (stage1_tag_we[i]       ),
        .addra  (stage1_tag_waddr       ),
        .dina   (stage1_tag_wrdata      ),
        .douta  (                       ),

        .enb    (1'b1                   ),
        .addrb  (stage0_ram_raddr       ),
        .doutb  (pipe0_tag_rddata[i]    )
    );

    dual_port_ram #(
        .SIZE(GROUP_NUM),
        .dtype(line_t)
    ) mem_data (
        .clk,
        .rst,

        .ena    (1'b1                   ),
        .wea    (stage2_data_we[i]      ),
        .addra  (stage2_data_waddr      ),
        .dina   (stage2_data_wrdata     ),
        .douta  (                       ),

        .enb    (1'b1                   ),
        .web    (1'b0                   ),
        .addrb  (stage0_ram_raddr       ),
        .dinb   (                       ),
        .doutb  (pipe0_data_rddata[i]   )
    );
end

// generate PLRU
for (genvar i = 0; i < GROUP_NUM; ++i) begin: gen_plru
    plru #(
        .SET_ASSOC (SET_ASSOC)
    ) plru_inst (
        .clk,
        .rst,
        .access     (pipe1_hit_n),      // stage1_hit
        .update     (dbus.ready && (~pipe0_req.inv) && i[INDEX_WIDTH-1:0] == get_index(pipe0_req.paddr)),
        .repl_index (pipe0_repl_index[i])
    );
end

endmodule
