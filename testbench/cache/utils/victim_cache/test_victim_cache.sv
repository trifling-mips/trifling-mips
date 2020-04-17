// test victim_cache
`include "test_victim_cache.svh"

module test_victim_cache #(
    parameter   LINE_WIDTH  =   256,
    parameter   LINE_DEPTH  =   8,
    // local parameter
    localparam  LINE_BYTE_OFFSET    =   $clog2(LINE_WIDTH / $bits(uint8_t)),
    localparam  LABEL_WIDTH         =   ($bits(phys_t) - LINE_BYTE_OFFSET),
    localparam  ADDR_WIDTH          =   (LINE_DEPTH == 0) ? 0 : $clog2(LINE_DEPTH),
    // parameter for type
    parameter type line_t  = logic [LABEL_WIDTH + LINE_WIDTH - 1:0],
    parameter type label_t = logic [LABEL_WIDTH - 1:0],
    parameter type data_t  = logic [LINE_WIDTH  - 1:0],
    parameter type be_t    = logic [(LINE_WIDTH / $bits(uint8_t)) - 1:0]
) (

);

// gen clk & sync_rst
logic clk, rst, sync_rst;
sim_clock m_sim_clock(.*);
always_ff @ (posedge clk) begin
    sync_rst <= rst;
end

// interface define
line_t rline, pline;
logic full, empty, pop, push, pushed;
label_t query_label;
logic query_found, query_on_pop, write, written;
data_t query_wdata, query_rdata;
be_t query_wbe;
// inst module
victim_cache #(
    .LINE_WIDTH(LINE_WIDTH),
    .LINE_DEPTH(LINE_DEPTH),        // need greater than 1(2 ** x)
    // parameter for type
    .line_t(line_t),
    .label_t(label_t),
    .data_t(data_t),
    .be_t(be_t)
) victim_cache_inst (
    .rst(sync_rst),
    .*
);

// record
string summary;

task unittest_(
    input string name
);
    string fans_name, fans_path, freq_name, freq_path, out;
    integer fans, freq, ans_counter, req_counter, cycle;
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
    while (!$feof(freq)) begin
        // wait negedge clk to ensure line_data already update
        @ (negedge clk);
        cycle = cycle + 1;
        if (req_counter != 0) begin
            // format output
            $sformat(out, {"%x-%x"}, rline[LABEL_WIDTH + LINE_WIDTH - 1 -: LABEL_WIDTH], rline[LINE_WIDTH - 1:0]);
            judge(fans, ans_counter, out);
            ans_counter = ans_counter + 1;
            // reset control signals
            pop = 1'b0;
            push = 1'b0;
            write = 1'b0;
            // issue next req
            if (!$feof(freq)) begin
                $fscanf(freq, "%s %x %x %x\n", req_type, req1, req2, req3);
                req_counter = req_counter + 1;
                // set corresponding value
                if (req_type == "push") begin
                    push = 1'b1;
                    pline = {req1, req2};
                end else if (req_type == "pop") begin
                    pop = 1'b1;
                end else if (req_type == "pp") begin
                    push = 1'b1;
                    pline = {req1, req2};
                    pop = 1'b1;
                end else if (req_type == "write") begin
                    write = 1'b1;
                    query_label = req1;
                    query_wdata = req2;
                    query_wbe = req3;
                end else begin
                    $display("[ERROR] unknown req_type(%s)!", req_type);
                    $stop;
                end
            end
        end else if (req_counter == 0 && ans_counter == 0) begin
            // issue first req
            // reset control signals
            pop = 1'b0;
            push = 1'b0;
            write = 1'b0;
            if (!$feof(freq)) begin
                $fscanf(freq, "%s %x %x %x\n", req_type, req1, req2, req3);
                req_counter = req_counter + 1;
                // set corresponding value
                if (req_type == "push") begin
                    push = 1'b1;
                    pline = {req1, req2};
                end else if (req_type == "pop") begin
                    pop = 1'b1;
                end else if (req_type == "pp") begin
                    push = 1'b1;
                    pline = {req1, req2};
                    pop = 1'b1;
                end else if (req_type == "write") begin
                    write = 1'b1;
                    query_label = req1;
                    query_wdata = req2;
                    query_wbe = req3;
                end else begin
                    $display("[ERROR] unknown req_type(%s)!", req_type);
                    $stop;
                end
            end
        end else begin
            $display("[ERROR] should not come here!");
            $stop;
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
