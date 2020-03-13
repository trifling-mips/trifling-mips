// Pseudo-LRU generator
// supports all SET_ASSOC

module repl_rand #(
	parameter int unsigned	SET_ASSOC	=	4
) (
	input								clk			,
	input								rst_n		,

	input	[SET_ASSOC - 1:0]			access		,		// useless
	input								update		,		// useless

	output	[$clog2(SET_ASSOC) - 1:0]	repl_index	
);

logic [$clog2(SET_ASSOC) - 1:0] state;

// assign output index
assign repl_index = state;

// update state
always_ff @ (posedge clk) begin
	if (!rst_n) begin
		state <= '0;
	end else begin
		state <= state + 1'b1;
		`ifdef REPL_SIM
		$display("state: %h\n", state);
		`endif
	end
end

endmodule
