// i$ for inst cache
`include "icache.svh"

module icache #(
    parameter   DATA_WIDTH      =   32,     // single issue
    parameter   LINE_WIDTH      =   256,
    parameter   SET_ASSOC       =   4,
    parameter   CACHE_SIZE      =   16 * 1024 * 8,
    parameter   ARID            =   0
) (
    // external signals
    input   logic   clk,
    input   logic   rst,
    // CPU signals
    cpu_ibus_if.slave   ibus,
    // AXI3 signals
    axi3_rd_if.master   axi3_rd_if
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
`DEF_STRUCT_ICACHE_TAG_T
`DEF_STRUCT_INDEX_T
`DEF_STRUCT_LABEL_T
`DEF_STRUCT_OFFSET_T
`DEF_STRUCT_LINE_T
`DEF_FUNC_GET_TAG
`DEF_FUNC_GET_INDEX
`DEF_FUNC_GET_LABEL
`DEF_FUNC_GET_OFFSET

// stage 0(before pipe 0)
index_t stage0_ram_raddr;
// pipe 0(tag access & data access)
tag_t [SET_ASSOC - 1:0] pipe0_tag_rddata1, pipe0_tag_rdata2;
line_t [SET_ASSOC - 1:0] pipe0_data_rddata;
logic pipe0_inv, pipe0_read;
index_t pipe0_inv_index;
// repl
logic [GROUP_NUM - 1:0][$clog2(SET_ASSOC) - 1:0] pipe0_repl_index;
// prefetch
label_t pipe0_sb_label_o;
line_t pipe0_sb_line;
logic pipe0_sb_label_o_vld, pipe0_sb_written, pipe0_sb_was_hit;
logic [(LINE_WIDTH / DATA_WIDTH) - 1:0] pipe0_sb_line_vld;
// stage 1(tag we & data we)
logic [SET_ASSOC-1:0] stage1_tag_whit, stage1_data_whit;
logic [SET_ASSOC-1:0] stage1_tag_we, stage1_data_we;
index_t stage1_tag_waddr, stage1_data_waddr;
tag_t stage1_tag_wrdata;
line_t stage1_data_wrdata, stage1_data_mux, stage1_data_ram;
// repl
logic [$clog2(SET_ASSOC) - 1:0] stage1_assoc_waddr, stage1_repl_index_waddr;
logic [$clog2(SET_ASSOC) - 1:0] stage1_sb_assoc_waddr, stage1_sb_repl_index_waddr;
// prefetch
label_t stage1_sb_label_i;
logic stage1_sb_label_i_rdy, stage1_sb_inv, stage1_sb_write, stage1_sb_hit;
// state
icache_state_t stage1_state, stage1_state_n;
// invalidate counter, only use after rst
index_t stage1_inv_cnt, stage1_inv_cnt_n;
// check cache miss
logic stage1_cache_miss, stage1_cache_miss_plus1;
logic [SET_ASSOC-1:0] stage1_hit, stage1_hit_rd, stage1_hit_fr, stage1_hit_plus1;
logic stage1_prefetch_hit, stage1_prefetch_hit_plus1;
// pipe 1(extra pipe, hold tag we & data we for fr)
logic [SET_ASSOC-1:0] pipe1_tag_we, pipe1_data_we;
index_t pipe1_tag_waddr, pipe1_data_waddr;
tag_t pipe1_tag_wrdata;
line_t pipe1_data_wrdata;

// stage 0
assign stage0_ram_raddr = ibus.ready ? get_index(ibus.vaddr) : get_index(ibus.paddr);

// pipe 0
always_ff @ (posedge clk) begin
    if (rst) begin
        pipe0_read <= 1'b0;
    end else if (ibus.ready) begin
        pipe0_read <= ibus.read;
    end
end
always_ff @ (posedge clk) begin
    if (rst) begin
        // inv_icache
        pipe0_inv       <= 1'b0;
        pipe0_inv_index <= '0;
    end else begin
        // pipe0_inv can only hold one peroid
        pipe0_inv       <= ibus.inv & ibus.ready;
        pipe0_inv_index <= get_index(ibus.inv_addr);
    end
end

// stage 1
// check cache_miss
// hit from tag_rddata
for(genvar i = 0; i < SET_ASSOC; ++i) begin : gen_icache_hit_rd
    assign stage1_hit_rd[i] = pipe0_tag_rddata1[i].valid & (get_tag(ibus.paddr) == pipe0_tag_rddata1[i].tag);
