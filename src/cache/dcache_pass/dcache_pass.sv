// dcache_pass for dcache write through
`include "dcache_pass.svh"

module dcache_pass #(
    parameter   DATA_WIDTH      =   32,
    // icache - 0(only arid), dcache - 1(both arid and awid), dcache_pass - 2(both arid and awid)
    parameter   ARID            =   2,
    parameter   AWID            =   2,
    parameter   DATA_DEPTH      =   8,
    // local parameter
    localparam int unsigned ADDR_WIDTH  = (DATA_DEPTH == 0) ? 0 : $clog2(DATA_DEPTH),
    localparam bit          TYPE_STORE  = 1'b0,
    localparam bit          TYPE_LOAD   = 1'b1
) (
    // external signals
    input   logic   clk,
    input   logic   rst,

    // AXI3 wr & rd interface
    axi3_rd_if.master   axi3_rd_if,
    axi3_wr_if.master   axi3_wr_if,

    // uncached req
    input   dcache_req  dcache_uncached_req,
    input   logic       push,
    output  logic       full,

    // uncached resp, only for load
    output  dcache_resp dcache_uncached_resp
);

generate if (DATA_DEPTH == 0) begin

end else begin
    // type define
    typedef logic [ADDR_WIDTH - 1:0] addr_t;

    // control signals
    logic empty, pop, poped, pushed;
    // state
    dp_state_t state, state_n;
    // pointer
    addr_t head, head_n, tail, tail_n;
    // mem & valid
    dcache_req [DATA_DEPTH - 1:0] mem, mem_n;
    logic  [DATA_DEPTH - 1:0] valid, valid_n;
    // axi3 transfer for load
    dcache_req transfer_line, transfer_line_n;

    // Grow --->
    // O O O X X X X O O
    //       H       T
    assign empty = ~|valid;
    assign full = &valid;
    assign transfer_line_n = mem[head];

    always_comb begin
        head_n = head;
        tail_n = tail;
        mem_n = mem;
        valid_n = valid;

        pushed = 1'b0;
        poped  = 1'b0;
        // pop one line, allow push & pop at full
        if(pop && ~empty) begin
            valid_n[head] = 1'b0;

            if(head == DATA_DEPTH[ADDR_WIDTH - 1:0] - 1) begin
                head_n = '0;
            end else begin
                head_n = head + 1;
            end

            poped = 1'b1;
        end

        // push one line
        if(push && ~full) begin
            mem_n[tail] = dcache_uncached_req;
            valid_n[tail] = 1'b1;

            if(tail == DATA_DEPTH[ADDR_WIDTH - 1:0] - 1) begin
                tail_n = '0;
            end else begin
                tail_n = tail + 1;
            end

            pushed = 1'b1;
        end
    end

    always_ff @ (posedge clk) begin
        if(rst) begin
            head <= '0;
            tail <= '0;
            valid <= '0;
        end else begin
            head <= head_n;
            tail <= tail_n;
            valid <= valid_n;
        end
    end

    always_ff @ (posedge clk) begin
        if(rst) begin
            mem <= '0;
        end else if (pushed) begin
            mem <= mem_n;
        end
    end

    // sync transfer_line
    always_ff @ (posedge clk) begin
        if (rst) begin
            transfer_line <= '0;
        end else if (poped) begin
            transfer_line <= transfer_line_n;
        end
    end

    // pop prepare to transfer
    always_comb begin
        pop = 1'b0;
        if (state == DP_IDLE && ~empty) pop = 1'b1;
    end

    // set axi req
    always_comb begin
        // axi3 default
        axi3_rd_if.arid = ARID;
        axi3_rd_if.axi3_rd_req = '0;
        axi3_wr_if.awid = AWID;
        axi3_wr_if.wid  = AWID;
        axi3_wr_if.axi3_wr_req = '0;
        // INCR, but we are only doing one transfer in a burst
        // axi3 rd
        axi3_rd_if.axi3_rd_req.arburst = 2'b01;
        axi3_rd_if.axi3_rd_req.arlen   = 3'b0000;
        axi3_rd_if.axi3_rd_req.arsize  = 2'b010;    // 4 bytes
        axi3_rd_if.axi3_rd_req.araddr  = transfer_line.paddr;
        axi3_wr_if.axi3_wr_req.awburst = 2'b01;
        axi3_wr_if.axi3_wr_req.awlen   = 3'b0000;
        axi3_wr_if.axi3_wr_req.awsize  = 2'b010;    // 4 bytes
        axi3_wr_if.axi3_wr_req.wstrb   = transfer_line.be;
        axi3_wr_if.axi3_wr_req.awaddr  = transfer_line.paddr;
        axi3_wr_if.axi3_wr_req.wdata   = transfer_line.wrdata;
        axi3_wr_if.axi3_wr_req.bready  = 1'b1;
        case (state)
            DP_WAIT_AWREADY: axi3_wr_if.axi3_wr_req.awvalid = 1'b1;
            DP_WRITE: begin
                axi3_wr_if.axi3_wr_req.wvalid = 1'b1;
                axi3_wr_if.axi3_wr_req.wlast  = 1'b1;
            end
            DP_WAIT_ARREADY: axi3_rd_if.axi3_rd_req.arvalid = 1'b1;
            DP_READ: if (axi3_rd_if.axi3_rd_resp.rvalid) axi3_rd_if.axi3_rd_req.rready = 1'b1;
        endcase
    end

    // set rline, only for load
    always_comb begin
        dcache_uncached_resp = '0;
        case (state)
            // store complete
            DP_WAIT_BVALID:
                if (axi3_wr_if.axi3_wr_resp.bvalid) begin
                    // should not set valid as 1, for store commit after issue
                    dcache_uncached_resp.valid = 1'b1;
                end
            // load complete
            DP_READ:
                if (axi3_rd_if.axi3_rd_resp.rvalid) begin
                    dcache_uncached_resp.rddata = axi3_rd_if.axi3_rd_resp.rdata;
                    dcache_uncached_resp.valid  = 1'b1;
                end
        endcase
    end

    // update state_n
    always_comb begin
        state_n = state;
        case (state)
            DP_IDLE:
                if (~empty && transfer_line_n.read) begin
                    // means load type
                    state_n = DP_WAIT_ARREADY;
                end else if (~empty && transfer_line_n.write) begin
                    // means load type
                    state_n = DP_WAIT_AWREADY;
                end
            DP_WAIT_AWREADY: if(axi3_wr_if.axi3_wr_resp.awready) state_n = DP_WRITE;
            DP_WRITE: if(axi3_wr_if.axi3_wr_resp.wready) state_n = DP_WAIT_BVALID;
            DP_WAIT_BVALID: if(axi3_wr_if.axi3_wr_resp.bvalid) state_n = DP_IDLE;
            DP_WAIT_ARREADY: if (axi3_rd_if.axi3_rd_resp.arready) state_n = DP_READ;
            DP_READ: if(axi3_rd_if.axi3_rd_resp.rvalid) state_n = DP_IDLE;
        endcase
    end

    // sync update state & rline
    always_ff @ (posedge clk) begin
        if (rst) begin
            state     <= DP_IDLE;
        end else begin
            state     <= state_n;
        end
    end
end endgenerate

endmodule
