// Pseudo-LRU generator
// Only supports SET_ASSOC = 2 or 4

module plru #(
	parameter int unsigned SET_ASSOC = 4
) (
	input								clk			,
	input								rst_n		,

	input	[SET_ASSOC - 1:0]			access		,
	input								update		,

	output	[$clog2(SET_ASSOC) - 1:0]	repl_index	
);

logic [$clog2(SET_ASSOC) - 1:0] state, state_n;

// assign output index
// why [SET_ASSOC - 2:0]?
assign repl_index = state;

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
end
else begin					// 4-way
	always_comb begin
		state_n = state;
		casez (access)
			4'b1???: begin
				state_n[1] = 1'b0;
				state_n[0] = 1'b0;
			end
			4'b01??: begin
				state_n[1] = 1'b0;
				state_n[0] = 1'b1;
			end
			4'b001?: begin
				state_n[1] = 1'b1;
				state_n[0] = 1'b0;
			end
			4'b0001: begin
				state_n[1] = 1'b1;
				state_n[0] = 1'b1;
			end
		endcase
	end
end
endgenerate

// update state
always_ff @ (posedge clk) begin
	if (!rst_n) begin
		state <= '0;
	end else if (update) begin
		state <= state_n;
		`ifdef REPL_SIM
		$display("state: %h\n", state);
		`endif
	end
end

endmodule
