/*
 * Sean Michaels
 * Jackson Ryan
 * EECE 343, Fall 2016
 * Lab 6
 */
// The basic LCD control module, which only performs the initialization
// process for the LCD. Add any ports or states you need to display the
// messages for Lab 6. Try to reuse the states that are already present.
module lcd_control (
	input clk, rst_n,
	input [15:0] mem_data,										// data read from memory
	inout [7:0] LCD_DATA,
	output reg LCD_RW, LCD_EN, LCD_RS
);

	// State definitions
	localparam S_INIT_LCD          = 5'b00000;
	localparam S_BEGIN_TRANSACTION = 5'b00001;			// Enable LCD
	localparam S_END_TRANSACTION   = 5'b00010;			//
	localparam S_SETUP_BUSY_READ   = 5'b00011;
	localparam S_BEGIN_BUSY_READ   = 5'b00100;
	localparam S_END_BUSY_READ     = 5'b00101;
	localparam S_LCD_ENTRY_SET     = 5'b00110;
	localparam S_LCD_CLEAR         = 5'b00111;
	localparam S_LCD_DISPLAY_ON    = 5'b01000;
	localparam S_LCD_END_INIT      = 5'b01001;

	// LCD command values
	localparam CMD_LCD_FUNCTION_SET = 8'b00111000;
	localparam CMD_LCD_DISPLAY_ON   = 8'b00001110;
	localparam CMD_LCD_CLEAR        = 8'b00000001;
	localparam CMD_LCD_ENTRY_SET    = 8'b00000110;
	localparam CMD_LCD_CURSOR_RESET = 8'b00000010;		// resets the position back to 00 of lcd

	// Other constants
	localparam INIT_DELAY_COUNT_MAX = 23; // Clock cycles to delay between initialization commands
	localparam LCD_INIT_COUNT_MAX   = 4;  // Number of times to perform FUNCTION SET command


	// Current state
	reg [4:0] state;

	// When done with transaction, return to this state
	reg [4:0] return_state;

	// lcd position markers
	reg [4:0] lcd_pos;

	// binary to decimal then concat to 4'h3 for easy conversion to ascii table
	wire [3:0] hunds, ones, tens;
	wire [7:0] ascii_hund, ascii_tens, ascii_ones;
	bcd_converter count_d(.value(mem_data[13:5]), .hund(hunds), .tens(tens), .ones(ones));
	assign ascii_hund = {4'h3, hunds};
	assign ascii_tens = {4'h3, tens};
	assign ascii_ones = {4'h3, ones};

	// Signals for inout port
	wire [7:0] LCD_DATA_IN;
	reg [7:0] LCD_DATA_OUT;

	// Signals to control INIT process
	reg init_done;
	reg [16:0] init_delay_count;
	reg [2:0] init_count;

	// Standard inout port assignments
	assign LCD_DATA = (LCD_RW) ? 8'hZZ : LCD_DATA_OUT;
	assign LCD_DATA_IN = LCD_DATA;

	// Main state machine
	always @ (posedge clk) begin
		if( ~rst_n ) begin
			state <= S_INIT_LCD;
			init_done <= 0;
			init_delay_count <= 0;
			init_count <= 0;
			LCD_EN <= 0;
			LCD_RS <= 0;
			LCD_RW <= 0;
			LCD_DATA_OUT <= CMD_LCD_CLEAR;
			lcd_pos <= 0;
		end
		else begin
			case(state)
				/* -----------------------------------------------------
				 * Beginning of shared states that perform a transaction
				 * -----------------------------------------------------*/
				// Start the transaction by enabling the LCD
				S_BEGIN_TRANSACTION: begin
					LCD_EN <= 1;
					state <= S_END_TRANSACTION;
				end
				// End the transaction by disabling the LCD
				S_END_TRANSACTION: begin
					LCD_EN <= 0;

					// Read the busy signal by default
					if( init_done )
						state <= S_SETUP_BUSY_READ;
					// While in init the busy signal is not available
					else
						state <= return_state;
				end
				// Prepare the control lines for a read
				S_SETUP_BUSY_READ: begin
					LCD_RS <= 0;
					LCD_RW <= 1;
					state <= S_BEGIN_BUSY_READ;
				end
				// Perform the read transaction
				S_BEGIN_BUSY_READ: begin
					LCD_EN <= 1;
					state <= S_END_BUSY_READ;
				end
				// Check the busy signal
				S_END_BUSY_READ: begin
					LCD_EN <= 0;
					// LCD complete, go to the next state
					if( LCD_DATA_IN[7] == 0 ) begin
						state <= return_state;
					end
					// LCD still busy, try again
					else begin
						state <= S_SETUP_BUSY_READ;
					end
				end
				/* -----------------------------------------------------
				 * End of shared states that perform a transaction
				 * -----------------------------------------------------*/

				// Perform a FUNCTION SET command multiple times
				S_INIT_LCD: begin
					LCD_RS <= 0;
					LCD_RW <= 0;
					LCD_DATA_OUT <= CMD_LCD_FUNCTION_SET;
					return_state <= S_INIT_LCD;
					init_delay_count <= init_delay_count + 17'd1;

					// Wait for a given number of clock cycles between
					// FUNCTION SET commands
					if( init_delay_count == INIT_DELAY_COUNT_MAX ) begin
						init_delay_count <= 0;
						init_count <= init_count + 3'd1;
						state <= S_BEGIN_TRANSACTION;

						// Repeat the FUNCTION SET command multiple times
						if( init_count == LCD_INIT_COUNT_MAX ) begin
							return_state <= S_LCD_DISPLAY_ON;
							init_done <= 1;
						end
					end
				end

				// Send the DISPLAY ON command
				S_LCD_DISPLAY_ON: begin
					LCD_RS <= 0;
					LCD_RW <= 0;
					LCD_DATA_OUT <= CMD_LCD_DISPLAY_ON;
					return_state <= S_LCD_CLEAR;
					state <= S_BEGIN_TRANSACTION;
				end

				// Send the LCD CLEAR command
				S_LCD_CLEAR: begin
					LCD_RS <= 0;
					LCD_RW <= 0;
					LCD_DATA_OUT <= CMD_LCD_CLEAR;
					return_state <= S_LCD_ENTRY_SET;
					state <= S_BEGIN_TRANSACTION;
				end

				// Send the ENTRY SET command
				S_LCD_ENTRY_SET: begin
					LCD_RS <= 0;
					LCD_DATA_OUT = CMD_LCD_ENTRY_SET;
					return_state <= S_LCD_END_INIT;
					state <= S_BEGIN_TRANSACTION;
				end

				// Initialization complete.
				// This state could begin to display information on the LCD.
				S_LCD_END_INIT: begin
					// Display something

					if(mem_data[4])begin											// at every button press clear lcd, reset lcd_pos to 00;
						lcd_pos <= 5'h00;
						LCD_RS <= 0;
						LCD_RW <= 0;
						LCD_DATA_OUT <= CMD_LCD_CLEAR;
					end

					else begin
					case(mem_data[3:0])											// use the LED's from memory to control mode of lcd
					4'b0000:begin													// mode 0000 = entry, loops through display "Enter Combo"
						if(lcd_pos <= 5'h0f)begin								// only write this message if LCD position is 00-0f
							LCD_RS <= 1;											// write to LCD command
							LCD_RW <= 0;
							case(lcd_pos)
							5'h0: LCD_DATA_OUT <= "E";
							5'h1: LCD_DATA_OUT <= "n";
							5'h2: LCD_DATA_OUT <= "t";
							5'h3: LCD_DATA_OUT <= "e";
							5'h4: LCD_DATA_OUT <= "r";
							5'h5: LCD_DATA_OUT <= " ";
							5'h6: LCD_DATA_OUT <= "C";
							5'h7: LCD_DATA_OUT <= "o";
							5'h8: LCD_DATA_OUT <= "m";
							5'h9: LCD_DATA_OUT <= "b";
							5'hA: LCD_DATA_OUT <= "o";
							default : LCD_DATA_OUT <= " ";
							endcase
							lcd_pos <= lcd_pos + 1'b1;							// increment LCD position
	               end
						else begin
							LCD_RS <= 0;											// if position > 0f reset cursor position.
							LCD_RW <= 0;
							LCD_DATA_OUT <= CMD_LCD_CURSOR_RESET;			// found in datasheet of LCD
							lcd_pos <= 5'h00;										// position location reset to 00 as well
						end
					end
					4'b0001:begin													// locked state 1
						if(lcd_pos <= 5'h0e)begin
							LCD_RS <= 1;
							LCD_RW <= 0;
							case(lcd_pos)
							5'h00: LCD_DATA_OUT <= "L";
							5'h01: LCD_DATA_OUT <= "o";
							5'h02: LCD_DATA_OUT <= "c";
							5'h03: LCD_DATA_OUT <= "k";
							5'h04: LCD_DATA_OUT <= "e";
							5'h05: LCD_DATA_OUT <= "d";
							default : LCD_DATA_OUT <= " ";
							endcase
							lcd_pos <= lcd_pos + 1'b1;
	               end
						else begin
							if(lcd_pos == 5'h0f)begin							// if at edge of top row lcd 0f, push counter to 10
								LCD_RS <= 0;										// RS = 0, RW = 0, is write command to LCD
								LCD_RW <= 0;
								LCD_DATA_OUT <= 8'b11000000;					// LCD Move cursor 8'b1 add add add add add add add
								lcd_pos <= 5'h10;									// sets lcd position to 40 which is beginning of bottom row.
							end
							else if(lcd_pos < 5'h1f)begin						// now that LCD cursor and LCD position counter are in place
								LCD_RS <= 1;										// for the bottom row, write count and attempts.
								LCD_RW <= 0;
								case(lcd_pos)
								5'h10: LCD_DATA_OUT <= ascii_hund;			// already bcd_converter(count) then {4'h3,hund}, {4'h3,tens}, {4'h3,ones}
								5'h11: LCD_DATA_OUT <= ascii_tens;			// to conver them to aski no matter the value (0-9)
								5'h12: LCD_DATA_OUT <= ascii_ones;
								5'h13: LCD_DATA_OUT <= " ";
								5'h14: LCD_DATA_OUT <= "A";
								5'h15: LCD_DATA_OUT <= "t";
								5'h16: LCD_DATA_OUT <= "t";
								5'h17: LCD_DATA_OUT <= "e";
								5'h18: LCD_DATA_OUT <= "m";
								5'h19: LCD_DATA_OUT <= "p";
								5'h1a: LCD_DATA_OUT <= "t";
								5'h1b: LCD_DATA_OUT <= "s";
								5'h1c: LCD_DATA_OUT <= " ";
								default: LCD_DATA_OUT <= " ";
								endcase
								lcd_pos <= lcd_pos + 1'b1;
							end
							else begin
								LCD_RS <= 0;										// move cursor back up
								LCD_RW <= 0;
								LCD_DATA_OUT <= CMD_LCD_CURSOR_RESET;
								lcd_pos <= 5'h00;
							end
						end
					end

					4'b0011:begin
						if(lcd_pos <= 5'h0e)begin
							LCD_RS <= 1;
							LCD_RW <= 0;
							case(lcd_pos)
							5'h00: LCD_DATA_OUT <= "L";
							5'h01: LCD_DATA_OUT <= "o";
							5'h02: LCD_DATA_OUT <= "c";
							5'h03: LCD_DATA_OUT <= "k";
							5'h04: LCD_DATA_OUT <= "e";
							5'h05: LCD_DATA_OUT <= "d";
							default : LCD_DATA_OUT <= " ";
							endcase
							lcd_pos <= lcd_pos + 1'b1;
	               end
						else begin
							if(lcd_pos == 5'h0f)begin
								LCD_RS <= 0;
								LCD_RW <= 0;
								LCD_DATA_OUT <= 8'b11000000;
								lcd_pos <= 5'h10;
							end
							else if(lcd_pos < 5'h1f)begin
								LCD_RS <= 1;
								LCD_RW <= 0;
								case(lcd_pos)
								5'h10: LCD_DATA_OUT <= ascii_hund;
								5'h11: LCD_DATA_OUT <= ascii_tens;
								5'h12: LCD_DATA_OUT <= ascii_ones;
								5'h13: LCD_DATA_OUT <= " ";
								5'h14: LCD_DATA_OUT <= "A";
								5'h15: LCD_DATA_OUT <= "t";
								5'h16: LCD_DATA_OUT <= "t";
								5'h17: LCD_DATA_OUT <= "e";
								5'h18: LCD_DATA_OUT <= "m";
								5'h19: LCD_DATA_OUT <= "p";
								5'h1a: LCD_DATA_OUT <= "t";
								5'h1b: LCD_DATA_OUT <= "s";
								5'h1c: LCD_DATA_OUT <= " ";
								default: LCD_DATA_OUT <= " ";
								endcase
								lcd_pos <= lcd_pos + 1'b1;
							end
							else begin
								LCD_RS <= 0;
								LCD_RW <= 0;
								LCD_DATA_OUT <= CMD_LCD_CURSOR_RESET;
								lcd_pos <= 5'h00;
							end
						end
					end

					4'b0111:begin
						if(lcd_pos <= 5'h0e)begin
							LCD_RS <= 1;
							LCD_RW <= 0;
							case(lcd_pos)
							5'h00: LCD_DATA_OUT <= "L";
							5'h01: LCD_DATA_OUT <= "o";
							5'h02: LCD_DATA_OUT <= "c";
							5'h03: LCD_DATA_OUT <= "k";
							5'h04: LCD_DATA_OUT <= "e";
							5'h05: LCD_DATA_OUT <= "d";
							default : LCD_DATA_OUT <= " ";
							endcase
							lcd_pos <= lcd_pos + 1'b1;
	               end
						else begin
							if(lcd_pos == 5'h0f)begin
								LCD_RS <= 0;
								LCD_RW <= 0;
								LCD_DATA_OUT <= 8'b11000000;
								lcd_pos <= 5'h10;
							end
							else if(lcd_pos < 5'h1f)begin
								LCD_RS <= 1;
								LCD_RW <= 0;
								case(lcd_pos)
								5'h10: LCD_DATA_OUT <= ascii_hund;
								5'h11: LCD_DATA_OUT <= ascii_tens;
								5'h12: LCD_DATA_OUT <= ascii_ones;
								5'h13: LCD_DATA_OUT <= " ";
								5'h14: LCD_DATA_OUT <= "A";
								5'h15: LCD_DATA_OUT <= "t";
								5'h16: LCD_DATA_OUT <= "t";
								5'h17: LCD_DATA_OUT <= "e";
								5'h18: LCD_DATA_OUT <= "m";
								5'h19: LCD_DATA_OUT <= "p";
								5'h1a: LCD_DATA_OUT <= "t";
								5'h1b: LCD_DATA_OUT <= "s";
								5'h1c: LCD_DATA_OUT <= " ";
								default: LCD_DATA_OUT <= " ";
								endcase
								lcd_pos <= lcd_pos + 1'b1;
							end
							else begin
								LCD_RS <= 0;
								LCD_RW <= 0;
								LCD_DATA_OUT <= CMD_LCD_CURSOR_RESET;
								lcd_pos <= 5'h00;
							end
						end
					end

					4'b1111:begin
						if(lcd_pos <= 5'h0e)begin
							LCD_RS <= 1;
							LCD_RW <= 0;
							case(lcd_pos)
							5'h00: LCD_DATA_OUT <= "U";
							5'h01: LCD_DATA_OUT <= "n";
							5'h02: LCD_DATA_OUT <= "l";
							5'h03: LCD_DATA_OUT <= "o";
							5'h04: LCD_DATA_OUT <= "c";
							5'h05: LCD_DATA_OUT <= "k";
							5'h06: LCD_DATA_OUT <= "e";
							5'h07: LCD_DATA_OUT <= "d";
							5'h08: LCD_DATA_OUT <= " ";
							5'h09: LCD_DATA_OUT <= " ";
							5'h0A: LCD_DATA_OUT <= " ";
							default : LCD_DATA_OUT <= " ";
							endcase
							lcd_pos <= lcd_pos + 1'b1;
	               end
						else begin
							if(lcd_pos == 5'h0f)begin
								LCD_RS <= 0;
								LCD_RW <= 0;
								LCD_DATA_OUT <= 8'b11000000;
								lcd_pos <= 5'h10;
							end
							else begin
								LCD_RS <= 0;
								LCD_RW <= 0;
								LCD_DATA_OUT <= CMD_LCD_CURSOR_RESET;
								lcd_pos <= 5'h00;
							end
						end
					end
					default: begin
						LCD_RS <= 1;
						LCD_RW <= 0;
						LCD_DATA_OUT <= "_";
					end
					endcase
					end // end else
					return_state <= S_LCD_END_INIT;
					state <= S_BEGIN_TRANSACTION;
				end //

				default: begin
					LCD_EN <= 0;
					state <= S_INIT_LCD; // Could also define an error state
				end
			endcase
		end
	end
endmodule
