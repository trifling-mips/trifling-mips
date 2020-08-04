// stream buffer for cache prefetch
`include "stream_buffer.svh"

module stream_buffer #(
    parameter   LINE_WIDTH  =   256,
    parameter   DATA_WIDTH  =   32,
    parameter   ARID        =   2,      // arid(0, 1) is opcupied by icache & dcache
    // local parameter
    localparam  LINE_BYTE_OFFSET    =   $clog2(LINE_WIDTH / $bits(uint8_t)),
    localparam  LABEL_WIDTH         =   ($bits(phys_t) - LINE_BYTE_OFFSET)
) (
    // external logics
    input   logic       clk,
    input   logic       rst,
    // prefetch signals
    input   logic       [LABEL_WIDTH - 1:0] label_i,
    input   logic       label_i_rdy,
    input   logic       inv,
    // AXI3 rd interface
    axi3_rd_if.master   axi3_rd_if,
    // line_data
    output  logic       [LABEL_WIDTH - 1:0] label_o,    // label(tag + index)
    output  logic                           label_o_vld,
    output  logic       [LINE_WIDTH - 1:0]  data,
    output  logic       [(LINE_WIDTH / DATA_WIDTH) - 1:0]   data_vld,
    // record written state
    input   logic       write,
    output  logic       written,
    input   logic       hit,
    output  logic       was_hit
);

phys_t axi_raddr;
logic [LINE_BYTE_OFFSET - 1:0] burst_cnt, burst_cnt_n;
logic [LABEL_WIDTH - 1:0] label_n;
logic label_o_vld_n, written_n, was_hit_n;
logic [(LINE_WIDTH / DATA_WIDTH) - 1:0][DATA_WIDTH - 1:0] line_data;
logic [(LINE_WIDTH / DATA_WIDTH) - 1:0] data_vld_n;
sb_state_t state, state_n;

// assign output
assign data = line_data;

always_comb begin
    // update reg_n
    label_n       = label_o;        // let upper module to plus 1
    burst_cnt_n   = burst_cnt;
    label_o_vld_n = label_o_vld;
    data_vld_n    = data_vld;
    written_n     = written;

    // AXI read defaults
    axi3_rd_if.arid        = ARID;
    axi3_rd_if.axi3_rd_req = '0;
    axi3_rd_if.axi3_rd_req.arlen   = (LINE_WIDTH / DATA_WIDTH) - 1;
    axi3_rd_if.axi3_rd_req.arsize  = 3'b010;        // 4 bytes
    axi3_rd_if.axi3_rd_req.arburst = 2'b01;        // INCR
    axi_raddr = {label_o, {LINE_BYTE_OFFSET{1'b0}}};

    case (state)
        SB_IDLE: begin
            written_n = write & (&data_vld);
            if (label_i_rdy && ~inv) begin
                label_n       = label_i;
                label_o_vld_n = 1'b1;
                data_vld_n    = '0;
                written_n     = 1'b0;
            end
        end
        SB_WAIT_AXI_READY, SB_FLUSH_WAIT_AXI_READY: begin
            burst_cnt_n = '0;
            axi3_rd_if.axi3_rd_req.arvalid = 1'b1;
            axi3_rd_if.axi3_rd_req.araddr  = axi_raddr;
        end
        SB_RECEIVING:
            if (axi3_rd_if.axi3_rd_resp.rvalid) begin
                burst_cnt_n           = burst_cnt + 1;
                data_vld_n[burst_cnt] = 1'b1;
                axi3_rd_if.axi3_rd_req.rready = 1'b1;
            end
        SB_FLUSH_RECEIVING: axi3_rd_if.axi3_rd_req.rready = 1'b1;
    endcase
end
always_comb begin
    was_hit_n = was_hit;
    // update was_hit_n
    case (state)
        SB_IDLE: if (label_i_rdy && ~inv) was_hit_n = 1'b0;
        SB_RECEIVING: was_hit_n |= hit;
    endcase
end

// update state
always_comb begin
    state_n = state;
    case(state)
        SB_IDLE:
            if (label_i_rdy & ~inv)
                state_n = SB_WAIT_AXI_READY;
            else state_n = SB_IDLE;
        SB_WAIT_AXI_READY:
            if (axi3_rd_if.axi3_rd_resp.arready)
                state_n = inv ? SB_FLUSH_RECEIVING : SB_RECEIVING;
            else if (inv)
                state_n = SB_FLUSH_WAIT_AXI_READY;
        SB_RECEIVING:
            if (axi3_rd_if.axi3_rd_resp.rvalid & axi3_rd_if.axi3_rd_resp.rlast)
                state_n = SB_IDLE;
            else if (inv)
                state_n = SB_FLUSH_RECEIVING;
        SB_FLUSH_WAIT_AXI_READY:
            if (axi3_rd_if.axi3_rd_resp.arready)
                state_n = SB_FLUSH_RECEIVING;
        SB_FLUSH_RECEIVING:
            if (axi3_rd_if.axi3_rd_resp.rvalid & axi3_rd_if.axi3_rd_resp.rlast)
                state_n = SB_IDLE;
    endcase
end

// update next
always_ff @ (posedge clk) begin
    if (rst || inv) begin
        data_vld    <= '0;
        label_o     <= '0;
        label_o_vld <= 1'b0;
        written     <= 1'b1;
        was_hit     <= 1'b0;
    end else begin
        data_vld    <= data_vld_n;
        label_o     <= label_n;
        label_o_vld <= label_o_vld_n;
        written     <= written_n;
        was_hit     <= was_hit_n;
    end

    if (state == SB_RECEIVING && axi3_rd_if.axi3_rd_resp.rvalid) begin
        line_data[burst_cnt] <= axi3_rd_if.axi3_rd_resp.rdata;
    end

    if (rst) begin
        state     <= SB_IDLE;
        burst_cnt <= '0;
    end else begin
        state     <= state_n;
        burst_cnt <= burst_cnt_n;
    end
end

endmodule
