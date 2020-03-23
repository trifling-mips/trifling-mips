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
	// AXI3 rd interface
	axi3_rd_if.master	axi3_rd_if,
	// line_data
	output	logic	[LABEL_WIDTH - 1:0]	label_o,	// label(tag + index)
	output	logic	[LINE_WIDTH - 1:0]	data,
	output	logic						data_vld
);

phys_t axi_raddr;
logic [LINE_BYTE_OFFSET - 1:0] burst_cnt, burst_cnt_n;
logic [LABEL_WIDTH - 1:0] label_r, label_n;
logic data_vld_r;
logic [(LINE_WIDTH / 32) - 1:0][31:0] line_data;
sb_state_t state, state_n;

// assign output
assign label_o  = label_r;
assign data     = line_data;
assign data_vld = data_vld_r;

always_comb begin
	// update reg_n
	label_n = label_i;		// let upper module to plus 1
	burst_cnt_n = burst_cnt;

	// AXI read defaults
	axi3_rd_if.arid        = ARID;
	axi3_rd_if.axi3_rd_req = '0;
	axi3_rd_if.axi3_rd_req.arlen   = (LINE_WIDTH / 32) - 1;
	axi3_rd_if.axi3_rd_req.arsize  = 3'b010;		// 4 bytes
	axi3_rd_if.axi3_rd_req.arburst = 2'b01;		// INCR
	axi_raddr = {label_r, {LINE_BYTE_OFFSET{1'b0}}};

	case (state)
		SB_WAIT_AXI_READY: begin
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
				// do nothing, we use reg not lut
			end
		end
	endcase
end

// update state
always_comb begin
	state_n = state;
	unique case(state)
		SB_IDLE, SB_FINISH:
			if (label_i_rdy)
				state_n = SB_WAIT_AXI_READY;
			else state_n = SB_IDLE;
		SB_WAIT_AXI_READY:
			if (axi3_rd_if.axi3_rd_resp.arready) 
				state_n = SB_RECEIVING;
		SB_RECEIVING:
			if (axi3_rd_if.axi3_rd_resp.rvalid & axi3_rd_if.axi3_rd_resp.rlast)
				state_n = SB_FINISH;
	endcase
end

// update next
always_ff @ (posedge clk) begin
	if (rst)
		data_vld_r <= 1'b0;
	else if (state_n == SB_FINISH)
		data_vld_r <= 1'b1;
	else if (state_n == SB_WAIT_AXI_READY) begin
		data_vld_r <= 1'b0;
		label_r <= label_n;
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
