// test stream_buffer
`include "test_stream_buffer.svh"

module test_stream_buffer #(
	// common parameter
	parameter	BUS_WIDTH	=	4,
	// parameter for mem_device
	parameter	ADDR_WIDTH	=	16,
	parameter	DATA_WIDTH	=	32,
	// parameter for stream_buffer
	parameter	LINE_WIDTH	=	256,
	parameter	ARID		=	2,
	// local parameter
	localparam	LINE_BYTE_OFFSET	=	$clog2(LINE_WIDTH / 8),
	localparam	LABEL_WIDTH			=	($bits(phys_t) - LINE_BYTE_OFFSET)
) (

);

// define funcs
`DEF_FUNC_GET_REQ

// gen clk & sync_rst
logic clk, rst, sync_rst;
sim_clock m_sim_clock(.*);
always_ff @ (posedge clk) begin
	sync_rst <= rst;
end

// interface define
logic [LABEL_WIDTH - 1:0] label_i;
logic label_i_rdy, inv;
logic [LABEL_WIDTH - 1:0] label_o;	// label(tag + index)
logic [LINE_WIDTH - 1:0]  data;
logic data_vld, ready;
axi3_rd_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_rd_if();
axi3_wr_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_wr_if();
// inst module
stream_buffer #(
	.LINE_WIDTH(LINE_WIDTH),
	.ARID(ARID)
) m_stream_buffer (
	.rst(sync_rst),
	.*
);
mem_device #(
	.BUS_WIDTH(BUS_WIDTH),
	.ADDR_WIDTH(ADDR_WIDTH),
	.DATA_WIDTH(DATA_WIDTH)
) m_mem_device (
	.rst(sync_rst),
	.*
);

// record
string summary;

task unittest_(
	input string name
);
	string fmem_name, fmem_path, fans_name, fans_path, freq_name, freq_path, out;
	integer fmem, fans, freq, mem_counter, ans_counter, req_counter, cycle;

	fmem_name = {name, ".mem"};
	fmem_path = get_path(fmem_name);
	if (fmem_path == "") begin
		$display("[Error] file[%0s] not found!", fmem_name);
		$stop;
	end
	// $display(fmem_path);
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

	// load mem into m_mem_device.ram.mem
	begin
		fmem = $fopen({fmem_path}, "r");
		fans = $fopen({fans_path}, "r");
		freq = $fopen({freq_path}, "r");
		mem_counter = 0;
		while (!$feof(fmem)) begin
			$fscanf(fmem, "%x\n", m_mem_device.ram.mem[mem_counter]);
			// $display("%08x", m_mem_device.ram.mem[mem_counter]);
			mem_counter = mem_counter + 1;
		end
		$fclose(fmem);
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
		// reset control signals
		inv = 1'b0;
		label_i_rdy = 1'b0;
		if (data_vld) begin
			// data is valid, ready to compare
			$sformat(out, {"%x"}, data);
			judge(fans, ans_counter, out);
			ans_counter = ans_counter + 1;
		end

		// issue first req
		if (ready && !$feof(freq)) begin
			label_i = get_req(freq);
			label_i_rdy = 1'b1;
			req_counter = req_counter + 1;
		end
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
	unittest("sequential");
	$display("summary: %0s", summary);
	$stop;
end

endmodule
