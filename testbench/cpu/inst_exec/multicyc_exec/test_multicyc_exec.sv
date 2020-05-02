// test multicyc_exec
`include "test_multicyc_exec.svh"

module test_multicyc_exec #(

) (

);

// gen clk & sync_rst
logic clk, rst, sync_rst;
sim_clock sim_clock_inst(.*);
always_ff @ (posedge clk) begin
    sync_rst <= rst;
end

// interface define
multicyc_req_t  multicyc_req;
multicyc_resp_t multicyc_resp;
// inst multicyc_exec
multicyc_exec #(

) multicyc_exec_inst (
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
    logic [1:0] op;

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

    // get req & ans fpointer
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
    // reset global control signals
    multicyc_req.is_multicyc = 1'b0;
    while (!$feof(fans)) begin
        // wait negedge clk to ensure line_data already update
        @ (negedge clk);
        cycle = cycle + 1;

        // reset control signals
        multicyc_req.is_multicyc = 1'b0;
        multicyc_req.hilo        = 1'b0;    // unused

        // issue req
        if (multicyc_resp.ready && !$feof(freq)) begin
            $fscanf(freq, "%x %x %x\n",
                op,
                multicyc_req.reg0,
                multicyc_req.reg1
            );
            // set op & is_multicyc
            case (op)
                2'd0: multicyc_req.op = OP_MULT;
                2'd1: multicyc_req.op = OP_MULTU;
                2'd2: multicyc_req.op = OP_DIV;
                2'd3: multicyc_req.op = OP_DIVU;
            endcase
            multicyc_req.is_multicyc = 1'b1;
            req_counter = req_counter + 1;
        end

        // check ans
        if (multicyc_resp.valid) begin
            $sformat(out, {"%x"}, multicyc_resp.hilo);
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
    unittest("mul");
    unittest("div");
    $display("summary: %0s", summary);
    $stop;
end

endmodule
