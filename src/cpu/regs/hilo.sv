// hilo
`include "regs.svh"

module hilo #(

) (
    // external signals
    input   logic   clk,
    input   logic   rst,
    // wr & rd req
    input   logic       we,
    input   uint64_t    wrdata,
    output  uint64_t    rddata
);

uint64_t hilo;

// update hilo
always @ (posedge clk) begin
    if(rst)
        hilo <= '0;
    else if (we)
        hilo <= wrdata;
end

// set rddata
assign rddata = hilo;

endmodule
