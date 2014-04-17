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
	// centroids
	input wire [2:0] centroids_read_addr,
 	output wire [31:0] centroids_data_read,
 	//blob sizes
	input wire [4:0] blob_sizes_read_addr_b,
 	output wire [15:0] blob_sizes_data_read_b,
	output reg tracking_output_done
	);
		
	initial tracking_output_done = 0;
	
	//-----Instantiate block ram for x, y, s centroids
	// x centroids = [31:24] centroids
	// y centroids = [23:16] centroids
	// s centroids = [15:0] centroids
	reg [2:0] centroids_write_addr = 0;
	reg [31:0] centroids_data_write;
	reg wren_centroids;
	
	// written to here, read from in main. 
	centroids xys_centroids_array(
		.clka(clk), 	// input clka
		.wea(wren_centroids), // input [0 : 0] wea
		.addra(centroids_write_addr), // input [2 : 0] addra
		.dina(centroids_data_write), 	// input [31 : 0] dina
		.douta(), // output [31 : 0] douta (--NOT USED--)
		.clkb(clk),	 // input clkb
		.web(0), 	// input [0 : 0] web
		.addrb(centroids_read_addr), // input [2 : 0] addrb
		.dinb(),	 // input [31 : 0] dinb (--NOT USED--)
		.doutb(centroids_data_read) // output [31 : 0] doutb
		);	
	
	reg [4:0] blob_sizes_write_addr;
	reg [15:0] blob_sizes_data_write;
	reg [4:0] blob_sizes_read_addr_a;
 	wire [15:0] blob_sizes_data_read_a;
	reg wren_blob_sizes;
	
	// written to here, read from in main. 
	blob_sizes_ram blob_sizes_ram (
		.clka(clk), // input clka
		.wea(wren_blob_sizes), // input [0 : 0] wea
		.addra(blob_sizes_write_addr), // input [4 : 0] addra
		.dina(blob_sizes_data_write), // input [15 : 0] dina 
		.douta(blob_sizes_data_read_a), // output [15 : 0] douta
		.clkb(clk), // input clkbf
		.web(0), // input [0 : 0] web
		.addrb(blob_sizes_read_addr_b), // input [4 : 0] addrb
		.dinb(), // input [15 : 0] dinb (--NOT USED--)
		.doutb(blob_sizes_data_read_b) // output [15 : 0] doutb
		);
				
	reg [15:0] tracking_output_pointer_counter = 0;	// local
	reg [7:0] tracking_output_counter_color;	// local
	reg [15:0] tracking_output_counter_size;	// local
	
	reg tracking_output_ok_to_send_data = 0;	// local
	reg [15:0] tracking_output_pointer = 0;		// local
	
	reg [15:0] tracking_output_blob_location [17:0];  // local
	reg [31:0] tracking_output_temp_data;	// local
	reg [7:0] location_to_extract = 0;	// local
	reg [3:0] enable_tracking_output_verified = 0;	// local

	reg [5:0] tracking_output_counter_tog = 0;
	reg [5:0] tracking_output_counter_togg = 0;
	reg [5:0] tracking_output_counter_toggle = 0;
	reg [31:0] tracking_output_counter_temp = 0;
	
	reg [2:0] tracking_output_holdoff = 0;
	
	reg [4:0] centroid_array_state;
	reg [4:0] blob_sizes_state;
	reg [4:0] test_value_state;
	reg [4:0] test_value_state1;
	
	reg [8:0] blob_size_color_counter1;
	reg [8:0] blob_size_color_counter2;
	reg [8:0] blob_size_color_counter3;
	reg [8:0] blob_size_location_to_extract;
	
	reg [2:0] statecount1;
	reg [2:0] statecount2;
	reg [2:0] statecount3;
	reg [2:0] statecount4;
	reg [2:0] statecount5;
	reg [2:0] statecount6;
	
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
					//write zeros to the first 5 slots in the XY portion of centroid array
					case (centroid_array_state) 
						0: begin
							wren_centroids = 1'b0;
							centroids_write_addr = 0;
							centroid_array_state = centroid_array_state + 1;
						end
						1: begin
							centroids_data_write = 0;
							wren_centroids = 1'b1;
							centroids_write_addr = centroids_write_addr + 1;
							centroid_array_state = centroid_array_state + 1;
						end
						2: begin
							wren_centroids = 1'b0;
							//reset addresses after words 0-5 written
							if (centroids_write_addr > 5) begin
								centroids_write_addr = 0;
							end
							centroid_array_state = centroid_array_state - 1; //bounce between states 1 and 2 (0 state is initial only)
						end
					endcase
					
					
					tracking_output_holdoff = 1;
				end
				
				1:begin
					//write zeros to the 0-17 slots in the blob sizes array
					case (blob_sizes_state) 
						0: begin
							wren_blob_sizes = 1'b0;
							blob_sizes_write_addr = 0;
							blob_sizes_state = blob_sizes_state + 1;
						end
						1: begin
							blob_sizes_data_write = 0;
							wren_blob_sizes = 1'b1;
							blob_sizes_write_addr = blob_sizes_write_addr + 1;
							blob_sizes_state = blob_sizes_state + 1;
						end
						2: begin
							wren_blob_sizes = 1'b0;
							//reset addresses after words 0-17 written
							if (blob_sizes_write_addr > 18) begin
								blob_sizes_write_addr = 0;
							end
							blob_sizes_state = blob_sizes_state - 1; //bounce between states 1 and 2 (0 state is initial only)
						end
					endcase

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
							
							// read from ram into test condition values
							// ensure wren low (read) for duration of this case
							case(test_value_state) 
								0: begin
									wren_blob_sizes = 0;
									blob_sizes_read_addr_a = tracking_output_counter_color;
									test_value_state = test_value_state + 1;
								end
								1: begin
									blob_size_color_counter1 = blob_sizes_data_read_a;
									test_value_state = test_value_state + 1;
								end
								2: begin
									blob_sizes_read_addr_a = tracking_output_counter_color + 6;
									test_value_state = test_value_state + 1;
								end
								3: begin
									blob_size_color_counter2 = blob_sizes_data_read_a;
									test_value_state = test_value_state + 1;
								end
								4: begin
									blob_sizes_read_addr_a = tracking_output_counter_color + 12;
									test_value_state = test_value_state + 1;
								end
								5: begin
									blob_size_color_counter3 = blob_sizes_data_read_a;
									test_value_state = test_value_state + 1;
								end
								6: begin
									blob_sizes_read_addr_a = 0;
								end
							endcase
							 
							wren = 0;
							tracking_output_pointer = tracking_output_pointer + 2;
							address = tracking_output_pointer + 200000;
							if ((blob_size_color_counter1 < tracking_output_counter_size) && (tracking_output_counter_size > minimum_blob_size)) begin
								
								case(statecount1) 
									0: begin
										blob_sizes_write_addr   = tracking_output_counter_color + 12;
										statecount1 = statecount1 + 1;
									end
									1: begin
										blob_sizes_data_write = blob_size_color_counter2;
										wren_blob_sizes = 1;
										statecount1 = statecount1 + 1;
									end
									2: begin
										wren_blob_sizes = 0;
										blob_sizes_write_addr   = 0;
										statecount1 = 0;
									end
								endcase
								tracking_output_blob_location[tracking_output_counter_color + 12] = tracking_output_blob_location[tracking_output_counter_color + 6];
								
								case(statecount2) 
									0: begin
										blob_sizes_write_addr   = tracking_output_counter_color + 6;
										statecount2 = statecount2 + 1;
									end
									1: begin
										blob_sizes_data_write = blob_size_color_counter1;
										wren_blob_sizes = 1;
										statecount2 = statecount2 + 1;
									end
									2: begin
										wren_blob_sizes = 0;
										blob_sizes_write_addr   = 0;
										statecount2 = 0;
									end
								endcase
								tracking_output_blob_location[tracking_output_counter_color + 6] = tracking_output_blob_location[tracking_output_counter_color];
								
								case(statecount3) 
									0: begin
										blob_sizes_write_addr   = tracking_output_counter_color;
										statecount3 = statecount3 + 1;
									end
									1: begin
										blob_sizes_data_write = tracking_output_counter_size;
										wren_blob_sizes = 1;
										statecount3 = statecount3 + 1;
									end
									2: begin
										wren_blob_sizes = 0;
										blob_sizes_write_addr   = 0;
										statecount3 = 0;
									end
								endcase
								tracking_output_blob_location[tracking_output_counter_color] = tracking_output_pointer;
							end else begin						
								if ((blob_size_color_counter2 < tracking_output_counter_size) && (tracking_output_counter_size > minimum_blob_size)) begin
									
									case(statecount4) 
										0: begin
											blob_sizes_write_addr   = tracking_output_counter_color + 12;
											statecount4 = statecount4 + 1;
										end
										1: begin
											blob_sizes_data_write = blob_size_color_counter2;
											wren_blob_sizes = 1;
											statecount4 = statecount4 + 1;
										end
										2: begin
											wren_blob_sizes = 0;
											blob_sizes_write_addr   = 0;
											statecount4 = 0;
										end
									endcase
									tracking_output_blob_location[tracking_output_counter_color + 12] = tracking_output_blob_location[tracking_output_counter_color + 6];
									
									case(statecount5) 
										0: begin
											blob_sizes_write_addr   = tracking_output_counter_color + 6;
											statecount5 = statecount5 + 1;
										end
										1: begin
											blob_sizes_data_write = tracking_output_counter_size;
											wren_blob_sizes = 1;
											statecount5 = statecount5 + 1;
										end
										2: begin
											wren_blob_sizes = 0;
											blob_sizes_write_addr   = 0;
											statecount5 = 0;
										end
									endcase
									tracking_output_blob_location[tracking_output_counter_color + 6] = tracking_output_pointer;
								end else begin
									if ((blob_size_color_counter3 < tracking_output_counter_size) && (tracking_output_counter_size > minimum_blob_size)) begin
										
										case(statecount6) 
											0: begin
												blob_sizes_write_addr   = tracking_output_counter_color + 12;
												statecount6 = statecount6 + 1;
											end
											1: begin
												blob_sizes_data_write = tracking_output_counter_size;
												wren_blob_sizes = 1;
												statecount6 = statecount6 + 1;
											end
											2: begin
												wren_blob_sizes = 0;
												blob_sizes_write_addr   = 0;
												statecount6 = 0;
											end
										endcase
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
							centroids_write_addr = 0;
						end
						
						// get value of blob_size_location_to_extract
						case(test_value_state1) 
								0: begin
									blob_sizes_read_addr_a = location_to_extract;
									test_value_state1 = test_value_state1 + 1;
								end
								1: begin
									blob_size_location_to_extract = blob_sizes_read_addr_a;
									wren_blob_sizes = 1;
									test_value_state1 = test_value_state1 + 1;
								end
								3: begin
									wren_blob_sizes = 0;
									blob_sizes_read_addr_a = 0;
								end
							endcase
						
						if ((tracking_output_counter_tog == 2) && (blob_size_location_to_extract != 0)) begin
							tracking_output_temp_data = data_read;
							
							centroids_data_write[31:24] = tracking_output_temp_data[31:24]; // x data
							centroids_data_write[23:16] = tracking_output_temp_data[23:16]; // y data
							centroids_data_write[15:0] = tracking_output_temp_data[15:0];   // s data
							centroids_write_addr = centroids_write_addr + 1;
							wren_centroids = 1'b1;
							
							tracking_output_temp_data[15:0] = 0;
							address = tracking_output_blob_location[location_to_extract];
							data_write = tracking_output_temp_data;
							wren = 1;
						end
						
						if (tracking_output_counter_tog == 3) begin
							wren = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
						end
						
						if ((tracking_output_counter_tog == 4) && (blob_size_location_to_extract != 0)) begin
							tracking_output_temp_data = data_read;
							centroids_data_write[31:24] = tracking_output_temp_data[31:24]; // x data
							centroids_data_write[31:16] = tracking_output_temp_data[23:16]; // y data
							centroids_data_write[15:0] = tracking_output_temp_data[15:0];   // s data
							centroids_write_addr = centroids_write_addr + 1;
							wren_centroids = 1'b1;
							
							tracking_output_temp_data[15:0] = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
							data_write = tracking_output_temp_data;
							wren = 1;
						end
						
						if (tracking_output_counter_tog == 5) begin
							wren = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
						end
						
						if ((tracking_output_counter_tog == 6) && (blob_size_location_to_extract != 0)) begin
							tracking_output_temp_data = data_read;
							centroids_data_write[31:24] = tracking_output_temp_data[31:24]; // x data
							centroids_data_write[31:16] = tracking_output_temp_data[23:16]; // y data
							centroids_data_write[15:0] = tracking_output_temp_data[15:0];   // s data
							centroids_write_addr = centroids_write_addr + 1;
							wren_centroids = 1'b1;
							
							tracking_output_temp_data[15:0] = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
							data_write = tracking_output_temp_data;
							wren = 1;
						end
						
						if (tracking_output_counter_tog == 7) begin
							wren = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
						end
						
						if ((tracking_output_counter_tog == 8) && (blob_size_location_to_extract != 0)) begin
							tracking_output_temp_data = data_read;
							centroids_data_write[31:24] = tracking_output_temp_data[31:24]; // x data
							centroids_data_write[31:16] = tracking_output_temp_data[23:16]; // y data
							centroids_data_write[15:0] = tracking_output_temp_data[15:0];   // s data
							centroids_write_addr = centroids_write_addr + 1;
							wren_centroids = 1'b1;
							
							tracking_output_temp_data[15:0] = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
							data_write = tracking_output_temp_data;
							wren = 1;
						end
						
						if (tracking_output_counter_tog == 9) begin
							wren = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
						end
						
						if ((tracking_output_counter_tog == 10) && (blob_size_location_to_extract != 0)) begin
							tracking_output_temp_data = data_read;
							centroids_data_write[31:24] = tracking_output_temp_data[31:24]; // x data
							centroids_data_write[31:16] = tracking_output_temp_data[23:16]; // y data
							centroids_data_write[15:0] = tracking_output_temp_data[15:0];   // s data
							centroids_write_addr = centroids_write_addr + 1;
							wren_centroids = 1'b1;
							
							tracking_output_temp_data[15:0] = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
							data_write = tracking_output_temp_data;
							wren = 1;
						end
						
						if (tracking_output_counter_tog == 11) begin
							wren = 0;
							address = tracking_output_blob_location[location_to_extract] + 199998;
						end
						
						if ((tracking_output_counter_tog == 12) && (blob_size_location_to_extract != 0)) begin
							tracking_output_temp_data = data_read;
							centroids_data_write[31:24] = tracking_output_temp_data[31:24]; // x data
							centroids_data_write[31:16] = tracking_output_temp_data[23:16]; // y data
							centroids_data_write[15:0] = tracking_output_temp_data[15:0];   // s data
							centroids_write_addr = centroids_write_addr + 1;
							wren_centroids = 1'b1;
							
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
							wren_centroids = 1'b0;
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
