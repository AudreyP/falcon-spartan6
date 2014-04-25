`timescale 1ns / 1ps
/**********************************************************************
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

module blob_sorting(
	//input wires
	input wire clk,
	input wire clk_fast,
	input wire pause,
	input wire enable_blob_sorting,	
	input wire [7:0] minimum_blob_size,
	input wire [7:0] slide_switches,
	input wire [15:0] blob_extraction_blob_counter,
	
	input wire [4:0] pointer_memory_read_addr_b,
	output wire [17:0] pointer_memory_data_read_b,

	// main memory interface
	input wire [31:0] data_read,
	output reg [31:0] data_write,
	output reg [17:0] address,
	output reg wren,
	
	output reg [4:0] number_of_valid_blobs,
	output reg [15:0] debug_display,
	
	output reg blob_sorting_done
	);
	
	parameter BlobStorageOffset = 200000; //same def'n as in blob_extraction module
	parameter BUFFER0_OFFSET = 0;
	parameter BUFFER1_OFFSET = 76801;
	parameter BUFFER2_OFFSET = 153602;
	parameter BUFFER3_OFFSET = 230403;
	
	initial blob_sorting_done = 0;
	initial debug_display = 1010;
	initial number_of_valid_blobs = 0;
	
	//-----Instantiate block ram for x, y, s centroids
	// x centroids = [31:24] centroids
	// y centroids = [23:16] centroids
	// s centroids = [15:0] centroids
	reg [2:0] centroids_write_addr = 0;
	reg [31:0] centroids_data_write;
	reg wren_centroids;
	
	
	//-----Instantiate block ram for blob sizes
	reg [4:0] blob_data_addr_a;
	reg [15:0] blob_data_data_write;
 	wire [15:0] blob_data_data_read_a;
	reg wren_blob_data;
	
	// written to here, read from in main. 
	blob_sizes_ram blob_data_ram (
		.clka(clk_fast), // input clka
		.wea(wren_blob_data), // input [0 : 0] wea
		.addra(blob_data_addr_a), // input [4 : 0] addra
		.dina(blob_data_data_write), // input [15 : 0] dina 
		.douta(blob_data_data_read_a), // output [15 : 0] douta
		//port b is unused.
		.clkb(clk_fast), // input clkbf
		.web(1'b0), // input [0 : 0] web
		.addrb(5'b00000), // input [4 : 0] addrb
		.dinb(), // input [15 : 0] dinb (--NOT USED--)
		.doutb() // output [15 : 0] doutb
		);
	
	
	//-----Instantiate block ram for address pointers to blobs of interest
	reg [4:0] pointer_memory_addr_a;
	reg [17:0] pointer_memory_data_write;
 	wire [17:0] pointer_memory_data_read_a;
	reg wren_pointer_memory;
	
	pointer_memory pointer_memory (
		.clka(clk_fast), // input clk
		.wea(wren_pointer_memory), // input [0 : 0] wea
		.addra(pointer_memory_addr_a), // input [4 : 0] addra
		.dina(pointer_memory_data_write), // input [17 : 0] dina
		.douta(pointer_memory_data_read_a), // output [17 : 0] douta
		.clkb(clk_fast), // input clkbf
		.web(1'b0), // input [0 : 0] web
		.addrb(pointer_memory_read_addr_b), // input [4 : 0] addrb
		.dinb(), // input [18 : 0] dinb (--NOT USED--)
		.doutb(pointer_memory_data_read_b) // output [17 : 0] doutb
		);
	
	reg [17:0] new_blob_ptr;
	reg [7:0] matching_color_slot;
	reg [7:0] new_x_centroid_coord;
	reg [7:0] new_y_centroid_coord;
	reg [15:0] new_blob_size;
	reg [3:0] comparison_type;
	
	//state machine counters
	reg [5:0] main_state = 0;
	reg [2:0] blob_data_initialization = 0;
	reg [2:0] pointer_memory_initialization = 0;
	reg [2:0] get_new_blob_data = 0;
	reg [2:0] get_rank_one_blob = 0;
	reg [2:0] get_rank_two_blob = 0;
	reg [2:0] get_rank_three_blob = 0;
	reg [5:0] replace_rank_one = 0;
	reg [4:0] replace_rank_two = 0;
	reg [2:0] replace_rank_three = 0;
	reg [3:0] debug1_state = 0;
	reg [3:0] debug2_state = 0;
	reg [3:0] debug3_state = 0;
	// address offset counter
	reg [17:0] tracking_output_pointer = 0;
	
	// temorary data storage registers
	reg [7:0] rank_one_x_centroid_coord = 0;
	reg [7:0] rank_one_y_centroid_coord = 0;
	reg [15:0] rank_one_blob_size = 0;
	
	reg [7:0] rank_two_x_centroid_coord = 0;
	reg [7:0] rank_two_y_centroid_coord = 0;
	reg [15:0] rank_two_blob_size = 0;
	
	reg [7:0] rank_three_x_centroid_coord = 0;
	reg [7:0] rank_three_y_centroid_coord = 0;
	reg [15:0] rank_three_blob_size = 0;
	
	reg [15:0] blob_data_temp = 0;
	reg [17:0] pointer_temp = 0;

	localparam 
		INITIALIZATION = 0,
		GET_NEW_BLOB_DATA = 1,
// 		GET_COMPARISON_TYPE = 2,
		GET_RANK_ONE_BLOB = 3,
		COMPARE_NEW_TO_RANK_ONE = 4,
		REPLACE_RANK_ONE = 5,
		GET_RANK_TWO_BLOB = 6,
		COMPARE_NEW_TO_RANK_TWO = 7,
		REPLACE_RANK_TWO = 8,
		GET_RANK_THREE_BLOB = 9,
		COMPARE_NEW_TO_RANK_THREE = 10,
		REPLACE_RANK_THREE = 11,
		DEBUG1 = 12,
		DEBUG2 = 13,
		DEBUG3 = 14,
		DONE = 15;
	
	localparam 
		Y_CENTROID_LOWEST = 0,
		Y_CENTROID_HIGHEST = 1,
		BLOB_BIGGEST = 2, //default case
		BLOB_SMALLEST = 3;
	
	localparam
		RANK_ONE_BLOB_ADDR = 0,
		RANK_TWO_BLOB_ADDR = 6,
		RANK_THREE_BLOB_ADDR = 12; 	
	
	// Output the tracking data
	always @(posedge clk) begin
		if (pause == 0) begin
			if (enable_blob_sorting == 1) begin
				case (main_state) 
					//initialize to zero
					INITIALIZATION: begin
						blob_sorting_done = 0;
						number_of_valid_blobs = 0;
						
						//write zeros to the 0-17 slots in the blob sizes array
						case (blob_data_initialization) 
							0: begin
								wren_blob_data = 1'b0;
								blob_data_addr_a = 0;
								blob_data_data_write = 0;
								blob_data_initialization = 1;
							end
							1: begin
								blob_data_data_write = 0;
								wren_blob_data = 1'b1;
								blob_data_initialization = 2;
							end
							2: begin
								wren_blob_data = 1'b0;
								blob_data_addr_a = blob_data_addr_a + 1;
								//reset addresses after words 0-17 written
								if (blob_data_addr_a > 17) begin
									blob_data_addr_a = 0;
								end
								blob_data_initialization = 1; //bounce between states 1 and 2 (0 state is initial only)
							end
						endcase
						// initialize pointer memory to all ones (7fff)
						case (pointer_memory_initialization) 
							0: begin
								wren_pointer_memory = 1'b0;
								pointer_memory_addr_a = 0;
								pointer_memory_data_write = 18'h7ffff;
								pointer_memory_initialization = 1;
							end
							1: begin
								pointer_memory_data_write = 18'h7ffff;
								wren_pointer_memory = 1'b1;
								pointer_memory_initialization = 2;
							end
							2: begin
								wren_pointer_memory = 1'b0;
								pointer_memory_addr_a = pointer_memory_addr_a + 1;
								//reset addresses after words 0-17 written
								if (pointer_memory_addr_a > 17) begin
									pointer_memory_addr_a = 0;
									blob_data_addr_a = 0;
									main_state = GET_NEW_BLOB_DATA;
								end
								pointer_memory_initialization = 1; //bounce between states 1 and 2 (0 state is initial only)
							end
						endcase
					end
					// Next, read the first two blob data words from main memory
					GET_NEW_BLOB_DATA: begin
						if (tracking_output_pointer <= (blob_extraction_blob_counter * 3)) begin
							//memory read state machine
							case (get_new_blob_data) 
								0: begin
									//set address
									wren = 0;
									address = tracking_output_pointer + BlobStorageOffset;
									get_new_blob_data = 1;
								end
								1: begin
									//read new blob data from first word into registers
									
									// debugging
// 									if (address == 200000) begin
// 										debug_display = data_read[7:0];
// 									end
									
									if (data_read[7:0] == 0) begin // this is the color slot data from blob word one. 
										// blob is NOT of interest and will not be stored. Get new.
										tracking_output_pointer = tracking_output_pointer + 3; // increment to next blob
										get_new_blob_data = 0; //return to initial state in GET_NEW_BLOB_DATA with new pointer
									end else begin
										// blob is of interest
										matching_color_slot = data_read[7:0];
										new_blob_ptr = address; //points to the beginning of the blob's info in main memory (allows for signal propogation from state 0)
										number_of_valid_blobs = number_of_valid_blobs + 1;
										tracking_output_pointer = tracking_output_pointer + 1;
										get_new_blob_data = 2;
									end
								end
								2: begin
									address = tracking_output_pointer + BlobStorageOffset; // set address with new tracking output pointer value.
									get_new_blob_data = 3;
								end
								3: begin
									// debugging
									if (address == 200001) begin
										debug_display = data_read[7:0];
									end
									// read new blob data from second word
									new_x_centroid_coord = data_read[31:24];
									new_y_centroid_coord = data_read[23:16];
									new_blob_size = data_read[15:0];
									// increment address by two (skip 3rd blob data word)
									tracking_output_pointer = tracking_output_pointer + 2;
// 									address = tracking_output_pointer + BlobStorageOffset;
									get_new_blob_data = 0;
									main_state = GET_RANK_ONE_BLOB;
								end
							endcase
							// read switches determine the type of comparison that will be done.
							// x or y centroid or blob size? Smallest or largest?
							case (slide_switches[3:2])
								2'b00: comparison_type = BLOB_BIGGEST; //default
								2'b01: comparison_type = BLOB_SMALLEST;
								2'b10: comparison_type = Y_CENTROID_HIGHEST;
								2'b11: comparison_type = Y_CENTROID_LOWEST;
							endcase		
						end else begin
// 							blob_sorting_done = 1;
// 							main_state = DONE;
 							main_state = DEBUG1;
						end	
							
					end
					GET_RANK_ONE_BLOB: begin
						case (get_rank_one_blob) 
							0: begin
								wren_blob_data = 1'b0;
								blob_data_addr_a = RANK_ONE_BLOB_ADDR + matching_color_slot - 1;
								get_rank_one_blob = 1;
							end
							1: begin
								if (comparison_type < BLOB_BIGGEST) begin
									rank_one_x_centroid_coord = blob_data_data_read_a[15:8];
									rank_one_y_centroid_coord = blob_data_data_read_a[7:0];
								end else begin
									rank_one_blob_size = blob_data_data_read_a[15:0];
								end
								get_rank_one_blob = 0;
								main_state = COMPARE_NEW_TO_RANK_ONE;
							end
						endcase
					end
					COMPARE_NEW_TO_RANK_ONE: begin
						case (comparison_type)
							Y_CENTROID_LOWEST: begin
								if (new_y_centroid_coord < rank_one_y_centroid_coord) begin
									main_state = REPLACE_RANK_ONE;
								end else begin
									main_state = GET_RANK_TWO_BLOB;
								end
							end
							Y_CENTROID_HIGHEST: begin
								if (new_y_centroid_coord > rank_one_y_centroid_coord) begin
									main_state = REPLACE_RANK_ONE;
								end else begin
									main_state = GET_RANK_TWO_BLOB;
								end
							end
							BLOB_BIGGEST: begin
								if (new_blob_size > rank_one_blob_size) begin
									main_state = REPLACE_RANK_ONE;
								end else begin
									main_state = GET_RANK_TWO_BLOB;
								end
							end
							BLOB_SMALLEST: begin
								if (new_blob_size < rank_one_blob_size) begin
									main_state = REPLACE_RANK_ONE;
								end else begin
									main_state = GET_RANK_TWO_BLOB;
								end
							end
						endcase
					end
					GET_RANK_TWO_BLOB: begin
						case (get_rank_two_blob) 
							0: begin
								wren_blob_data = 1'b0;
								blob_data_addr_a = RANK_TWO_BLOB_ADDR + matching_color_slot - 1;
								get_rank_two_blob = 1;
							end
							1: begin
								if (comparison_type < BLOB_BIGGEST) begin
									rank_two_x_centroid_coord = blob_data_data_read_a[15:8];
									rank_two_y_centroid_coord = blob_data_data_read_a[7:0];
								end else begin
									rank_two_blob_size = blob_data_data_read_a[15:0];
								end
								get_rank_two_blob = 0;
								main_state = COMPARE_NEW_TO_RANK_TWO;
							end
						endcase
					end
					COMPARE_NEW_TO_RANK_TWO: begin
						case (comparison_type)
							Y_CENTROID_LOWEST: begin
								if (new_y_centroid_coord < rank_two_y_centroid_coord) begin
									main_state = REPLACE_RANK_TWO;
								end else begin
									main_state = GET_RANK_THREE_BLOB;
								end
							end
							Y_CENTROID_HIGHEST: begin
								if (new_y_centroid_coord > rank_two_y_centroid_coord) begin
									main_state = REPLACE_RANK_TWO;
								end else begin
									main_state = GET_RANK_THREE_BLOB;
								end
							end
							BLOB_BIGGEST: begin
								if (new_blob_size > rank_two_blob_size) begin
									main_state = REPLACE_RANK_TWO;
								end else begin
									main_state = GET_RANK_THREE_BLOB;
								end
							end
							BLOB_SMALLEST: begin
								if (new_blob_size < rank_two_blob_size) begin
									main_state = REPLACE_RANK_TWO;
								end else begin
									main_state = GET_RANK_THREE_BLOB;
								end
							end
						endcase
					end
					GET_RANK_THREE_BLOB: begin
						case (get_rank_three_blob) 
							0: begin
								wren_blob_data = 1'b0;
								blob_data_addr_a = RANK_THREE_BLOB_ADDR + matching_color_slot - 1;
								get_rank_three_blob = 1;
							end
							1: begin
								if (comparison_type < BLOB_BIGGEST) begin
									rank_three_x_centroid_coord = blob_data_data_read_a[15:8];
									rank_three_y_centroid_coord = blob_data_data_read_a[7:0];
								end else begin
									rank_three_blob_size = blob_data_data_read_a[15:0];
								end
								get_rank_three_blob = 0;
								main_state = COMPARE_NEW_TO_RANK_THREE;
							end
						endcase
					end
					COMPARE_NEW_TO_RANK_THREE: begin
						case (comparison_type)
							Y_CENTROID_LOWEST: begin
								if (new_y_centroid_coord < rank_three_y_centroid_coord) begin
									main_state = REPLACE_RANK_THREE;
								end else begin
									main_state = GET_NEW_BLOB_DATA;
								end
							end
							Y_CENTROID_HIGHEST: begin
								if (new_y_centroid_coord > rank_three_y_centroid_coord) begin
									main_state = REPLACE_RANK_THREE;
								end else begin
									main_state = GET_NEW_BLOB_DATA;
								end
							end
							BLOB_BIGGEST: begin
								if (new_blob_size > rank_three_blob_size) begin
									main_state = REPLACE_RANK_THREE;
								end else begin
									main_state = GET_NEW_BLOB_DATA;
								end
							end
							BLOB_SMALLEST: begin
								if (new_blob_size < rank_three_blob_size) begin
									main_state = REPLACE_RANK_THREE;
								end else begin
									main_state = GET_NEW_BLOB_DATA;
								end
							end
						endcase
					end
					REPLACE_RANK_ONE: begin
						case (replace_rank_one)
							// read current rank 2 blob, demote addr to rank 3 position and write.
							// also demote addr pointer to blob's info in main memory.
							0: begin
								wren_blob_data = 0;
								wren_pointer_memory = 0;
								blob_data_addr_a = RANK_TWO_BLOB_ADDR + matching_color_slot - 1;
								pointer_memory_addr_a = RANK_TWO_BLOB_ADDR + matching_color_slot - 1;
								replace_rank_one = 1;
							end
							1: begin
								// read
								if (comparison_type < BLOB_BIGGEST) begin
									blob_data_temp[7:0] = blob_data_data_read_a[7:0]; // data to compare is y_centroid
								end else begin
									blob_data_temp = blob_data_data_read_a; // data to compare is blob size
								end
								pointer_temp = pointer_memory_data_read_a;
								replace_rank_one = 2;
							end
							// write old rank 2 data to rank 3 position
							2: begin
								// set addr lines
								blob_data_addr_a = RANK_THREE_BLOB_ADDR + matching_color_slot - 1; 
								pointer_memory_addr_a = RANK_THREE_BLOB_ADDR + matching_color_slot - 1;
								// set data lines
								if (comparison_type < BLOB_BIGGEST) begin
									blob_data_data_write[7:0] = blob_data_temp[7:0];
								end else begin
 									blob_data_data_write = blob_data_temp;
//  									blob_data_data_write = blob_data_data_read_a;
								end
								pointer_memory_data_write = pointer_temp;
								replace_rank_one = 3;
							end
							3: begin
								wren_blob_data = 1;
								wren_pointer_memory = 1;
								replace_rank_one = 4;
							end	
							// read current rank 1 blob, demote addr to rank 2 position and write.
							// also demote addr pointer to blob's info in main memory.
							4: begin
								wren_blob_data = 0;
								wren_pointer_memory = 0;
								blob_data_addr_a = RANK_ONE_BLOB_ADDR + matching_color_slot - 1;
								pointer_memory_addr_a = RANK_ONE_BLOB_ADDR + matching_color_slot - 1;
								replace_rank_one = 5;
							end
							5: begin
								// read
								if (comparison_type < BLOB_BIGGEST) begin
									blob_data_temp[7:0] = blob_data_data_read_a[7:0]; // data to compare is y_centroid
								end else begin
									blob_data_temp = blob_data_data_read_a; // data to compare is blob size
								end
								pointer_temp = pointer_memory_data_read_a;
								replace_rank_one = 6;
							end
							// write to old rank 1 data to rank 2 position
							6: begin
								// set addr lines
								blob_data_addr_a = RANK_TWO_BLOB_ADDR + matching_color_slot - 1;
								pointer_memory_addr_a = RANK_TWO_BLOB_ADDR + matching_color_slot - 1;
								// set data lines
								if (comparison_type < BLOB_BIGGEST) begin
									blob_data_data_write[7:0] = blob_data_temp[7:0];
								end else begin
 									blob_data_data_write = blob_data_temp;
// 									blob_data_data_write = blob_data_data_read_a;
								end
								pointer_memory_data_write = pointer_temp;
								replace_rank_one = 7;
							end
							7: begin
								wren_blob_data = 1;
								wren_pointer_memory = 1;
								replace_rank_one = 8;
							end
							// write new blob size to now-empty rank 1 position. 
							// store addr pointer to new blob's info in main memory in top slot.
							8: begin
								wren_blob_data = 0;
								wren_pointer_memory = 0;
								// set addr lines 
								blob_data_addr_a = RANK_ONE_BLOB_ADDR + matching_color_slot - 1;
								pointer_memory_addr_a = RANK_ONE_BLOB_ADDR + matching_color_slot - 1;
								// set data lines
								if (comparison_type < BLOB_BIGGEST) begin
									//that is, if the comparison type is X or Y centroid
									blob_data_data_write = {new_x_centroid_coord, new_y_centroid_coord};
								end else begin
									blob_data_data_write = new_blob_size;
								end
								pointer_memory_data_write = new_blob_ptr;
								replace_rank_one = 9;
							end
							9: begin
								wren_blob_data = 1;
								wren_pointer_memory = 1;
								replace_rank_one = 10;
							end
							10: begin
								wren_blob_data = 0;
								wren_pointer_memory = 0;
								replace_rank_one = 0;
								main_state = GET_NEW_BLOB_DATA;
							end
						endcase
					end
					REPLACE_RANK_TWO: begin
						case (replace_rank_two) 
							// leave current rank 1 blob where it is
							// read current rank 2 blob, demote addr to rank 3 position and write.
							// also demote addr pointer to blob's info in main memory.
							0: begin
								wren_blob_data = 0;
								wren_pointer_memory = 0;
								blob_data_addr_a = RANK_TWO_BLOB_ADDR + matching_color_slot - 1;
								pointer_memory_addr_a = RANK_TWO_BLOB_ADDR + matching_color_slot - 1;
								replace_rank_two = 1;
							end
							1: begin
								// read in data to temp registers
								if (comparison_type < BLOB_BIGGEST) begin
									blob_data_temp[7:0] = blob_data_data_read_a[7:0]; // data to compare is y_centroid
								end else begin
									blob_data_temp = blob_data_data_read_a; // data to compare is blob size
								end
								pointer_temp = pointer_memory_data_read_a;
								replace_rank_two = 2;
							end
							2: begin
								//set addr
								blob_data_addr_a = RANK_THREE_BLOB_ADDR + matching_color_slot - 1;
								pointer_memory_addr_a = RANK_THREE_BLOB_ADDR + matching_color_slot - 1;
								// set data lines
								if (comparison_type < BLOB_BIGGEST) begin
									blob_data_data_write[7:0] = blob_data_temp[7:0];
								end else begin
									blob_data_data_write = blob_data_temp;
//  									blob_data_data_write = blob_data_data_read_a;
								end
								pointer_memory_data_write = pointer_temp;
								replace_rank_two = 3;
							end
							3: begin
								wren_blob_data = 1;
								wren_pointer_memory = 1;
								replace_rank_two = 4;
							end	
							// write new blob size to now-empty rank 2 position. 
							// store addr pointer to new blob's info in main memory in rank 2 position for that color
							4: begin
								wren_blob_data = 0;
								wren_pointer_memory = 0;
								//set addr lines
								blob_data_addr_a = RANK_TWO_BLOB_ADDR + matching_color_slot - 1;
								pointer_memory_addr_a = RANK_TWO_BLOB_ADDR + matching_color_slot - 1;
								// set data lines
								if (comparison_type < BLOB_BIGGEST) begin
									//that is, if the comparison type is X or Y centroid
									blob_data_data_write = {new_x_centroid_coord, new_y_centroid_coord};
								end else begin
									blob_data_data_write = new_blob_size;
								end
								pointer_memory_data_write = new_blob_ptr;
								replace_rank_two = 5;
							end
							5: begin
								wren_blob_data = 1;
								wren_pointer_memory = 1;
								replace_rank_two = 6;
							end
							6: begin
								wren_blob_data = 0;
								wren_pointer_memory = 0;
								replace_rank_two = 0;
								main_state = GET_NEW_BLOB_DATA;
							end
						endcase
					end
					REPLACE_RANK_THREE: begin
						case (replace_rank_three)
							// leave current rank 1 and rank 2 blobs where they are
							// overwrite current rank 3 blob
							// also overwrite addr pointer to blob's info in main memory.
							0: begin
								wren_blob_data = 0;
								wren_pointer_memory = 0;
								// set addr lines
								blob_data_addr_a = RANK_THREE_BLOB_ADDR + matching_color_slot - 1;
								pointer_memory_addr_a = RANK_THREE_BLOB_ADDR + matching_color_slot - 1;
								// set data lines
								if (comparison_type < BLOB_BIGGEST) begin
									//that is, if the comparison type is X or Y centroid
									blob_data_data_write = {new_x_centroid_coord, new_y_centroid_coord};
								end else begin
									blob_data_data_write = new_blob_size;
								end
								pointer_memory_data_write = new_blob_ptr;
								replace_rank_three = 1;
							end
							1: begin
								wren_blob_data = 1;
								wren_pointer_memory = 1;
								replace_rank_three = 2;
							end
							2: begin
								wren_blob_data = 0;
								wren_pointer_memory = 0;
								replace_rank_three = 0;
								main_state = GET_NEW_BLOB_DATA;
							end
						endcase
					end	// end REPLACE_RANK_THREE state
					DEBUG1: begin
						//write contents of   blob data memory   to main memory, starting at address BUFFER1_OFFSET + 320	
						case (debug1_state)
							// set read address line
							0: begin
								wren = 1'b0;
								wren_blob_data = 1'b0;
								blob_data_addr_a = 0;
								//address = BUFFER2_OFFSET + 320;
								address = 209602 + 320;
								debug1_state = 1;
							end
							// set write address and data lines to main memory
							1: begin
								wren = 1'b1;
								data_write = {12'hFFF, blob_data_data_read_a};
								debug1_state = 2;
							end
							// write to main memory
							// increment read address 
							// return to write state until counter reached
							2: begin
								wren = 1'b0;
								address = address + 1;
								blob_data_addr_a = blob_data_addr_a + 1;
								//reset addresses after words 0-17 read
								if (blob_data_addr_a > 17) begin
									blob_data_addr_a = 0;
									main_state = DEBUG2;
								end else begin
									debug1_state = 1; //bounce between states 1 and 2 (0 state is initial only)
								end
							end
						endcase
					end
					DEBUG2: begin
						//write contents of pointer memory to main memory, starting at address BUFFER1_OFFSET + 3200	
						case (debug2_state)
							// set read address line
							0: begin
								wren = 1'b0;
								wren_pointer_memory = 1'b0;
								pointer_memory_addr_a = 0;
								//address = BUFFER2_OFFSET + 3200;
								address = 209602 + 3200;
								debug2_state = 1;
							end
							// set write address and data lines to main memory
							1: begin
								wren = 1'b1;
								data_write = {12'hFFF, pointer_memory_data_read_a};
								debug2_state = 2;
							end
							// write to main memory
							// increment read address 
							// return to write state until counter reached
							2: begin
								wren = 1'b0;
								//reset addresses after words 0-17 read
								address = address + 1;
								pointer_memory_addr_a = pointer_memory_addr_a + 1;
								if (pointer_memory_addr_a > 17) begin
									pointer_memory_addr_a = 0;
									main_state = DONE;
								end else begin
									debug2_state = 1; //bounce between states 1 and 2 (0 state is initial only)
								end
							end
						endcase
					end
// 					DEBUG3: begin
// 						//check data stored at main memory location 200000 (BlobStorageOffset)
// 						case (debug3_state)
// 							0: begin
// 								//set address and wren
// 								address = BlobStorageOffset + 1;
// 								wren = 0;
// 								debug3_state = 1;
// 							end
// 							1: begin
// 								//read
// 								debug_display = data_read[15:0];
// 								debug3_state = 0;
// 								main_state = DONE;
// 							end
// 						endcase
// 					end
					DONE: begin
						blob_sorting_done = 1;
						
						// Reset all registers for next pass
						main_state = INITIALIZATION;
						blob_data_addr_a = 0;
						pointer_memory_addr_a = 0;
						blob_data_initialization = 0;
						pointer_memory_initialization = 0;
						tracking_output_pointer = 0;
						blob_data_initialization = 0;
						pointer_memory_initialization = 0;
						get_new_blob_data = 0;
						get_rank_one_blob = 0;
						get_rank_two_blob = 0;
						get_rank_three_blob = 0;
						replace_rank_one = 0;
						replace_rank_two = 0;
						replace_rank_three = 0;
						debug1_state = 0;
						debug2_state = 0;
						debug3_state = 0;
				
						data_write = 32'b0;
						address = 18'b0;
						wren = 1'b0;
						main_state = DONE;
					end
				endcase // end main case statement
			end else begin //end if enable = 1
				blob_sorting_done = 0;

				// Reset all registers for next pass
				main_state = INITIALIZATION;
				blob_data_addr_a = 0;
				pointer_memory_addr_a = 0;
				blob_data_initialization = 0;
				pointer_memory_initialization = 0;
				tracking_output_pointer = 0;
				blob_data_initialization = 0;
				pointer_memory_initialization = 0;
				get_new_blob_data = 0;
				get_rank_one_blob = 0;
				get_rank_two_blob = 0;
				get_rank_three_blob = 0;
				replace_rank_one = 0;
				replace_rank_two = 0;
				replace_rank_three = 0;
				debug1_state = 0;
				debug2_state = 0;
				debug3_state = 0;

				address = 18'b0;
				data_write = 32'b0;
				wren = 1'b0;
			end
		end	//end if pause == 0
	end // end always

endmodule

