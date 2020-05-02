/*------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Copyright (c) 2016, Loongson Technology Corporation Limited.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this 
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

3. Neither the name of Loongson Technology Corporation Limited nor the names of 
its contributors may be used to endorse or promote products derived from this 
software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL LOONGSON TECHNOLOGY CORPORATION LIMITED BE LIABLE
TO ANY PARTY FOR DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--------------------------------------------------------------------------------
------------------------------------------------------------------------------*/
`timescale 1ns / 1ps

`define TRACE_REF_FILE "../../../../../../../cpu132_gettrace/golden_trace.txt"
`define CONFREG_NUM_REG      soc_lite.u_confreg.num_data
//for func test, no define RUN_PERF_TEST
//`define CONFREG_OPEN_TRACE   soc_lite.u_confreg.open_trace
`define CONFREG_OPEN_TRACE   1'b0
`define CONFREG_NUM_MONITOR  soc_lite.u_confreg.num_monitor
`define CONFREG_UART_DISPLAY soc_lite.u_confreg.write_uart_valid
`define CONFREG_UART_DATA    soc_lite.u_confreg.write_uart_data
`define END_PC 32'hbfc00100

module trace_gen( );
reg resetn;
reg clk;

//goio
wire [15:0] led;
wire [1 :0] led_rg0;
wire [1 :0] led_rg1;
wire [7 :0] num_csn;
wire [6 :0] num_a_g;
wire [7 :0] switch;
wire [3 :0] btn_key_col;
wire [3 :0] btn_key_row;
wire [1 :0] btn_step;
assign switch      = 8'hFF;
assign btn_key_row = 4'd0;
assign btn_step    = 2'd3;

initial
begin
    clk = 1'b0;
    resetn = 1'b0;
    #2000;
    resetn = 1'b1;
end
always #5 clk=~clk;
soc_axi_lite_top #(.SIMULATION(1'b1)) soc_lite
(
       .resetn      (resetn     ), 
       .clk         (clk        ),
    
        //------gpio-------
        .num_csn    (num_csn    ),
        .num_a_g    (num_a_g    ),
        .led        (led        ),
        .led_rg0    (led_rg0    ),
        .led_rg1    (led_rg1    ),
        .switch     (switch     ),
        .btn_key_col(btn_key_col),
        .btn_key_row(btn_key_row),
        .btn_step   (btn_step   )
    );   

//"cpu_clk" means cpu core clk
//"sys_clk" means system clk
//"wb" means write-back stage in pipeline
//"rf" means regfiles in cpu
//"w" in "wen/wnum/wdata" means writing
wire cpu_clk;
wire sys_clk;
wire [31:0] debug_wb_pc;
wire [3 :0] debug_wb_rf_wen;
wire [4 :0] debug_wb_rf_wnum;
wire [31:0] debug_wb_rf_wdata;
assign cpu_clk           = soc_lite.cpu_clk;
assign sys_clk           = soc_lite.sys_clk;
assign debug_wb_pc       = soc_lite.debug_wb_pc;
assign debug_wb_rf_wen   = soc_lite.debug_wb_rf_wen;
assign debug_wb_rf_wnum  = soc_lite.debug_wb_rf_wnum;
assign debug_wb_rf_wdata = soc_lite.debug_wb_rf_wdata;

// open the trace file;
integer trace_ref;
initial begin
    trace_ref = $fopen(`TRACE_REF_FILE, "r");
end

//get reference result in falling edge
reg        trace_cmp_flag;
reg        debug_end;

reg [31:0] ref_wb_pc;
reg [4 :0] ref_wb_rf_wnum;
reg [31:0] ref_wb_rf_wdata;

