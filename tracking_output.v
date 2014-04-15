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

module tracking_output(
	//input wires
	input wire clk,
	input wire pause,
	input wire [15:0] blob_extraction_blob_counter,   //assigned in blob extraction module--only used in an if condition here.
	input wire enable_tracking_output,	
	input wire find_biggest,
	input wire find_highest,
	input wire [7:0] minimum_blob_size,
	input wire [7:0] slide_switches,
	input wire [31:0] data_read,
	
	//output regs
	output reg wren,
	output reg [31:0] data_write,
	output reg [17:0] address,
	output reg [63:0] x_centroids_array,   //assigned here--only used in main.
	output reg [63:0] y_centroids_array,   //assigned here--only used in main.
	output reg [127:0] s_centroids_array,   //assigned here--only used in main.
	output reg [288:0] tracking_output_blob_sizes /*[17:0]*/,	//assigned here--only used in main. 
	output reg tracking_output_done
	);
		
	initial tracking_output_done = 0;

	localparam  	BLOB_SIZE_WORD_SIZE = 16,
			BLOB_SIZE_WORD_0 = 1*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_1 = 2*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_2 = 3*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_3 = 4*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_4 = 5*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_5 = 6*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_6 = 7*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_7 = 8*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_8 = 9*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_9 = 10*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_10 = 11*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_11 = 12*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_12 = 13*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_13 = 14*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_14 = 15*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_15 = 16*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_16 = 17*BLOB_SIZE_WORD_SIZE-1,
			BLOB_SIZE_WORD_17 = 18*BLOB_SIZE_WORD_SIZE-1;
	
	localparam	S_CENTROIDS_WORD_SIZE = 16,
			S_CENTROIDS_WORD_0 = 1*S_CENTROIDS_WORD_SIZE - 1,
			S_CENTROIDS_WORD_1 = 2*S_CENTROIDS_WORD_SIZE - 1,
			S_CENTROIDS_WORD_2 = 3*S_CENTROIDS_WORD_SIZE - 1,
			S_CENTROIDS_WORD_3 = 4*S_CENTROIDS_WORD_SIZE - 1,
			S_CENTROIDS_WORD_4 = 5*S_CENTROIDS_WORD_SIZE - 1,
			S_CENTROIDS_WORD_5 = 6*S_CENTROIDS_WORD_SIZE - 1,
			S_CENTROIDS_WORD_6 = 7*S_CENTROIDS_WORD_SIZE - 1,
			S_CENTROIDS_WORD_7 = 8*S_CENTROIDS_WORD_SIZE - 1,
			
			X_CENTROIDS_WORD_SIZE = 8,
			X_CENTROIDS_WORD_0 = 1*X_CENTROIDS_WORD_SIZE - 1,
			X_CENTROIDS_WORD_1 = 2*X_CENTROIDS_WORD_SIZE - 1,
			X_CENTROIDS_WORD_2 = 3*X_CENTROIDS_WORD_SIZE - 1,
			X_CENTROIDS_WORD_3 = 4*X_CENTROIDS_WORD_SIZE - 1,
			X_CENTROIDS_WORD_4 = 5*X_CENTROIDS_WORD_SIZE - 1,
			X_CENTROIDS_WORD_5 = 6*X_CENTROIDS_WORD_SIZE - 1,
			X_CENTROIDS_WORD_6 = 7*X_CENTROIDS_WORD_SIZE - 1,
			X_CENTROIDS_WORD_7 = 8*X_CENTROIDS_WORD_SIZE - 1,
			
			Y_CENTROIDS_WORD_SIZE = 8,
			Y_CENTROIDS_WORD_0 = 1*Y_CENTROIDS_WORD_SIZE - 1,
			Y_CENTROIDS_WORD_1 = 2*Y_CENTROIDS_WORD_SIZE - 1,
			Y_CENTROIDS_WORD_2 = 3*Y_CENTROIDS_WORD_SIZE - 1,
			Y_CENTROIDS_WORD_3 = 4*Y_CENTROIDS_WORD_SIZE - 1,
			Y_CENTROIDS_WORD_4 = 5*Y_CENTROIDS_WORD_SIZE - 1,
			Y_CENTROIDS_WORD_5 = 6*Y_CENTROIDS_WORD_SIZE - 1,
			Y_CENTROIDS_WORD_6 = 7*Y_CENTROIDS_WORD_SIZE - 1,
			Y_CENTROIDS_WORD_7 = 8*Y_CENTROIDS_WORD_SIZE - 1;
				
	
	//reg tracking_output_main_chunk_already_loaded = 0;   //UNUSED IN EITHER LOCATION!
	//reg [7:0] tracking_output_counter_buffer_blue;   //UNUSED IN EITHER LOCATION!

	reg [15:0] tracking_output_pointer_counter = 0;	//HERE ONLY
	reg [7:0] tracking_output_counter_color;	//HERE ONLY
	reg [15:0] tracking_output_counter_size;	//HERE ONLY
	
	reg tracking_output_ok_to_send_data = 0;	//HERE ONLY
	reg [15:0] tracking_output_pointer = 0;		//HERE ONLY
	
	reg [15:0] tracking_output_blob_location [17:0];  //HERE ONLY
	reg [31:0] tracking_output_temp_data;	//HERE ONLY
	reg [7:0] location_to_extract = 0;	//HERE ONLY
	reg [3:0] enable_tracking_output_verified = 0;	//here only

	reg [5:0] tracking_output_counter_tog = 0;
	reg [5:0] tracking_output_counter_togg = 0;
	reg [5:0] tracking_output_counter_toggle = 0;
	reg [31:0] tracking_output_counter_temp = 0;
	
	reg [2:0] tracking_output_holdoff = 0;

