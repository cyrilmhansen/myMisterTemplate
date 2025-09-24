module lfsr
#(
        parameter integer N = 64
)
(
        input              clk,
        input              reset,
        output reg [N-1:0] rnd
);

wire feedback = ~(rnd[N - 1] ^ rnd[N - 3] ^ rnd[N - 4] ^ rnd[N - 6] ^ rnd[N - 10]);

always @(posedge clk) begin
        if(reset) begin
                rnd <= {N{1'b1}};
        end else begin
                rnd <= {rnd[N - 2:0], feedback};
        end
end

endmodule