always @(posedge cpu_clk)
begin 
    #1;
    if(|debug_wb_rf_wen && debug_wb_rf_wnum!=5'd0 && !debug_end && `CONFREG_OPEN_TRACE)
    begin
        trace_cmp_flag=1'b0;
        while (!trace_cmp_flag && !($feof(trace_ref)))
        begin
            $fscanf(trace_ref, "%h %h %h %h", trace_cmp_flag,
                    ref_wb_pc, ref_wb_rf_wnum, ref_wb_rf_wdata);
        end
    end
end

//wdata[i*8+7 : i*8] is valid, only wehile wen[i] is valid
wire [31:0] debug_wb_rf_wdata_v;
wire [31:0] ref_wb_rf_wdata_v;
assign debug_wb_rf_wdata_v[31:24] = debug_wb_rf_wdata[31:24] & {8{debug_wb_rf_wen[3]}};
assign debug_wb_rf_wdata_v[23:16] = debug_wb_rf_wdata[23:16] & {8{debug_wb_rf_wen[2]}};
assign debug_wb_rf_wdata_v[15: 8] = debug_wb_rf_wdata[15: 8] & {8{debug_wb_rf_wen[1]}};
assign debug_wb_rf_wdata_v[7 : 0] = debug_wb_rf_wdata[7 : 0] & {8{debug_wb_rf_wen[0]}};
assign   ref_wb_rf_wdata_v[31:24] =   ref_wb_rf_wdata[31:24] & {8{debug_wb_rf_wen[3]}};
assign   ref_wb_rf_wdata_v[23:16] =   ref_wb_rf_wdata[23:16] & {8{debug_wb_rf_wen[2]}};
assign   ref_wb_rf_wdata_v[15: 8] =   ref_wb_rf_wdata[15: 8] & {8{debug_wb_rf_wen[1]}};
assign   ref_wb_rf_wdata_v[7 : 0] =   ref_wb_rf_wdata[7 : 0] & {8{debug_wb_rf_wen[0]}};

logic icache_miss;
assign icache_miss = soc_lite.u_cpu.nontrivial_mips_inst.cache_controller_inst.icache_inst.icache_miss;
integer icache_miss_counter, instr_counter, cycle_counter, mispredict_counter, branch_counter, dcache_counter, uncache_counter, dcache_access_counter, stall_mm_counter, noncf_miss_counter;
branch_resolved_t resolved_branch;
assign resolved_branch = soc_lite.u_cpu.nontrivial_mips_inst.cpu_core_inst.instr_fetch_inst.resolved_branch;

pipeline_memwb_t [1:0] pipe_wb, pipe_mem;
pipeline_exec_t [1:0] pipe_dcache_last;
assign pipe_wb = soc_lite.u_cpu.nontrivial_mips_inst.cpu_core_inst.pipeline_wb;
assign pipe_dcache_last = soc_lite.u_cpu.nontrivial_mips_inst.cpu_core_inst.pipeline_dcache_last;
assign pipe_mem = soc_lite.u_cpu.nontrivial_mips_inst.cpu_core_inst.pipeline_mem;
integer ftrace, fmem_trace;

task output_mem_trace(input pipeline_exec_t pipe_dcache_last, input pipeline_memwb_t pipe_mem);
	if(pipe_dcache_last.memreq.uncached | ~pipe_dcache_last.valid | soc_lite.u_cpu.nontrivial_mips_inst.cpu_core_inst.stall_mm) return;
	if(pipe_dcache_last.memreq.read) begin
		$fwrite(fmem_trace, "r %08x %08x\n", pipe_dcache_last.memreq.paddr, pipe_mem.wdata);
	end else if(pipe_dcache_last.memreq.write) begin
		$fwrite(fmem_trace, "w %08x %08x\n", pipe_dcache_last.memreq.paddr, pipe_dcache_last.memreq.wrdata);
	end
endtask

task output_trace(input pipeline_memwb_t pipe_wb);
	//$display("1 0x%8h 0x%2h 0x%8h\n", pipe_wb.pc, pipe_wb.rd, pipe_wb.wdata);
	if(pipe_wb.rd!=5'd0) begin
		$fwrite(ftrace, "1 0x%8h 0x%2h 0x%8h\n",
				  pipe_wb.pc, pipe_wb.rd, pipe_wb.wdata);
	end

endtask

//compare result in rsing edge 
reg debug_wb_err;
always @(posedge cpu_clk)
begin
    #2;
    if(!resetn)
    begin
        debug_wb_err <= 1'b0;
		icache_miss_counter <= '0;
		instr_counter <= '0;
		cycle_counter <= '0;
		mispredict_counter <= '0;
		branch_counter <= '0;
		dcache_counter <= '0;
		dcache_access_counter <= '0;
		uncache_counter <= '0;
		stall_mm_counter <= '0;
		noncf_miss_counter <= '0;
    end
    else begin
		cycle_counter <= cycle_counter + 1;
		icache_miss_counter <= icache_miss_counter + icache_miss;
		instr_counter <= instr_counter + (pipe_wb[0].valid) + (pipe_wb[1].valid);
		noncf_miss_counter <= noncf_miss_counter + soc_lite.u_cpu.nontrivial_mips_inst.cpu_core_inst.instr_fetch_inst.presolved_branch.mispredict;
		dcache_access_counter <= dcache_access_counter + soc_lite.u_cpu.nontrivial_mips_inst.cache_controller_inst.dcache_inst.debug_uncache_access;
		stall_mm_counter <= stall_mm_counter + soc_lite.u_cpu.nontrivial_mips_inst.cpu_core_inst.stall_from_mm;
		dcache_counter <= dcache_counter + soc_lite.u_cpu.nontrivial_mips_inst.cache_controller_inst.dcache_inst.debug_cache_miss;
		//uncache_counter <= uncache_counter + soc_lite.u_cpu.nontrivial_mips_inst.cache_controller_inst.uncached_inst.uncache_access;
		branch_counter <= branch_counter + resolved_branch.valid;
		mispredict_counter <= mispredict_counter + (resolved_branch.valid & resolved_branch.mispredict);
		//if(resolved_branch.valid)
		//	$display("mispredict = %d, taken = %d, pc = 0x%08x, target = 0x%08x", resolved_branch.mispredict, resolved_branch.taken, resolved_branch.pc, resolved_branch.target);
		output_trace(pipe_wb[0]);
		output_trace(pipe_wb[1]);
		output_mem_trace(pipe_dcache_last[0], pipe_mem[0]);
		output_mem_trace(pipe_dcache_last[1], pipe_mem[1]);
    end
end

//monitor numeric display
reg [7:0] err_count;
wire [31:0] confreg_num_reg = `CONFREG_NUM_REG;
reg  [31:0] confreg_num_reg_r;
always @(posedge sys_clk)
begin
    confreg_num_reg_r <= confreg_num_reg;
    if (!resetn)
    begin
        err_count <= 8'd0;
    end
    else if (confreg_num_reg_r != confreg_num_reg && `CONFREG_NUM_MONITOR)
    begin
        if(confreg_num_reg[7:0]!=confreg_num_reg_r[7:0]+1'b1)
        begin
            $display("--------------------------------------------------------------");
            $display("[%t] Error(%d)!!! Occurred in number 8'd%02d Functional Test Point!",$time, err_count, confreg_num_reg[31:24]);
            $display("--------------------------------------------------------------");
            err_count <= err_count + 1'b1;
        end
        else if(confreg_num_reg[31:24]!=confreg_num_reg_r[31:24]+1'b1)
        begin
            $display("--------------------------------------------------------------");
            $display("[%t] Error(%d)!!! Unknown, Functional Test Point numbers are unequal!",$time,err_count);
            $display("--------------------------------------------------------------");
            $display("==============================================================");
            err_count <= err_count + 1'b1;
        end
        else
        begin
            $display("----[%t] Number 8'd%02d Functional Test Point PASS!!!", $time, confreg_num_reg[31:24]);
        end
    end
end

//monitor test
initial
begin
	ftrace = $fopen("/tmp/traces/my_bitcount.txt", "w");
	fmem_trace = $fopen("/tmp/traces/mem_bitcount.txt", "w");
    $timeformat(-9,0," ns",10);
    while(!resetn) #5;
    $display("==============================================================");
    $display("Test begin!");

  //  #10000;
   // while(`CONFREG_NUM_MONITOR)
  //  begin
 //       #10000;
//        $display ("        [%t] Test is running, debug_wb_pc = 0x%8h",$time, debug_wb_pc);
  //  end
end

//模拟串口打印
wire uart_display;
wire [7:0] uart_data;
assign uart_display = `CONFREG_UART_DISPLAY;
assign uart_data    = `CONFREG_UART_DATA;

always @(posedge sys_clk)
begin
    if(uart_display)
    begin
        if(uart_data==8'hff)
        begin
            ;//$finish;
        end
        else
        begin
            $write("%c",uart_data);
        end
    end
end

//test end
wire global_err = debug_wb_err || (err_count!=8'd0);
wire test_end = (debug_wb_pc==`END_PC) || (uart_display && uart_data==8'hff);
always @(posedge sys_clk)
begin
    if (!resetn)
    begin
        debug_end <= 1'b0;
    end
    else if(test_end && !debug_end)
    begin
        debug_end <= 1'b1;
        $display("==============================================================");
        $display("Test end!");
        #40;
        $fclose(trace_ref);
        if (global_err)
        begin
            $display("Fail!!!Total %d errors!",err_count);
        end
        else
        begin
            $display("----PASS!!!");
			$display("I$ miss: %d", icache_miss_counter);
			$display("D$ miss: %d", dcache_counter);
			$display("D$ access count: %d", dcache_access_counter);
			$display("UD miss: %d", uncache_counter);
			$display("instr: %d", instr_counter);
			$display("cycle: %d", cycle_counter);
			$display("branch: %d", branch_counter);
			$display("mispredict: %d", mispredict_counter);
			$display("NoCF mispredict: %d", noncf_miss_counter);
			$display("mm_stall: %d", stall_mm_counter);
        end
	    $finish;
	end
end
endmodule
