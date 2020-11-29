/*
 * Sean Michaels
 * Jackson Ryan
 * EECE 343, Fall 2016
 * Lab 6 Timed Electronic Safe
 */

module lab6(
	// Ports identical to Lab 5
	input clk_in, rst_n, action_n,
	input [17:0] SW,
	output [6:0] HEX7, HEX6, HEX5, HEX4, HEX2, HEX1, HEX0,
	output [3:0] LEDG,

	// New LCD ports
	inout [7:0] LCD_DATA,
	output LCD_RW, LCD_EN, LCD_RS, LCD_ON
);


	// This signal is always high to keep the LCD powered
	assign LCD_ON = 1'b1;
	// Setup the two clocks
	//  - lcd_clk should drive all logic on the output side of the RAM block
	//  - safe_clk should drive all logic on the input side of the RAM block
	wire lcd_clk, safe_clk;
	clk_divider #(.BITS(15)) lcd_clk_divider(.clk_in(clk_in), .clk_out(lcd_clk));
	clk_divider #(.BITS(21)) safe_clk_divider(.clk_in(clk_in), .clk_out(safe_clk));

	// Signals that interface to the dual-port RAM block. One port only writes
	// to the memory (mem_wr_??? signals) and the other port only reads from
	// the memory (mem_rd_??? signals).
	// You may need to change the size of these signals if you adjust the RAM
	// block size.
	reg [3:0] mem_rd_addr;
	reg [3:0] mem_wr_addr; // Read and write addresses
	wire [15:0] mem_rd_data;
	reg [15:0] mem_wr_data; // Read and write data
	reg mem_wr_en; // Write enable signal. A write occurs on every safe_clk rising
	                // edge where mem_wr_en is asserted. You may write on
					// consecutive clock edges.
	// Instantiate the RAM block
	ram memory (.data(mem_wr_data), .rdaddress(mem_rd_addr), .rdclock(lcd_clk), .wraddress(mem_wr_addr), .wrclock(safe_clk), .wren(mem_wr_en), .q(mem_rd_data));

	// Instantiate the LCD control state machine
	lcd_control lcd(.clk(lcd_clk), .rst_n(rst_n), .mem_data(mem_rd_data), .LCD_DATA(LCD_DATA), .LCD_RW(LCD_RW), .LCD_EN(LCD_EN), .LCD_RS(LCD_RS));

	wire en; // dbounced button press to pass to lcd_write through memory.
	debounce_button bPress(safe_clk, rst_n, action_n, en);

	// load data needed into 16'b memory location. and set address to write to
	// need en, ledg, and count to be passed to lcd_control through memory.
	// every safe_clk edge high write the data into location 0000
	always @(posedge safe_clk) begin
		mem_wr_en <= 1'b1;
		mem_wr_addr <= 4'h0;
		mem_wr_data <= {2'b00,count,en,ledg};
	end
	//every lcd_clk edge high read data from location 0000 and pass it to lcd_control.
	always @(posedge lcd_clk)begin
		mem_rd_addr <= 4'h0;
	end

	wire[8:0] count;	// number of incorrect guesses from lab5 module.
	wire[3:0] ledg;	// ledg used to signify mode lcd should be in also from lab5 module.
	assign LEDG = ledg;
	// Lab 5 Module, controls 7seg, LEDG, had to additionally pull the out the incorrect count from lab 5.
	lab5 lock_control(.clk(safe_clk), .rst_n(rst_n), .SW(SW), .action_n(action_n), .count(count), .HEX7(HEX7), .HEX6(HEX6), .HEX5(HEX5), .HEX4(HEX4), .HEX2(HEX2), .HEX1(HEX1), .HEX0(HEX0), .LEDG(ledg));
	//wire [15:0] mem_data;
	//assign mem_data = {2'b00, count, en, LEDG};


endmodule

module clk_divider #(parameter BITS = 21) (input clk_in, output clk_out);
	reg [BITS-1:0] cnt;

	always @ (posedge clk_in) begin
		cnt <= cnt + {{BITS-1{1'b0}},1'b1};
	end

	assign clk_out = cnt[BITS-1];
endmodule
