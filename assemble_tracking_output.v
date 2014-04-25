module tracking_output_assembly (
	//input wires
	input wire clk,
	input wire clk_fast,
	input wire pause,
	input wire enable_tracking_output,	
	input wire [7:0] slide_switches,
	input wire [31:0] data_read,
	//output regs
	output reg wren,
	output reg [31:0] data_write,
	output reg [17:0] address,
	
	output reg [4:0] blob_pointer_addr,
	input wire [17:0] blob_pointer,
	input wire [4:0] number_of_valid_blobs,
	
	input wire [5:0] tracking_output_addr_b,
	output wire [7:0] tracking_output_data_read_b,
	
	output reg [6:0] number_of_bytes_to_transmit,
	output reg [5:0] tracking_display,
	
	output reg tracking_output_done
	);
		
	initial tracking_output_done = 0;
	initial blob_pointer_addr = 0;
	initial tracking_display = 0;
	
	// instantiate tracking_output memory
	reg [5:0] tracking_output_addr_a = 0;
	reg [7:0] tracking_output_data_write = 0;
 	wire [7:0] tracking_output_data_read_a;
	reg wren_tracking_output = 0;
	
	// written to here, read from in main. 
	tracking_output tracking_output (
		.clka(clk_fast), // input clka
		.wea(wren_tracking_output), // input [0 : 0] wea
		.addra(tracking_output_addr_a), // input [5 : 0] addra
		.dina(tracking_output_data_write), // input [7 : 0] dina 
		.douta(tracking_output_data_read_a), // output [7 : 0] douta
		//port b is unused.
		.clkb(clk_fast), // input clkbf
		.web(1'b0), // input [0 : 0] web
		.addrb(tracking_output_addr_b), // input [5 : 0] addrb
		.dinb(), // input [7 : 0] dinb (--NOT USED--)
		.doutb(tracking_output_data_read_b) // output [7 : 0] doutb
		);
	
	// state machine counters
	reg [4:0] main_state = 0;
	reg [2:0] tracking_output_initialization = 0;
	reg [4:0] markers_and_protocol = 0;
	reg [4:0] get_blob_info = 0;
	reg [4:0] store_blob_info = 0;
	reg [4:0] store_blobs_mode1 = 0;
	reg [4:0] store_blobs_mode2 = 0;
	
	reg [4:0] blobs_written = 0;
	reg [2:0] blob_rank = 0;
	reg [7:0] blob_color = 0;
	reg [2:0] tracking_mode = 0;
	
	reg [31:0] blob_data_word_one = 0;
	reg [31:0] blob_data_word_two = 0;
	reg [31:0] blob_data_word_three = 0;
	
	//main states
	localparam
		INITIALIZATION = 0,
		SET_MARKERS_AND_PROTOCOL = 1,
		GET_NEW_BLOB_INFO = 2,
		STORE_MODE_1_BLOB_INFO = 3,
		STORE_MODE_2_BLOB_INFO = 4,
		INC_ADDR = 5,
		DONE = 6;
		
	localparam
		RED = 0,
		ORANGE = 1,
		YELLOW = 2,
		GREEN = 3,
		BLUE = 4,
		PURPLE = 5;
		
	localparam
		ASCII_176 = 176,
		ASCII_10 = 10,
		ASCII_13 = 13,
		PROTOCOL_VERSION_1 = 1,
		PROTOCOL_VERSION_2 = 2,
		PROTOCOL_VERSION_3 = 3;	
		

	always @(posedge clk) begin
		if (pause == 0) begin
			if (enable_tracking_output == 1) begin
				if (blobs_written <= number_of_valid_blobs) begin
					// get tracking mode)
					case (slide_switches[1:0])
						2'b01: begin 
							tracking_mode = 1;
							number_of_bytes_to_transmit = 28;
						end
						2'b10: begin
							tracking_mode = 2;
							number_of_bytes_to_transmit = 52;
						end
						2'b11: begin 
							tracking_mode = 3;
							number_of_bytes_to_transmit = 52;
						end
					endcase
					
					case (main_state) 
						INITIALIZATION: begin
							tracking_display = 8'b0;
							//write zeros to the 0-5 slots in the tracking_output array
							case (tracking_output_initialization) 
								0: begin
									wren_tracking_output = 1'b0;
									tracking_output_addr_a = 0;
									tracking_output_data_write = 0;
									tracking_output_initialization = 1;
								end
								1: begin
									tracking_output_data_write = 0;
									wren_tracking_output = 1'b1;
									tracking_output_addr_a = tracking_output_addr_a + 1;
									tracking_output_initialization = 2;
								end
								2: begin
									wren_tracking_output = 1'b0;
									//reset addresses after words 0-51 written
									if (tracking_output_addr_a > 51) begin
										tracking_output_addr_a = 0;
										main_state = SET_MARKERS_AND_PROTOCOL;
										tracking_output_initialization = 0;
									end else begin
										tracking_output_initialization = 1; //bounce between states 1 and 2 (0 state is initial only)
									end
								end
							endcase
						end
						SET_MARKERS_AND_PROTOCOL: begin
							case (markers_and_protocol)
								0: begin
									// this is written regardless of blob rank.
									tracking_output_addr_a = 0;
									wren_tracking_output = 1;
									tracking_output_data_write = ASCII_176;
									markers_and_protocol = markers_and_protocol + 1;
								end
								1: begin
									// Wait for no reason whatsoever because I really like to WASTE TIME...hehehe...
									markers_and_protocol = markers_and_protocol + 1;
								end
								2: begin
									// this is written regardless of blob rank.
									tracking_output_addr_a = 1;
									wren_tracking_output = 1;
									case (tracking_mode)
										1: tracking_output_data_write = PROTOCOL_VERSION_1;
										2: tracking_output_data_write = PROTOCOL_VERSION_2;
										3: tracking_output_data_write = PROTOCOL_VERSION_3;
									endcase
									markers_and_protocol = markers_and_protocol + 1;
								end
								3: begin
									// Wait for no reason whatsoever because I really like to WASTE TIME...hehehe...
									markers_and_protocol = markers_and_protocol + 1;
								end
								4: begin
									// this is written regardless of blob rank.
									wren_tracking_output = 1;
									case (tracking_mode)
										1: tracking_output_addr_a = 26;
										2: tracking_output_addr_a = 50;
										3: tracking_output_addr_a = 50;
									endcase
									tracking_output_data_write = ASCII_10;
									markers_and_protocol = markers_and_protocol + 1;
								end
								5: begin
									// Wait for no reason whatsoever because I really like to WASTE TIME...hehehe...
									markers_and_protocol = markers_and_protocol + 1;
								end
								6: begin
									// this is written regardless of blob rank.
									wren_tracking_output = 1;
									case (tracking_mode)
										1: tracking_output_addr_a = 27;
										2: tracking_output_addr_a = 51;
										3: tracking_output_addr_a = 51;
									endcase
									tracking_output_data_write = ASCII_13;
									markers_and_protocol = markers_and_protocol + 1;
								end
								7: begin
									// Wait for no reason whatsoever because I really like to WASTE TIME...hehehe...
									markers_and_protocol = markers_and_protocol + 1;
								end
								8: begin
									// write pulse low
									wren_tracking_output = 0;
									markers_and_protocol = 0;
									tracking_output_addr_a = 0;
									main_state = GET_NEW_BLOB_INFO;
								end
							endcase
						end
						GET_NEW_BLOB_INFO: begin
							if ((blob_pointer >= 200000) && (blob_pointer < 524288)) begin // if blob is valid
								//set blob rank
								if (blob_pointer_addr < 6) begin
									 blob_rank = 1;
								end
								else if ((blob_pointer_addr > 5) && (blob_pointer < 12)) begin
									blob_rank = 2;
								end 
								else if (blob_pointer_addr > 11) begin
									blob_rank = 3;
								end
								
								if (tracking_mode == 1 && blob_rank >= 2) begin
									tracking_output_done = 1;
									main_state = DONE;
									address = 18'b0;
									data_write = 32'b0;
									wren = 1'b0;
									main_state = DONE;
								end
								else if (tracking_mode == 2 && blob_rank >= 3) begin
									tracking_output_done = 1;
									main_state = DONE;
									address = 18'b0;
									data_write = 32'b0;
									wren = 1'b0;
									main_state = DONE;
								end
								
								case (get_blob_info) 
									0: begin 
										//set main memory addr lines
										address = blob_pointer;
										get_blob_info = 1;
									end
									1: begin
										//read first word from main memory
										blob_data_word_one = data_read;
										address = address + 1;
										get_blob_info = 2;
									end
									2: begin
										// determine blob color
										blob_color = blob_data_word_one[7:0] - 1;
										//read second word
										blob_data_word_two = data_read;
										address = address + 1;
										get_blob_info = 3;
									end
									3: begin
										//set tracking display
										case (blob_color) 
											RED: tracking_display[0] = 1;
											ORANGE: tracking_display[1] = 1;
											YELLOW: tracking_display[2] = 1;
											GREEN: tracking_display[3] = 1;
											BLUE: tracking_display[4] = 1;
											PURPLE: tracking_display[5] = 1;
										endcase
										//read third word
										blob_data_word_three = data_read;
										get_blob_info = 0;
										if (tracking_mode == 1) begin
											main_state = STORE_MODE_1_BLOB_INFO;
										end
										else if (tracking_mode == 2) begin
											main_state = STORE_MODE_2_BLOB_INFO;
										end
										// CURRENTLY DISABLED
										/*else if (tracking_mode == 3) begin
											main_state = STORE_MODE_3_BLOB_INFO;
										end*/
									end
								endcase
							end else begin // if this is reached, there was no blob of interest at that address.
								main_state = INC_ADDR;
							end
						end
						STORE_MODE_1_BLOB_INFO: begin
							// in mode one, only the rank 1 and rank 2 blobs are used.
							//sequence to store rank 1 blob info in memory according to mode 1 pattern
							
							case (store_blobs_mode1)
							//in mode one, only Red, Green, and Blue colors are used.
								0: begin
									wren_tracking_output = 0;
									// set address and data lines according to blob rank and blob color.
									// the first data written for each blob is the x-centroid coordinate.
									if (blob_rank == 1) begin
										case (blob_color)
											RED: begin
												tracking_output_addr_a = 2;		
												tracking_output_data_write = blob_data_word_two[31:24]; //x centroid
											end
											GREEN: begin
												tracking_output_addr_a = 4;		
												tracking_output_data_write = blob_data_word_two[31:24]; //x centroid
											end
											BLUE: begin
												tracking_output_addr_a = 6;		
												tracking_output_data_write = blob_data_word_two[31:24]; //x centroid
											end
										endcase
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									else if (blob_rank == 2) begin
										case (blob_color)
											RED: begin
												tracking_output_addr_a = 8;		
												tracking_output_data_write = blob_data_word_two[31:24]; //x centroid
											end
											GREEN: begin
												tracking_output_addr_a = 10;		
												tracking_output_data_write = blob_data_word_two[31:24]; //x centroid
											end
											BLUE: begin
												tracking_output_addr_a = 12;		
												tracking_output_data_write = blob_data_word_two[31:24]; //x centroid
											end
										endcase
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
								end
								1: begin
									wren_tracking_output = 1;	
									store_blobs_mode1 = store_blobs_mode1 + 1;
								end
								2: begin
									wren_tracking_output = 0;
									// set address and data lines according to blob rank and blob color.
									// the second data written for each blob is the y-centroid coordinate.
									if (blob_rank == 1) begin
										case (blob_color)
											RED: begin
												tracking_output_addr_a = 3;		
												tracking_output_data_write = blob_data_word_two[23:16]; //y centroid
											end
											GREEN: begin
												tracking_output_addr_a = 5;		
												tracking_output_data_write = blob_data_word_two[23:16]; //y centroid
											end
											BLUE: begin
												tracking_output_addr_a = 7;		
												tracking_output_data_write = blob_data_word_two[23:16]; //y centroid
											end
										endcase
									end
									else if (blob_rank == 2) begin
										case (blob_color)
											RED: begin
												tracking_output_addr_a = 9;		
												tracking_output_data_write = blob_data_word_two[23:16]; //y centroid
											end
											GREEN: begin
												tracking_output_addr_a = 11;		
												tracking_output_data_write = blob_data_word_two[23:16]; //y centroid
											end
											BLUE: begin
												tracking_output_addr_a = 13;		
												tracking_output_data_write = blob_data_word_two[23:16]; //y centroid
											end
										endcase
									end
									store_blobs_mode1 = store_blobs_mode1 + 1;
								end
								3: begin
									wren_tracking_output = 1;	
									store_blobs_mode1 = store_blobs_mode1 + 1;
								end
								4: begin
									wren_tracking_output = 0;
									// set address and data lines according to blob rank and blob color.
									// the third data written for each blob is the upper 8 bits of the blob size.
									if (blob_rank == 1) begin
										case (blob_color)
											RED: begin
												tracking_output_addr_a = 14;		
												tracking_output_data_write = blob_data_word_two[15:8]; //upper size byte
											end
											GREEN: begin
												tracking_output_addr_a = 16;		
												tracking_output_data_write = blob_data_word_two[15:8]; 
											end
											BLUE: begin
												tracking_output_addr_a = 18;		
												tracking_output_data_write = blob_data_word_two[15:8]; 
											end
										endcase
									end
									else if (blob_rank == 2) begin
										case (blob_color)
											RED: begin
												tracking_output_addr_a = 20;		
												tracking_output_data_write = blob_data_word_two[15:8]; //upper size byte
											end
											GREEN: begin
												tracking_output_addr_a = 22;		
												tracking_output_data_write = blob_data_word_two[15:8];
											end
											BLUE: begin
												tracking_output_addr_a = 24;		
												tracking_output_data_write = blob_data_word_two[15:8];
											end
										endcase
									end
									store_blobs_mode1 = store_blobs_mode1 + 1;
								end
								5: begin
									wren_tracking_output = 1;	
									store_blobs_mode1 = store_blobs_mode1 + 1;
								end
								6: begin
									wren_tracking_output = 0;
									// set address and data lines according to blob rank and blob color.
									// the final data written for each blob is the lower 8 bits of the blob size.
									if (blob_rank == 1) begin
										case (blob_color)
											RED: begin
												tracking_output_addr_a = 15;		
												tracking_output_data_write = blob_data_word_two[7:0]; //lower size byte
											end
											GREEN: begin
												tracking_output_addr_a = 17;		
												tracking_output_data_write = blob_data_word_two[7:0];
											end
											BLUE: begin
												tracking_output_addr_a = 19;		
												tracking_output_data_write = blob_data_word_two[7:0];
											end
										endcase
									end
									else if (blob_rank == 2) begin
										case (blob_color)
											RED: begin
												tracking_output_addr_a = 21;
												tracking_output_data_write = blob_data_word_two[7:0]; //lower size byte
											end
											GREEN: begin
												tracking_output_addr_a = 23;		
												tracking_output_data_write = blob_data_word_two[7:0];
											end
											BLUE: begin
												tracking_output_addr_a = 25;		
												tracking_output_data_write = blob_data_word_two[7:0];
											end
										endcase
									end
									store_blobs_mode1 = store_blobs_mode1 + 1;
								end
								7: begin
									wren_tracking_output = 1;	
									store_blobs_mode1 = store_blobs_mode1 + 1;
								end
								8: begin
									wren_tracking_output = 0;
									store_blobs_mode1 = 0;
									blobs_written = blobs_written + 1;
									main_state = INC_ADDR;
								end
							endcase
						end 
						STORE_MODE_2_BLOB_INFO: begin
							// Mode 2: Simultaneous tracking of 12 objects
							// Six colors (R, O, Y, G, B, P)
							// Two objects (blobs ranked 1 and 2)
							// Reference FALCON user guide to see storing pattern
							case (store_blobs_mode2)
							//in mode one, only Red, Green, and Blue colors are used.
								0: begin
									wren_tracking_output = 0;
									// set address and data lines according to blob rank and blob color.
									// the first data written for each blob is the x-centroid coordinate.
									if (blob_rank == 1) begin
										case (blob_color)
											RED: begin
												tracking_output_addr_a = 2;		
												tracking_output_data_write = blob_data_word_two[31:24]; //x centroid
											end
											ORANGE: begin
												tracking_output_addr_a = 4;		
												tracking_output_data_write = blob_data_word_two[31:24]; 
											end
											YELLOW: begin
												tracking_output_addr_a = 6;		
												tracking_output_data_write = blob_data_word_two[31:24]; 
											end
											GREEN: begin
												tracking_output_addr_a = 8;		
												tracking_output_data_write = blob_data_word_two[31:24]; 
											end
											BLUE: begin
												tracking_output_addr_a = 10;		
												tracking_output_data_write = blob_data_word_two[31:24];
											end
											PURPLE: begin
												tracking_output_addr_a = 12;		
												tracking_output_data_write = blob_data_word_two[31:24];
											end
										endcase
									end
									else if (blob_rank == 2) begin
										case (blob_color)
											RED: begin
												tracking_output_addr_a = 14;		
												tracking_output_data_write = blob_data_word_two[31:24]; //x centroid
											end
											ORANGE: begin
												tracking_output_addr_a = 16;		
												tracking_output_data_write = blob_data_word_two[31:24]; 
											end
											YELLOW: begin
												tracking_output_addr_a = 18;		
												tracking_output_data_write = blob_data_word_two[31:24]; 
											end
											GREEN: begin
												tracking_output_addr_a = 20;		
												tracking_output_data_write = blob_data_word_two[31:24]; 
											end
											BLUE: begin
												tracking_output_addr_a = 22;		
												tracking_output_data_write = blob_data_word_two[31:24];
											end
											PURPLE: begin
												tracking_output_addr_a = 24;		
												tracking_output_data_write = blob_data_word_two[31:24];
											end
										endcase
									end
									store_blobs_mode2 = store_blobs_mode2 + 1;
								end
								1: begin
									wren_tracking_output = 1;	
									store_blobs_mode2 = store_blobs_mode2 + 1;
								end
								2: begin
									wren_tracking_output = 0;
									// set address and data lines according to blob rank and blob color.
									// the second data written for each blob is the y-centroid coordinate.
									if (blob_rank == 1) begin
										case (blob_color)
											RED: begin
												tracking_output_addr_a = 3;		
												tracking_output_data_write = blob_data_word_two[23:16]; //y centroid
											end
											ORANGE: begin
												tracking_output_addr_a = 5;		
												tracking_output_data_write = blob_data_word_two[23:16]; 
											end
											YELLOW: begin
												tracking_output_addr_a = 7;		
												tracking_output_data_write = blob_data_word_two[23:16]; 
											end
											GREEN: begin
												tracking_output_addr_a = 9;		
												tracking_output_data_write = blob_data_word_two[23:16]; 
											end
											BLUE: begin
												tracking_output_addr_a = 11;		
												tracking_output_data_write = blob_data_word_two[23:16]; 
											end
											PURPLE: begin
												tracking_output_addr_a = 13;		
												tracking_output_data_write = blob_data_word_two[23:16]; 
											end
										endcase
									end
									else if (blob_rank == 2) begin
										case (blob_color)
											RED: begin
												tracking_output_addr_a = 15;		
												tracking_output_data_write = blob_data_word_two[23:16]; //y centroid
											end
											ORANGE: begin
												tracking_output_addr_a = 17;		
												tracking_output_data_write = blob_data_word_two[23:16]; 
											end
											YELLOW: begin
												tracking_output_addr_a = 19;		
												tracking_output_data_write = blob_data_word_two[23:16]; 
											end
											GREEN: begin
												tracking_output_addr_a = 21;		
												tracking_output_data_write = blob_data_word_two[23:16]; 
											end
											BLUE: begin
												tracking_output_addr_a = 23;		
												tracking_output_data_write = blob_data_word_two[23:16]; 
											end
											PURPLE: begin
												tracking_output_addr_a = 25;		
												tracking_output_data_write = blob_data_word_two[23:16]; 
											end
										endcase
									end
									store_blobs_mode2 = store_blobs_mode2 + 1;
								end
								3: begin
									wren_tracking_output = 1;	
									store_blobs_mode2 = store_blobs_mode2 + 1;
								end
								4: begin
									wren_tracking_output = 0;
									// set address and data lines according to blob rank and blob color.
									// the third data written for each blob is the upper 8 bits of the blob size.
									if (blob_rank == 1) begin
										case (blob_color)
											RED: begin
												tracking_output_addr_a = 26;		
												tracking_output_data_write = blob_data_word_two[15:8]; //upper size byte
											end
											ORANGE: begin
												tracking_output_addr_a = 28;		
												tracking_output_data_write = blob_data_word_two[15:8]; 
											end
											YELLOW: begin
												tracking_output_addr_a = 30;		
												tracking_output_data_write = blob_data_word_two[15:8]; 
											end
											GREEN: begin
												tracking_output_addr_a = 32;		
												tracking_output_data_write = blob_data_word_two[15:8]; 
											end
											BLUE: begin
												tracking_output_addr_a = 34;		
												tracking_output_data_write = blob_data_word_two[15:8]; 
											end
											PURPLE: begin
												tracking_output_addr_a = 36;		
												tracking_output_data_write = blob_data_word_two[15:8]; 
											end
										endcase
									end
									else if (blob_rank == 2) begin
										case (blob_color)
											RED: begin
												tracking_output_addr_a = 38;		
												tracking_output_data_write = blob_data_word_two[15:8]; //upper size byte
											end
											ORANGE: begin
												tracking_output_addr_a = 40;		
												tracking_output_data_write = blob_data_word_two[15:8]; 
											end
											YELLOW: begin
												tracking_output_addr_a = 42;
												tracking_output_data_write = blob_data_word_two[15:8]; 
											end
											GREEN: begin
												tracking_output_addr_a = 44;
												tracking_output_data_write = blob_data_word_two[15:8]; 
											end
											BLUE: begin
												tracking_output_addr_a = 46;
												tracking_output_data_write = blob_data_word_two[15:8]; 
											end
											PURPLE: begin
												tracking_output_addr_a = 48;
												tracking_output_data_write = blob_data_word_two[15:8]; 
											end
										endcase
									end
									store_blobs_mode2 = store_blobs_mode2 + 1;
								end
								5: begin
									wren_tracking_output = 1;	
									store_blobs_mode2 = store_blobs_mode2 + 1;
								end
								6: begin
									wren_tracking_output = 0;
									// set address and data lines according to blob rank and blob color.
									// the final data written for each blob is the lower 8 bits of the blob size.
									if (blob_rank == 1) begin
										case (blob_color)
											RED: begin
												tracking_output_addr_a = 27;		
												tracking_output_data_write = blob_data_word_two[7:0]; //lower size byte
											end
											ORANGE: begin
												tracking_output_addr_a = 29;		
												tracking_output_data_write = blob_data_word_two[7:0]; 
											end
											YELLOW: begin
												tracking_output_addr_a = 31;		
												tracking_output_data_write = blob_data_word_two[7:0]; 
											end
											GREEN: begin
												tracking_output_addr_a = 33;		
												tracking_output_data_write = blob_data_word_two[7:0]; 
											end
											BLUE: begin
												tracking_output_addr_a = 35;		
												tracking_output_data_write = blob_data_word_two[7:0]; 
											end
											PURPLE: begin
												tracking_output_addr_a = 37;		
												tracking_output_data_write = blob_data_word_two[7:0]; 
											end
										endcase
									end
									else if (blob_rank == 2) begin
										case (blob_color)
											RED: begin
												tracking_output_addr_a = 39;		
												tracking_output_data_write = blob_data_word_two[7:0]; //lower size byte
											end
											ORANGE: begin
												tracking_output_addr_a = 41;		
												tracking_output_data_write = blob_data_word_two[7:0]; 
											end
											YELLOW: begin
												tracking_output_addr_a = 43;		
												tracking_output_data_write = blob_data_word_two[7:0]; 
											end
											GREEN: begin
												tracking_output_addr_a = 45;		
												tracking_output_data_write = blob_data_word_two[7:0]; 
											end
											BLUE: begin
												tracking_output_addr_a = 47;		
												tracking_output_data_write = blob_data_word_two[7:0]; 
											end
											PURPLE: begin
												tracking_output_addr_a = 49;		
												tracking_output_data_write = blob_data_word_two[7:0]; 
											end
										endcase
									end
									store_blobs_mode2 = store_blobs_mode2 + 1;
								end
								7: begin
									wren_tracking_output = 1;	
									store_blobs_mode2 = store_blobs_mode2 + 1;
								end
								8: begin
									store_blobs_mode2 = 0;
									blobs_written = blobs_written + 1;
									main_state = INC_ADDR;
								end
							endcase
						end
						INC_ADDR: begin
							// go to next blob pointer slot
							blob_pointer_addr = blob_pointer_addr + 1;
							if (blob_pointer_addr < 19) begin
								main_state = GET_NEW_BLOB_INFO;
							end else begin
								// if this is reached, we have read all of the pointers in the pointer address memory.
								tracking_output_done = 1;
								main_state = DONE;
								address = 18'b0;
								data_write = 32'b0;
								wren = 1'b0;
							end
						end
						DONE: begin
							main_state = DONE;
						end
							
						// THIS MODULE IS CURRENTLY DISABLED
						/*STORE_MODE_3_BLOB_INFO: begin
						end */
					endcase //end main case statment
				end else begin // end if blobs_written < number_of_valid_blobs
					tracking_output_done = 1;
					address = 18'b0;
					data_write = 32'b0;
					wren = 1'b0;
				end // end else
			end else begin // end if enable == 1, else (if enable == 0)
				tracking_output_done = 0;
				blobs_written = 0;
				blob_pointer_addr = 0;
				main_state = INITIALIZATION;
				address = 18'b0;
				data_write = 32'b0;
				wren = 1'b0;
			end
		end // end if pause == 0
	end // end always
endmodule


