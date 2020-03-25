// Pseudo-LRU generator
// Only supports SET_ASSOC = 2 or 4
`include "repl_defs.svh"

module plru #(
	parameter int unsigned	SET_ASSOC	=	4,
	// local parameter
	localparam	PLRU_STATE_WIDTH = (SET_ASSOC - 1)
) (
	input								clk			,
	input								rst			,

	input	logic	[SET_ASSOC - 1:0]			access		,
	input	logic								update		,

	output	logic	[$clog2(SET_ASSOC) - 1:0]	repl_index	
);

logic [(PLRU_STATE_WIDTH - 1):0] state, state_n;

// assign output index
generate
if (SET_ASSOC == 2) begin
	assign repl_index = state;
end else if (SET_ASSOC == 4) begin
	assign repl_index = state[2] == 1'b0 ? state[2 -: 2] : {state[2], state[0]};
end else begin
	// TODO
end
endgenerate

// update state_n
generate
if (SET_ASSOC == 2) begin	// 2-way
	always_comb begin
		state_n = state;
		casez (access)
			2'b1?: begin
				state_n[0] = 1'b0;
			end
			2'b01: begin
				state_n[0] = 1'b1;
			end
		endcase
	end
end else if (SET_ASSOC == 4) begin					// 4-way
	always_comb begin
		state_n = state;
		casez (access)
			4'b1???: begin
				state_n[2] = 1'b0;
				state_n[0] = 1'b0;
			end
			4'b01??: begin
				state_n[2] = 1'b0;
				state_n[0] = 1'b1;
			end
			4'b001?: begin
				state_n[2] = 1'b1;
				state_n[1] = 1'b0;
			end
			4'b0001: begin
				state_n[2] = 1'b1;
				state_n[1] = 1'b1;
			end
		endcase
	end
end else begin										// other-way
	// TODO
end
endgenerate

// update state
always_ff @ (posedge clk) begin
	if (rst) begin
		state <= '0;
	end else if (update) begin
		state <= state_n;
		`ifdef REPL_SIM
		$display("state: %h\n", state);
		`endif
	end
end

endmodule
