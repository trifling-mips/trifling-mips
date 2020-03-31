// stream buffer for cache prefetch
`include "stream_buffer.svh"

module stream_buffer #(
	parameter	LINE_WIDTH	=	256,
	parameter	ARID		=	2,		// arid(0, 1) is opcupied by icache & dcache
	// local parameter
	localparam	LINE_BYTE_OFFSET	=	$clog2(LINE_WIDTH / $bits(uint8_t)),
	localparam	LABEL_WIDTH			=	($bits(phys_t) - LINE_BYTE_OFFSET)
) (
	// external logics
	input	logic		clk,
	input	logic		rst,
	// prefetch signals
	input	logic	[LABEL_WIDTH - 1:0]	label_i,
	input	logic		label_i_rdy,
	input	logic		inv,
	// AXI3 rd interface
	axi3_rd_if.master	axi3_rd_if,
	// line_data
	output	logic	[LABEL_WIDTH - 1:0]	label_o,	// label(tag + index)
	output	logic	[LINE_WIDTH - 1:0]	data,
	output	logic						data_vld,
	output	logic						ready
);

phys_t axi_raddr;
logic [LINE_BYTE_OFFSET - 1:0] burst_cnt, burst_cnt_n;
logic [LABEL_WIDTH - 1:0] label_n;
logic data_vld_n;
logic [(LINE_WIDTH / 32) - 1:0][31:0] line_data;
sb_state_t state, state_n;

// assign output
assign data     = line_data;
assign ready    = (state == SB_IDLE);

always_comb begin
	// update reg_n
	label_n = label_o;		// let upper module to plus 1
	burst_cnt_n = burst_cnt;
	data_vld_n  = data_vld;

	// AXI read defaults
	axi3_rd_if.arid        = ARID;
	axi3_rd_if.axi3_rd_req = '0;
	axi3_rd_if.axi3_rd_req.arlen   = (LINE_WIDTH / 32) - 1;
	axi3_rd_if.axi3_rd_req.arsize  = 3'b010;		// 4 bytes
	axi3_rd_if.axi3_rd_req.arburst = 2'b01;		// INCR
	axi_raddr = {label_o, {LINE_BYTE_OFFSET{1'b0}}};

	case (state)
		SB_IDLE:
			if (label_i_rdy && ~inv) begin
				label_n    = label_i;
				data_vld_n = 1'b0;
			end
		SB_WAIT_AXI_READY, SB_FLUSH_WAIT_AXI_READY: begin
			burst_cnt_n = '0;
			axi3_rd_if.axi3_rd_req.arvalid = 1'b1;
			axi3_rd_if.axi3_rd_req.araddr  = axi_raddr;
		end
		SB_RECEIVING: begin
			if (axi3_rd_if.axi3_rd_resp.rvalid) begin
				axi3_rd_if.axi3_rd_req.rready = 1'b1;
				burst_cnt_n       = burst_cnt + 1;
			end

			if (axi3_rd_if.axi3_rd_resp.rvalid & axi3_rd_if.axi3_rd_resp.rlast) begin
				data_vld_n = 1'b1;
			end
		end
		SB_FLUSH_RECEIVING: axi3_rd_if.axi3_rd_req.rready = 1'b1;
	endcase
end

// update state
always_comb begin
	state_n = state;
	unique case(state)
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
		data_vld <= 1'b0;
		label_o  <= '0;
	end else begin
		data_vld <= data_vld_n;
		label_o  <= label_n;
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
