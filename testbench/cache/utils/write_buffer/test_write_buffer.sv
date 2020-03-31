// test write_buffer
`include "test_write_buffer.svh"

module test_write_buffer #(
	// common parameter
	parameter	BUS_WIDTH	=	4,
	parameter	LINE_DEPTH	=	8,
	// parameter for identity_device
	parameter	ADDR_WIDTH	=	32,
	parameter	DATA_WIDTH	=	32,
	// parameter for write_buffer
	parameter	LINE_WIDTH	=	256,
	parameter	AWID		=	2,
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

);

// gen clk & sync_rst
logic clk, rst, sync_rst;
sim_clock sim_clock_inst(.*);
always_ff @ (posedge clk) begin
	sync_rst <= rst;
end

// interface define
axi3_wr_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_wr_if();
axi3_rd_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_rd_if();
line_t pline;
logic full, push, pushed;
label_t query_label;
logic query_found, query_on_pop, write, written;
data_t query_wdata, query_rdata;
be_t query_wbe;
logic query_found_wb;
logic [LINE_WIDTH - 1:0] line_recv;
logic line_recv_vld;
// inst module
write_buffer #(
	.LINE_WIDTH(LINE_WIDTH),
	.AWID(AWID),
	`ifdef VICTIM_CACHE_ENABLE
	.LINE_DEPTH(LINE_DEPTH),
	`endif
	// parameter for type
	.line_t(line_t),
	.label_t(label_t),
	.data_t(data_t),
	.be_t(be_t)
) write_buffer_inst (
	.rst(sync_rst),
	.*
);
identity_device #(
	.ADDR_WIDTH(ADDR_WIDTH),
	.DATA_WIDTH(DATA_WIDTH),
	.LINE_WIDTH(LINE_WIDTH)
) identity_device_inst (
	.rst(sync_rst),
	.*
);

// record
string summary;

task unittest_(
	input string name
);
	string fans_name, fans_path, freq_name, freq_path, out;
	integer fans, freq, cycle, req_counter, ans_counter;
	string req, req_type;
	label_t req1;
	data_t req2;
	be_t req3;

	fans_name = {name, ".ans"};
	fans_path = get_path(fans_name);
	if (fans_path == "") begin
		$display("[Error] file[%0s] not found!", fans_name);
		$stop;
	end
	freq_name = {name, ".req"};
	freq_path = get_path(freq_name);
	if (freq_path == "") begin
		$display("[Error] file[%0s] not found!", freq_name);
		$stop;
	end

	// get file pointer
	begin
		fans = $fopen({fans_path}, "r");
		freq = $fopen({freq_path}, "r");
	end

	// reset inst
	begin
		rst = 1'b1;
		#50 rst = 1'b0;
	end

	$display("======= unittest: %0s =======", name);

	// reset ans_counter & req_counter & cycle
	ans_counter = 0;
	req_counter = 0;
	cycle = 0;
	while (!$feof(fans)) begin
		// wait negedge clk to ensure line_data already update
		@ (negedge clk);
		cycle = cycle + 1;

		// check ans
		if (line_recv_vld) begin
			// format output
			$sformat(out, {"%x"}, line_recv);
			judge(fans, ans_counter, out);
			ans_counter = ans_counter + 1;
		end

		// issue req
		// reset control signals
		push = 1'b0;
		write = 1'b0;
		`ifdef VICTIM_CACHE_ENABLE
		// issue every period
		if (!$feof(freq)) begin
			$fscanf(freq, "%s %x %x %x\n", req_type, req1, req2, req3);
			req_counter = req_counter + 1;
			// set corresponding value
			if (req_type == "push") begin
				push = 1'b1;
				pline = {req1, req2};
			end else if (req_type == "write") begin
				write = 1'b1;
				query_label = req1;
				query_wdata = req2;
				query_wbe = req3;
			end else if (req_type == "skip") begin
				// do nothing
			end else begin
				$display("[ERROR] unknown req_type(%s)!", req_type);
				$stop;
			end
		end
		`else
		// issue when not full(means ready to accept next pline
		if (~full) begin
			if (!$feof(freq)) begin
				$fscanf(freq, "%s %x %x %x\n", req_type, req1, req2, req3);
				req_counter = req_counter + 1;
				// set corresponding value
				if (req_type == "push") begin
					push = 1'b1;
					pline = {req1, req2};
				end else if (req_type == "skip") begin
				// do nothing
				end else begin
					$display("[ERROR] unknown req_type(%s)!", req_type);
					$stop;
				end
			end
		end
		`endif
	end

	$display("[OK] %0s\n", name);
	$sformat(summary, "%0s%0s: cycle = %d\n", summary, name, cycle);
endtask

task unittest(
	input string name
);
	unittest_(name);
endtask

initial begin
	wait(rst == 1'b0);
	summary = "";
	`ifdef VICTIM_CACHE_ENABLE
	unittest("write");
	unittest("full");
	`else
	unittest("nonvc");
	`endif
	$display("summary: %0s", summary);
	$stop;
end

endmodule
