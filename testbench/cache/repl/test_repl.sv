// test repl
`include "test_repl.svh"

module test_repl #(
	parameter int unsigned SET_ASSOC = 4
) (

);

// gen clk & sync_rst
logic clk, rst, sync_rst;
sim_clock sim_clock_inst(.*);
always_ff @ (posedge clk) begin
	sync_rst <= rst;
end

// interface define
logic [SET_ASSOC - 1:0] access;
logic update;
logic [$clog2(SET_ASSOC) - 1:0] repl_index;
// inst module
generate if (`TEST_REPL_TARGET == "plru") begin
	plru #(
		.SET_ASSOC(SET_ASSOC)
	) plru_inst (
		.*
	);
end else if (`TEST_REPL_TARGET == "repl_fifo") begin
	repl_fifo #(
		.SET_ASSOC(SET_ASSOC)
	) repl_fifo (
		.*
	);
end else begin
	repl_rand #(
		.SET_ASSOC(SET_ASSOC)
	) repl_rand_inst (
		.*
	);
end endgenerate

// record
string summary;

task unittest_(
	input string name
);
	string fans_name, fans_path, freq_name, freq_path, out;
	integer fans, freq, ans_counter, req_counter, cycle;

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

	// get fpointer
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

		// reset control signals
		update = 1'b0;
		access = '0;

		// check ans
		if (req_counter >= 1) begin
			$sformat(out, {"%x"}, repl_index);
			judge(fans, ans_counter, out);
			ans_counter = ans_counter + 1;
		end

		// issue req
		if (!$feof(freq)) begin
			$fscanf(freq, "%x %x\n", access, update);
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
	if (`TEST_REPL_TARGET == "plru") unittest("plru");
	if (`TEST_REPL_TARGET == "repl_fifo") unittest("repl_fifo");
	$display("summary: %0s", summary);
	$stop;
end

endmodule
