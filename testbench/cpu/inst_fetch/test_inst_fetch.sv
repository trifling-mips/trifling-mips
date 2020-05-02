// test inst_fetch
`include "test_inst_fetch.svh"

module test_inst_fetch #(
    // common parameter
    parameter   BUS_WIDTH   =   4,
    parameter   DATA_WIDTH  =   32,
    // parameter for mem_device
    parameter   ADDR_WIDTH  =   16,
    // parameter for icache
    parameter   LINE_WIDTH  =   256,
    parameter   SET_ASSOC   =   4,
    parameter   CACHE_SIZE  =   16 * 1024 * 8,
    parameter   ARID        =   0,
    // parameter for inst_fetch
    parameter   BOOT_VEC    =   32'hbfc00000,
    parameter   N_ISSUE     =   1
) (

);

// gen clk & sync_rst
logic clk, rst, sync_rst;
sim_clock sim_clock_inst(.*);
always_ff @ (posedge clk) begin
    sync_rst <= rst;
end

// interface define
// inst_fetch
logic ibus_ready;
branch_resolved_t resolved_branch;
except_req_t except_req;
virt_t pc, npc;
logic ibus_valid;
uint32_t ibus_rddata;
pipe_if_t pipe_if;
logic ready_i;
// icache
cpu_ibus_if ibus();
axi3_rd_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_rd_if();
axi3_wr_if #(.BUS_WIDTH(BUS_WIDTH)) axi3_wr_if();
// inst module
inst_fetch #(
    .BOOT_VEC(BOOT_VEC),
    .N_ISSUE(N_ISSUE)
) inst_fetch_inst (
    .rst(sync_rst),
    .*
);
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
// set default value
assign ibus.inv         = 1'b0;
assign ibus.inv_addr    = '0;
assign ibus.read        = ibus.ready;
assign ibus.vaddr       = npc;
assign ibus.paddr       = pc;
assign ibus.paddr_plus1 = pc + (1 << $clog2(LINE_WIDTH / 8));
assign except_req.delayslot  = 1'b0;
assign except_req.eret       = 1'b0;
assign except_req.code       = EXCCODE_INT;
assign except_req.pc         = pc;
assign except_req.extra      = '0;
assign resolved_branch.valid = resolved_branch.taken;
// connect module
assign ibus_ready       = ibus.ready;
assign ibus_valid       = ibus.valid;
assign ibus_rddata      = ibus.rddata;

// record
string summary;
string mem_prefix = "sequential";

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
    // reset global control signals
    ready_i = 1'b1;
    while (!$feof(fans)) begin
        // wait negedge clk to ensure line_data already update
        @ (negedge clk);
        cycle = cycle + 1;

        // reset control signals
        resolved_branch.taken = 1'b0;
        except_req.valid      = 1'b0;

        // issue req
        if (ibus.ready && !$feof(freq)) begin
            $fscanf(freq, "%x %x %x %x %x\n",
                ready_i,
                resolved_branch.taken,
                resolved_branch.target,
                except_req.valid,
                except_req.except_vec
            );
            req_counter = req_counter + 1;
        end

        // check ans
        if (pipe_if.valid) begin
            $sformat(out, {"%x-%x"}, pipe_if.vaddr, pipe_if.inst);
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
    unittest("stall");
    unittest("branch");
    unittest("except");
    unittest("all");
    $display("summary: %0s", summary);
    $stop;
end

endmodule
