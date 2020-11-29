/*
 * Sean Michaels
 * Jackson Ryan
 * EECE 343, Fall 2016
 * Lab 5
 */
// Edge detector: every clock cycle check for rst low, else check if previous button press is high and current low output 1
//		else output 0, every clock cycle set previous button press to current button press.
module debounce_button(input clk, rst, en, output reg db_en);
reg en1;

	always @ (posedge clk)begin
		if(~rst) begin
			en1 <= 1'b0;
		end
		else if({en1, en}==2'b10) begin
			db_en <= en1;
		end
		else begin
			db_en <= 1'b0;
		end
		en1 <= en;
	end
endmodule
