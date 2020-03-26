// test dcache_pass
`include "test_dcache_pass.svh"

module test_dcache_pass #(
	// common parameter
	parameter	BUS_WIDTH	=	4,
	parameter	DATA_WIDTH	=	32,
	// parameter for mem_device
	parameter	ADDR_WIDTH	=	16,
	// parameter for dcache_pass
	// icache - 0(only arid), dcache - 1(both arid and awid), dcache_pass - 2(both arid and awid)
	parameter	ARID			=	2,
	parameter	AWID			=	2,
	parameter	DATA_DEPTH		=	8,
	// local parameter
	localparam int unsigned LABEL_WIDTH = $bits(phys_t) - $clog2(DATA_WIDTH / $bits(uint8_t)),
	// parameter for type
	parameter type be_t    = logic [(DATA_WIDTH / $bits(uint8_t)) - 1:0],
	parameter type label_t = logic [LABEL_WIDTH - 1:0],
	parameter type data_t  = logic [DATA_WIDTH  - 1:0],
	// line_t ls_type(0 - store, l - load) ---- wbe ---- label_t ---- data_t
	parameter type line_t  = logic [$bits(be_t) + $bits(label_t) + $bits(data_t):0]
) (

);

// gen clk & sync_rst
logic clk, rst, sync_rst;
sim_clock sim_clock_inst(.*);
always_ff @ (posedge clk) begin
	sync_rst <= rst;
end

// interface define
line_t pline, rline;
logic push, full;
axi3_rd_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_rd_if();
axi3_wr_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_wr_if();
// inst module
dcache_pass #(
	.DATA_WIDTH(DATA_WIDTH),
	.ARID(ARID),
	.AWID(AWID),
	.DATA_DEPTH(DATA_DEPTH)
) dcache_pass_inst (
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
string mem_prefix = "sequential";

task unittest_(
	input string name
);
	string fmem_name, fmem_path, fans_name, fans_path, freq_name, freq_path, out;
	integer fmem, fans, freq, mem_counter, ans_counter, req_counter, cycle;

	fmem_name = {mem_prefix, ".mem"};
	fmem_path = get_path(fmem_name);
	if (fmem_path == "") begin
		$display("[Error] file[%0s] not found!", fmem_name);
		$stop;
	end
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
		push = 1'b0;

		// issue req
		if (~full && !$feof(freq)) begin
			$fscanf(freq, "%x %x %x %x\n", 
				pline[$bits(line_t) - 1], 
				pline[$bits(line_t) - 2 -: $bits(be_t)], 
				pline[$bits(line_t) - 2 - $bits(be_t) -: $bits(label_t)], 
				pline[$bits(line_t) - 2 - $bits(be_t) - $bits(label_t) -: $bits(data_t)]
			);
			push  = 1'b1;
			req_counter = req_counter + 1;
		end

		// check ans
		if (rline[$bits(line_t) - 1]) begin
			$sformat(out, {"%x-%x-%x-%x"}, 
				rline[$bits(line_t) - 1], 
				rline[$bits(line_t) - 2 -: $bits(be_t)], 
				rline[$bits(line_t) - 2 - $bits(be_t) - $bits(label_t) + ADDR_WIDTH -: ADDR_WIDTH], 
				rline[$bits(line_t) - 2 - $bits(be_t) - $bits(label_t) -: $bits(data_t)]
			);
			judge(fans, ans_counter, out);
			ans_counter = ans_counter + 1;
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
	unittest("random");
	$display("summary: %0s", summary);
	$stop;
end

endmodule
