// sim_clock
`include "testbench_defs.svh"

module sim_clock(
    output  logic   clk,
    output  logic   rst
);

always #20 clk = ~clk;

initial begin
    rst = 1'b1;
    clk = 1'b0;
    #50 rst = 1'b0;
end

endmodule
