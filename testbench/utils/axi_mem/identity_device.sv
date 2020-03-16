// identity_device
`include "common_defs.svh"

module identity_device #(
	parameter ADDR_WIDTH = 32,
	parameter DATA_WIDTH = 32
) (
	input logic clk,
	input logic rst,
	axi3_rd_if.slave	axi3_rd_if,
	axi3_wr_if.slave	axi3_wr_if
);

logic [ADDR_WIDTH - 1:0] base_addr, base_addr_d;
logic [$clog2(ADDR_WIDTH)-1:0] burst_counter, burst_counter_d, burst_target, burst_target_d;
logic writing, writing_d;

enum logic [2:0] {
	IDLE, READING, WRITING
} state, state_d;

always_comb begin
	burst_counter_d = burst_counter;
	burst_target_d = burst_target;
	base_addr_d = base_addr;
	state_d = state;

	axi3_rd_if.axi3_rd_resp.arready = state == IDLE && axi3_rd_if.axi3_rd_req.arvalid;
	axi3_wr_if.axi3_wr_resp.awready = state == IDLE && axi3_wr_if.axi3_wr_req.awvalid;
	axi3_rd_if.axi3_rd_resp.rvalid = state == READING;
	axi3_rd_if.axi3_rd_resp.rlast = state == READING && burst_counter == burst_target;
	axi3_wr_if.axi3_wr_resp.wready = state == WRITING && axi3_wr_if.axi3_wr_req.wvalid;

	case(state)
		IDLE: begin
			if(axi3_rd_if.axi3_rd_req.arvalid) begin
				base_addr_d = axi3_rd_if.axi3_rd_req.araddr;

				burst_target_d = axi3_rd_if.axi3_rd_req.arlen;
				burst_counter_d = 0;

				state_d = READING;
			end

			if(axi3_wr_if.axi3_wr_req.awvalid) begin
				base_addr_d = axi3_wr_if.axi3_wr_req.awaddr;
				burst_target_d = axi3_wr_if.axi3_wr_req.awlen;
				$display("Slave: Writing length: %0d", burst_target_d + 1);
				burst_counter_d = 0;

				state_d = WRITING;
			end
		end
		READING: begin
			axi3_rd_if.axi3_rd_resp.rdata = burst_counter * 4 + base_addr;

			if(axi3_rd_if.axi3_rd_req.rready) begin
				burst_counter_d = burst_counter + 1;
			end

			if(burst_counter == burst_target) begin
				state_d = IDLE;
			end
		end
		WRITING: begin
			if(axi3_wr_if.axi3_wr_req.wvalid) begin
				burst_counter_d = burst_counter + 1;
				$display("Slave: Writing transfer %0d / %0d: %08x", burst_counter_d, burst_target + 1, axi3_wr_if.axi3_wr_req.wdata);
			end

			if(axi3_wr_if.axi3_wr_req.wlast) begin
				if(burst_counter != burst_target) begin
					$display("Slave: Unexpected end of burst");
					$stop;
				end
				state_d = IDLE;
			end
		end
	endcase
end

always_ff @(posedge clk or posedge rst) begin
	if(rst) begin
		burst_counter <= 0;
		burst_target <= 0;
		base_addr <= '0;
		state <= IDLE;
	end else begin
		burst_counter <= burst_counter_d;
		burst_target <= burst_target_d;
		base_addr <= base_addr_d;
		state <= state_d;
	end
end

endmodule
