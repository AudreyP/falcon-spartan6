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

module tracking_output(
	//input wires
	input wire crystal_clk_div_by_two,
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
	output reg [7:0] x_centroids_array,   //assigned here--only used in main.
	output reg [7:0] y_centroids_array,   //assigned here--only used in main.
	output reg [15:0] s_centroids_array,   //assigned here--only used in main.
	output reg [15:0] tracking_output_blob_sizes [17:0],	//assigned here--only used in main. 
	output reg tracking_output_done
	);
	
	//reg tracking_output_main_chunk_already_loaded = 0;   //UNUSED IN EITHER LOCATION!
	//reg [7:0] tracking_output_counter_buffer_blue;   //UNUSED IN EITHER LOCATION!

	reg [31:0] data_read_sync_tracking_output = 0;	//HERE ONLY
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
	//always @(posedge clk) begin
	//always @(posedge clk_div_by_two) begin
	always @(posedge crystal_clk_div_by_two) begin
		data_read_sync_tracking_output = data_read;
		
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
				x_centroids_array[0] = 0;
				y_centroids_array[0] = 0;
				x_centroids_array[1] = 0;
				y_centroids_array[1] = 0;
				x_centroids_array[2] = 0;
				y_centroids_array[2] = 0;
				x_centroids_array[3] = 0;
				y_centroids_array[3] = 0;
				x_centroids_array[4] = 0;
				y_centroids_array[4] = 0;
				x_centroids_array[5] = 0;
				y_centroids_array[5] = 0;
				tracking_output_holdoff = 1;
			end
			
			1:begin
				tracking_output_blob_sizes[0] = 0;
				tracking_output_blob_sizes[1] = 0;
				tracking_output_blob_sizes[2] = 0;
				tracking_output_blob_sizes[3] = 0;
				tracking_output_blob_sizes[4] = 0;
				tracking_output_blob_sizes[5] = 0;
				tracking_output_blob_sizes[6] = 0;
				tracking_output_blob_sizes[7] = 0;
				tracking_output_blob_sizes[8] = 0;
				tracking_output_blob_sizes[9] = 0;
				tracking_output_blob_sizes[10] = 0;
				tracking_output_blob_sizes[11] = 0;
				tracking_output_blob_sizes[12] = 0;
				tracking_output_blob_sizes[13] = 0;
				tracking_output_blob_sizes[14] = 0;
				tracking_output_blob_sizes[15] = 0;
				tracking_output_blob_sizes[16] = 0;
				tracking_output_blob_sizes[17] = 0;
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
						tracking_output_counter_color = data_read_sync_tracking_output[7:0];
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
							tracking_output_counter_size = data_read_sync_tracking_output[15:0];
						end
						
						if (find_highest == 1) begin
							tracking_output_counter_size = data_read_sync_tracking_output[23:16];
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
						tracking_output_temp_data = data_read_sync_tracking_output;
						x_centroids_array[0] = tracking_output_temp_data[31:24];
						y_centroids_array[0] = tracking_output_temp_data[23:16];
						s_centroids_array[0] = tracking_output_temp_data[15:0];
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
						tracking_output_temp_data = data_read_sync_tracking_output;
						x_centroids_array[1] = tracking_output_temp_data[31:24];
						y_centroids_array[1] = tracking_output_temp_data[23:16];
						s_centroids_array[1] = tracking_output_temp_data[15:0];
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
						tracking_output_temp_data = data_read_sync_tracking_output;
						x_centroids_array[2] = tracking_output_temp_data[31:24];
						y_centroids_array[2] = tracking_output_temp_data[23:16];
						s_centroids_array[2] = tracking_output_temp_data[15:0];
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
						tracking_output_temp_data = data_read_sync_tracking_output;
						x_centroids_array[3] = tracking_output_temp_data[31:24];
						y_centroids_array[3] = tracking_output_temp_data[23:16];
						s_centroids_array[3] = tracking_output_temp_data[15:0];
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
						tracking_output_temp_data = data_read_sync_tracking_output;
						x_centroids_array[4] = tracking_output_temp_data[31:24];
						y_centroids_array[4] = tracking_output_temp_data[23:16];
						s_centroids_array[4] = tracking_output_temp_data[15:0];
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
						tracking_output_temp_data = data_read_sync_tracking_output;
						x_centroids_array[5] = tracking_output_temp_data[31:24];
						y_centroids_array[5] = tracking_output_temp_data[23:16];
						s_centroids_array[5] = tracking_output_temp_data[15:0];
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
			address = 18'bz;
			data_write = 32'bz;
			wren = 1'bz;
		end
	end

endmodule
