// write buffer for cache wb_fifo
`include "write_buffer.svh"

module write_buffer #(
	parameter	LINE_WIDTH	=	256,
	parameter	AWID		=	2,		// awid(0, 1) is opcupied by icache & dcache, is use in dcache, awid = 1
	`ifdef VICTIM_CACHE_ENABLE
	parameter	LINE_DEPTH	=	8,
	`endif
	// local parameter
	localparam	LINE_BYTE_OFFSET	=	$clog2(LINE_WIDTH / $bits(uint8_t)),
	localparam	LABEL_WIDTH			=	($bits(phys_t) - LINE_BYTE_OFFSET),
	localparam	BURST_LIMIT			=	(LINE_WIDTH / 32) - 1,
	// parameter for type
	parameter type line_t  = logic [LABEL_WIDTH + LINE_WIDTH - 1:0],
	parameter type label_t = logic [LABEL_WIDTH - 1:0],
	parameter type data_t  = logic [LINE_WIDTH  - 1:0],
	parameter type be_t    = logic [(LINE_WIDTH / $bits(uint8_t)) - 1:0]
) (
	input	logic	clk,
	input	logic	rst,

	// AXI3 wr interface
	axi3_wr_if.master	axi3_wr_if,

	// fifo signals
	input	line_t	pline,
	output	logic	full,
	input	logic	push,
	output	logic	pushed,

	// query signals
	input	label_t	query_label,
	output	logic	query_found,
	input	data_t	query_wdata,
	output	data_t	query_rdata,
	input	be_t	query_wbe,
	input	logic	write,
	output	logic	written,

	// query_wb signals
	// if query_label is found in wb_line, set as 1 for 1 period(before posedge clk) to re-write d$
	// meanwhile, victim line of this re-write will be confirmed by pushed signal
	output	logic	query_found_wb
);

// state_t
state_t state, state_n;
// common logic
logic empty;
line_t wb_line, wb_line_n;
logic wb_vld, wb_vld_n;
phys_t wb_addr, wb_addr_n;
logic [BURST_LIMIT:0][31:0] wb_burst_line;
logic [LINE_BYTE_OFFSET - 1:0] wb_burst_cnt, wb_burst_cnt_n;
assign wb_burst_line = wb_line[LINE_WIDTH - 1:0];		// reshape
assign query_found_wb = query_found ? 1'b0 : (wb_line[LINE_WIDTH +: LABEL_WIDTH] == query_label) && wb_vld;

`ifdef VICTIM_CACHE_ENABLE
// define interface
line_t rline;
logic pop;
data_t query_rdata_vic;
// inst module
victim_cache #(
	.LINE_WIDTH(LINE_WIDTH),
	.LINE_DEPTH(LINE_DEPTH),
	// parameter for type
	.line_t(line_t),
	.label_t(label_t),
	.data_t(data_t),
	.be_t(be_t)
) victim_cache_inst (
	.query_rdata(query_rdata_vic),
	.*
);
// assign output
assign query_rdata = query_found ? query_rdata_vic : wb_line[LINE_WIDTH - 1:0];
// state machine(part)
always_comb begin
	pop = 1'b0;
	wb_addr_n = wb_addr;
	wb_line_n = wb_line;
	case(state)
		IDLE: begin
			pop = 1'b1;
			wb_addr_n = {rline[LINE_WIDTH +: LABEL_WIDTH], {LINE_BYTE_OFFSET{1'b0}}};
			wb_line_n = rline[LINE_WIDTH - 1:0];
		end
	endcase
end
`else
// assign output
assign query_found = 1'b0;
assign query_rdata = wb_line[LINE_WIDTH - 1:0];
assign written     = 1'b0;				// cannot write at all
assign full        = (state != IDLE);	// handling burst_wr req
assign pushed      = push & ~full;		// empty, immediately receive data
assign empty       = ~pushed;			// not handling burst_wr req

// state machine(part)
always_comb begin
	wb_addr_n = wb_addr;
	wb_line_n = wb_line;
	case(state)
		IDLE: begin
			wb_addr_n = {pline[LINE_WIDTH +: LABEL_WIDTH], {LINE_BYTE_OFFSET{1'b0}}};
			wb_line_n = pline[LINE_WIDTH - 1:0];
		end
	endcase
end
`endif

// state machine
always_comb begin
	state_n = state;
	wb_vld_n = wb_vld;
	wb_burst_cnt_n = wb_burst_cnt;

	// AXI default value
	axi3_wr_if.axi3_wr_req.awvalid = 1'b0;
	axi3_wr_if.axi3_wr_req.wvalid  = 1'b0;
	axi3_wr_if.axi3_wr_req.bready  = 1'b1;		// Ignores bresp

	axi3_wr_if.awid = AWID;
	axi3_wr_if.wid  = AWID;

	axi3_wr_if.axi3_wr_req.awsize  = 2'b010;
	axi3_wr_if.axi3_wr_req.awlen   = BURST_LIMIT;
	axi3_wr_if.axi3_wr_req.awburst = 2'b01;
	axi3_wr_if.axi3_wr_req.awaddr  = wb_addr;
	axi3_wr_if.axi3_wr_req.awlock  = '0;
	axi3_wr_if.axi3_wr_req.awprot  = '0;
	axi3_wr_if.axi3_wr_req.awcache = '0;

	axi3_wr_if.axi3_wr_req.wdata = wb_burst_line[wb_burst_cnt];
	axi3_wr_if.axi3_wr_req.wlast = wb_burst_cnt == BURST_LIMIT[LINE_BYTE_OFFSET - 1:0];
	axi3_wr_if.axi3_wr_req.wstrb = 4'b1111;

	case(state)
		IDLE: begin
			if(~empty) begin
				wb_vld_n = 1'b1;
				state_n  = WAIT_AWREADY;
			end
		end

		WAIT_AWREADY: begin
			axi3_wr_if.axi3_wr_req.awvalid = 1'b1;

			wb_burst_cnt_n = '0;

			if(axi3_wr_if.axi3_wr_resp.awready) begin
				state_n = WRITE;
			end
		end

		WRITE: begin
			axi3_wr_if.axi3_wr_req.wvalid = 1'b1;

			if(axi3_wr_if.axi3_wr_resp.wready) begin
				wb_burst_cnt_n += 1;
			end

			if(axi3_wr_if.axi3_wr_resp.wready && axi3_wr_if.axi3_wr_req.wlast) begin
				state_n = WAIT_BVALID;
			end
		end

		WAIT_BVALID: begin
			if(axi3_wr_if.axi3_wr_resp.bvalid)
				state_n = IDLE;
		end
	endcase
end

// update common logic
always_ff @ (posedge clk) begin
	if (rst) begin
		state   <= IDLE;
		wb_addr <= '0;
		wb_line <= '0;
		wb_vld  <= '0;
		wb_burst_cnt <= '0;
	end else begin
		state   <= state_n;
		wb_addr <= wb_addr_n;
		wb_line <= wb_line_n;
		wb_vld  <= wb_vld_n;
		wb_burst_cnt <= wb_burst_cnt_n;
	end
end

endmodule
