`timescale 1ns / 1ps
/**********************************************************************
 Copyright (c) 2007-2014 Timothy Pearson <kb9vqf@pearsoncomputing.net>
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

// This module writes a complete list of all detected blobs in the image to a region in memory starting at BlobStorageOffset
// Each blob is represented by a data structure with the following format:
// Bit fields	|         31 - 24         |         23 - 16         |         15 - 8         |        7 - 0         |
// -------------+-------------------------+-------------------------+------------------------+----------------------+
// Word 0:	|       red average       |      green average      |      blue average      | matching color slot  |
// Word 1:	|  centroid x coordinate  |  centroid y coordinate  |                    blob size                  |
// Word 2:	|   leftmost blob pixel   |    lowest blob pixel    |  rightmost blob pixel  |  topmost blob pixel  |
//
// Blob information is stored continuously starting at BlobStorageOffset:
// <blob0><blob1><blob2>...
// Blobs are not stored in any particular order
// End of blob data area is denotated by thee consecutive data words with value 0xffffffff, starting with Word 0
// The pixel values in Word 2 are divided by two to ensure that they fit in their respective 8-bit fields

module blob_extraction(
	//input wires
	input wire clk,
	input wire clk_fast,

	input wire primary_color_slots_clka,
	input wire wren_primary_color_slots,
	input wire [4:0] address_primary_color_slots,
	input wire [23:0] data_write_primary_color_slots,

	input wire pause,
	input wire enable_blob_extraction,
	input wire [31:0] data_read,
	input wire [7:0] color_similarity_threshold,
	//input wire [575:0] primary_color_slots,	

	//output regs
	output reg wren,
	output reg [31:0] data_write,
	output reg [17:0] address,
	output reg blob_extraction_done,
	output reg [15:0] blob_count,
	
	output wire [15:0] debug0,
	output wire [15:0] debug1,
	output wire [3:0] debug2,
	output wire [4:0] debug3,
	output reg [23:0] debug_display,
	output reg [11:0] debug2_display,
	output reg [11:0] debug3_display
	);

	parameter ImageWidth = 320;
	parameter ImageHeight = 240;
	parameter ImageOffset = (ImageWidth*ImageHeight)+1;
	parameter BlobStorageOffset = 200000;

	initial blob_extraction_done = 0;
	initial blob_count = 0;

	reg [3:0] enable_blob_extraction_verified = 0;
	reg [15:0] blob_extraction_blob_counter = 0;
	
	reg [5:0] blob_extraction_counter_tog = 0;
	reg [5:0] blob_extraction_counter_togg = 0;
	reg [5:0] blob_extraction_counter_toggle = 0;
	reg [31:0] blob_extraction_counter_temp = 0;
	
	reg blob_extraction_holdoff = 0;
	reg [8:0] blob_extraction_x_counter = 0;	
	reg [8:0] blob_extraction_y_counter = 0;	
	
	reg [15:0] blob_extraction_x = 0;
	reg [15:0] blob_extraction_y = 0;
	
	reg [15:0] blob_extraction_x_temp = 0;
	reg [15:0] blob_extraction_y_temp = 0;
	
	reg [15:0] blob_extraction_x_temp_1 = 0;
	reg [15:0] blob_extraction_y_temp_1 = 0;
	
	reg spanLeft = 0;
	reg spanRight = 0;
	
	reg [31:0] blob_extraction_data_temp = 0;
	
	reg blob_extraction_execution_interrupted = 0;
	
	// Here is the stack in all of its glory...we are using 9 bit numbers for X coordinate storage here, with a max. stack depth of 16384
	// We will be using 8 bit numbers for the Y coordinates
	
	//reg [31:0] stack = 0;
	reg [15:0] stack_pointer = 0;

	reg [4:0] blob_extraction_toggler = 0;
	reg [3:0] blob_extraction_inner_toggler = 0;

	assign debug0 = blob_extraction_x_temp;
	assign debug1 = blob_extraction_y_temp_1;
	assign debug2 = blob_extraction_inner_toggler;
	assign debug3 = blob_extraction_toggler;
	
	reg [24:0] blob_extraction_red_average = 0;
	reg [24:0] blob_extraction_green_average = 0;
	reg [24:0] blob_extraction_blue_average = 0;
	reg [24:0] blob_extraction_x_average = 0;
	reg [24:0] blob_extraction_y_average = 0;
	
	reg [15:0] blob_extraction_red_average_final = 0;
	reg [15:0] blob_extraction_green_average_final = 0;
	reg [15:0] blob_extraction_blue_average_final = 0;
	reg [15:0] blob_extraction_x_average_final = 0;
	reg [15:0] blob_extraction_y_average_final = 0;
	
	reg [15:0] blob_extraction_lowest_x_value = 0;
	reg [15:0] blob_extraction_lowest_y_value = 0;
	reg [15:0] blob_extraction_highest_x_value = 0;
	reg [15:0] blob_extraction_highest_y_value = 0;
	
	reg [16:0] blob_extraction_blob_size = 0;
	
	reg [15:0] blob_extraction_current_difference = 0;
	reg [15:0] blob_extraction_minimum_difference = 0;
	reg [7:0] blob_extraction_blob_color_number = 0;
	
	reg [2:0] blob_extraction_color_loop = 0;
	reg [4:0] blob_extraction_slot_loop = 0;

	reg [2:0] blob_extractor_termination_record_loop = 0;
	
	reg ok_to_do_averaging = 0;
	
	//-----Instantiate stack_ram
	reg [16:0] stack_ram_dina;	
	reg [13:0] stack_ram_addra;	
	reg stack_ram_wea;
	wire [16:0] stack_ram_douta;
	
	stack_ram stack_ram(
		.clka(clk_fast),
		.dina(stack_ram_dina),
		.addra(stack_ram_addra),
		.wea(stack_ram_wea),
		.douta(stack_ram_douta)
		);

	//-----Instantiate block ram for primary_color_slots
	reg [4:0] primary_color_slots_addrb;
	wire [23:0] primary_color_slots_doutb;
	
	primary_color_slots primary_color_slots (
		.clka(primary_color_slots_clka), // input clka
		.wea(wren_primary_color_slots), // input [0 : 0] wea
		.addra(address_primary_color_slots), // input [4 : 0] addra
		.dina(data_write_primary_color_slots), // input [23 : 0] dina
		.douta(), // output [23 : 0] douta (--NOT USED--)
		.clkb(clk_fast), // input clkb
		.web(0), // input [0 : 0] web
		.addrb(primary_color_slots_addrb), // input [4 : 0] addrb
		.dinb(), // input [23 : 0] dinb (--NOT USED--)
		.doutb(primary_color_slots_doutb) // output [23 : 0] doutb
	);

	// Instantiate division modules
	reg [17:0] divider_dividend_red;
	reg [17:0] divider_divisor_red;
	wire [17:0] divider_quotient_red;
	wire [17:0] divider_remainder_red;
	wire divider_zeroflag_red;
	
	reg [17:0] divider_dividend_green;
	reg [17:0] divider_divisor_green;
	wire [17:0] divider_quotient_green;
	wire [17:0] divider_remainder_green;
	wire divider_zeroflag_green;

	reg [17:0] divider_dividend_blue;
	reg [17:0] divider_divisor_blue;
	wire [17:0] divider_quotient_blue;
	wire [17:0] divider_remainder_blue;
	wire divider_zeroflag_blue;

	reg [17:0] divider_dividend_x;
	reg [17:0] divider_divisor_x;
	wire [17:0] divider_quotient_x;
	wire [17:0] divider_remainder_x;
	wire divider_zeroflag_x;

	reg [17:0] divider_dividend_y;
	reg [17:0] divider_divisor_y;
	wire [17:0] divider_quotient_y;
	wire [17:0] divider_remainder_y;
	wire divider_zeroflag_y;

	serial_divide_uu serial_divide_uu_red (.dividend(divider_dividend_red), .divisor(divider_divisor_red), .quotient(divider_quotient_red), .remainder(divider_remainder_red), .zeroflag(divider_zeroflag_red));
	serial_divide_uu serial_divide_uu_green (.dividend(divider_dividend_green), .divisor(divider_divisor_green), .quotient(divider_quotient_green), .remainder(divider_remainder_green), .zeroflag(divider_zeroflag_green));
	serial_divide_uu serial_divide_uu_blue (.dividend(divider_dividend_blue), .divisor(divider_divisor_blue), .quotient(divider_quotient_blue), .remainder(divider_remainder_blue), .zeroflag(divider_zeroflag_blue));
	serial_divide_uu serial_divide_uu_x (.dividend(divider_dividend_x), .divisor(divider_divisor_x), .quotient(divider_quotient_x), .remainder(divider_remainder_x), .zeroflag(divider_zeroflag_x));
	serial_divide_uu serial_divide_uu_y (.dividend(divider_dividend_y), .divisor(divider_divisor_y), .quotient(divider_quotient_y), .remainder(divider_remainder_y), .zeroflag(divider_zeroflag_y));
	
	// Now it's time to find and extract the blobs
	//always @(posedge clk_div_by_four) begin
	//always @(posedge crystal_clk_div_by_two) begin
	//always @(posedge clk_div_by_two) begin
	//always @(posedge modified_clock) begin
	//always @(posedge clk) begin
	//always @(posedge clk_fast) begin
	always @(posedge clk) begin
		if (pause == 0) begin
			//leds[5:0] = blob_extraction_toggler + 1;
			
			if (enable_blob_extraction == 1) begin
				enable_blob_extraction_verified = enable_blob_extraction_verified + 1;
			end else begin
				enable_blob_extraction_verified = 0;
			end
			
			if (enable_blob_extraction_verified >= 2) begin
				enable_blob_extraction_verified = 2;		// Keep this running!
				if (blob_extraction_done == 0) begin
					if (blob_extraction_holdoff == 0) begin
						wren = 0;
						address = (ImageWidth*7);								// Skip the topmost 7 lines of the image
						blob_extraction_counter_tog = (ImageWidth*7);
						blob_extraction_counter_togg = (ImageWidth*7);
						blob_extraction_holdoff = 1;
						blob_extraction_toggler = 0;
						blob_extraction_blob_counter = 1;
						blob_extraction_execution_interrupted = 0;
						
						blob_extraction_x = 7;
						blob_extraction_y = 8;
					end else begin
						if (blob_extraction_execution_interrupted == 0) begin
							// For blob_extraction_y = 7 to 233
							if (blob_extraction_y < (ImageHeight-7)) begin
								// For blob_extraction_x = 7 to 313
								if (blob_extraction_x < (ImageWidth-7)) begin
									if (blob_extraction_toggler == 0) begin
										// Set up the next read
										wren = 0;
										address = ((blob_extraction_y * ImageWidth) + blob_extraction_x);
										
										blob_extraction_toggler = 1;
									end else begin
										// Read the current X, Y pixel
										// If pixel == 0, then we need to fill this region
										if (data_read == 0) begin
											blob_extraction_data_temp[16:8] = blob_extraction_x;
											blob_extraction_data_temp[7:0] = blob_extraction_y;
											stack_ram_dina = blob_extraction_data_temp;
											stack_pointer = 1;
											stack_ram_addra = 1;
											stack_ram_wea = 1;
											// This must only be executed once!
											// Basically, just interrupt execution of the above routines
											blob_extraction_execution_interrupted = 1;
											blob_extraction_blob_counter = blob_extraction_blob_counter + 1;
											
											blob_extraction_red_average_final = 0;
											blob_extraction_green_average_final = 0;
											blob_extraction_blue_average_final = 0;
											blob_extraction_x_average_final = 0;
											blob_extraction_y_average_final = 0;
												
											blob_extraction_lowest_x_value = 0;
											blob_extraction_lowest_y_value = 0;
											blob_extraction_highest_x_value = 0;
											blob_extraction_highest_y_value = 0;
											
											blob_extraction_blob_size = 1;
											ok_to_do_averaging = 0;
										end
										
										blob_extraction_toggler = 0;
										blob_extraction_x = blob_extraction_x + 1;
									end
								end else begin
									blob_extraction_x = 0;
									blob_extraction_y = blob_extraction_y + 1;
								end
								blob_extractor_termination_record_loop = 0;
							end else begin
								// Write end-of-data words
								case (blob_extractor_termination_record_loop)
// 									0: begin
// 										blob_extraction_blob_counter = 0; //DEBUGGING--only writes one blob (to match simulation)
// 										address = ((blob_extraction_blob_counter * 3) + (BlobStorageOffset+0));
// 										data_write = 32'hff000001;
// 										wren = 1;
// 										blob_extractor_termination_record_loop = 1;
// 									end
// 									1: begin
// 										address = ((blob_extraction_blob_counter * 3) + (BlobStorageOffset+1));
// 										data_write = 32'ha07803e8;
// 										wren = 1;
// 										blob_extractor_termination_record_loop = 2;
// 									end
// 									2: begin
// 										address = ((blob_extraction_blob_counter * 3) + (BlobStorageOffset+2));
// 										data_write = 32'h37236955;
// 										wren = 1;
// 										blob_extractor_termination_record_loop = 3;
// 									end
									0: begin
// 										blob_extraction_blob_counter = blob_extraction_blob_counter + 1;
										address = ((blob_extraction_blob_counter * 3) + (BlobStorageOffset+0));
										data_write = 32'hffffffff;
										wren = 1;
										blob_extractor_termination_record_loop = 1;
									end
									1: begin
										address = ((blob_extraction_blob_counter * 3) + (BlobStorageOffset+1));
										data_write = 32'hffffffff;
										wren = 1;
										blob_extractor_termination_record_loop = 2;
									end
									2: begin
										address = ((blob_extraction_blob_counter * 3) + (BlobStorageOffset+2));
										data_write = 32'hffffffff;
										wren = 1;
										blob_extractor_termination_record_loop = 3;
									end
									3: begin
										// Done!
										blob_extraction_y = 0;
										blob_extraction_counter_tog = 0;
										blob_extraction_counter_togg = 0;
										blob_extraction_counter_toggle = 0;
										blob_extraction_done = 1;
										blob_extraction_holdoff = 0;
										blob_extractor_termination_record_loop = 0;
										blob_count = blob_extraction_blob_counter;
										wren = 0;
									end
								endcase
							end
						end else begin		// Interrupted
							if (blob_extraction_toggler == 0) begin
								// Set up stack read operation
								stack_ram_wea = 0;
								stack_ram_addra = stack_pointer;
								
								// Do this here for later
								blob_extraction_inner_toggler = 0;
							end
							
							if (blob_extraction_toggler == 1) begin
								// Pop data from the stack
								blob_extraction_x_temp = stack_ram_douta[16:8];
								blob_extraction_y_temp = stack_ram_douta[7:0];
								stack_pointer = stack_pointer - 1;
								
								blob_extraction_y_temp_1 = blob_extraction_y_temp;
								
								spanLeft = 0;
								spanRight = 0;
								
								address = ((blob_extraction_y_temp_1 * ImageWidth) + blob_extraction_x_temp);
							end
							
							if (blob_extraction_toggler == 2) begin
								// Go up until an edge is found
								
								if ((data_read == 0) && (blob_extraction_x_temp > 7) && (blob_extraction_x_temp < (ImageWidth-7)) && (blob_extraction_y_temp_1 > 7) && (blob_extraction_y_temp_1 < (ImageHeight-7))) begin
									// Set up the read operation
									wren = 0;
									blob_extraction_y_temp_1 = blob_extraction_y_temp_1 - 1;
									address = ((blob_extraction_y_temp_1 * ImageWidth) + blob_extraction_x_temp);
										
									blob_extraction_inner_toggler = 1;
								end else begin
									blob_extraction_inner_toggler = 0;
									blob_extraction_y_temp_1 = blob_extraction_y_temp_1 + 1;
									blob_extraction_toggler = 3;
								end
							end
							
							if (blob_extraction_toggler == 3) begin
								// Set up a read operation for the pixel at (blob_extraction_x_temp, blob_extraction_y_temp)
								address = ((blob_extraction_y_temp_1 * ImageWidth) + blob_extraction_x_temp);
							end
		
							if (blob_extraction_toggler == 4) begin
								blob_extraction_toggler = 5;
							end
								
							if (blob_extraction_toggler == 5) begin
								// Read in the first pixel
								// If the pixel is zero, write the current blob number in its place
								if (blob_extraction_inner_toggler == 0) begin
									if ((data_read == 0) 
										&& (blob_extraction_x_temp > 7) && (blob_extraction_x_temp < (ImageWidth-7)) 
										&& (blob_extraction_y_temp_1 > 7) && (blob_extraction_y_temp_1 < (ImageHeight-7))) begin
										// Write the data
										address = ((blob_extraction_y_temp_1 * ImageWidth) + blob_extraction_x_temp);
										data_write = blob_extraction_blob_counter;
										wren = 1;
										
										blob_extraction_inner_toggler = 1;
									end else begin
										//Does not reach this point
										blob_extraction_toggler = 6;
										blob_extraction_inner_toggler = 0;
									end
								end
								
								if (blob_extraction_inner_toggler == 1) begin
									// Wait a clock cycle--DO NOT SWITCH OUT OF WRITE MODE HERE!
								end
									
								if (blob_extraction_inner_toggler == 2) begin
									// Switch to read; we need to read the RGB value of the median-filtered image
									wren = 0;
									address = (((blob_extraction_y_temp_1 * ImageWidth) + blob_extraction_x_temp) + ImageOffset);
								end
		
								if (blob_extraction_inner_toggler == 3) begin
									// And compute the running average, lowest pixel, centroid, etc.
									if (ok_to_do_averaging == 1) begin
										blob_extraction_red_average = blob_extraction_red_average + data_read[7:0];
										blob_extraction_green_average = blob_extraction_green_average + data_read[15:8];
										blob_extraction_blue_average = blob_extraction_blue_average + data_read[31:24];
										blob_extraction_x_average = blob_extraction_x_average + blob_extraction_x_temp;
										blob_extraction_y_average = blob_extraction_y_average + blob_extraction_y_temp_1;
										
										if (blob_extraction_lowest_x_value > blob_extraction_x_temp) begin
											blob_extraction_lowest_x_value = blob_extraction_x_temp;
										end
										
										if (blob_extraction_highest_x_value < blob_extraction_x_temp) begin
											blob_extraction_highest_x_value = blob_extraction_x_temp;
										end
										
										if (blob_extraction_lowest_y_value > blob_extraction_y_temp_1) begin
											blob_extraction_lowest_y_value = blob_extraction_y_temp_1;
										end
										
										if (blob_extraction_highest_y_value < blob_extraction_y_temp_1) begin
											blob_extraction_highest_y_value = blob_extraction_y_temp_1;
										end
										
										blob_extraction_blob_size = blob_extraction_blob_size + 1;
									end else begin
										blob_extraction_red_average = data_read[7:0];
										blob_extraction_green_average = data_read[15:8];
										blob_extraction_blue_average = data_read[31:24];
										blob_extraction_x_average = blob_extraction_x_temp;
										blob_extraction_y_average = blob_extraction_y_temp_1;
										
										blob_extraction_lowest_x_value = blob_extraction_x_temp;
										blob_extraction_lowest_y_value = blob_extraction_y_temp_1;
										blob_extraction_highest_x_value = blob_extraction_x_temp;
										blob_extraction_highest_y_value = blob_extraction_y_temp_1;
										
										blob_extraction_blob_size = 1;
										ok_to_do_averaging = 1;
									end
									
									// Set up the red averaging
									if (blob_extraction_red_average < 65535) begin
										divider_dividend_red = blob_extraction_red_average;
										divider_divisor_red = blob_extraction_blob_size;
									end
									if ((blob_extraction_red_average > 65534) && (blob_extraction_red_average < 131071)) begin
										divider_dividend_red = (blob_extraction_red_average / 2);
										divider_divisor_red = (blob_extraction_blob_size / 2);
									end
									if ((blob_extraction_red_average > 131070) && (blob_extraction_red_average < 262143)) begin
										divider_dividend_red = (blob_extraction_red_average / 4);
										divider_divisor_red = (blob_extraction_blob_size / 4);
									end
									if ((blob_extraction_red_average > 262142) && (blob_extraction_red_average < 524287)) begin
										divider_dividend_red = (blob_extraction_red_average / 8);
										divider_divisor_red = (blob_extraction_blob_size / 8);
									end
									if ((blob_extraction_red_average > 524286) && (blob_extraction_red_average < 1048575)) begin
										divider_dividend_red = (blob_extraction_red_average / 16);
										divider_divisor_red = (blob_extraction_blob_size / 16);
									end
									if ((blob_extraction_red_average > 1048575) && (blob_extraction_red_average < 2097151)) begin
										divider_dividend_red = (blob_extraction_red_average / 32);
										divider_divisor_red = (blob_extraction_blob_size / 32);
									end
									if (blob_extraction_red_average > 2097150) begin
										divider_dividend_red = (blob_extraction_red_average / 128);
										divider_divisor_red = (blob_extraction_blob_size / 128);
									end
									
									// Set up the green averaging
									if (blob_extraction_green_average < 65535) begin
										divider_dividend_green = blob_extraction_green_average;
										divider_divisor_green = blob_extraction_blob_size;
									end
									if ((blob_extraction_green_average > 65534) && (blob_extraction_green_average < 131071)) begin
										divider_dividend_green = (blob_extraction_green_average / 2);
										divider_divisor_green = (blob_extraction_blob_size / 2);
									end
									if ((blob_extraction_green_average > 131070) && (blob_extraction_green_average < 262143)) begin
										divider_dividend_green = (blob_extraction_green_average / 4);
										divider_divisor_green = (blob_extraction_blob_size / 4);
									end
									if ((blob_extraction_green_average > 262142) && (blob_extraction_green_average < 524287)) begin
										divider_dividend_green = (blob_extraction_green_average / 8);
										divider_divisor_green = (blob_extraction_blob_size / 8);
									end
									if ((blob_extraction_green_average > 524286) && (blob_extraction_green_average < 1048575)) begin
										divider_dividend_green = (blob_extraction_green_average / 16);
										divider_divisor_green = (blob_extraction_blob_size / 16);
									end
									if ((blob_extraction_green_average > 1048575) && (blob_extraction_green_average < 2097151)) begin
										divider_dividend_green = (blob_extraction_green_average / 32);
										divider_divisor_green = (blob_extraction_blob_size / 32);
									end
									if (blob_extraction_green_average > 2097150) begin
										divider_dividend_green = (blob_extraction_green_average / 128);
										divider_divisor_green = (blob_extraction_blob_size / 128);
									end
								end
									
								if (blob_extraction_inner_toggler == 4) begin
									// Read the red averaging result
									blob_extraction_red_average_final = divider_quotient_red;
									
									// Read the green averaging result
									blob_extraction_green_average_final = divider_quotient_green;
		
									// Set up the blue averaging
									if (blob_extraction_blue_average < 65535) begin
										divider_dividend_blue = blob_extraction_blue_average;
										divider_divisor_blue = blob_extraction_blob_size;
									end
									if ((blob_extraction_blue_average > 65534) && (blob_extraction_blue_average < 131071)) begin
										divider_dividend_blue = (blob_extraction_blue_average / 2);
										divider_divisor_blue = (blob_extraction_blob_size / 2);
									end
									if ((blob_extraction_blue_average > 131070) && (blob_extraction_blue_average < 262143)) begin
										divider_dividend_blue = (blob_extraction_blue_average / 4);
										divider_divisor_blue = (blob_extraction_blob_size / 4);
									end
									if ((blob_extraction_blue_average > 262142) && (blob_extraction_blue_average < 524287)) begin
										divider_dividend_blue = (blob_extraction_blue_average / 8);
										divider_divisor_blue = (blob_extraction_blob_size / 8);
									end
									if ((blob_extraction_blue_average > 524286) && (blob_extraction_blue_average < 1048575)) begin
										divider_dividend_blue = (blob_extraction_blue_average / 16);
										divider_divisor_blue = (blob_extraction_blob_size / 16);
									end
									if ((blob_extraction_blue_average > 1048575) && (blob_extraction_blue_average < 2097151)) begin
										divider_dividend_blue = (blob_extraction_blue_average / 32);
										divider_divisor_blue = (blob_extraction_blob_size / 32);
									end
									if (blob_extraction_blue_average > 2097150) begin
										divider_dividend_blue = (blob_extraction_blue_average / 128);
										divider_divisor_blue = (blob_extraction_blob_size / 128);
									end
									
									// Set up the X averaging
									if (blob_extraction_x_average < 65535) begin
										divider_dividend_x = blob_extraction_x_average;
										divider_divisor_x = blob_extraction_blob_size;
									end
									if ((blob_extraction_x_average > 65534) && (blob_extraction_x_average < 131071)) begin
										divider_dividend_x = (blob_extraction_x_average / 2);
										divider_divisor_x = (blob_extraction_blob_size / 2);
									end
									if ((blob_extraction_x_average > 131070) && (blob_extraction_x_average < 262143)) begin
										divider_dividend_x = (blob_extraction_x_average / 4);
										divider_divisor_x = (blob_extraction_blob_size / 4);
									end
									if ((blob_extraction_x_average > 262142) && (blob_extraction_x_average < 524287)) begin
										divider_dividend_x = (blob_extraction_x_average / 8);
										divider_divisor_x = (blob_extraction_blob_size / 8);
									end
									if ((blob_extraction_x_average > 524286) && (blob_extraction_x_average < 1048575)) begin
										divider_dividend_x = (blob_extraction_x_average / 16);
										divider_divisor_x = (blob_extraction_blob_size / 16);
									end
									if ((blob_extraction_x_average > 1048575) && (blob_extraction_x_average < 2097151)) begin
										divider_dividend_x = (blob_extraction_x_average / 32);
										divider_divisor_x = (blob_extraction_blob_size / 32);
									end
									if (blob_extraction_x_average > 2097150) begin
										divider_dividend_x = (blob_extraction_x_average / 512);
										divider_divisor_x = (blob_extraction_blob_size / 512);
									end
									
									// We need to read data from the image here, so set up another read cycle
									address = ((blob_extraction_y_temp_1 * ImageWidth) + blob_extraction_x_temp - 1);
									wren = 0;
								end
								
								if (blob_extraction_inner_toggler == 5) begin
									// Read the blue averaging result
									blob_extraction_blue_average_final = divider_quotient_blue;
									
									// Read the X averaging result
									blob_extraction_x_average_final = divider_quotient_x;
		
									// Set up the Y averaging
									if (blob_extraction_y_average < 65535) begin
										divider_dividend_y = blob_extraction_y_average;
										divider_divisor_y = blob_extraction_blob_size;
									end
									if ((blob_extraction_y_average > 65534) && (blob_extraction_y_average < 131071)) begin
										divider_dividend_y = (blob_extraction_y_average / 2);
										divider_divisor_y = (blob_extraction_blob_size / 2);
									end
									if ((blob_extraction_y_average > 131070) && (blob_extraction_y_average < 262143)) begin
										divider_dividend_y = (blob_extraction_y_average / 4);
										divider_divisor_y = (blob_extraction_blob_size / 4);
									end
									if ((blob_extraction_y_average > 262142) && (blob_extraction_y_average < 524287)) begin
										divider_dividend_y = (blob_extraction_y_average / 8);
										divider_divisor_y = (blob_extraction_blob_size / 8);
									end
									if ((blob_extraction_y_average > 524286) && (blob_extraction_y_average < 1048575)) begin
										divider_dividend_y = (blob_extraction_y_average / 16);
										divider_divisor_y = (blob_extraction_blob_size / 16);
									end
									if ((blob_extraction_y_average > 1048575) && (blob_extraction_y_average < 2097151)) begin
										divider_dividend_y = (blob_extraction_y_average / 32);
										divider_divisor_y = (blob_extraction_blob_size / 32);
									end
									if (blob_extraction_y_average > 2097150) begin
										divider_dividend_y = (blob_extraction_y_average / 128);
										divider_divisor_y = (blob_extraction_blob_size / 128);
									end
									
									// Now read in the data
									if ((spanLeft == 0) && (data_read == 0)) begin
										// Push data!
										stack_pointer = stack_pointer + 1;
										stack_ram_addra = stack_pointer;
										blob_extraction_data_temp[16:8] = blob_extraction_x_temp - 1;
										blob_extraction_data_temp[7:0] = blob_extraction_y_temp_1;
										stack_ram_dina = blob_extraction_data_temp;
										stack_ram_wea = 1;
										spanLeft = 1;
									end else begin
										if ((spanLeft == 1) && (data_read != 0)) begin
											spanLeft = 0;
										end
									end
									
									blob_extraction_inner_toggler = 6;
								end
								
								if (blob_extraction_inner_toggler == 6) begin
									/*divider_dividend = ImageWidth;
									divider_divisor = 2;*/
									
									// We need to read some more data from the image here, so set up yet another read cycle
									address = ((blob_extraction_y_temp_1 * ImageWidth) + blob_extraction_x_temp + 1);
									wren = 0;
								end
									
								if (blob_extraction_inner_toggler == 7) begin
									// Read the Y averaging result...done!
									blob_extraction_y_average_final = divider_quotient_y;
									
									// Now read in the data
									if ((spanRight == 0) && (data_read == 0)) begin
										// Push data!
										stack_pointer = stack_pointer + 1;
										stack_ram_addra = stack_pointer;
										blob_extraction_data_temp[16:8] = blob_extraction_x_temp + 1;
										blob_extraction_data_temp[7:0] = blob_extraction_y_temp_1;
										stack_ram_dina = blob_extraction_data_temp;
										stack_ram_wea = 1;
										spanRight = 1;
									end else begin
										if ((spanRight == 1) && (data_read != 0)) begin
											spanRight = 0;
										end
									end
									
									blob_extraction_inner_toggler = 8;
								end
								
								if (blob_extraction_inner_toggler == 8) begin
									// Wait a clock cycle
									wren = 0;
									blob_extraction_y_temp_1 = blob_extraction_y_temp_1 + 1;
									address = ((blob_extraction_y_temp_1 * ImageWidth) + blob_extraction_x_temp);	// Set up the next read
									blob_extraction_inner_toggler = 0;
									blob_extraction_toggler = 4;			// Go again...this will become 5 on the next loop!
								end
							end
							
							if (blob_extraction_toggler == 6) begin
								// All of that above is done while the stack pointer is greater than 0
								// If it is now zero, cut out!
								if (stack_pointer != 0) begin
									// Skip all of the blob information writing stuff below...
									blob_extraction_toggler = 16;
								end
								
								blob_extraction_color_loop = 0;
								blob_extraction_slot_loop = 0;
								primary_color_slots_addrb = 0;
								
								blob_extraction_minimum_difference = color_similarity_threshold;
								blob_extraction_blob_color_number = 0;		// Default to 'not found'
							end
		
							if (blob_extraction_toggler == 7) begin
								// Before we can fill the last data slot, we need to find which color slot this is!
								// We will be calculating the sum of the errors for each color, winner takes all and is then compared against the threshold
								
								//for (blob_extraction_color_loop = 0; blob_extraction_color_loop < 6; blob_extraction_color_loop = blob_extraction_color_loop + 1) begin
									//for (blob_extraction_slot_loop = 0; blob_extraction_slot_loop < 8; blob_extraction_slot_loop = blob_extraction_slot_loop + 1) begin
										// Red
										if (blob_extraction_red_average_final > primary_color_slots_doutb[7:0]) begin
											//old syntax was primary_color_slots[blob_extraction_color_loop][blob_extraction_slot_loop][7:0] 
											
											blob_extraction_current_difference = blob_extraction_red_average_final - primary_color_slots_doutb[7:0];
										end else begin
											blob_extraction_current_difference = primary_color_slots_doutb[7:0] - blob_extraction_red_average_final;
										end
										
										// Green
										if (blob_extraction_green_average_final > primary_color_slots_doutb[15:8]) begin
											//old syntax was primary_color_slots[blob_extraction_color_loop][blob_extraction_slot_loop][15:8]
												
											blob_extraction_current_difference = 
											(blob_extraction_current_difference + (blob_extraction_green_average_final - primary_color_slots_doutb[15:8]));
										end else begin
											blob_extraction_current_difference = (blob_extraction_current_difference + (primary_color_slots_doutb[15:8] - blob_extraction_green_average_final));
										end
										
										// Blue
										if (blob_extraction_blue_average_final > primary_color_slots_doutb[23:16]) begin
											//old syntax was primary_color_slots[blob_extraction_color_loop][blob_extraction_slot_loop][23:16]
											
											blob_extraction_current_difference = 
											(blob_extraction_current_difference + (blob_extraction_blue_average_final 
												- primary_color_slots_doutb[23:16]));
										end else begin
											blob_extraction_current_difference = 
											(blob_extraction_current_difference 
												+ (primary_color_slots_doutb[23:16] - blob_extraction_blue_average_final));
										end
										
										// debugging
										// red slot
										if (blob_extraction_slot_loop == 0 && blob_extraction_color_loop == 0) begin
											// sends red, green, blue out to main for display
											debug_display = primary_color_slots_doutb;
											debug2_display = primary_color_slots_addrb;
										end
										
										// Compare...
										if (blob_extraction_current_difference < blob_extraction_minimum_difference) begin
											blob_extraction_minimum_difference = blob_extraction_current_difference;
											blob_extraction_blob_color_number = blob_extraction_color_loop + 1;
											debug3_display = debug3_display + 1;
										end
									//end
								//end	
								
								blob_extraction_slot_loop = blob_extraction_slot_loop + 1;
								if (blob_extraction_slot_loop > 3) begin
									blob_extraction_slot_loop = 0;
									blob_extraction_color_loop = blob_extraction_color_loop + 1;
								end
								if (blob_extraction_color_loop < 6) begin
									blob_extraction_toggler = blob_extraction_toggler - 1;		// This will make us go again here
								end
								
								//set read addr for primary color slots 
								primary_color_slots_addrb = (blob_extraction_color_loop*4) + blob_extraction_slot_loop;
								
								// TESTING ONLY!!! ***FIXME***
								/*blob_extraction_x_average_final = 160;
								blob_extraction_y_average_final = 120;*/
							end
							
							if (blob_extraction_toggler == 8) begin
								// Begin writing the data
								address = ((blob_extraction_blob_counter * 3) + (BlobStorageOffset+0));
								blob_extraction_data_temp[31:24] = blob_extraction_red_average_final;
								blob_extraction_data_temp[23:16] = blob_extraction_green_average_final;
								blob_extraction_data_temp[15:8] = blob_extraction_blue_average_final;
								
								/*blob_extraction_data_temp[31:24] = 255;
								blob_extraction_data_temp[23:16] = 127;
								blob_extraction_data_temp[15:8] = 0;*/
								
								blob_extraction_data_temp[7:0] = blob_extraction_blob_color_number;
								data_write = blob_extraction_data_temp;
								wren = 1;
							end
							
							if (blob_extraction_toggler == 9) begin
								// Delay a cycle
								wren = 0;
							end
							
							if (blob_extraction_toggler == 10) begin
								// Continue writing the data
								address = ((blob_extraction_blob_counter * 3) + (BlobStorageOffset+1));
								blob_extraction_data_temp[31:24] = ((blob_extraction_x_average_final - 8) / 2);
								blob_extraction_data_temp[23:16] = ((blob_extraction_y_average_final - 8) / 2);
								blob_extraction_data_temp[15:0] = (blob_extraction_blob_size / 2);
								if (blob_extraction_data_temp[7:0] == 176) begin
									blob_extraction_data_temp[7:0] = 177;
								end
								if (blob_extraction_data_temp[15:8] == 176) begin
									blob_extraction_data_temp[15:8] = 177;
								end
								data_write = blob_extraction_data_temp;
								wren = 1;
							end
							
							if (blob_extraction_toggler == 11) begin
								// Delay a cycle
								wren = 0;
							end
							
							if (blob_extraction_toggler == 12) begin
								// Write the third and last data frame
								address = ((blob_extraction_blob_counter * 3) + (BlobStorageOffset+2));
								blob_extraction_data_temp[31:24] = (blob_extraction_lowest_x_value / 2);
								blob_extraction_data_temp[23:16] = (blob_extraction_lowest_y_value / 2);
								blob_extraction_data_temp[15:8] = (blob_extraction_highest_x_value / 2);
								blob_extraction_data_temp[7:0] = (blob_extraction_highest_y_value / 2);
								data_write = blob_extraction_data_temp;
								wren = 1;
							end
							
							if (blob_extraction_toggler == 13) begin
								// Delay a cycle
								wren = 0;
							end
							
							if (blob_extraction_toggler == 14) begin
								// Put a little red dot dot where the centroid is
								address = ((blob_extraction_y_average_final * ImageWidth) + blob_extraction_x_average_final) + ImageOffset;	// Set up the next write
								blob_extraction_data_temp = 255;
								blob_extraction_data_temp[31:24] = blob_extraction_blob_color_number;
								data_write = blob_extraction_data_temp;
								wren = 1;
							end
							
							if (blob_extraction_toggler == 15) begin		// There is no more data on the stack, so return to top
								wren = 0;
								blob_extraction_execution_interrupted = 0;
								blob_extraction_toggler = 17;
							end
							
							if (blob_extraction_toggler == 16) begin		// There is still data on the stack, so go again
								wren = 0;
								blob_extraction_toggler = 17;
							end
													
							// Increment our counters
							if (blob_extraction_inner_toggler == 0) begin
								blob_extraction_toggler = blob_extraction_toggler + 1;
							end else begin
								blob_extraction_inner_toggler = blob_extraction_inner_toggler + 1;
							end
							
							if (blob_extraction_toggler >= 17) begin
								blob_extraction_toggler = 0;
								blob_extraction_inner_toggler = 0;
							end
						end	// Interrupted
					end
				end
			end else begin
				blob_extraction_done = 0;
				address = 18'b0;
				data_write = 32'b0;
				wren = 1'b0;
	
				debug3_display = 0;
			end
		end	//end if pause = 0
	end
endmodule
