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

module edge_detection(
	//input wires
	input wire clk,
	input wire pause,
	input wire [31:0] data_read,
	input wire enable_edge_detection,
	input wire edge_detection_threshold_red,
	input wire edge_detection_threshold_green,
	input wire edge_detection_threshold_blue,
	
	//output regs
	output reg wren,
	output reg [31:0] data_write,
	output reg [17:0] address,
	output reg edge_detection_done
	);
	
	initial edge_detection_done = 0;
	
	reg edge_detection_holdoff = 0;	//here only
	reg [17:0] edge_detection_counter_tog = 0;
	reg [17:0] edge_detection_counter_togg = 0;
	reg [17:0] edge_detection_counter_toggle = 0;
	reg [31:0] edge_detection_counter_temp = 0;

	reg [31:0] data_read_sync_edge_detection = 0;
	reg edge_detection_main_chunk_already_loaded = 0;
	reg [7:0] edge_detection_x_counter = 0;
	reg [7:0] edge_detection_y_counter = 0;
	reg [23:0] edge_detection_counter_buffer_red;
	reg [23:0] edge_detection_counter_buffer_green;
	reg [23:0] edge_detection_counter_buffer_blue;
	reg [15:0] edge_detection_running_total_red = 0;
	reg [15:0] edge_detection_running_total_green = 0;
	reg [15:0] edge_detection_running_total_blue = 0;
	reg [15:0] edge_detection_running_total_ave_red = 0;
	reg [15:0] edge_detection_running_total_ave_green = 0;
	reg [15:0] edge_detection_running_total_ave_blue = 0;
	
	reg edge_detection_skip_this_column = 0;

	
	parameter edge_detector_averaging_window = 16;
	//parameter edge_detector_averaging_window = 15;
	//parameter edge_detector_averaging_window = 14;
	
	// For every pixel, see if it lies on an edge.
	always @(posedge clk) begin
	if (pause == 0) begin
		if (enable_edge_detection == 1) begin
			if (edge_detection_holdoff == 0) begin
				wren = 0;
				address = 79041;								// Skip the topmost 7 lines of the image
				edge_detection_counter_tog = 79041;
				edge_detection_counter_togg = 2240;
				edge_detection_holdoff = 1;
				edge_detection_counter_toggle = 1;
				edge_detection_main_chunk_already_loaded = 0;
				edge_detection_running_total_red = 0;
				edge_detection_running_total_green = 0;
				edge_detection_running_total_blue = 0;
			end else begin				
				data_read_sync_edge_detection = data_read;
				
				// Now find the average of the surrounding pixels (8 in either direction :ahh:)
				if (edge_detection_counter_toggle == 4) begin
					if (edge_detection_main_chunk_already_loaded == 1) begin
						// Main chunk already loaded--simply load what we need to continue
						if (edge_detection_skip_this_column == 0) begin
							if (edge_detection_y_counter < (edge_detector_averaging_window * 2)) begin
								if (edge_detection_y_counter < edge_detector_averaging_window) begin
									// Set up the next read operation
									if (edge_detection_y_counter != (edge_detector_averaging_window - 2)) begin
										address = (((edge_detection_counter_tog - (edge_detector_averaging_window / 2)) + (edge_detection_y_counter * 320)) - (((edge_detector_averaging_window / 2) - 2) * 320));
									end else begin
										address = ((edge_detection_counter_tog + (edge_detector_averaging_window / 2)) - (((edge_detector_averaging_window / 2) - 1) * 320));
									end
									
									// Load the leftmost column and subtract each value from the accumulators
									edge_detection_running_total_red = edge_detection_running_total_red - data_read[7:0];	// This is whatever pixel I previously loaded in!
									edge_detection_running_total_green = edge_detection_running_total_green - data_read[15:8];
									edge_detection_running_total_blue = edge_detection_running_total_blue - data_read[31:24];
								end else begin
									// Set up the next read operation
									address = (((edge_detection_counter_tog + (edge_detector_averaging_window / 2)) + ((edge_detection_y_counter - edge_detector_averaging_window) * 320)) - (((edge_detector_averaging_window / 2) - 2) * 320));
									
									// Load the rightmost column and add each value to the accumulators
									edge_detection_running_total_red = edge_detection_running_total_red + data_read[7:0];	// This is whatever pixel I previously loaded in!
									edge_detection_running_total_green = edge_detection_running_total_green + data_read[15:8];
									edge_detection_running_total_blue = edge_detection_running_total_blue + data_read[31:24];
								end
								edge_detection_y_counter = edge_detection_y_counter + 2;
							end else begin
								edge_detection_y_counter = 0;
								edge_detection_skip_this_column = 1;
								edge_detection_counter_toggle = edge_detection_counter_toggle + 1;	// Next stage, please!
							end
						end else begin
							edge_detection_skip_this_column = 0;
							edge_detection_counter_toggle = edge_detection_counter_toggle + 1;	// Next stage, please!
						end
					end else begin
						// for x=0 to 16
						if (edge_detection_x_counter < edge_detector_averaging_window) begin
							// for y=0 to 16
							if (edge_detection_y_counter < edge_detector_averaging_window) begin
								// Set up the next read operation...
								address = ((((edge_detection_counter_tog + edge_detection_x_counter) - ((edge_detector_averaging_window / 2) - 1)) + (edge_detection_y_counter * 320)) - (((edge_detector_averaging_window / 2) - 1) * 320));
								wren = 0;

								// Keep a running total of all the points that I visit...
								edge_detection_running_total_red = edge_detection_running_total_red + data_read[7:0];	// This is whatever pixel I previously loaded in!
								edge_detection_running_total_green = edge_detection_running_total_green + data_read[15:8];
								edge_detection_running_total_blue = edge_detection_running_total_blue + data_read[31:24];
						
								// next y
								edge_detection_y_counter = edge_detection_y_counter + 2;
							end else begin
								edge_detection_y_counter = 0;
								// next x
								edge_detection_x_counter = edge_detection_x_counter + 2;
							end
						end else begin
							edge_detection_y_counter = 0;
							edge_detection_skip_this_column = 1;
							edge_detection_main_chunk_already_loaded = 1;
							edge_detection_counter_toggle = edge_detection_counter_toggle + 1;	// Next stage, please!
						end
					end
				end
				
				// Yes, this one IS supposed to be "out of sequence", as it does not need to wait a cycle before continuing on!
				if (edge_detection_counter_toggle == 5) begin
					edge_detection_counter_temp = 0;
					
					// Now that we have all of our data, we can see if this is an edge or not!
					// Finish calculating the average
					edge_detection_running_total_ave_red = edge_detection_running_total_red / 256;
					edge_detection_running_total_ave_green = edge_detection_running_total_green / 256;
					edge_detection_running_total_ave_blue = edge_detection_running_total_blue / 256;
					
					// Add the noise floor thresholds...
					edge_detection_running_total_ave_red = edge_detection_running_total_ave_red + edge_detection_threshold_red;
					edge_detection_running_total_ave_green = edge_detection_running_total_ave_green + edge_detection_threshold_green;
					edge_detection_running_total_ave_blue = edge_detection_running_total_ave_blue + edge_detection_threshold_blue;
					
					// First the red...
					if (edge_detection_counter_buffer_red[7:0] > edge_detection_running_total_ave_red) begin
						if (edge_detection_counter_buffer_red[15:8] < edge_detection_running_total_ave_red) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
						if (edge_detection_counter_buffer_red[23:16] < edge_detection_running_total_ave_red) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
					end else begin
						if (edge_detection_counter_buffer_red[15:8] > edge_detection_running_total_ave_red) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
						if (edge_detection_counter_buffer_red[23:16] > edge_detection_running_total_ave_red) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
					end
					
					// ...next the green...
					if (edge_detection_counter_buffer_green[7:0] > edge_detection_running_total_ave_green) begin
						if (edge_detection_counter_buffer_green[15:8] < edge_detection_running_total_ave_green) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
						if (edge_detection_counter_buffer_green[23:16] < edge_detection_running_total_ave_green) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
					end else begin
						if (edge_detection_counter_buffer_green[15:8] > edge_detection_running_total_ave_green) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
						if (edge_detection_counter_buffer_green[23:16] > edge_detection_running_total_ave_green) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
					end
					
					// ...and finally the blue!
					if (edge_detection_counter_buffer_blue[7:0] > edge_detection_running_total_ave_blue) begin
						if (edge_detection_counter_buffer_blue[15:8] < edge_detection_running_total_ave_blue) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
						if (edge_detection_counter_buffer_blue[23:16] < edge_detection_running_total_ave_blue) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
					end else begin
						if (edge_detection_counter_buffer_blue[15:8] > edge_detection_running_total_ave_blue) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
						if (edge_detection_counter_buffer_blue[23:16] > edge_detection_running_total_ave_blue) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
					end
					
					// For testing ONLY, load in the average values for this pixel and store them so that I can see them!
					//edge_detection_counter_temp[7:0] = edge_detection_running_total_ave_red;
					//edge_detection_counter_temp[15:8] = edge_detection_running_total_ave_green;
					//edge_detection_counter_temp[31:24] = edge_detection_running_total_ave_blue;
					
					edge_detection_counter_tog = edge_detection_counter_tog + 1;			// We need to read from the next pixel
					edge_detection_counter_toggle = edge_detection_counter_toggle + 1;	// Next stage, please!
				end
				
				// Load in the pixel to the right
				if (edge_detection_counter_toggle == 3) begin
					edge_detection_counter_buffer_red[23:16] = data_read[7:0];			// This is the bottom pixel
					edge_detection_counter_buffer_green[23:16] = data_read[15:8];
					edge_detection_counter_buffer_blue[23:16] = data_read[31:24];
					if (edge_detection_main_chunk_already_loaded == 0) begin
						address = edge_detection_counter_tog + (((edge_detector_averaging_window / 2) * 320) + (edge_detector_averaging_window / 2));			// Set next read address (8 down and 8 to the right)
					end else begin
						address = edge_detection_counter_tog - ((((edge_detector_averaging_window / 2) - 1) * 320) + (edge_detector_averaging_window / 2));			// Set next read address (7 up and 8 to the left)
					end
					edge_detection_counter_toggle = edge_detection_counter_toggle + 1;	// Next stage, please!
					edge_detection_x_counter = 0;
					edge_detection_y_counter = 0;
				end
				
				// Load in the pixel to the right
				if (edge_detection_counter_toggle == 2) begin
					edge_detection_counter_buffer_red[15:8] = data_read[7:0];			// This is the rightmost pixel
					edge_detection_counter_buffer_green[15:8] = data_read[15:8];
					edge_detection_counter_buffer_blue[15:8] = data_read[31:24];
					address = edge_detection_counter_tog + 320;			// Set next read address (1 down)
					edge_detection_counter_toggle = edge_detection_counter_toggle + 1;	// Next stage, please!
					edge_detection_x_counter = 0;
					edge_detection_y_counter = 0;
				end
				
				// Load in the first pixel
				if (edge_detection_counter_toggle == 1) begin
					edge_detection_counter_buffer_red[7:0] = data_read[7:0];			// This is the center pixel
					edge_detection_counter_buffer_green[7:0] = data_read[15:8];
					edge_detection_counter_buffer_blue[7:0] = data_read[31:24];
					address = edge_detection_counter_tog + 1;			// Set next read address (1 to the right)
					edge_detection_counter_toggle = edge_detection_counter_toggle + 1;	// Next stage, please!
					edge_detection_x_counter = 0;
					edge_detection_y_counter = 0;
				end
				
				if (edge_detection_counter_togg == 74561) begin		// All done!	It is 74561 because we don't need to process the last 7 lines of the image, as they would just be garbage anyway!
					edge_detection_counter_tog = 0;
					edge_detection_counter_togg = 0;
					edge_detection_counter_toggle = 0;
					edge_detection_done = 1;
					edge_detection_holdoff = 0;
					wren = 0;
				end
				
				if (edge_detection_counter_toggle == 6) begin
					address = edge_detection_counter_togg;
					data_write = edge_detection_counter_temp;
					wren = 1;
				end
				if (edge_detection_counter_toggle == 7) begin
					wren = 0;
					address = edge_detection_counter_tog;
					edge_detection_counter_togg = edge_detection_counter_togg + 1;
					edge_detection_counter_toggle = 1;
				end
				if (edge_detection_counter_toggle > 5) begin
					edge_detection_counter_toggle = edge_detection_counter_toggle + 1;
				end
			end
		end else begin
			edge_detection_done = 0;
			address = 18'b0;
			data_write = 32'b0;
			wren = 1'b0;
		end
	end //end if pause == 0
	end

endmodule
