// stream buffer for cache prefetch
`include "stream_buffer.svh"

module #(
	parameter	BUS_WIDTH	=	4,
	parameter	LINE_WIDTH	=	256,
	parameter	ARID		=	2,		// arid(0, 1) is opcupied by icache & dcache
	// local parameter
	localparam	LINE_BYTE_OFFSET	=	$clog2(LINE_WIDTH / 8),
	localparam	LABEL_WIDTH			=	($bits(phys_t) - LINE_BYTE_OFFSET)
) stream_buffer (
	// external logics
	input	logic		clk,
	input	logic		rst_n,
	// prefetch signals
	input	phys_t		addr,
	input	logic		addr_rdy,
	// AXI3 rd interface
	axi3_rd_if.master	axi3_rd_if,
	// line_data
	output	[LABEL_WIDTH - 1:0]	label,	// label(tag + index)
	output	[LINE_WIDTH - 1:0]	data,
	output	logic				data_vld
);

phys_t axi_raddr;
logic [LINE_BYTE_OFFSET - 1:0] burst_cnt, burst_cnt_n;
logic [LABEL_WIDTH - 1:0] label_r, label_n;
logic data_vld_r;
logic [(LINE_WIDTH / 32) - 1:0][31:0] line_data;
state_t state, state_n;

always_comb begin
	// update reg_n
	label_n = addr + 1;
	burst_cnt_n = burst_cnt;

	// AXI read defaults
	axi3_rd_if      = '0;
	axi3_rd_if.arid = ARID;
	axi3_rd_if.arlen   = (LINE_WIDTH / 32) - 1;
	axi3_rd_if.arsize  = 3'b010;		// 4 bytes
	axi3_rd_if.arburst = 2'b01;		// INCR
	axi_raddr = {label_r, {LINE_BYTE_OFFSET{1'b0}};

	case (state)
		WAIT_AXI_READY: begin
			burst_cnt_n = '0;
			axi3_rd_if.arvalid = 1'b1;
			axi3_rd_if.araddr  = axi_raddr;
		end
		RECEIVING: begin
			if (axi3_rd_if.rvalid) begin
				axi3_rd_if.rready = 1'b1;
				burst_cnt_n       = burst_cnt + 1;
			end

			if (axi3_rd_if.rvalid & axi3_rd_if.rlast) begin
				// do nothing, we use reg not lut
			end
		end
	endcase
end

// update state
always_comb begin
	state_n = state;
	unique case(state)
		IDLE, FINISH:
			if (addr_rdy)
				state_n = WAIT_AXI_READY;
			else state_n = IDLE;
		WAIT_AXI_READY:
			if (axi3_rd_if.arready) 
				state_n = RECEIVING;
		RECEIVING:
			if (axi3_rd_if.rvalid & axi3_rd_if.rlast)
				state_n = FINISH;
	endcase
end

// update next
always_ff @ (posedge clk) begin
	if (~rst_n)
		data_vld_r <= 1'b0;
	else if (state_n == FINISH)
		data_vld_r <= 1'b1;
	else if (state_n == WAIT_AXI_READY) begin
		data_vld_r <= 1'b0;
		label_r <= label_n;
	end

	if (state == RECEIVING && axi3_rd_if.rvalid) begin
		line_data[burst_cnt] <= axi3_rd_if.rdata;
	end

	if (~rst_n) begin
		state     <= IDLE;
		burst_cnt <= '0;
	end else begin
		state     <= state_n;
		burst_cnt <= burst_cnt_n;
	end
end

endmodule
