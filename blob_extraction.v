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

module blob_extraction(
	//input wires
	input wire modified_clock_two_div_by_two,
	input wire modified_clock_two,
	input wire pause,
	input wire enable_blob_extraction,
	input wire [31:0] data_read,
	input wire [17:0] divider_quotient,
	input wire [17:0] divider_quotient_two,
	input wire [7:0] color_similarity_threshold,
	input wire [575:0] primary_color_slots,	

	//output regs
	output reg wren,
	output reg [31:0] data_write,
	output reg [17:0] address,
	output reg blob_extraction_done,
	output reg divider_dividend,
	output reg divider_divisor,
	output reg divider_dividend_two,
	output reg divider_divisor_two,
	
	output wire [15:0] debug0,
	output wire [15:0] debug1,
	output wire [3:0] debug2,
	output wire [4:0] debug3
	);

		initial blob_extraction_done = 0;

		reg [3:0] enable_blob_extraction_verified = 0;
		reg [15:0] blob_extraction_blob_counter = 0;
		
		reg [5:0] blob_extraction_counter_tog = 0;
		reg [5:0] blob_extraction_counter_togg = 0;
		reg [5:0] blob_extraction_counter_toggle = 0;
		reg [31:0] blob_extraction_counter_temp = 0;
		
		reg blob_extraction_holdoff = 0;
		reg [31:0] data_read_sync_blob_extraction = 0;
		reg blob_extraction_main_chunk_already_loaded = 0;	//not used anywhere!
		reg [8:0] blob_extraction_x_counter = 0;	//here only
		reg [8:0] blob_extraction_y_counter = 0;	//here only
		
		reg [15:0] blob_extraction_x = 0;	//here only
		reg [15:0] blob_extraction_y = 0;	//here only
		
		reg [15:0] blob_extraction_x_temp = 0;	//here only
		reg [15:0] blob_extraction_y_temp = 0;	//here only
		
		reg [15:0] blob_extraction_x_temp_1 = 0; //here only
		reg [15:0] blob_extraction_y_temp_1 = 0; //here only
		
		reg spanLeft = 0;	//here only
		reg spanRight = 0;	//here only
		
		reg [31:0] blob_extraction_data_temp = 0; //here only
		
		reg blob_extraction_execution_interrupted = 0; //here only
		
		// Here is the stack in all of its glory...we are using 9 bit numbers for X coordinate storage here, with a max. stack depth of 2000
		// We will be using 8 bit numbers for the Y coordinates
		//reg [17999:0] stack_x = 0;
		//reg [15999:0] stack_y = 0;
		//reg [11:0] stack_pointer = 0;
		
		//reg [31:0] stack = 0;
		reg [15:0] stack_pointer = 0;

		reg [4:0] blob_extraction_toggler = 0;		//here only
		reg [3:0] blob_extraction_inner_toggler = 0;	//here only

		assign debug0 = blob_extraction_x_temp;
		assign debug1 = blob_extraction_y_temp_1;
		assign debug2 = blob_extraction_inner_toggler;
		assign debug3 = blob_extraction_toggler;
		
		
		reg [24:0] blob_extraction_red_average = 0;	//here only
		reg [24:0] blob_extraction_green_average = 0;	//here only
		reg [24:0] blob_extraction_blue_average = 0;	//here only
		reg [24:0] blob_extraction_x_average = 0;	//here only
		reg [24:0] blob_extraction_y_average = 0;	//here only
		
		reg [15:0] blob_extraction_red_average_final = 0;	//here only
		reg [15:0] blob_extraction_green_average_final = 0;	//here only 
		reg [15:0] blob_extraction_blue_average_final = 0;	//here only
		reg [15:0] blob_extraction_x_average_final = 0;		//here only
		reg [15:0] blob_extraction_y_average_final = 0;		//here only
		
		reg [15:0] blob_extraction_lowest_x_value = 0;	//here only
		reg [15:0] blob_extraction_lowest_y_value = 0;	//here only
		reg [15:0] blob_extraction_highest_x_value = 0;	//here only
		reg [15:0] blob_extraction_highest_y_value = 0;	//here only
		
		reg [16:0] blob_extraction_blob_size = 0;	//here only
		
		reg [15:0] blob_extraction_current_difference = 0;	//here only
		reg [15:0] blob_extraction_minimum_difference = 0;	//here only
		reg [7:0] blob_extraction_blob_color_number = 0;	//here only
		
		reg [2:0] blob_extraction_color_loop = 0;	//here only
		reg [4:0] blob_extraction_slot_loop = 0;	//here only
		
		reg ok_to_do_averaging = 0;
		
		localparam [5:0] PRIMARY_COLOR_SLOTS_WORD_SIZE = 24;
		localparam [3:0] ARRAY_SPEC_1_MAX = 5;
		reg [575:0] array_spec;
		
		
		//-----Instantiate stack_ram
		reg [16:0] stack_ram_dina;	
		reg [13:0] stack_ram_addra;	
		reg stack_ram_wea;			
		wire [16:0] stack_ram_douta;
		
		stack_ram stack_ram(
			.clka(modified_clock_two),
			.dina(stack_ram_dina),
			.addra(stack_ram_addra),
			.wea(stack_ram_wea),
			.douta(stack_ram_douta)
			);
		
		
		// Now it's time to find and extract the blobs
		//always @(posedge clk_div_by_four) begin
		//always @(posedge crystal_clk_div_by_two) begin
		//always @(posedge clk_div_by_two) begin
		//always @(posedge modified_clock) begin
		//always @(posedge clk) begin
		//always @(posedge modified_clock_two) begin
		always @(posedge modified_clock_two_div_by_two) begin
		if (pause == 0) begin
			data_read_sync_blob_extraction = data_read;
			
			//leds[5:0] = blob_extraction_toggler + 1;
			
			if (enable_blob_extraction == 1) begin
				enable_blob_extraction_verified = enable_blob_extraction_verified + 1;
			end else begin
				enable_blob_extraction_verified = 0;
			end
			
			if (enable_blob_extraction_verified >= 2) begin
				enable_blob_extraction_verified = 2;		// Keep this running!
				
				if (blob_extraction_holdoff == 0) begin
					wren = 0;
					address = 2240;								// Skip the topmost 7 lines of the image
					blob_extraction_counter_tog = 2240;
					blob_extraction_counter_togg = 2240;
					blob_extraction_holdoff = 1;
					blob_extraction_toggler = 0;
					blob_extraction_blob_counter = 1;
					blob_extraction_execution_interrupted = 0;
					
					blob_extraction_x = 7;
					blob_extraction_y = 8;
				end else begin
					if (blob_extraction_execution_interrupted == 0) begin
						// For blob_extraction_y = 7 to 233
						if (blob_extraction_y < 233) begin
							// For blob_extraction_x = 7 to 313
							if (blob_extraction_x < 313) begin
								if (blob_extraction_toggler == 0) begin
									// Set up the next read
									wren = 0;
									address = ((blob_extraction_y * 320) + blob_extraction_x);
									
									blob_extraction_toggler = 1;
								end else begin
									// Read the current X, Y pixel
									// If pixel == 0, then we need to fill this region
									if (data_read_sync_blob_extraction == 0) begin
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
						end else begin
							// Done!
							blob_extraction_y = 0;
							blob_extraction_counter_tog = 0;
							blob_extraction_counter_togg = 0;
							blob_extraction_counter_toggle = 0;
							blob_extraction_done = 1;
							blob_extraction_holdoff = 0;
							wren = 0;
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
									
									address = ((blob_extraction_y_temp_1 * 320) + blob_extraction_x_temp);
								end
								
								if (blob_extraction_toggler == 2) begin
									// Go up until an edge is found
									
									if ((data_read_sync_blob_extraction == 0) && (blob_extraction_x_temp > 7) && (blob_extraction_x_temp < 313) && (blob_extraction_y_temp_1 > 7) && (blob_extraction_y_temp_1 < 233)) begin
										// Set up the read operation
										wren = 0;
										blob_extraction_y_temp_1 = blob_extraction_y_temp_1 - 1;
										address = ((blob_extraction_y_temp_1 * 320) + blob_extraction_x_temp);
											
										blob_extraction_inner_toggler = 1;
									end else begin
										blob_extraction_inner_toggler = 0;
										blob_extraction_y_temp_1 = blob_extraction_y_temp_1 + 1;
										blob_extraction_toggler = 3;
									end
								end
								
								if (blob_extraction_toggler == 3) begin
									// Set up a read operation for the pixel at (blob_extraction_x_temp, blob_extraction_y_temp)
									address = ((blob_extraction_y_temp_1 * 320) + blob_extraction_x_temp);
								end

								if (blob_extraction_toggler == 4) begin
									blob_extraction_toggler = 5;
								end
									
								if (blob_extraction_toggler == 5) begin
									// Read in the first pixel
									// If the pixel is zero, write the current blob number in its place
									if (blob_extraction_inner_toggler == 0) begin
										if ((data_read_sync_blob_extraction == 0) 
											&& (blob_extraction_x_temp > 7) && (blob_extraction_x_temp < 313) 
											&& (blob_extraction_y_temp_1 > 7) && (blob_extraction_y_temp_1 < 233)) begin
											// Write the data
											address = ((blob_extraction_y_temp_1 * 320) + blob_extraction_x_temp);
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
										address = (((blob_extraction_y_temp_1 * 320) + blob_extraction_x_temp) + 76801);
									end

									if (blob_extraction_inner_toggler == 3) begin
										// And compute the running average, lowest pixel, centroid, etc.
										if (ok_to_do_averaging == 1) begin
											blob_extraction_red_average = blob_extraction_red_average + data_read_sync_blob_extraction[7:0];
											blob_extraction_green_average = blob_extraction_green_average + data_read_sync_blob_extraction[15:8];
											blob_extraction_blue_average = blob_extraction_blue_average + data_read_sync_blob_extraction[31:24];
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
											blob_extraction_red_average = data_read_sync_blob_extraction[7:0];
											blob_extraction_green_average = data_read_sync_blob_extraction[15:8];
											blob_extraction_blue_average = data_read_sync_blob_extraction[31:24];
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
											divider_dividend_two = blob_extraction_red_average;
											divider_divisor_two = blob_extraction_blob_size;
										end
										if ((blob_extraction_red_average > 65534) && (blob_extraction_red_average < 131071)) begin
											divider_dividend_two = (blob_extraction_red_average / 2);
											divider_divisor_two = (blob_extraction_blob_size / 2);
										end
										if ((blob_extraction_red_average > 131070) && (blob_extraction_red_average < 262143)) begin
											divider_dividend_two = (blob_extraction_red_average / 4);
											divider_divisor_two = (blob_extraction_blob_size / 4);
										end
										if ((blob_extraction_red_average > 262142) && (blob_extraction_red_average < 524287)) begin
											divider_dividend_two = (blob_extraction_red_average / 8);
											divider_divisor_two = (blob_extraction_blob_size / 8);
										end
										if ((blob_extraction_red_average > 524286) && (blob_extraction_red_average < 1048575)) begin
											divider_dividend_two = (blob_extraction_red_average / 16);
											divider_divisor_two = (blob_extraction_blob_size / 16);
										end
										if ((blob_extraction_red_average > 1048575) && (blob_extraction_red_average < 2097151)) begin
											divider_dividend_two = (blob_extraction_red_average / 32);
											divider_divisor_two = (blob_extraction_blob_size / 32);
										end
										if (blob_extraction_red_average > 2097150) begin
											divider_dividend_two = (blob_extraction_red_average / 128);
											divider_divisor_two = (blob_extraction_blob_size / 128);
										end
										
										// Set up the green averaging									
										if (blob_extraction_green_average < 65535) begin
											divider_dividend = blob_extraction_green_average;
											divider_divisor = blob_extraction_blob_size;
										end
										if ((blob_extraction_green_average > 65534) && (blob_extraction_green_average < 131071)) begin
											divider_dividend = (blob_extraction_green_average / 2);
											divider_divisor = (blob_extraction_blob_size / 2);
										end
										if ((blob_extraction_green_average > 131070) && (blob_extraction_green_average < 262143)) begin
											divider_dividend = (blob_extraction_green_average / 4);
											divider_divisor = (blob_extraction_blob_size / 4);
										end
										if ((blob_extraction_green_average > 262142) && (blob_extraction_green_average < 524287)) begin
											divider_dividend = (blob_extraction_green_average / 8);
											divider_divisor = (blob_extraction_blob_size / 8);
										end
										if ((blob_extraction_green_average > 524286) && (blob_extraction_green_average < 1048575)) begin
											divider_dividend = (blob_extraction_green_average / 16);
											divider_divisor = (blob_extraction_blob_size / 16);
										end
										if ((blob_extraction_green_average > 1048575) && (blob_extraction_green_average < 2097151)) begin
											divider_dividend = (blob_extraction_green_average / 32);
											divider_divisor = (blob_extraction_blob_size / 32);
										end
										if (blob_extraction_green_average > 2097150) begin
											divider_dividend = (blob_extraction_green_average / 128);
											divider_divisor = (blob_extraction_blob_size / 128);
										end
									end
										
									if (blob_extraction_inner_toggler == 4) begin
										// Read the red averaging result
										blob_extraction_red_average_final = divider_quotient_two;
										
										// Read the green averaging result and set up the blue averaging
										blob_extraction_green_average_final = divider_quotient;
										if (blob_extraction_blue_average < 65535) begin
											divider_dividend = blob_extraction_blue_average;
											divider_divisor = blob_extraction_blob_size;
										end
										if ((blob_extraction_blue_average > 65534) && (blob_extraction_blue_average < 131071)) begin
											divider_dividend_two = (blob_extraction_blue_average / 2);
											divider_divisor_two = (blob_extraction_blob_size / 2);
										end
										if ((blob_extraction_blue_average > 131070) && (blob_extraction_blue_average < 262143)) begin
											divider_dividend_two = (blob_extraction_blue_average / 4);
											divider_divisor_two = (blob_extraction_blob_size / 4);
										end
										if ((blob_extraction_blue_average > 262142) && (blob_extraction_blue_average < 524287)) begin
											divider_dividend_two = (blob_extraction_blue_average / 8);
											divider_divisor_two = (blob_extraction_blob_size / 8);
										end
										if ((blob_extraction_blue_average > 524286) && (blob_extraction_blue_average < 1048575)) begin
											divider_dividend_two = (blob_extraction_blue_average / 16);
											divider_divisor_two = (blob_extraction_blob_size / 16);
										end
										if ((blob_extraction_blue_average > 1048575) && (blob_extraction_blue_average < 2097151)) begin
											divider_dividend_two = (blob_extraction_blue_average / 32);
											divider_divisor_two = (blob_extraction_blob_size / 32);
										end
										if (blob_extraction_blue_average > 2097150) begin
											divider_dividend_two = (blob_extraction_blue_average / 128);
											divider_divisor_two = (blob_extraction_blob_size / 128);
										end
										
										// Set up the X averaging
										if (blob_extraction_x_average < 65535) begin
											divider_dividend = blob_extraction_x_average;
											divider_divisor = blob_extraction_blob_size;
										end
										if ((blob_extraction_x_average > 65534) && (blob_extraction_x_average < 131071)) begin
											divider_dividend = (blob_extraction_x_average / 2);
											divider_divisor = (blob_extraction_blob_size / 2);
										end
										if ((blob_extraction_x_average > 131070) && (blob_extraction_x_average < 262143)) begin
											divider_dividend = (blob_extraction_x_average / 4);
											divider_divisor = (blob_extraction_blob_size / 4);
										end
										if ((blob_extraction_x_average > 262142) && (blob_extraction_x_average < 524287)) begin
											divider_dividend = (blob_extraction_x_average / 8);
											divider_divisor = (blob_extraction_blob_size / 8);
										end
										if ((blob_extraction_x_average > 524286) && (blob_extraction_x_average < 1048575)) begin
											divider_dividend = (blob_extraction_x_average / 16);
											divider_divisor = (blob_extraction_blob_size / 16);
										end
										if ((blob_extraction_x_average > 1048575) && (blob_extraction_x_average < 2097151)) begin
											divider_dividend = (blob_extraction_x_average / 32);
											divider_divisor = (blob_extraction_blob_size / 32);
										end
										if (blob_extraction_x_average > 2097150) begin
											divider_dividend = (blob_extraction_x_average / 512);
											divider_divisor = (blob_extraction_blob_size / 512);
										end
										
										// We need to read data from the image here, so set up another read cycle
										address = ((blob_extraction_y_temp_1 * 320) + blob_extraction_x_temp - 1);
										wren = 0;
									end
									
									if (blob_extraction_inner_toggler == 5) begin
										// Read the blue averaging result
										blob_extraction_blue_average_final = divider_quotient_two;
										
										// Read the X averaging result and set up the Y averaging
										blob_extraction_x_average_final = divider_quotient;
										if (blob_extraction_y_average < 65535) begin
											divider_dividend = blob_extraction_y_average;
											divider_divisor = blob_extraction_blob_size;
										end
										if ((blob_extraction_y_average > 65534) && (blob_extraction_y_average < 131071)) begin
											divider_dividend = (blob_extraction_y_average / 2);
											divider_divisor = (blob_extraction_blob_size / 2);
										end
										if ((blob_extraction_y_average > 131070) && (blob_extraction_y_average < 262143)) begin
											divider_dividend = (blob_extraction_y_average / 4);
											divider_divisor = (blob_extraction_blob_size / 4);
										end
										if ((blob_extraction_y_average > 262142) && (blob_extraction_y_average < 524287)) begin
											divider_dividend = (blob_extraction_y_average / 8);
											divider_divisor = (blob_extraction_blob_size / 8);
										end
										if ((blob_extraction_y_average > 524286) && (blob_extraction_y_average < 1048575)) begin
											divider_dividend = (blob_extraction_y_average / 16);
											divider_divisor = (blob_extraction_blob_size / 16);
										end
										if ((blob_extraction_y_average > 1048575) && (blob_extraction_y_average < 2097151)) begin
											divider_dividend = (blob_extraction_y_average / 32);
											divider_divisor = (blob_extraction_blob_size / 32);
										end
										if (blob_extraction_y_average > 2097150) begin
											divider_dividend = (blob_extraction_y_average / 128);
											divider_divisor = (blob_extraction_blob_size / 128);
										end
										
										// Now read in the data
										if ((spanLeft == 0) && (data_read_sync_blob_extraction == 0)) begin
											// Push data!
											stack_pointer = stack_pointer + 1;
											stack_ram_addra = stack_pointer;
											blob_extraction_data_temp[16:8] = blob_extraction_x_temp - 1;
											blob_extraction_data_temp[7:0] = blob_extraction_y_temp_1;
											stack_ram_dina = blob_extraction_data_temp;
											stack_ram_wea = 1;
											spanLeft = 1;
										end else begin
											if ((spanLeft == 1) && (data_read_sync_blob_extraction != 0)) begin
												spanLeft = 0;
											end
										end
										
										blob_extraction_inner_toggler = 6;
									end
									
									if (blob_extraction_inner_toggler == 6) begin
										/*divider_dividend = 320;
										divider_divisor = 2;*/
										
										// We need to read some more data from the image here, so set up yet another read cycle
										address = ((blob_extraction_y_temp_1 * 320) + blob_extraction_x_temp + 1);
										wren = 0;
									end
										
									if (blob_extraction_inner_toggler == 7) begin
										// Read the Y averaging result...done!
										blob_extraction_y_average_final = divider_quotient;
										
										// Now read in the data
										if ((spanRight == 0) && (data_read_sync_blob_extraction == 0)) begin
											// Push data!
											stack_pointer = stack_pointer + 1;
											stack_ram_addra = stack_pointer;
											blob_extraction_data_temp[16:8] = blob_extraction_x_temp + 1;
											blob_extraction_data_temp[7:0] = blob_extraction_y_temp_1;
											stack_ram_dina = blob_extraction_data_temp;
											stack_ram_wea = 1;
											spanRight = 1;
										end else begin
											if ((spanRight == 1) && (data_read_sync_blob_extraction != 0)) begin
												spanRight = 0;
											end
										end
										
										blob_extraction_inner_toggler = 8;
									end								
									
									if (blob_extraction_inner_toggler == 8) begin									
										// Wait a clock cycle
										wren = 0;
										blob_extraction_y_temp_1 = blob_extraction_y_temp_1 + 1;
										address = ((blob_extraction_y_temp_1 * 320) + blob_extraction_x_temp);	// Set up the next read
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
									
									blob_extraction_minimum_difference = color_similarity_threshold;
									blob_extraction_blob_color_number = 0;		// Default to 'not found'
								end
								
								//one_dim_array_spec = (PRIMARY_COLOR_SLOTS_WORD_SIZE*(ARRAY_SPEC_1_MAX*array_spec_2 + array_spec_1 + array_spec_2 +1)) - 1;
								array_spec = (PRIMARY_COLOR_SLOTS_WORD_SIZE*(ARRAY_SPEC_1_MAX*blob_extraction_slot_loop + blob_extraction_color_loop + blob_extraction_slot_loop)) - 1;
																
								if (blob_extraction_toggler == 7) begin
									// Before we can fill the last data slot, we need to find which color slot this is!
									// We will be calculating the sum of the errors for each color, winner takes all and is then compared against the threshold
									
									//for (blob_extraction_color_loop = 0; blob_extraction_color_loop < 6; blob_extraction_color_loop = blob_extraction_color_loop + 1) begin
										//for (blob_extraction_slot_loop = 0; blob_extraction_slot_loop < 8; blob_extraction_slot_loop = blob_extraction_slot_loop + 1) begin
											// Red
											if (blob_extraction_red_average_final > primary_color_slots[(array_spec - 16) -: 8]) begin
												//old syntax was primary_color_slots[blob_extraction_color_loop][blob_extraction_slot_loop][7:0] 
												
												blob_extraction_current_difference = blob_extraction_red_average_final - primary_color_slots[(array_spec - 16) -: 8];
											end else begin
												blob_extraction_current_difference = primary_color_slots[(array_spec - 16) -: 8] - blob_extraction_red_average_final;
											end
											
											// Green
											if (blob_extraction_green_average_final > primary_color_slots[(array_spec - 8) -: 8]) begin
												//old syntax was primary_color_slots[blob_extraction_color_loop][blob_extraction_slot_loop][15:8]
												 
												blob_extraction_current_difference = 
												(blob_extraction_current_difference + (blob_extraction_green_average_final - primary_color_slots[(array_spec - 8) -:8]));
											end else begin
												blob_extraction_current_difference = (blob_extraction_current_difference + (primary_color_slots[(array_spec - 8) -: 8] - blob_extraction_green_average_final));
											end
											
											// Blue
											if (blob_extraction_blue_average_final > primary_color_slots[array_spec -: 8]) begin
												//old syntax was primary_color_slots[blob_extraction_color_loop][blob_extraction_slot_loop][23:16]
												
												blob_extraction_current_difference = 
												(blob_extraction_current_difference + (blob_extraction_blue_average_final 
													- primary_color_slots[array_spec -: 8]));
											end else begin
												blob_extraction_current_difference = 
												(blob_extraction_current_difference 
													+ (primary_color_slots[array_spec -: 8] - blob_extraction_blue_average_final));
											end
											
											// Compare...
											if (blob_extraction_current_difference < blob_extraction_minimum_difference) begin
												blob_extraction_minimum_difference = blob_extraction_current_difference;
												blob_extraction_blob_color_number = blob_extraction_color_loop + 1;
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
									
									// TESTING ONLY!!! ***FIXME***
									/*blob_extraction_x_average_final = 160;
									blob_extraction_y_average_final = 120;*/
								end
								
								if (blob_extraction_toggler == 8) begin
									// Begin writing the data
									address = ((blob_extraction_blob_counter * 3) + 200000);
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
									address = ((blob_extraction_blob_counter * 3) + 200001);
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
									address = ((blob_extraction_blob_counter * 3) + 200002);
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
									address = ((blob_extraction_y_average_final * 320) + blob_extraction_x_average_final) + 76801;	// Set up the next write
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
			end else begin
				blob_extraction_done = 0;
				address = 18'b0;
				data_write = 32'b0;
				wren = 1'b0;
			end
		end	//end if pause = 0
		end
		
endmodule 
