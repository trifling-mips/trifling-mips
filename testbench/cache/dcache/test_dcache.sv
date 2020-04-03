// test dcache
`include "test_dcache.svh"

module test_dcache #(
	// common parameter
	parameter	BUS_WIDTH		=	4,
	parameter	DATA_WIDTH		=	32,
	// parameter for mem_device
	parameter	ADDR_WIDTH		=	24,
	// parameter for dcache
	parameter	LINE_WIDTH		=	256, 
	parameter	SET_ASSOC		=	4,
	parameter	CACHE_SIZE		=	16 * 1024 * 8,
	parameter	WB_LINE_DEPTH	=	8,
	parameter	AID				=	1,
	parameter	PASS_DATA_DEPTH	=	8,
	parameter	PASS_AID		=	2,
	// local parameter
	localparam int unsigned N_REQ = 100000
) (

);

// gen clk & sync_rst
logic clk, rst, sync_rst;
sim_clock sim_clock_inst(.*);
always_ff @ (posedge clk) begin
	sync_rst <= rst;
end

// interface define
cpu_dbus_if dbus();
axi3_rd_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_rd_if();
axi3_wr_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_wr_if();
axi3_rd_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_rd_if_uncached();
axi3_wr_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_wr_if_uncached();
// inst module
dcache #(
	.BUS_WIDTH(BUS_WIDTH),
	.DATA_WIDTH(DATA_WIDTH), 
	.LINE_WIDTH(LINE_WIDTH), 
	.SET_ASSOC(SET_ASSOC),
	.CACHE_SIZE(CACHE_SIZE),
	.WB_LINE_DEPTH(WB_LINE_DEPTH),
	.AID(AID),
	.PASS_DATA_DEPTH(PASS_DATA_DEPTH),
	.PASS_AID(PASS_AID)
) dcache_inst (
	.rst(sync_rst),
	.*
);
mem_device #(
	.BUS_WIDTH(BUS_WIDTH),
	.ADDR_WIDTH(ADDR_WIDTH),
	.DATA_WIDTH(DATA_WIDTH)
) mem_device_inst (
	.rst(sync_rst),
	.*
);

// record
string summary;
integer stall_cnt, wr_cnt, rd_cnt, cycle;
logic [$clog2(N_REQ + 3):0] req;
// for sim compare
logic [N_REQ + 3:0][DATA_WIDTH - 1:0] addr;
logic [N_REQ + 3:0][DATA_WIDTH - 1:0] data;
logic [N_REQ + 3:0][(DATA_WIDTH / $bits(uint8_t)) - 1:0] be;
req_type_t req_type[N_REQ + 3:0];
req_type_t curr_type;
byte mode [N_REQ - 1:0];

// record performence
always_ff @ (posedge sync_rst or posedge dbus.stall) begin
	if(sync_rst) begin
		stall_cnt <= 0;
	end else begin
		stall_cnt <= stall_cnt + 1;
	end
end
always_ff @ (posedge sync_rst or posedge axi3_rd_if.axi3_rd_req.arvalid) begin
	if(sync_rst) begin
		rd_cnt <= 0;
	end else begin
		rd_cnt <= rd_cnt + 1;
	end
end
always_ff @ (posedge sync_rst or posedge axi3_wr_if.axi3_wr_req.awvalid) begin
	if(sync_rst) begin
		wr_cnt <= 0;
	end else begin
		wr_cnt <= wr_cnt + 1;
	end
end
// record test state
always_ff @ (posedge clk or posedge sync_rst) begin
	if(sync_rst) begin
		req <= '0;
	end else if (~dbus.stall) begin
		req <= req + 1;
	end
end
// reset control signals
assign dbus.inv_icache       = 1'b0;
assign dbus.lsu_req.uncached = 1'b0;
assign dbus.lsu_req.lsu_idx  = 1;
// issue req
assign curr_type               = req_type[req];
assign dbus.lsu_req.addr       = addr[req];
assign dbus.lsu_req.wrdata     = data[req];
assign dbus.lsu_req.read       = curr_type == READ;
assign dbus.lsu_req.write      = curr_type == WRITE;
assign dbus.inv_dcache         = curr_type == INV;
assign dbus.lsu_req.be         = be[req];

task unittest_(
	input string name,
	input integer n_req,
	input integer with_be
);
	// sim fpointer
	string fdat_name, fdat_path;
	integer fdat, ans;

	// setup sim status
	fdat_name = {name, ".data"};
	fdat_path = get_path(fdat_name);
	if (fdat_path == "") begin
		$display("[Error] file[%0s] not found!", fdat_name);
		$stop;
	end
	// load sim status
	begin
		fdat = $fopen({fdat_path}, "r");
		for(int i = 0; i < n_req; i++) begin
			if (with_be == 1)
				$fscanf(fdat, "%c %h %h %h\n", mode[i], addr[i], data[i], be[i]);
			else begin
				$fscanf(fdat, "%c %h %h\n", mode[i], addr[i], data[i]);
				be[i] = '1;		// write word
			end
			case (mode[i])
				"r": req_type[i] = READ;
				"w": req_type[i] = WRITE;
				"i": req_type[i] = INV;
			endcase
		end
		for (int i = n_req; i < N_REQ; i++) begin
			addr[i]     = '1;
			data[i]     = '1;
			be[i]       = '1;
			req_type[i] = NOP;
		end
	end

	// reset inst
	begin
		rst = 1'b1;
		#50 rst = 1'b0;
	end

	$display("======= unittest: %0s =======", name);

	// reset cycle
	cycle = 0;
	ans   = 0;
	while (req < n_req + 3) begin
		// wait negedge clk to ensure line_data already update
		@ (negedge clk);
		cycle = cycle + 1;

		// check ans(only read)
		if (dbus.lsu_resp.rddata_vld) begin
			$display("[%0d] req = %0d, data = %08x", cycle, ans, dbus.lsu_resp.rddata);
			if(req_type[ans] == READ && ~(dbus.lsu_resp.rddata === data[ans])) begin
				$display("[Error] expected = %08x", data[ans]);
				$stop;
			end
			ans = ans + 1;
		end
	end

	// show performence
	begin
		$display("[pass]");
		$display("  Stall count: %d", stall_cnt);
		$display("  Read count: %d", rd_cnt);
		$display("  Write count: %d", wr_cnt);
	end

	$display("[OK] %0s\n", name);
	$sformat(summary, "%0s%0s: cycle = %d\n", summary, name, cycle);
endtask

task unittest(
	input string name,
	input integer n_req,
	input integer with_be
);
	unittest_(name, n_req, with_be);
endtask

initial begin
	wait(rst == 1'b0);
	summary = "";
	// can only unittest one situation, for mem_device will hold mem during initial
	// unittest("test_inv", 6, 1);
	// unittest("mem_bitcount", 3800, 0);
	// unittest("mem_bubble_sort", 61613, 0);
	// unittest("mem_dc_coremark", 82967, 0);
	// unittest("mem_quick_sort", 38517, 0);
	// unittest("mem_select_sort", 21594, 0);
	// unittest("mem_stream_copy", 39924, 0);
	// unittest("mem_string_search", 33101, 0);
	// unittest("random.2", 50000, 0);
	// unittest("random.be", 50000, 1);
	// unittest("random", 50000, 0);
	// unittest("sequential", 32768, 0);
	unittest("simple", 10, 0);
	$display("summary: %0s", summary);
	$stop;
end

// expr result
// test_inv
//   [pass]
//     Stall count:           7
//     Read count:           2
//     Write count:           1
//   [OK] test_inv
//   summary: test_inv: cycle =         171
// mem_bitcount
//   [pass]
//     Stall count:          47
//     Read count:          34
//     Write count:           0
//   [OK] mem_bitcount
//   summary: mem_bitcount: cycle =        4166
// mem_bubble_sort
//   [pass]
//     Stall count:         174
//     Read count:         118
//     Write count:           0
//   [OK] mem_bubble_sort
//   summary: mem_bubble_sort: cycle =       62456
// mem_dc_coremark
//   [pass]
//     Stall count:         142
//     Read count:         109
//     Write count:           0
//   [OK] mem_dc_coremark
//   summary: mem_dc_coremark: cycle =       83677
// mem_quick_sort
//   [pass]
//     Stall count:         778
//     Read count:         525
//     Write count:           0
//   [OK] mem_quick_sort
//   summary: mem_quick_sort: cycle =       41704
// mem_select_sort
//   [pass]
//     Stall count:         174
//     Read count:         118
//     Write count:           0
//   [OK] mem_select_sort
//   summary: mem_select_sort: cycle =       22437
// mem_stream_copy
//   [pass]
//     Stall count:         165
//     Read count:          91
//     Write count:           0
//   [OK] mem_stream_copy
//   summary: mem_stream_copy: cycle =       40315
// mem_string_search
//   [pass]
//     Stall count:         303
//     Read count:         579
//     Write count:           0
//   [OK] mem_string_search
//   summary: mem_string_search: cycle =       34525
// random.2
//   [pass]
//     Stall count:       20297
//     Read count:        6150
//     Write count:        3932
//   [OK] random.2
//   summary: random.2: cycle =      161979
// random.be
//   [pass]
//     Stall count:       20548
//     Read count:        6198
//     Write count:        3951
//   [OK] random.be
//   summary: random.be: cycle =      162786
// random
//   [pass]
//     Stall count:       20805
//     Read count:        6257
//     Write count:        4005
//   [OK] random
//   summary: random: cycle =      164583
// sequential
//   [pass]
//     Stall count:        1024
//     Read count:         513
//     Write count:           0
//   [OK] sequential
//   summary: sequential: cycle =       38531
// simple
//   [pass]
//     Stall count:           2
//     Read count:           2
//     Write count:           0
//   [OK] simple
//   summary: simple: cycle =         152


endmodule
