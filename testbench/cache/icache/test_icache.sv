// test icache
`include "test_icache.svh"

module test_icache #(
	// common parameter
	parameter	BUS_WIDTH	=	4,
	parameter	DATA_WIDTH	=	32,
	// parameter for mem_device
	parameter	ADDR_WIDTH	=	16,
	// parameter for icache
	parameter	LINE_WIDTH	=	256,
	parameter	SET_ASSOC	=	4,
	parameter	CACHE_SIZE	=	16 * 1024 * 8,
	parameter	ARID		=	0
) (

);

// define funcs
`DEF_FUNC_GET_REQ

// gen clk & sync_rst
logic clk, rst, sync_rst;
sim_clock sim_clock_inst(.*);
always_ff @ (posedge clk) begin
	sync_rst <= rst;
end

// interface define
logic inv_icache;
logic [31:0] inv_addr;
cpu_ibus_if ibus();
axi3_rd_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_rd_if();
axi3_wr_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_wr_if();
// inst module
icache #(
	.DATA_WIDTH(DATA_WIDTH),
	.LINE_WIDTH(LINE_WIDTH),
	.SET_ASSOC(SET_ASSOC),
	.CACHE_SIZE(CACHE_SIZE),
	.ARID(ARID)
) icache_inst (
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
		inv_icache = 1'b0;
		inv_addr = '0;
		ibus.read = 1'b0;
		ibus.flush_1 = 1'b0;
		ibus.flush_2 = 1'b0;
		ibus.flush_3 = 1'b0;

		// issue req
		if (~ibus.stall && ibus.ready && !$feof(freq)) begin
			$fscanf(freq, "%x %x %x %x\n", ibus.addr, ibus.flush_1, ibus.flush_2, ibus.flush_3);
			ibus.addr = {{($bits(phys_t) - ADDR_WIDTH){1'b0}}, ibus.addr[ADDR_WIDTH - 1:0]};
			ibus.read = 1'b1;
			req_counter = req_counter + 1;
		end

		// check ans
		if (ibus.rddata_vld) begin
			$sformat(out, {"%x"}, ibus.rddata);
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
	unittest("sequential");
	unittest("random");
	unittest("sequ_rand");
	// testcases are wrong, flush_3 after stall cause data-unmatch
	// unittest("sequential_flush");
	// unittest("random_flush");
	// unittest("sequ_rand_flush");
	$display("summary: %0s", summary);
	$stop;
end

// expr result
// 1 with prefetch 100 * req
//   sequential: cycle =         327
//   random:     cycle =        1320
//   sequ_rand:  cycle =         656
// 1 without prefetch 100 * req
//   sequential: cycle =         387
//   random:     cycle =        1320
//   sequ_rand:  cycle =         606
// 2 with prefetch 1000 * req (max_sequ = 10)
//   sequential: cycle =        1762
//   random:     cycle =       10562
//   sequ_rand:  cycle =        4625
// 2 without prefetch 1000 * req (max_sequ = 10)
//   sequential: cycle =        2506
//   random:     cycle =       10393
//   sequ_rand:  cycle =        3991
// 3 with prefetch 1000 * req (max_sequ = 50)
//   sequential: cycle =        1762
//   random:     cycle =       10497
//   sequ_rand:  cycle =        2485
// 3 without prefetch 1000 * req (max_sequ = 50)
//   sequential: cycle =        2506
//   random:     cycle =       10294
//   sequ_rand:  cycle =        2869
// 4 with prefetch 1000 * req (max_sequ = 20)
//   sequential: cycle =        1762
//   random:     cycle =       10500
//   sequ_rand:  cycle =        3519
// 4 without prefetch 1000 * req (max_sequ = 20)
//   sequential: cycle =        2506
//   random:     cycle =       10305
//   sequ_rand:  cycle =        3419
// 5 with prefetch 1000 * req (max_sequ = 30)
//   sequential: cycle =        1762
//   random:     cycle =       10568
//   sequ_rand:  cycle =        2798
// 5 without prefetch 1000 * req (max_sequ = 30)
//   sequential: cycle =        2506
//   random:     cycle =       10360
//   sequ_rand:  cycle =        3001
// 6 with prefetch 1000 * req (max_sequ = 25)
//   sequential: cycle =        1762
//   random:     cycle =       10380
//   sequ_rand:  cycle =        2859
// 6 without prefetch 1000 * req (max_sequ = 25)
//   sequential: cycle =        2506
//   random:     cycle =       10195
//   sequ_rand:  cycle =        3045

endmodule
