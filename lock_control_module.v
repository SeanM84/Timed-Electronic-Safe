/*
 * Sean Michaels
 * Jackson Ryan
 * EECE 343, Fall 2016
 * Lab 5
 */

// Do not modify the definition of the lab5 module except to change an output type (reg/wire).
module lab5(input clk, rst_n, input [17:0] SW, input action_n, output [8:0] count, output [6:0] HEX7, HEX6, HEX5, HEX4, HEX2, HEX1, HEX0, output [3:0] LEDG);

wire [17:0] combo;
wire [8:0]  countx;
wire [6:0]	h7x, h6x, h5x, h4x, h2x, h1x, h0x, h2cnt, h1cnt, h0cnt;
wire [6:0]  blank, L, U;
wire [3:0]	combo1hund, combo1tens, combo1ones;
wire [3:0]	combo2hund, combo2tens, combo2ones;
wire [3:0] 	combo3hund, combo3tens, combo3ones;
wire [3:0]  cnt_hund, cnt_tens, cnt_ones;
wire [2:0] 	state;
wire 			en;

//-----HEX7, HEX6 Variables------------------------------------------------------
assign blank = ~7'b0000000;
assign L		 = ~7'b0111000;
assign U		 = ~7'b0111110;

//-------------Assign Combo Depending on State and Button Press------------------
assign combo = ((state == 3'b000) && en)? SW : combo;
//------------Edge Detector For Action Button------------------------------------
debounce_button bPress(clk, rst_n, action_n, en);

//------------Sets State---------------------------------------------------------
state_encoder safe_control(clk, rst_n, en, combo, SW, state, countx);

//------------Convert SW and Count Into Decimal------------------------------------
bcd_converter comb01_BCD({3'b000, SW[17:12]}, combo1hund, combo1tens, combo1ones);
bcd_converter combo2_BCD({3'b000, SW[11:6]},  combo2hund, combo2tens, combo2ones);
bcd_converter combo3_BCD({3'b000, SW[5:0]},   combo3hund, combo3tens, combo3ones);
bcd_converter counted(countx, cnt_hund, cnt_tens, cnt_ones);

//------------Display HEX7-HEX4, HEX2-HEX0 When State == 000------------------------------------------
segment_display combo1tens_SD(combo1tens, h7x);
segment_display combo1ones_SD(combo1ones, h6x);
segment_display combo2tens_SD(combo2tens, h5x);
segment_display combo2ones_SD(combo2ones, h4x);
segment_display combo3hund_SD(combo3hund, h2x);
segment_display combo3tens_SD(combo3tens, h1x);
segment_display combo3ones_SD(combo3ones, h0x);

//-----------Display For HEX2-HEX0 In All States Except State == 000 -------------------------
segment_display cnt_hund_SD(cnt_hund, h2cnt);
segment_display cnt_tens_SD(cnt_tens, h1cnt);
segment_display cnt_ones_SD(cnt_ones, h0cnt);

//-----------HEX Outputs Assign by State--------------------------------------------------------
assign HEX7 = (state == 3'b000)? h7x : blank;
assign HEX6 = (state == 3'b000)? h6x : (state == 3'b100)? U : L;
assign HEX5 = (state == 3'b000)? h5x : (state == 3'b100)? ~7'b0000000 : h1x;
assign HEX4 = (state == 3'b000)? h4x : (state == 3'b100)? ~7'b0000000 : h0x;
assign HEX2 = (state == 3'b000)? h2x : h2cnt;
assign HEX1 = (state == 3'b000)? h1x : h1cnt;
assign HEX0 = (state == 3'b000)? h0x : h0cnt;

//--------------LED Assign By State--------------------------------------------------
assign LEDG = (state == 3'b000)? 4'b000 : (state == 3'b001)? 4'b0001 : (state == 3'b010)? 4'b0011 : (state == 3'b011)? 4'b0111 : 4'b1111;
assign count = countx;
endmodule

/*
 * Do not modify the modules below. They are setup to provide a clock divider
 * for your main module and allow the testbench to run at that slower clock
 * rate.
 */
module lab5_top(input clk_in, rst_n, input [17:0] SW, input action_n, output [6:0] HEX7, HEX6, HEX5, HEX4, HEX2, HEX1, HEX0, output [3:0] LEDG);
	wire clk;
	clk_divider c0 (.clk_in(clk_in), .rst_n(rst_n), .clk_out(clk));
	lab5 device(clk, rst_n, SW, action_n, HEX7, HEX6, HEX5, HEX4, HEX2, HEX1, HEX0, LEDG);
endmodule