end
// hit from tag_wrdata
assign stage1_tag_whit      = pipe1_tag_we & {SET_ASSOC{(get_tag(ibus.paddr) == pipe1_tag_wrdata.tag) & (get_index(ibus.paddr) == pipe1_tag_waddr)}};
assign stage1_hit_fr        = {SET_ASSOC{pipe1_tag_wrdata.valid}} & stage1_tag_whit;
assign stage1_hit           = |stage1_tag_whit ? stage1_hit_fr : stage1_hit_rd;
assign stage1_cache_miss    = ~(|stage1_hit) & pipe0_read;
assign stage1_prefetch_hit  = (pipe0_sb_label_o == get_label(ibus.paddr) && pipe0_sb_label_o_vld) & pipe0_read;
// next line
for(genvar i = 0; i < SET_ASSOC; ++i) begin : gen_icache_hit_plus1
    assign stage1_hit_plus1[i] = pipe0_tag_rdata2[i].valid & (get_tag(ibus.paddr_plus1) == pipe0_tag_rdata2[i].tag);
end
assign stage1_cache_miss_plus1 = ~(|stage1_hit_plus1) & ~(|pipe1_tag_we) & pipe0_read;      // after tag write, inv rtag2
assign stage1_prefetch_hit_plus1 = (pipe0_sb_label_o == get_label(ibus.paddr_plus1) && pipe0_sb_label_o_vld) & pipe0_read;
// prefetch
assign stage1_sb_hit = stage1_prefetch_hit;
// repl
assign stage1_repl_index_waddr = pipe0_repl_index[get_index(ibus.paddr)];
always_comb begin
    stage1_assoc_waddr = stage1_repl_index_waddr;
    for(int i = 0; i < SET_ASSOC; ++i) begin
        // temp ignore stage1_tag_whit
        if(~pipe0_tag_rddata1[i].valid) stage1_assoc_waddr = i;
    end
