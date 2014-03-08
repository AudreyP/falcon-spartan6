`timescale 1ns / 1ps
/**********************************************************************
 Copyright (c) 2007-2014 Timothy Pearson <kb9vqf@pearsoncomputing.net>

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; version 2.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 02111-1307, USA
**********************************************************************/

module seven_segment_output(
	//input wires
	input wire clk,
	input wire [13:0] display_value,
	input wire show_decimal,

	//output regs
	output reg [7:0] sseg,		// Give myself a 7-segment display register
	output reg [3:0] cseg		// Give myself a 7-segment control register
	);

	reg [17:0] digit4_thousands;
	reg [14:0] digit3_hundreds;

	reg [7:0] sevenseg_multiplex = 0;
	reg [7:0] digit1 = 0;
	reg [7:0] digit2 = 0;
	reg [7:0] digit3 = 0;
	reg [7:0] digit4 = 0;
	reg [7:0] nextseg = 0;
	reg [15:0] sevenseg_delay = 0;

	// Display the current contents of the display_value register on the 7seg display.
	always @(posedge clk) begin		
		if (display_value < 1000) digit4 = 0;
		if ((display_value > 999) && (display_value < 2000)) digit4 = 1;
		if ((display_value > 1999) && (display_value < 3000)) digit4 = 2;
		if ((display_value > 2999) && (display_value < 4000)) digit4 = 3;
		if ((display_value > 3999) && (display_value < 5000)) digit4 = 4;
		if ((display_value > 4999) && (display_value < 6000)) digit4 = 5;
		if ((display_value > 5999) && (display_value < 7000)) digit4 = 6;
		if ((display_value > 6999) && (display_value < 8000)) digit4 = 7;
		if ((display_value > 7999) && (display_value < 9000)) digit4 = 8;
		if (display_value > 8999) digit4 = 9;
		digit4_thousands = digit4 * 1000;

		if ((display_value - digit4_thousands) < 100) digit3 = 0;
		if (((display_value - digit4_thousands) > 99) && ((display_value - digit4_thousands) < 200)) digit3 = 1;
		if (((display_value - digit4_thousands) > 199) && ((display_value - digit4_thousands) < 300)) digit3 = 2;
		if (((display_value - digit4_thousands) > 299) && ((display_value - digit4_thousands) < 400)) digit3 = 3;
		if (((display_value - digit4_thousands) > 399) && ((display_value - digit4_thousands) < 500)) digit3 = 4;
		if (((display_value - digit4_thousands) > 499) && ((display_value - digit4_thousands) < 600)) digit3 = 5;
		if (((display_value - digit4_thousands) > 599) && ((display_value - digit4_thousands) < 700)) digit3 = 6;
		if (((display_value - digit4_thousands) > 699) && ((display_value - digit4_thousands) < 800)) digit3 = 7;
		if (((display_value - digit4_thousands) > 799) && ((display_value - digit4_thousands) < 900)) digit3 = 8;
		if ((display_value - digit4_thousands) > 899) digit3 = 9;
		digit3_hundreds = digit3 * 100;

		if ((display_value - digit4_thousands - digit3_hundreds) < 10) digit2 = 0;
		if (((display_value - digit4_thousands - digit3_hundreds) > 9) && ((display_value - digit4_thousands - digit3_hundreds) < 20)) digit2 = 1;
		if (((display_value - digit4_thousands - digit3_hundreds) > 19) && ((display_value - digit4_thousands - digit3_hundreds) < 30)) digit2 = 2;
		if (((display_value - digit4_thousands - digit3_hundreds) > 29) && ((display_value - digit4_thousands - digit3_hundreds) < 40)) digit2 = 3;
		if (((display_value - digit4_thousands - digit3_hundreds) > 39) && ((display_value - digit4_thousands - digit3_hundreds) < 50)) digit2 = 4;
		if (((display_value - digit4_thousands - digit3_hundreds) > 49) && ((display_value - digit4_thousands - digit3_hundreds) < 60)) digit2 = 5;
		if (((display_value - digit4_thousands - digit3_hundreds) > 59) && ((display_value - digit4_thousands - digit3_hundreds) < 70)) digit2 = 6;
		if (((display_value - digit4_thousands - digit3_hundreds) > 69) && ((display_value - digit4_thousands - digit3_hundreds) < 80)) digit2 = 7;
		if (((display_value - digit4_thousands - digit3_hundreds) > 79) && ((display_value - digit4_thousands - digit3_hundreds) < 90)) digit2 = 8;
		if ((display_value - digit4_thousands - digit3_hundreds) > 89) digit2 = 9;

		digit1 = display_value - digit4_thousands - digit3_hundreds - (digit2 * 10);
		
		if (sevenseg_multiplex == 0) begin
			nextseg = digit4;
			cseg = 14;
		end
		if (sevenseg_multiplex == 1) begin
			nextseg = digit3;
			cseg = 13;
		end
		if (sevenseg_multiplex == 2) begin
			nextseg = digit2;
			cseg = 11;
		end
		if (sevenseg_multiplex == 3) begin
			nextseg = digit1;
			cseg = 7;
		end

		if (nextseg == 0) begin
			sseg = 64;
		end
		if (nextseg == 1) begin
			sseg = 121;
		end
		if (nextseg == 2) begin
			sseg = 36;
		end
		if (nextseg == 3) begin
			sseg = 48;
		end
		if (nextseg == 4) begin
			sseg = 25;
		end
		if (nextseg == 5) begin
			sseg = 18;
		end				
		if (nextseg == 6) begin
			sseg = 2;
		end
		if (nextseg == 7) begin
			sseg = 120;
		end
		if (nextseg == 8) begin
			sseg = 0;
		end
		if (nextseg == 9) begin
			sseg = 16;
		end
		
		if (show_decimal == 1'b0) begin
			sseg[7] = 1;
		end else begin
			// Illuminate the correct decimal point
			if (sevenseg_multiplex == 0) begin
				sseg[7] = 0;
			end else begin
				sseg[7] = 1;
			end
		end
		
		// loop controller
		sevenseg_delay = sevenseg_delay + 1;
		if (sevenseg_delay > 1500) begin
			sevenseg_delay = 0;
			sevenseg_multiplex = sevenseg_multiplex + 1;
			if (sevenseg_multiplex > 3) begin
				sevenseg_multiplex = 0;
			end
		end
	end

endmodule
