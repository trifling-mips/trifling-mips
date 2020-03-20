// victim_cache for cache store before wb_fifo
`include "victim_cache.svh"

module victim_cache #(
	parameter	LINE_WIDTH	=	256,
	parameter	LINE_DEPTH	=	8,		// need greater than 1(2 ** x)
	// local parameter
	localparam	LINE_BYTE_OFFSET	=	$clog2(LINE_WIDTH / $bits(uint8_t)),
	localparam	LABEL_WIDTH			=	($bits(phys_t) - LINE_BYTE_OFFSET),
	localparam	ADDR_WIDTH			=	(LINE_DEPTH == 0) ? 0 : $clog2(LINE_DEPTH),
	// parameter for type
	parameter type line_t  = logic [LABEL_WIDTH + LINE_WIDTH - 1:0],
	parameter type label_t = logic [LABEL_WIDTH - 1:0],
	parameter type data_t  = logic [LINE_WIDTH  - 1:0],
	parameter type be_t    = logic [(LINE_WIDTH / $bits(uint8_t)) - 1:0]
) (
	input	logic	clk,
	input	logic	rst,

	// fifo signals
	output	line_t	rline,
	input	line_t	pline,
	output	logic	full,
	output	logic	empty,
	input	logic	pop,
	input	logic	push,
	output	logic	pushed,

	// query signals
	input	label_t	query_label,
	output	logic	query_found,
	input	data_t	query_wdata,
	output	data_t	query_rdata,
	input	be_t	query_wbe,
	input	logic	write,
	output	logic	written
);

generate if (LINE_DEPTH == 0) begin
	// 0-depth fallthrough
	// because this is a 0-depth fallthrough FIFO, random RW never happens
	assign written = 1'b0;
	assign query_found = 1'b0;
	// reject push unless there is a concurrent pop request
	assign full = ~pop;
	assign pushed = pop & push;
	// same for pop
	assign empty = ~push;
	assign rline = pline;
end else begin
	// type define
	typedef logic [ADDR_WIDTH - 1:0] addr_t;

	// pointer
	addr_t head, head_n, tail, tail_n;
	// addr_t cnt, cnt_n;
	// mem & valid
	line_t [LINE_DEPTH - 1:0] mem, mem_n;
	logic  [LINE_DEPTH - 1:0] valid, valid_n;

	// hit
	logic [LINE_DEPTH - 1:0] hit, hit_non_pop;
	for(genvar i = 0; i < LINE_DEPTH; i++) begin
		assign hit[i] = valid[i] && mem[i][LINE_WIDTH +: LABEL_WIDTH] == query_label;
		assign hit_non_pop[i] = (pop && head == i[ADDR_WIDTH - 1:0]) ? 1'b0 : hit[i];
	end
	assign query_found = |hit;

	// rdata
	always_comb begin
		query_rdata = '0;

		for(int i = 0; i < LINE_DEPTH; i++) begin
			query_rdata |= hit[i] ? mem[i][0 +: LINE_WIDTH] : '0;
		end
	end

	// Grow --->
	// O O O X X X X O O
	//       H       T
	// assign empty = cnt == '0;
	assign empty = ~|valid;
	// assign full = cnt == LINE_DEPTH[ADDR_WIDTH-1:0];
	assign full = &valid;
	assign rline = mem[head];

	always_comb begin
		// cnt_n = cnt;
		head_n = head;
		tail_n = tail;
		mem_n = mem;
		valid_n = valid;

		written = 1'b0;
		pushed = 1'b0;

		// pop one line, allow push & pop at full
		if(pop && ~empty) begin
			valid_n[head] = 1'b0;

			if(head == LINE_DEPTH[ADDR_WIDTH - 1:0] - 1) begin
				head_n = '0;
			end else begin
				head_n = head + 1;
			end

			// cnt_n = cnt - 1;
		end

		// push one line
		if(push && ~(full && ~pop)) begin
			mem_n[tail] = pline;
			valid_n[tail] = 1'b1;

			if(tail == LINE_DEPTH[ADDR_WIDTH - 1:0] - 1) begin
				tail_n = '0;
			end else begin
				tail_n = tail + 1;
			end

			// cnt_n = cnt+1;

			pushed = 1'b1;
		end

		// push & pop one line
		if(push && ~full && pop && ~empty) begin
			// cnt_n = cnt;
		end

		// write(modify) one line
		if(write && |hit_non_pop) begin
			for(int i = 0; i < LINE_DEPTH; i++) if(hit_non_pop[i])
				for(int j = 0; j < (LINE_WIDTH / $bits(uint8_t)); j++) if(query_wbe[j])
					mem_n[i][j * $bits(uint8_t) +: $bits(uint8_t)] = query_wdata[j * $bits(uint8_t) +: $bits(uint8_t)];

			written = 1'b1;
		end
	end

	always_ff @(posedge clk) begin
		if(rst) begin
			head <= '0;
			tail <= '0;
			// cnt <= '0;
			valid <= '0;
		end else begin
			head <= head_n;
			tail <= tail_n;
			// cnt <= cnt_n;
			valid <= valid_n;
		end
	end

	always_ff @(posedge clk) begin
		if(rst) begin
			mem <= '0;
		end else if(written || pushed) begin
			mem <= mem_n;
		end
	end
end endgenerate

endmodule
