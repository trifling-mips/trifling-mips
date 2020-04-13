// test icache
`include "test_icache.svh"

module test_icache #(
    // general parameter
    parameter   BOOT_VEC    =   32'hbfc00000,
    parameter   N_ISSUE     =   1,
    // local parameter
    localparam  LBITS_PC    =   $clog2(N_ISSUE) + 2,
    // common parameter
    parameter   BUS_WIDTH   =   4,
    parameter   DATA_WIDTH  =   32,
    // parameter for mem_device
    parameter   ADDR_WIDTH  =   24,
    // parameter for icache
    parameter   LINE_WIDTH  =   256,
    parameter   SET_ASSOC   =   4,
    parameter   CACHE_SIZE  =   16 * 1024 * 8,
    parameter   ARID        =   0,
    // local parameter
    localparam int unsigned N_REQ = 100000
) (

);

`DEF_FUNC_MUX_BE

// gen clk & sync_rst
logic clk, rst, sync_rst;
sim_clock sim_clock_inst(.*);
always_ff @ (posedge clk) begin
    sync_rst <= rst;
end

// interface define
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

// general
virt_t pc, npc;
always_ff @ (posedge clk) begin
    if (sync_rst) begin
        pc <= {BOOT_VEC[$bits(virt_t) - 1:LBITS_PC] - 1, {LBITS_PC{1'b0}}};
    end else if (ibus.ready) begin
        pc <= npc;
    end
end
// set pc (without TLB)
assign ibus.paddr       = pc;
assign ibus.paddr_plus1 = pc + (1 << $clog2(LINE_WIDTH / 8));

// record
string summary;
string mem_prefix = "sequential";
`ifdef TEST_ICACHE_COMMON_TESTCASES
integer stall_cnt, rd_cnt;
logic [$clog2(N_REQ + 3):0] req;
// for sim compare
logic [N_REQ - 1:0][DATA_WIDTH - 1:0] addr;
logic [N_REQ - 1:0][DATA_WIDTH - 1:0] data;
logic [N_REQ - 1:0][(DATA_WIDTH / $bits(uint8_t)) - 1:0] be;
req_type_t req_type[N_REQ - 1:0];
req_type_t curr_type;
byte mode [N_REQ - 1:0];

// record performence
always_ff @ (posedge sync_rst or posedge ~ibus.ready) begin
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
`endif

`ifndef TEST_ICACHE_COMMON_TESTCASES
task unittest_(
    input string name
);
    string fmem_name, fmem_path, fans_name, fans_path, freq_name, freq_path, out;
    integer fmem, fans, freq, mem_counter, ans_counter, req_counter, cycle;
    logic flush_1, flush_2, flush_3;    // temp useless

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
        ibus.inv  = 1'b0;
        ibus.read = 1'b0;

        // issue req
        if (ibus.ready && !$feof(freq)) begin
            $fscanf(freq, "%x %x %x %x\n", npc, flush_1, flush_2, flush_3);
            npc         = {{($bits(virt_t) - ADDR_WIDTH){1'b0}}, npc[ADDR_WIDTH - 1:0]};
            ibus.vaddr  = npc;
            ibus.read   = 1'b1;
            req_counter = req_counter + 1;
        end

        // check ans
        if (ibus.valid) begin
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
`else
task unittest_(
    input string name,
    input integer n_req,
    input integer with_be
);
    // sim fpointer
    string fdat_name, fdat_path;
    integer fdat, cycle;

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
                be[i] = '1;        // write word
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
    req   = 0;
    while (req <= n_req) begin
        // wait negedge clk to ensure line_data already update
        @ (negedge clk);
        cycle = cycle + 1;

        // reset control signals
        ibus.inv      = 1'b0;
        ibus.inv_addr = '0;
        ibus.read     = 1'b0;

        // check req - 1(only read)
        if (ibus.valid) begin
            $display("[%0d] req = %0d, data = %08x", cycle, req - 1, ibus.rddata);
            if(req_type[req - 1] == READ && ~(ibus.rddata === data[req - 1])) begin
                $display("[Error] expected = %08x", data[req - 1]);
                $stop;
            end
        end

        // issue req
        if (ibus.ready) begin
            curr_type  = req_type[req];
            npc        = addr[req];
            ibus.vaddr = npc;
            ibus.read  = curr_type == READ;
            ibus.inv   = curr_type == WRITE || curr_type == INV;
            if (ibus.inv) ibus.inv_addr = npc;
            if (curr_type == WRITE) begin
                $display("read mem data(%08x): %08x", addr[req], m_mem_device.ram.mem[addr[req][ADDR_WIDTH - 1:$clog2(DATA_WIDTH / $bits(uint8_t))]]);
                m_mem_device.ram.mem[addr[req][ADDR_WIDTH - 1:$clog2(DATA_WIDTH / $bits(uint8_t))]] = mux_be(
                    m_mem_device.ram.mem[addr[req][ADDR_WIDTH - 1:$clog2(DATA_WIDTH / $bits(uint8_t))]],
                    data[req],
                    be[req]
                );
                $display("write mem data: %08x", m_mem_device.ram.mem[addr[req][ADDR_WIDTH - 1:$clog2(DATA_WIDTH / $bits(uint8_t))]]);
            end
            req = req + 1;
        end
    end

    // show performence
    begin
        $display("[pass]");
        $display("  Stall count: %d", stall_cnt);
        $display("  Read count: %d", rd_cnt);
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
`endif

initial begin
    wait(rst == 1'b0);
    summary = "";
    `ifndef TEST_ICACHE_COMMON_TESTCASES
    unittest("sequential");
    unittest("random");
    unittest("sequ_rand");
    // testcases are wrong, flush_3 after stall cause data-unmatch
    // unittest("sequential_flush");
    // unittest("random_flush");
    // unittest("sequ_rand_flush");
    `else
    // can only unittest one situation, for mem_device will hold mem during initial
    // unittest("test_inv", 8, 1);
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
    `endif
    $display("summary: %0s", summary);
    $stop;
end

// expr result (3-stage)
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

// expr result (1-stage)
// 1 with prefetch 100 * req
//   sequential: cycle =           -
//   random:     cycle =           -
//   sequ_rand:  cycle =           -
// 1 without prefetch 100 * req
//   sequential: cycle =           -
//   random:     cycle =           -
//   sequ_rand:  cycle =           -
// 2 with prefetch 1000 * req (max_sequ = 10)
//   sequential: cycle =        1504
//   random:     cycle =        9952
//   sequ_rand:  cycle =        3416
// 2 without prefetch 1000 * req (max_sequ = 10)
//   sequential: cycle =        1628
//   random:     cycle =        9854
//   sequ_rand:  cycle =        3352
// 3 with prefetch 1000 * req (max_sequ = 50)
//   sequential: cycle =        1504
//   random:     cycle =        9965
//   sequ_rand:  cycle =        1940
// 3 without prefetch 1000 * req (max_sequ = 50)
//   sequential: cycle =        1628
//   random:     cycle =        9785
//   sequ_rand:  cycle =        2014
// 4 with prefetch 1000 * req (max_sequ = 20)
//   sequential: cycle =        1504
//   random:     cycle =       10013
//   sequ_rand:  cycle =        2462
// 4 without prefetch 1000 * req (max_sequ = 20)
//   sequential: cycle =        1628
//   random:     cycle =        9836
//   sequ_rand:  cycle =        2430
// 5 with prefetch 1000 * req (max_sequ = 30)
//   sequential: cycle =        1504
//   random:     cycle =        9837
//   sequ_rand:  cycle =        2174
// 5 without prefetch 1000 * req (max_sequ = 30)
//   sequential: cycle =        1628
//   random:     cycle =        9648
//   sequ_rand:  cycle =        2234
// 6 with prefetch 1000 * req (max_sequ = 25)
//   sequential: cycle =        1504
//   random:     cycle =        9899
//   sequ_rand:  cycle =        2368
// 6 without prefetch 1000 * req (max_sequ = 25)
//   sequential: cycle =        1628
//   random:     cycle =        9769
//   sequ_rand:  cycle =        2322

// expr result(1-stage, TEST_ICACHE_COMMON_TESTCASES)
// test_inv
//   [pass]
//     Stall count:           3
//     Read  count:           3
//   [OK] test_inv
//   summary: test_inv:             cycle =         157
// mem_bitcount
//   [pass]
//     Stall count:         767
//     Read  count:         513
//   [OK] mem_bitcount
//   summary: mem_bitcount:         cycle =        7910
// mem_bubble_sort
//   [pass]
//     Stall count:       13360
//     Read  count:       13561
//   [OK] mem_bubble_sort
//   summary: mem_bubble_sort:      cycle =      166213
// mem_dc_coremark
//   [pass]
//     Stall count:       22413
//     Read  count:       16547
//   [OK] mem_dc_coremark
//   summary: mem_dc_coremark:      cycle =      211771
// mem_quick_sort
//   [pass]
//     Stall count:       16949
//     Read  count:       12247
//   [OK] mem_quick_sort
//   summary: mem_quick_sort:       cycle =      145818
// mem_select_sort
//   [pass]
//     Stall count:        1003
//     Read  count:         942
//   [OK] mem_select_sort
//   summary: mem_select_sort:      cycle =       26785
// mem_stream_copy
//   [pass]
//     Stall count:        9214
//     Read  count:        5658
//   [OK] mem_stream_copy
//   summary: mem_stream_copy:      cycle =       8317
// mem_string_search
//   [pass]
//     Stall count:        8596
//     Read  count:        4889
//   [OK] mem_string_search
//   summary: mem_string_search:    cycle =       71712
// random.2
//   [pass]
//     Stall count:       22058
//     Read  count:       17364
//   [OK] random.2
//   summary: random.2:             cycle =      207283
// random.be
//   [pass]
//     Stall count:       22117
//     Read  count:       17246
//   [OK] random.be
//   summary: random.be:            cycle =      205965
// random
//   [pass]
//     Stall count:       22028
//     Read  count:       17245
//   [OK] random
//   summary: random:               cycle =      206250
// sequential
//   [pass]
//     Stall count:         513
//     Read  count:         513
//   [OK] sequential
//   summary: sequential:           cycle =       32900
// simple
//   [pass]
//     Stall count:           4
//     Read  count:           4
//   [OK] simple
//   summary: simple:               cycle =         168

endmodule