end
assign stage1_sb_repl_index_waddr = pipe0_repl_index[get_index({pipe0_sb_label_o, {LINE_BYTE_OFFSET{1'b0}}})];
always_comb begin
    stage1_sb_assoc_waddr = stage1_sb_repl_index_waddr;
    for(int i = 0; i < SET_ASSOC; ++i) begin
        // temp ignore stage1_tag_whit
        if(~pipe0_tag_rddata1[i].valid) stage1_sb_assoc_waddr = i;
    end
end
// update state
always_comb begin
    stage1_state_n = stage1_state;
    unique case (stage1_state)
        ICACHE_IDLE:
            if (~stage1_cache_miss) begin
                // cache hit, prefetch content cannot be newer than cache
                stage1_state_n = ICACHE_IDLE;
            end else if (~stage1_prefetch_hit || ~pipe0_sb_line_vld[get_offset(ibus.paddr)]) begin
                // none hit, or data is invalid ,then start a new req
                stage1_state_n = ICACHE_FETCH;
            end else begin
                // prefetch hit, move line_data
                stage1_state_n = ICACHE_IDLE;
            end
        ICACHE_FETCH: begin
            if (pipe0_sb_line_vld[get_offset(ibus.paddr)] && stage1_prefetch_hit) begin
                // fetch complete
                stage1_state_n = ICACHE_IDLE;
            end
        end
        ICACHE_RESET:       // only all reset can cpu start working
            if (&stage1_inv_cnt) stage1_state_n = ICACHE_IDLE;
    endcase
end
// rddata
always_comb begin
    stage1_data_ram = '0;
    for (int i = 0; i < SET_ASSOC; ++i)
        stage1_data_ram |= {LINE_WIDTH{stage1_hit[i]}} & pipe0_data_rddata[i];
end
assign stage1_data_whit = stage1_tag_whit;
always_comb begin
    stage1_data_mux = stage1_data_ram;
    if (|stage1_data_whit) stage1_data_mux = pipe1_data_wrdata;
    if (stage1_cache_miss && stage1_prefetch_hit) stage1_data_mux = stage1_data_wrdata;
end
// prefetch signals
assign stage1_sb_inv = pipe0_inv;
always_comb begin
    stage1_sb_label_i = '0;
    stage1_sb_label_i_rdy = 1'b0;
    case (stage1_state)
        ICACHE_IDLE:
            if (stage1_cache_miss && ~stage1_prefetch_hit) begin
                // fetch
                stage1_sb_label_i = get_label(ibus.paddr);
                stage1_sb_label_i_rdy = 1'b1;
            end else if (stage1_cache_miss_plus1 & ~stage1_prefetch_hit_plus1) begin
                // prefetch, not check whether sb is busy(ignore)
                stage1_sb_label_i = get_label(ibus.paddr_plus1);
                stage1_sb_label_i_rdy = 1'b1;
            end
        ICACHE_FETCH:
            if (~stage1_prefetch_hit) begin
                // fetch
                stage1_sb_label_i = get_label(ibus.paddr);
                stage1_sb_label_i_rdy = 1'b1;
            end
    endcase
end
// ram req for tag & data
assign stage1_tag_wrdata.valid = stage1_state != ICACHE_RESET && ~pipe0_inv;
assign stage1_tag_wrdata.tag   = stage1_sb_write ? get_tag({pipe0_sb_label_o, {LINE_BYTE_OFFSET{1'b0}}}) : get_tag(ibus.paddr);
assign stage1_data_wrdata      = pipe0_sb_line;
always_comb begin
    stage1_tag_we    = '0;
    stage1_tag_waddr = get_index(ibus.vaddr) + 1;        // fetch line_plus1
    stage1_data_we   = '0;
    stage1_data_waddr = '0;
    // when ~sb_written & all line_data valid & sb_hit at least once
    // must ~pipe0_inv can we set sb_write as 1
    stage1_sb_write  = ~pipe0_sb_written & (&pipe0_sb_line_vld) & (pipe0_sb_was_hit | stage1_sb_hit) & ~pipe0_inv;

    stage1_inv_cnt_n   = '0;

    if (stage1_sb_write) begin
        // only when line is valid & was hit & not written yet
        stage1_tag_we[stage1_sb_assoc_waddr]  = 1'b1;
        stage1_tag_waddr  = get_index({pipe0_sb_label_o, {LINE_BYTE_OFFSET{1'b0}}});
        stage1_data_we[stage1_sb_assoc_waddr] = 1'b1;
        stage1_data_waddr = get_index({pipe0_sb_label_o, {LINE_BYTE_OFFSET{1'b0}}});
    end

    case (stage1_state)
        ICACHE_RESET: begin
            stage1_inv_cnt_n = stage1_inv_cnt + 1;
            stage1_tag_we    = '1;
            stage1_tag_waddr = stage1_inv_cnt;
        end
    endcase

    // inv
    if (pipe0_inv) begin
        stage1_tag_we    = '1;
        stage1_tag_waddr = pipe0_inv_index;
    end
end
// invalidate counter, only use after rst & state
always_ff @ (posedge clk) begin
    if (rst) begin
        stage1_state     <= ICACHE_RESET;
        stage1_inv_cnt   <= '0;
    end else begin
        stage1_state     <= stage1_state_n;
        stage1_inv_cnt   <= stage1_inv_cnt_n;
    end
end
// pipe 1(extra pipe)
always_ff @ (posedge clk) begin
    if (rst) begin
        pipe1_tag_we      <= '0;
        pipe1_data_we     <= '0;
        pipe1_tag_waddr   <= '0;
        pipe1_data_waddr  <= '0;
        pipe1_tag_wrdata  <= '0;
        pipe1_data_wrdata <= '0;
    end else begin
        pipe1_tag_we      <= stage1_tag_we;
        pipe1_data_we     <= stage1_data_we;
        pipe1_tag_waddr   <= stage1_tag_waddr;
        pipe1_data_waddr  <= stage1_data_waddr;
        pipe1_tag_wrdata  <= stage1_tag_wrdata;
        pipe1_data_wrdata <= stage1_data_wrdata;
    end
end

// ibus control signals
assign ibus.ready  = (stage1_state_n == ICACHE_IDLE);
assign ibus.valid  = ibus.ready & pipe0_read;
// ibus data signals
assign ibus.rddata = stage1_data_mux[get_offset(ibus.paddr)];

// stage 1 stream_buffer for cache_prefetch
// for data_vld will delay one period, maybe try to modify it.
// inst stream_buffer
stream_buffer #(
    .LINE_WIDTH(LINE_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ARID(ARID)
) icache_prefetch (
    .label_i(stage1_sb_label_i),
    .label_i_rdy(stage1_sb_label_i_rdy),
    .inv(stage1_sb_inv),
    .label_o(pipe0_sb_label_o),
    .label_o_vld(pipe0_sb_label_o_vld),
    .data(pipe0_sb_line),
    .data_vld(pipe0_sb_line_vld),
    .write(stage1_sb_write),
    .written(pipe0_sb_written),
    .hit(stage1_sb_hit),
    .was_hit(pipe0_sb_was_hit),
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
        .douta  (pipe0_tag_rdata2[i]    ),

        .enb    (1'b1                   ),
        .addrb  (stage0_ram_raddr       ),
        .doutb  (pipe0_tag_rddata1[i]   )
    );

    dual_port_ram #(
        .SIZE(GROUP_NUM),
        .dtype(line_t)
    ) mem_data (
        .clk,
        .rst,

        .ena    (1'b1                   ),
        .wea    (stage1_data_we[i]      ),
        .addra  (stage1_data_waddr      ),
        .dina   (stage1_data_wrdata     ),
        .douta  (                       ),

        .enb    (1'b1                   ),
        .web    (1'b0                   ),
        .addrb  (stage0_ram_raddr       ),
        .dinb   (                       ),
        .doutb  (pipe0_data_rddata[i]   )
    );
end

// generate PLRU
for(genvar i = 0; i < GROUP_NUM; ++i) begin: gen_plru
    plru #(
        .SET_ASSOC (SET_ASSOC)
    ) plru_inst (
        .clk,
        .rst,
        .access     (stage1_hit),
        .update     ((ibus.ready) && i[INDEX_WIDTH-1:0] == get_index(ibus.paddr)),
        .repl_index (pipe0_repl_index[i])
    );
end

endmodule
