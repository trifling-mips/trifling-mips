// repl-FIFO generator
// Only supports SET_ASSOC = 2 or 4
`include "repl_defs.svh"

module repl_fifo #(
	parameter int unsigned SET_ASSOC = 4
) (
	input								clk			,
	input								rst			,

	input	[SET_ASSOC - 1:0]			access		,
	input								update		,

	output	[$clog2(SET_ASSOC) - 1:0]	repl_index	
);

genvar i;
`ifdef REPL_SIM
integer sim_i;
`endif

logic [$clog2(SET_ASSOC) - 1:0] state[SET_ASSOC - 1:0];
logic [$clog2(SET_ASSOC) - 1:0] state_n[SET_ASSOC - 1:0];
logic [SET_ASSOC - 1:0] index_avail;
logic [$clog2(SET_ASSOC) - 1:0] index_avail_min;

// assign output index
assign repl_index = index_avail_min;

// decode state
generate begin
for (i = 0; i < SET_ASSOC; i++) begin
	assign index_avail[i] = ^|state[i];
end
if (SET_ASSOC == 2) begin	// 2-way
	always_comb begin
		index_avail_min = '0;
		casez (index_avail)
			2'1?: begin
				index_avail_min[0] = 1'b0;
			end
			2'b01: begin
				index_avail_min[0] = 1'b1;
			end
		endcase
	end
end
else begin					// 4-way
	always_comb begin
		index_avail_min = '0;
		casez (index_avail)
			4'b1???: begin
				index_avail_min[1] = 1'b0;
				index_avail_min[0] = 1'b0;
			end
			4'b01??: begin
				index_avail_min[1] = 1'b0;
				index_avail_min[0] = 1'b1;
			end
			4'b001?: begin
				index_avail_min[1] = 1'b1;
				index_avail_min[0] = 1'b0;
			end
			4'b0001: begin
				index_avail_min[1] = 1'b1;
				index_avail_min[0] = 1'b1;
			end
		endcase
	end
end
endgenerate

// update state_n
generate begin
// maybe we should generate different comb according to SET_ASSOC?
always_comb begin
	state_n = state;
	for (i = 0; i < SET_ASSOC; i++) begin
		if (access[i]) begin
			state_n[i] = {$clog2(SET_ASSOC){1'b1}};
		end
		else if (|state_n[i]) begin
			state_n[i] = state_n[i] - '1;
		end
	end
end

// update state
always_ff @ (posedge clk) begin
	if (rst) begin
		state <= '0;
	end
	else if (update) begin
		state <= state_n;
	end
	`ifdef REPL_SIM
	$display("state:\n");
	for (sim_i = 0; sim_i < SET_ASSOC; sim_i++) begin
		$display("%h\t", state[sim_i]);
	end
	$display("\n");
	`endif
end

endmodule