//---IS THIS STUFF OK?
/*	reg wren;
	reg [31:0] data_write;
	reg [17:0] address;
		
	assign wren_wire = wren;
	assign data_write_wire = data_write;
	assign address_wire = address;*/
	
	
	// Output the tracking data
	always @(posedge clk) begin
		if (pause == 0) begin
			if (enable_tracking_output == 1) begin
				enable_tracking_output_verified = enable_tracking_output_verified + 1;
			end else begin
				enable_tracking_output_verified = 0;
			end
			
			if ((enable_tracking_output_verified >= 2) && (tracking_output_done == 0)) begin
				enable_tracking_output_verified = 2;		// Keep this running!
			
				case (tracking_output_holdoff)
				0:begin
					wren = 0;
					tracking_output_counter_tog = 5;
					tracking_output_counter_togg = 0;
					tracking_output_pointer_counter = 0;
					tracking_output_ok_to_send_data = 0;
					tracking_output_pointer = 6;
					x_centroids_array[X_CENTROIDS_WORD_0 : 0] = 0;
					y_centroids_array[Y_CENTROIDS_WORD_0 : 0] = 0;
					x_centroids_array[X_CENTROIDS_WORD_1 : 1+X_CENTROIDS_WORD_0] = 0;
					y_centroids_array[Y_CENTROIDS_WORD_1 : 1+Y_CENTROIDS_WORD_0] = 0;
					x_centroids_array[X_CENTROIDS_WORD_2 : 1+X_CENTROIDS_WORD_1] = 0;
					y_centroids_array[Y_CENTROIDS_WORD_2 : 1+Y_CENTROIDS_WORD_1] = 0;
					x_centroids_array[X_CENTROIDS_WORD_3 : 1+X_CENTROIDS_WORD_2] = 0;
					y_centroids_array[Y_CENTROIDS_WORD_3 : 1+Y_CENTROIDS_WORD_2] = 0;
					x_centroids_array[X_CENTROIDS_WORD_4 : 1+X_CENTROIDS_WORD_3] = 0;
					y_centroids_array[Y_CENTROIDS_WORD_4 : 1+Y_CENTROIDS_WORD_3] = 0;
					x_centroids_array[X_CENTROIDS_WORD_5 : 1+X_CENTROIDS_WORD_4] = 0;
					y_centroids_array[Y_CENTROIDS_WORD_5 : 1+Y_CENTROIDS_WORD_4] = 0;
					tracking_output_holdoff = 1;
				end
				
				1:begin
					tracking_output_blob_sizes[BLOB_SIZE_WORD_0 : 0] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_1 : 1+BLOB_SIZE_WORD_0] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_2 : 1+BLOB_SIZE_WORD_1] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_3 : 1+BLOB_SIZE_WORD_2] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_4 : 1+BLOB_SIZE_WORD_3] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_5 : 1+BLOB_SIZE_WORD_4] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_6 : 1+BLOB_SIZE_WORD_5] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_7 : 1+BLOB_SIZE_WORD_6] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_8 : 1+BLOB_SIZE_WORD_7] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_9 : 1+BLOB_SIZE_WORD_8] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_10 : 1+BLOB_SIZE_WORD_9] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_11 : 1+BLOB_SIZE_WORD_10] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_12 : 1+BLOB_SIZE_WORD_11] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_13 : 1+BLOB_SIZE_WORD_12] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_14 : 1+BLOB_SIZE_WORD_13] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_15 : 1+BLOB_SIZE_WORD_14] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_16 : 1+BLOB_SIZE_WORD_15] = 0;
					tracking_output_blob_sizes[BLOB_SIZE_WORD_17 : 1+BLOB_SIZE_WORD_16] = 0;
					tracking_output_holdoff = 2;
				end
				
				2:begin
					tracking_output_blob_location[0] = 0;
					tracking_output_blob_location[1] = 0;
					tracking_output_blob_location[2] = 0;
					tracking_output_blob_location[3] = 0;
					tracking_output_blob_location[4] = 0;
					tracking_output_blob_location[5] = 0;
					tracking_output_blob_location[6] = 0;
					tracking_output_blob_location[7] = 0;
					tracking_output_blob_location[8] = 0;
					tracking_output_blob_location[9] = 0;
					tracking_output_blob_location[10] = 0;
					tracking_output_blob_location[11] = 0;
					tracking_output_blob_location[12] = 0;
					tracking_output_blob_location[13] = 0;
					tracking_output_blob_location[14] = 0;
					tracking_output_blob_location[15] = 0;
					tracking_output_blob_location[16] = 0;
					tracking_output_blob_location[17] = 0;
					tracking_output_holdoff = 3;
				end
				
				3:begin
					if (tracking_output_pointer <= (blob_extraction_blob_counter * 3)) begin
						// Cycle through the data points
						if (tracking_output_counter_tog == 5) begin			// Only run this once to preload data
							wren = 0;
							address = tracking_output_pointer + 200000;
						end
						
						if (tracking_output_counter_tog == 0) begin
							tracking_output_counter_color = data_read[7:0];
							if (tracking_output_counter_color == 0) begin		// If the blob we are looking at is NOT a recognized color
								tracking_output_pointer = tracking_output_pointer + 3;
								wren = 0;
								address = tracking_output_pointer + 200000;
								tracking_output_counter_tog = 2;		// Go again with the next blob!
							end else begin
								tracking_output_counter_color = tracking_output_counter_color - 1;		// The color data is stored offset by 1
								wren = 0;
								tracking_output_pointer = tracking_output_pointer + 1;
								address = tracking_output_pointer + 200000;
							end
						end
						
						if (tracking_output_counter_tog == 1) begin
							if (find_biggest == 1) begin
								tracking_output_counter_size = data_read[15:0];
							end
							
							if (find_highest == 1) begin
								tracking_output_counter_size = data_read[23:16];
								if (tracking_output_counter_size > 120) begin
									tracking_output_counter_size = 0;			// Ignore this; out of bounds!
								end
							end
							wren = 0;
							tracking_output_pointer = tracking_output_pointer + 2;
							address = tracking_output_pointer + 200000;
							if ((tracking_output_blob_sizes[tracking_output_counter_color] < tracking_output_counter_size) && (tracking_output_counter_size > minimum_blob_size)) begin
								tracking_output_blob_sizes[tracking_output_counter_color + 12] = tracking_output_blob_sizes[tracking_output_counter_color + 6];
								tracking_output_blob_location[tracking_output_counter_color + 12] = tracking_output_blob_location[tracking_output_counter_color + 6];
							
								tracking_output_blob_sizes[tracking_output_counter_color + 6] = tracking_output_blob_sizes[tracking_output_counter_color];
								tracking_output_blob_location[tracking_output_counter_color + 6] = tracking_output_blob_location[tracking_output_counter_color];
								
								tracking_output_blob_sizes[tracking_output_counter_color] = tracking_output_counter_size;
								tracking_output_blob_location[tracking_output_counter_color] = tracking_output_pointer;
							end else begin						
								if ((tracking_output_blob_sizes[tracking_output_counter_color + 6] < tracking_output_counter_size) && (tracking_output_counter_size > minimum_blob_size)) begin
									tracking_output_blob_sizes[tracking_output_counter_color + 12] = tracking_output_blob_sizes[tracking_output_counter_color + 6];
									tracking_output_blob_location[tracking_output_counter_color + 12] = tracking_output_blob_location[tracking_output_counter_color + 6];
									
									tracking_output_blob_sizes[tracking_output_counter_color + 6] = tracking_output_counter_size;
									tracking_output_blob_location[tracking_output_counter_color + 6] = tracking_output_pointer;
								end else begin
									if ((tracking_output_blob_sizes[tracking_output_counter_color + 12] < tracking_output_counter_size) && (tracking_output_counter_size > minimum_blob_size)) begin
										tracking_output_blob_sizes[tracking_output_counter_color + 12] = tracking_output_counter_size;
										tracking_output_blob_location[tracking_output_counter_color + 12] = tracking_output_pointer;
									end
								end
							end
						end
						
						tracking_output_counter_tog = tracking_output_counter_tog + 1;
						if (tracking_output_counter_tog > 1) begin
							tracking_output_counter_tog = 0;
						end
					end else begin
						// Write the zeroes to our selected blobs' sizes
						location_to_extract = ((tracking_output_counter_tog - 1) / 2);
						if ((slide_switches[1] == 1) && (slide_switches[0] == 1)) begin		// Enhanced mode!
							if (slide_switches[2] == 0) begin		// 2 color 6 centroids
								if (tracking_output_counter_tog == 3) begin
									location_to_extract = 6; 
								end
								if (tracking_output_counter_tog == 4) begin
									location_to_extract = 6; 
								end
								if (tracking_output_counter_tog == 5) begin
									location_to_extract = 12; 
								end
								if (tracking_output_counter_tog == 6) begin
									location_to_extract = 12; 
								end
								if (tracking_output_counter_tog == 9) begin
									location_to_extract = 7; 
								end
								if (tracking_output_counter_tog == 10) begin
									location_to_extract = 7; 
								end
								if (tracking_output_counter_tog == 11) begin
									location_to_extract = 13;
								end
								if (tracking_output_counter_tog == 12) begin
									location_to_extract = 13;
								end
							end
						end
						
						if (tracking_output_counter_tog == 1) begin		// Pick up where we left off above...						
							wren = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
						end
						
						if ((tracking_output_counter_tog == 2) && (tracking_output_blob_sizes[location_to_extract] != 0)) begin
							tracking_output_temp_data = data_read;
							x_centroids_array[X_CENTROIDS_WORD_0 : 0] = tracking_output_temp_data[31:24];
							y_centroids_array[Y_CENTROIDS_WORD_0 : 0] = tracking_output_temp_data[23:16];
							s_centroids_array[S_CENTROIDS_WORD_0 : 0] = tracking_output_temp_data[15:0];
							tracking_output_temp_data[15:0] = 0;
							address = tracking_output_blob_location[location_to_extract];
							data_write = tracking_output_temp_data;
							wren = 1;
						end
						
						if (tracking_output_counter_tog == 3) begin
							wren = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
						end
						
						if ((tracking_output_counter_tog == 4) && (tracking_output_blob_sizes[location_to_extract] != 0)) begin
							tracking_output_temp_data = data_read;
							x_centroids_array[X_CENTROIDS_WORD_1 : 1+X_CENTROIDS_WORD_0] = tracking_output_temp_data[31:24];
							y_centroids_array[Y_CENTROIDS_WORD_1 : 1+Y_CENTROIDS_WORD_0] = tracking_output_temp_data[23:16];
							s_centroids_array[S_CENTROIDS_WORD_1 : 1+S_CENTROIDS_WORD_0] = tracking_output_temp_data[15:0];
							tracking_output_temp_data[15:0] = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
							data_write = tracking_output_temp_data;
							wren = 1;
						end
						
						if (tracking_output_counter_tog == 5) begin
							wren = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
						end
						
						if ((tracking_output_counter_tog == 6) && (tracking_output_blob_sizes[location_to_extract] != 0)) begin
							tracking_output_temp_data = data_read;
							x_centroids_array[X_CENTROIDS_WORD_2 : 1+X_CENTROIDS_WORD_1] = tracking_output_temp_data[31:24];
							y_centroids_array[Y_CENTROIDS_WORD_2 : 1+Y_CENTROIDS_WORD_1] = tracking_output_temp_data[23:16];
							s_centroids_array[S_CENTROIDS_WORD_2 : 1+S_CENTROIDS_WORD_1] = tracking_output_temp_data[15:0];
							tracking_output_temp_data[15:0] = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
							data_write = tracking_output_temp_data;
							wren = 1;
						end
						
						if (tracking_output_counter_tog == 7) begin
							wren = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
						end
						
						if ((tracking_output_counter_tog == 8) && (tracking_output_blob_sizes[location_to_extract] != 0)) begin
							tracking_output_temp_data = data_read;
							x_centroids_array[X_CENTROIDS_WORD_3 : 1+X_CENTROIDS_WORD_2] = tracking_output_temp_data[31:24];
							y_centroids_array[Y_CENTROIDS_WORD_3 : 1+Y_CENTROIDS_WORD_2] = tracking_output_temp_data[23:16];
							s_centroids_array[S_CENTROIDS_WORD_3 : 1+S_CENTROIDS_WORD_2] = tracking_output_temp_data[15:0];
							tracking_output_temp_data[15:0] = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
							data_write = tracking_output_temp_data;
							wren = 1;
						end
						
						if (tracking_output_counter_tog == 9) begin
							wren = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
						end
						
						if ((tracking_output_counter_tog == 10) && (tracking_output_blob_sizes[location_to_extract] != 0)) begin
							tracking_output_temp_data = data_read;
							x_centroids_array[X_CENTROIDS_WORD_4 : 1+X_CENTROIDS_WORD_3] = tracking_output_temp_data[31:24];
							y_centroids_array[Y_CENTROIDS_WORD_4 : 1+Y_CENTROIDS_WORD_3] = tracking_output_temp_data[23:16];
							s_centroids_array[S_CENTROIDS_WORD_4 : 1+S_CENTROIDS_WORD_3] = tracking_output_temp_data[15:0];
							tracking_output_temp_data[15:0] = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
							data_write = tracking_output_temp_data;
							wren = 1;
						end
						
						if (tracking_output_counter_tog == 11) begin
							wren = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
						end
						
						if ((tracking_output_counter_tog == 12) && (tracking_output_blob_sizes[location_to_extract] != 0)) begin
							tracking_output_temp_data = data_read;
							x_centroids_array[X_CENTROIDS_WORD_5 : 1+X_CENTROIDS_WORD_4] = tracking_output_temp_data[31:24];
							y_centroids_array[Y_CENTROIDS_WORD_5 : 1+Y_CENTROIDS_WORD_4] = tracking_output_temp_data[23:16];
							s_centroids_array[S_CENTROIDS_WORD_5 : 1+S_CENTROIDS_WORD_4] = tracking_output_temp_data[15:0];
							tracking_output_temp_data[15:0] = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
							data_write = tracking_output_temp_data;
							wren = 1;
						end
						
						if (tracking_output_counter_tog == 13) begin
							wren = 0;
						end
						
						if (tracking_output_counter_tog > 13) begin
							// Done!
							tracking_output_done = 1;
							wren = 0;
						end else begin
							tracking_output_counter_tog = tracking_output_counter_tog + 1;
						end
					end
				end
				endcase
			end
			
			if (enable_tracking_output == 0) begin
				tracking_output_counter_tog = 0;
				tracking_output_holdoff = 0;
				tracking_output_done = 0;
				address = 18'b0;
				data_write = 32'b0;
				wren = 1'b0;
			end
		end	//end if pause == 0
	end

endmodule
