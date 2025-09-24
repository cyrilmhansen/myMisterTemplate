
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
/* verilator lint_off UNUSEDSIGNAL */
reg  [9:0] rnd_reg;
wire [63:0] rnd;
/* verilator lint_on UNUSEDSIGNAL */

wire  [5:0] rnd_c = {rnd_reg[0],rnd_reg[1],rnd_reg[2],rnd_reg[2],rnd_reg[2],rnd_reg[2]};

lfsr random(
        .clk(clk),
        .reset(reset),
        .rnd(rnd)
);

wire [7:0] cpu_led;

soc_demo demo_cpu(
        .clk(clk),
        .reset(reset),
        .led_value(cpu_led)
);

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

        rnd_reg <= rnd[9:0];
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

/* verilator lint_off UNUSEDSIGNAL */
reg  [7:0] cos_out;
wire [11:0] cos_addr_full = {2'b00, vvc} + {vc>>scandouble, 2'b00};
wire [9:0]  cos_addr = cos_addr_full[9:0];
/* verilator lint_on UNUSEDSIGNAL */
wire [5:0] cos_g = cos_out[7:3]+6'd32;
cos cos(cos_addr, cos_out);

wire [7:0] plasma = (cos_g >= rnd_c) ? {cos_g - rnd_c, 2'b00} : 8'd0;
assign video = plasma ^ cpu_led;

endmodule

/* verilator lint_off DECLFILENAME */
module soc_demo
(
        input         clk,
        input         reset,
        output [7:0]  led_value
);

localparam MEM_WORDS = 1024; // 4 KB of tightly-coupled memory

wire [31:0] mem_addr;
wire [31:0] mem_wdata;
wire  [3:0] mem_wmask;
wire [31:0] mem_rdata;
wire        mem_rstrb;
wire        mem_rbusy = 1'b0;
wire        mem_wbusy = 1'b0;

FemtoRV32 cpu(
        .clk(clk),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb),
        .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy),
        .interrupt_request(1'b0),
        .reset(~reset)
);

localparam [31:0] IO_LED_ADDR = 32'h00001000;

reg [31:0] mem_rdata_reg;
assign mem_rdata = mem_rdata_reg;

reg [31:0] ram [0:MEM_WORDS-1];

(* verilator public_flat_rw *) reg [7:0] led_reg;
assign led_value = led_reg;

initial begin
        led_reg = 8'd0;
        $readmemh("rtl/firmware.hex", ram);
end

wire ram_sel = (mem_addr[31:12] == 20'd0);
wire io_sel  = (mem_addr == IO_LED_ADDR);

wire [9:0] ram_word = mem_addr[11:2];

reg [31:0] write_word;

always @(posedge clk) begin
        if(reset) begin
                led_reg <= 8'd0;
                mem_rdata_reg <= 32'h00000013;
        end else begin
                if(mem_rstrb) begin
                        if(ram_sel) begin
                                mem_rdata_reg <= ram[ram_word];
                        end else if(io_sel) begin
                                mem_rdata_reg <= {24'd0, led_reg};
                        end else begin
                                mem_rdata_reg <= 32'h00000013; // NOP
                        end
                end

                if(|mem_wmask) begin
/* verilator lint_off BLKSEQ */
                        if(ram_sel) begin
                                write_word = ram[ram_word];
                                if(mem_wmask[0]) write_word[7:0]   = mem_wdata[7:0];
                                if(mem_wmask[1]) write_word[15:8]  = mem_wdata[15:8];
                                if(mem_wmask[2]) write_word[23:16] = mem_wdata[23:16];
                                if(mem_wmask[3]) write_word[31:24] = mem_wdata[31:24];
                                ram[ram_word] <= write_word;
                        end else if(io_sel) begin
                                if(mem_wmask[0]) led_reg <= mem_wdata[7:0];
                        end
/* verilator lint_on BLKSEQ */
                end
        end
end

endmodule
/* verilator lint_on DECLFILENAME */
