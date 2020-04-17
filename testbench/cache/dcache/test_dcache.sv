// test dcache
`include "test_dcache.svh"

module test_dcache #(
    // common parameter
    parameter   BUS_WIDTH               =   4,
    parameter   DATA_WIDTH              =   32,
    // parameter for mem_device
    parameter   ADDR_WIDTH              =   24,
    // parameter for dcache
    parameter   LINE_WIDTH              =   256, 
    parameter   SET_ASSOC               =   2,      // 4,
    parameter   CACHE_SIZE              =   8 * 1024 * 8,       // 16 * 1024 * 8,
    parameter   WB_LINE_DEPTH           =   8,
    parameter   AID                     =   1,
    parameter   VICTIM_CACHE_ENABLED    =   1,
    parameter   PASS_DATA_DEPTH         =   8,
    parameter   PASS_AID                =   2,
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
    `ifdef TEST_DCACHE_UNCACHED_REQ
    .axi3_rd_if(axi3_rd_if_uncached),
    .axi3_wr_if(axi3_wr_if_uncached),
    `endif
    .*
);

// record
string summary;
bit delayed_stall;
integer stall_cnt, wr_cnt, rd_cnt, cycle;
logic [$clog2(N_REQ + 3):0] req;
// for sim compare
logic [N_REQ - 1:0][DATA_WIDTH - 1:0] addr;
logic [N_REQ - 1:0][DATA_WIDTH - 1:0] data;
logic [N_REQ - 1:0][(DATA_WIDTH / $bits(uint8_t)) - 1:0] be;
req_type_t req_type[N_REQ - 1:0];
req_type_t curr_type;
byte mode [N_REQ - 1:0];
// dtlb signals
virt_t dtlb_i;
phys_t dtlb_o;

// record performence
always_ff @ (posedge clk) begin
    if (sync_rst) begin
        delayed_stall <= 1'b0;
    end else begin
        delayed_stall <= ~dbus.ready;
    end
end
always_ff @ (posedge clk) begin
    if (sync_rst) begin
        stall_cnt <= 0;
    end else if (~dbus.ready & ~delayed_stall) begin
        stall_cnt <= stall_cnt + 1;
    end
end
always_ff @ (posedge sync_rst or posedge axi3_rd_if.axi3_rd_req.arvalid) begin
    if (sync_rst) begin
        rd_cnt <= 0;
    end else begin
        rd_cnt <= rd_cnt + 1;
    end
end
always_ff @ (posedge sync_rst or posedge axi3_wr_if.axi3_wr_req.awvalid) begin
    if (sync_rst) begin
        wr_cnt <= 0;
    end else begin
        wr_cnt <= wr_cnt + 1;
    end
end
// reset control signals
`ifdef TEST_DCACHE_UNCACHED_REQ
assign dbus.dcache_req.uncached = 1'b1;
`else
assign dbus.dcache_req.uncached = 1'b0;
`endif
// dtlb_o
always_ff @ (posedge clk) begin
    if (sync_rst) begin
        dtlb_o <= '0;
    end else if (dbus.ready) begin
        dtlb_o <= dtlb_i;
    end
