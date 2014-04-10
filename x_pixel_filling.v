`timescale 1ns / 1ps
/**********************************************************************
 Copyright (c) 2007 Timothy Pearson <kb9vqf@pearsoncomputing.net>
 Copyright (c) 2014 Audrey Pearson <aud.pearson@gmail.com> 

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

module x_pixel_filling (
	//input wires
	input wire clk_div_by_two,
	input wire pause,
	input wire enable_x_pixel_filling,
	input wire [31:0] data_read,
	
	//output regs
	output reg wren,
	output reg [31:0] data_write,
	output reg [17:0] address,
	output reg x_pixel_filling_done
	);

	initial x_pixel_filling_done = 0;

	reg x_pixel_filling_holdoff = 0;

	reg [17:0] x_pixel_filling_counter_tog = 0;
	reg [17:0] x_pixel_filling_counter_togg = 0;
	reg [17:0] x_pixel_filling_counter_toggle = 0;
	reg [31:0] x_pixel_filling_counter_temp = 0;

	reg [31:0] data_read_sync_x_pixel_filling = 0;
	reg [7:0] x_pixel_filling_x_counter = 0;
	reg [7:0] x_pixel_filling_y_counter = 0;
	reg [31:0] x_pixel_filling_counter_buffer_red;
	reg [31:0] x_pixel_filling_counter_buffer_green;
	reg [31:0] x_pixel_filling_counter_buffer_blue;

	// Dominant scan pattern:
	// ------------------------
	// | . --> --> --> (row 1)
	// | . -->         (row 2)
	// | .
	// | .
	// | .

	// Per-pixel scan pattern
	// o: origin
	// n: next pixel in dominant scan pattern
	// x  x  x  x  x
	// x  x  x  x  x
	// x  2  o  1n x
	// x  x  x  x  x
	// x  x  x  x  x
	
	// Fill in missing edge pixels in the X direction.
	//always @(posedge clk) begin
	always @(posedge clk_div_by_two) begin
	//always @(posedge modified_clock) begin
		if (pause == 0) begin
			data_read_sync_x_pixel_filling = data_read;
			
			if (enable_x_pixel_filling == 1) begin
				if (x_pixel_filling_holdoff == 0) begin
					wren = 0;
					address = 2240;								// Skip the topmost 7 lines of the image
					x_pixel_filling_counter_tog = 2240;
					x_pixel_filling_counter_togg = 2240;
					x_pixel_filling_holdoff = 1;
				end else begin
					// Load in the first pixel
					if (x_pixel_filling_counter_toggle == 1) begin
						x_pixel_filling_counter_buffer_red = data_read_sync_x_pixel_filling;			// This is the center pixel
						x_pixel_filling_counter_tog = x_pixel_filling_counter_tog + 1;							// Set next read address (one pixel to the right)
					end
					
					if (x_pixel_filling_counter_toggle == 2) begin
						x_pixel_filling_counter_buffer_green = data_read_sync_x_pixel_filling;		// This is the rightmost pixel
						x_pixel_filling_counter_tog = x_pixel_filling_counter_tog - 2;							// Set next read address (two pixels to the left)
					end
					
					if (x_pixel_filling_counter_toggle == 3) begin
						x_pixel_filling_counter_buffer_blue = data_read_sync_x_pixel_filling;			// This is the leftmost pixel
						x_pixel_filling_counter_tog = x_pixel_filling_counter_tog + 2;							// Set next read address (two pixels to the right)
						
						// OK, we have our data, now we can see if we need to fill this pixel or not!
						x_pixel_filling_counter_temp = x_pixel_filling_counter_buffer_red;
						
						if ((x_pixel_filling_counter_buffer_blue == 1) && (x_pixel_filling_counter_buffer_green == 1)) begin
							x_pixel_filling_counter_temp = 1;
						end
					end
					
					if (x_pixel_filling_counter_togg == 74561) begin		// All done!	It is 74561 because we don't need to process the last 7 lines of the image, as they are just garbage anyway!
						x_pixel_filling_counter_tog = 0;
						x_pixel_filling_counter_togg = 0;
						x_pixel_filling_counter_toggle = 0;
						x_pixel_filling_done = 1;
						x_pixel_filling_holdoff = 0;
						wren = 0;
					end
					
					x_pixel_filling_counter_toggle = x_pixel_filling_counter_toggle + 1;
					if (x_pixel_filling_counter_toggle < 4) begin
						address = x_pixel_filling_counter_tog;
						wren = 0;
					end
					if (x_pixel_filling_counter_toggle == 4) begin
						address = x_pixel_filling_counter_togg;
						data_write = x_pixel_filling_counter_temp;
						wren = 1;
					end
					if (x_pixel_filling_counter_toggle == 5) begin
						wren = 0;
						address = x_pixel_filling_counter_tog;
						x_pixel_filling_counter_togg = x_pixel_filling_counter_togg + 1;
						x_pixel_filling_counter_toggle = 0;
					end
				end
			end else begin
				x_pixel_filling_done = 0;
				address = 18'b0;
				data_write = 32'b0;
				wren = 1'b0;
			end
		end // end if pause == 0
	end
endmodule
