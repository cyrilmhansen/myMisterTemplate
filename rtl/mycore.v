
module mycore
(
	input         clk,
	input         reset,
	
	input         pal,
	input         scandouble,

	output reg    ce_pix,

	output reg    HBlank,
	output reg    HSync,
	output reg    VBlank,
	output reg    VSync,

	output  [7:0] video
);

reg   [9:0] hc;
reg   [9:0] vc;
reg   [9:0] vvc;
reg  [63:0] rnd_reg;

wire  [5:0] rnd_c = {rnd_reg[0],rnd_reg[1],rnd_reg[2],rnd_reg[2],rnd_reg[2],rnd_reg[2]};
wire [63:0] rnd;

lfsr random(rnd);

// -----------------------------------------------------------------------------
// Simple FemtoRV32 integration ------------------------------------------------
// -----------------------------------------------------------------------------

localparam MEM_WORDS = 256;
localparam [31:0] LED_ADDR = 32'h00000100;

wire [31:0] cpu_mem_addr;
wire [31:0] cpu_mem_wdata;
wire  [3:0] cpu_mem_wmask;
wire        cpu_mem_rstrb;
reg  [31:0] cpu_mem_rdata;
reg  [31:0] cpu_led_reg /*verilator public_flat*/;

reg  [31:0] ram [0:MEM_WORDS-1];

wire [7:0]  cpu_word_addr = cpu_mem_addr[9:2];
wire        cpu_addr_in_ram = (cpu_mem_addr[31:10] == 0);
wire        cpu_addr_is_led = (cpu_mem_addr == LED_ADDR);

FemtoRV32 #(
        .RESET_ADDR(32'h00000000)
) cpu (
        .clk(clk),
        .mem_addr(cpu_mem_addr),
        .mem_wdata(cpu_mem_wdata),
        .mem_wmask(cpu_mem_wmask),
        .mem_rdata(cpu_mem_rdata),
        .mem_rstrb(cpu_mem_rstrb),
        .mem_rbusy(1'b0),
        .mem_wbusy(1'b0),
        .interrupt_request(1'b0),
        .reset(~reset)
);

integer i;
initial begin
        cpu_led_reg = 0;
        for(i = 0; i < MEM_WORDS; i = i + 1)
                ram[i] = 32'h00000013; // NOP

        ram[0] = 32'h000000B7; // lui  x1,0
        ram[1] = 32'h10008093; // addi x1,x1,256 -> LED address
        ram[2] = 32'h00000113; // addi x2,x0,0
        ram[3] = 32'h00110113; // addi x2,x2,1
        ram[4] = 32'h0020A023; // sw   x2,0(x1)
        ram[5] = 32'hFF9FF06F; // jal  x0,-8 (loop)
end

always @(posedge clk) begin
        if(reset) begin
                cpu_led_reg <= 0;
        end else if(|cpu_mem_wmask) begin
                if(cpu_addr_is_led) begin
                        if(cpu_mem_wmask[0]) cpu_led_reg[7:0]   <= cpu_mem_wdata[7:0];
                        if(cpu_mem_wmask[1]) cpu_led_reg[15:8]  <= cpu_mem_wdata[15:8];
                        if(cpu_mem_wmask[2]) cpu_led_reg[23:16] <= cpu_mem_wdata[23:16];
                        if(cpu_mem_wmask[3]) cpu_led_reg[31:24] <= cpu_mem_wdata[31:24];
                end else if(cpu_addr_in_ram) begin
                        if(cpu_mem_wmask[0]) ram[cpu_word_addr][7:0]   <= cpu_mem_wdata[7:0];
                        if(cpu_mem_wmask[1]) ram[cpu_word_addr][15:8]  <= cpu_mem_wdata[15:8];
                        if(cpu_mem_wmask[2]) ram[cpu_word_addr][23:16] <= cpu_mem_wdata[23:16];
                        if(cpu_mem_wmask[3]) ram[cpu_word_addr][31:24] <= cpu_mem_wdata[31:24];
                end
        end
end

always @(*) begin
        if(cpu_addr_is_led)
                cpu_mem_rdata = cpu_led_reg;
        else if(cpu_addr_in_ram)
                cpu_mem_rdata = ram[cpu_word_addr];
        else
                cpu_mem_rdata = 32'h00000013;
end

always @(posedge clk) begin
	if(scandouble) ce_pix <= 1;
		else ce_pix <= ~ce_pix;

	if(reset) begin
		hc <= 0;
		vc <= 0;
	end
	else if(ce_pix) begin
		if(hc == 637) begin
			hc <= 0;
			if(vc == (pal ? (scandouble ? 623 : 311) : (scandouble ? 523 : 261))) begin 
				vc <= 0;
				vvc <= vvc + 9'd6;
			end else begin
				vc <= vc + 1'd1;
			end
		end else begin
			hc <= hc + 1'd1;
		end

		rnd_reg <= rnd;
	end
end

always @(posedge clk) begin
	if (hc == 529) HBlank <= 1;
		else if (hc == 0) HBlank <= 0;

	if (hc == 544) begin
		HSync <= 1;

		if(pal) begin
			if(vc == (scandouble ? 609 : 304)) VSync <= 1;
				else if (vc == (scandouble ? 617 : 308)) VSync <= 0;

			if(vc == (scandouble ? 601 : 300)) VBlank <= 1;
				else if (vc == 0) VBlank <= 0;
		end
		else begin
			if(vc == (scandouble ? 490 : 245)) VSync <= 1;
				else if (vc == (scandouble ? 496 : 248)) VSync <= 0;

			if(vc == (scandouble ? 480 : 240)) VBlank <= 1;
				else if (vc == 0) VBlank <= 0;
		end
	end
	
	if (hc == 590) HSync <= 0;
end

reg  [7:0] cos_out;
wire [5:0] cos_g = cos_out[7:3]+6'd32;
cos cos(vvc + {vc>>scandouble, 2'b00}, cos_out);

wire [7:0] base_video = (cos_g >= rnd_c) ? {cos_g - rnd_c, 2'b00} : 8'd0;
assign video = base_video ^ cpu_led_reg[7:0];

endmodule