end
assign dbus.dcache_req.paddr   = dtlb_o;

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
        for (int i = 0; i < n_req; i++) begin
            if (with_be == 1)
                $fscanf(fdat, "%c %h %h %h\n", mode[i], addr[i], data[i], be[i]);
            else begin
                $fscanf(fdat, "%c %h %h\n", mode[i], addr[i], data[i]);
                be[i] = '1;     // write word
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
        // reset mem_device_inst
        for (int i = 0; i <= {(ADDR_WIDTH - $clog2(DATA_WIDTH / $bits(uint8_t))){1'b1}}; ++i) begin
            mem_device_inst.ram.mem[i] = '0;
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
    req   = 0;
    // reset ctrl signals
    dbus.dcache_req.inv    = 1'b0;
    dbus.dcache_req.read   = 1'b0;
    dbus.dcache_req.write  = 1'b0;
    dbus.dcache_req.vaddr  = '0;
    dbus.dcache_req.wrdata = '0;
    dbus.dcache_req.be     = '0;
    while (req <= n_req) begin
        // wait negedge clk to ensure line_data already update
        @ (negedge clk);
        cycle = cycle + 1;

        // reset control signals
        dbus.dcache_req.inv   = 1'b0;
        dbus.dcache_req.read  = 1'b0;
        dbus.dcache_req.write = 1'b0;

        // check req - 1(only read)
        if (dbus.dcache_resp.valid) begin
            $display("[%0d] req = %0d, data = %08x", cycle, req - 1, dbus.dcache_resp.rddata);
            if (req_type[req - 1] == READ && ~(dbus.dcache_resp.rddata === data[req - 1])) begin
                $display("[Error] expected = %08x", data[req - 1]);
                $stop;
            end
        end

        // issue req
        if (dbus.ready) begin
            curr_type  = req_type[req];
            dtlb_i     = addr[req];
            dbus.dcache_req.vaddr  = dtlb_i;
            dbus.dcache_req.inv    = curr_type == INV;
            dbus.dcache_req.read   = curr_type == READ;
            dbus.dcache_req.write  = curr_type == WRITE;
            dbus.dcache_req.wrdata = data[req];
            dbus.dcache_req.be     = be[req];
            req = req + 1;
        end
    end

    // show performence
    begin
        $sformat(summary, "%0s%0s\n  [pass]\n", summary, name);
        $sformat(summary, "%0s    Stall count: %d\n", summary, stall_cnt);
        $sformat(summary, "%0s    Read  count: %d\n", summary, rd_cnt);
        $sformat(summary, "%0s    Write count: %d\n", summary, wr_cnt);
    end

    $sformat(summary, "%0s  [OK] %0s\n", summary, name);
    $sformat(summary, "%0s  %0s: cycle = %d\n", summary, name, cycle);
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
    unittest("test_inv", 8, 1);
    unittest("mem_bitcount", 3800, 0);
    unittest("mem_bubble_sort", 61613, 0);
    unittest("mem_dc_coremark", 82967, 0);
    unittest("mem_quick_sort", 38517, 0);
    unittest("mem_select_sort", 21594, 0);
    unittest("mem_stream_copy", 39924, 0);
    unittest("mem_string_search", 33101, 0);
    unittest("random.2", 50000, 0);
    unittest("random.be", 50000, 1);
    unittest("random", 50000, 0);
    unittest("sequential", 32768, 0);
    unittest("simple", 10, 0);
    $display("summary: %0s", summary);
    $stop;
end

// expr result(3-stage)
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

// expr result(1-stage, SET_ASSOC = 4)
// test_inv
//   [pass]
//     Stall count:           6
//     Read  count:           2
//     Write count:           1
//   [OK] test_inv
//   test_inv: cycle =         170
// mem_bitcount
//   [pass]
//     Stall count:          26
//     Read  count:          25
//     Write count:           0
//   [OK] mem_bitcount
//   mem_bitcount: cycle =        4203
// mem_bubble_sort
//   [pass]
//     Stall count:          89
//     Read  count:          88
//     Write count:           0
//   [OK] mem_bubble_sort
//   mem_bubble_sort: cycle =       62709
// mem_dc_coremark
//   [pass]
//     Stall count:          77
//     Read  count:          76
//     Write count:           0
//   [OK] mem_dc_coremark
//   mem_dc_coremark: cycle =       83931
// mem_quick_sort
//   [pass]
//     Stall count:         391
//     Read  count:         390
//     Write count:           0
//   [OK] mem_quick_sort
//   mem_quick_sort: cycle =       42935
// mem_select_sort
//   [pass]
//     Stall count:          89
//     Read  count:          88
//     Write count:           0
//   [OK] mem_select_sort
//   mem_select_sort: cycle =       22690
// mem_stream_copy
//   [pass]
//     Stall count:          85
//     Read  count:          84
//     Write count:           0
//   [OK] mem_stream_copy
//   mem_stream_copy: cycle =       40976
// mem_string_search
//   [pass]
//     Stall count:         154
//     Read  count:         153
//     Write count:           0
//   [OK] mem_string_search
//   mem_string_search: cycle =       34912
// random.2
//   [pass]
//     Stall count:        9341
//     Read  count:        4444
//     Write count:        3932
//   [OK] random.2
//   random.2: cycle =      158842
// random.be
//   [pass]
//     Stall count:        9445
//     Read  count:        4487
//     Write count:        3951
//   [OK] random.be
//   random.be: cycle =      159281
// random
//   [pass]
//     Stall count:        9613
//     Read  count:        4564
//     Write count:        4005
//   [OK] random
//   random: cycle =      161304
// sequential
//   [pass]
//     Stall count:         513
//     Read  count:         512
//     Write count:           0
//   [OK] sequential
//   sequential: cycle =       38528
// simple
//   [pass]
//     Stall count:           2
//     Read  count:           1
//     Write count:           0
//   [OK] simple
//   simple: cycle =         149

// expr result(1-stage, SET_ASSOC = 2)
// test_inv
//   [pass]
//     Stall count:           6
//     Read  count:           2
//     Write count:           1
//   [OK] test_inv
//   test_inv: cycle =         166
// mem_bitcount
//   [pass]
//     Stall count:          26
//     Read  count:          25
//     Write count:           0
//   [OK] mem_bitcount
//   mem_bitcount: cycle =        4203
// mem_bubble_sort
//   [pass]
//     Stall count:          89
//     Read  count:          88
//     Write count:           0
//   [OK] mem_bubble_sort
//   mem_bubble_sort: cycle =       62709
// mem_dc_coremark
//   [pass]
//     Stall count:          77
//     Read  count:          76
//     Write count:           0
//   [OK] mem_dc_coremark
//   mem_dc_coremark: cycle =       83931
// mem_quick_sort
//   [pass]
//     Stall count:         396
//     Read  count:         395
//     Write count:          69
//   [OK] mem_quick_sort
//   mem_quick_sort: cycle =       42990
// mem_select_sort
//   [pass]
//     Stall count:          89
//     Read  count:          88
//     Write count:           0
//   [OK] mem_select_sort
//   mem_select_sort: cycle =       22690
// mem_stream_copy
//   [pass]
//     Stall count:          85
//     Read  count:          84
//     Write count:           0
//   [OK] mem_stream_copy
//   mem_stream_copy: cycle =       40976
// mem_string_search
//   [pass]
//     Stall count:         154
//     Read  count:         153
//     Write count:           0
//   [OK] mem_string_search
//   mem_string_search: cycle =       34912
// random.2
//   [pass]
//     Stall count:        9341
//     Read  count:        4444
//     Write count:        3932
//   [OK] random.2
//   random.2: cycle =      149084
// random.be
//   [pass]
//     Stall count:        9445
//     Read  count:        4487
//     Write count:        3951
//   [OK] random.be
//   random.be: cycle =      149390
// random
//   [pass]
//     Stall count:        9613
//     Read  count:        4564
//     Write count:        4005
//   [OK] random
//   random: cycle =      151241
// sequential
//   [pass]
//     Stall count:        1025
//     Read  count:        1024
//     Write count:         512
//   [OK] sequential
//   sequential: cycle =       44150
// simple
//   [pass]
//     Stall count:           2
//     Read  count:           1
//     Write count:           0
//   [OK] simple
//   simple: cycle =         149

// expr result(1-stage, uncached)
// test_inv
//   [pass]
//     Stall count:           6
//     Read  count:           0
//     Write count:           0
//   [OK] test_inv
//   test_inv: cycle =         160
// mem_bitcount
//   [pass]
//     Stall count:        2912
//     Read  count:           0
//     Write count:           0
//   [OK] mem_bitcount
//   mem_bitcount: cycle =       18232
// mem_bubble_sort
//   [pass]
//     Stall count:       40597
//     Read  count:           0
//     Write count:           0
//   [OK] mem_bubble_sort
//   mem_bubble_sort: cycle =      287174
// mem_dc_coremark
//   [pass]
//     Stall count:       66948
//     Read  count:           0
//     Write count:           0
//   [OK] mem_dc_coremark
//   mem_dc_coremark: cycle =      398585
// mem_quick_sort
//   [pass]
//     Stall count:       28128
//     Read  count:           0
//     Write count:           0
//   [OK] mem_quick_sort
//   mem_quick_sort: cycle =      182244
// mem_select_sort
//   [pass]
//     Stall count:       20884
//     Read  count:           0
//     Write count:           0
//   [OK] mem_select_sort
//   mem_select_sort: cycle =      107385
// mem_stream_copy
//   [pass]
//     Stall count:       30344
//     Read  count:           0
//     Write count:           0
//   [OK] mem_stream_copy
//   mem_stream_copy: cycle =      189895
// mem_string_search
//   [pass]
//     Stall count:       26741
//     Read  count:           0
//     Write count:           0
//   [OK] mem_string_search
//   mem_string_search: cycle =      145246
// random.2
//   [pass]
//     Stall count:       29884
//     Read  count:           0
//     Write count:           0
//   [OK] random.2
//   random.2: cycle =      218179
// random.be
//   [pass]
//     Stall count:       30167
//     Read  count:           0
//     Write count:           0
//   [OK] random.be
//   random.be: cycle =      218425
// random
//   [pass]
//     Stall count:       29948
//     Read  count:           0
//     Write count:           0
//   [OK] random
//   random: cycle =      217844
// sequential
//   [pass]
//     Stall count:       32758
//     Read  count:           0
//     Write count:           0
//   [OK] sequential
//   sequential: cycle =      147584
// simple
//   [pass]
//     Stall count:           5
//     Read  count:           0
//     Write count:           0
//   [OK] simple
//   simple: cycle =         172

endmodule
