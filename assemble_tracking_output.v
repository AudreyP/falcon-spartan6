module tracking_output_assembly (
	//input wires
	input wire clk,
	input wire pause,
	input wire enable_tracking_output,	
	//output regs
	output reg wren,
	output reg [31:0] data_write,
	output reg [17:0] address,
	
	output reg [4:0] blob_pointer_addr,
	input wire [18:0] blob_pointer,
	input wire [4:0] number_of_valid_blobs,
	
	output reg tracking_output_done
	);
		
	initial tracking_output_done = 0;
	initial blob_pointer_addr = 0;
	
	// instantiate tracking_output memory
	reg [5:0] tracking_output_addr_a;
	reg [31:0] tracking_output_write;
 	wire [31:0] tracking_output_data_read_a;
	reg wren_tracking_output;
	
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
	reg [4:0] main_state;
	reg [4:0] get_blob_info;
	reg [4:0] store_blob_info;
	
	localparam
		GET_BLOB_INFO = 0,
		STORE_BLOB_INFO = 1;
		
	localparam
		RED = 0,
		ORANGE = 1,
		YELLOW = 2,
		GREEN = 3,
		BLUE = 4,
		PURPLE = 5;

	always @(posedge clk) begin
		if (pause == 0) begin
			if (enable_tracking_output == 1) begin
				if (blob_count < number_of_valid_blobs) begin
					// get tracking mode)
					case (slide_switches)
						1: tracking_mode = 1;
						2: tracking_mode = 2;
						3: tracking_mode = 3;
					endcase
					
					case (main_state) 
						GET_BLOB_INFO: begin
							if ((blob_pointer < 19'h7fff) &&  (blob_pointer_addr < 19)) begin
								//set blob rank
								if (blob_pointer < 6) begin
									 blob_rank = 1;
								end
								else if ((blob_pointer > 5) && (blob_pointer < 12)) begin
									blob_rank = 2;
								end else if (blob_pointer > 11) begin
									blob_rank = 3;
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
										blob_color = blob_data_word_one[7:0]
										//read second word
										blob_data_word_two = data_read;
										address = address + 1;
										get_blob_info = 3;
									end
									3: begin
										//read third word
										blob_data_word_three = data_read;
										get_blob_info = 0;
										// go to next blob pointer slot
										blob_pointer_addr = blob_pointer_addr + 1;
										if (tracking_mode = 1) begin
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
							end else begin
								// if this is reached, we have read all of the pointers in the pointer address memory.
								tracking_output_done = 1;
								main_state = 0;
								address = 18'b0;
								data_write = 32'b0;
								wren = 1'b0;
							end
							STORE_MODE_1_BLOB_INFO: begin
								// in mode one, only the rank 1 and rank 2 blobs are used.
								//sequence to store rank 1 blob info in memory according to mode 1 pattern
								
								// determine blob color
								blob_color = blob_data_word_one[7:0]
								
								case (store_blobs_mode1)
								//in mode one, only Red, Green, and Blue colors are used.
									0: begin
										// this is written regardless of blob rank.
										wren_tracking_output = 0;
										tracking_output_addr_a = 0;
										tracking_output_data_write = ASCII_MARKER_176;
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									1: begin
										// write pulse
										wren_tracking_output = 1;
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									3: begin
										// this is written regardless of blob rank.
										wren_tracking_output = 0;
										tracking_output_addr_a = tracking_output_addr_a + 1;
										tracking_output_data_write = PROTOCOL_VERSION_1;
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									4: begin
										// write pulse
										wren_tracking_output = 1;
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									5: begin
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
										end
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									6: begin
										wren_tracking_output = 1;	
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									7: begin
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
									8: begin
										wren_tracking_output = 1;	
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									9: begin
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
									10: begin
										wren_tracking_output = 1;	
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									11: begin
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
									12: begin
										wren_tracking_output = 1;	
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									13: begin
										wren_tracking_output = 0;
										tracking_output_addr_a = 26;
										tracking_output_data_write = ASCII_10;
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									14: begin
										wren_tracking_output = 1;	
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									15: begin
										wren_tracking_output = 0;
										tracking_output_addr_a = 27;
										tracking_output_data_write = ASCII_13;
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									16: begin
										wren_tracking_output = 1;
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									16: begin
										wren_tracking_output = 0;
										store_blobs_mode1 = 0;
										blob_count = blob_count + 1;
										main_state = GET_NEW_BLOB_INFO;
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
										// this is written regardless of blob rank.
										wren_tracking_output = 0;
										tracking_output_addr_a = 0;
										tracking_output_data_write = ASCII_MARKER_176;
										store_blobs_mode2 = store_blobs_mode2 + 1;
									end
									1: begin
										// write pulse
										wren_tracking_output = 1;
										store_blobs_mode2 = store_blobs_mode2 + 1;
									end
									3: begin
										// this is written regardless of blob rank.
										wren_tracking_output = 0;
										tracking_output_addr_a = tracking_output_addr_a + 1;
										tracking_output_data_write = PROTOCOL_VERSION_2;
										store_blobs_mode2 = store_blobs_mode2 + 1;
									end
									4: begin
										// write pulse
										wren_tracking_output = 1;
										store_blobs_mode2 = store_blobs_mode2 + 1;
									end
									5: begin
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
												YELLOw: begin
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
												YELLOw: begin
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
									6: begin
										wren_tracking_output = 1;	
										store_blobs_mode2 = store_blobs_mode2 + 1;
									end
									7: begin
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
									8: begin
										wren_tracking_output = 1;	
										store_blobs_mode2 = store_blobs_mode2 + 1;
									end
									9: begin
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
									10: begin
										wren_tracking_output = 1;	
										store_blobs_mode2 = store_blobs_mode2 + 1;
									end
									11: begin
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
									12: begin
										wren_tracking_output = 1;	
										store_blobs_mode2 = store_blobs_mode2 + 1;
									end
									13: begin
										wren_tracking_output = 0;
										tracking_output_addr_a = 50;
										tracking_output_data_write = ASCII_10;
										store_blobs_mode2 = store_blobs_mode2 + 1;
									end
									14: begin
										wren_tracking_output = 1;	
										store_blobs_mode2 = store_blobs_mode2 + 1;
									end
									15: begin
										wren_tracking_output = 0;
										tracking_output_addr_a = 51;
										tracking_output_data_write = ASCII_13;
										store_blobs_mode2 = store_blobs_mode2 + 1;
									16: begin
										wren_tracking_output = 1;
										store_blobs_mode2 = store_blobs_mode2 + 1;
									end 
									17: begin
										store_blobs_mode2 = 0;
										main_state = GET_NEW_BLOB_INFO;
									end
								endcase
							end
							// THIS MODULE IS CURRENTLY DISABLED
							/*STORE_MODE_3_BLOB_INFO: begin
								// in mode one, only the rank 1 and rank 2 blobs are used.
								//sequence to store rank 1 blob info in memory according to mode 1 pattern
								
								// determine blob color
								blob_color = blob_data_word_one[7:0]
								
								case (store_blobs_mode3)
								// Mode 3: Simultaneous tracking of 12 objects
								// 2 colors (red and blue)
								// 6 objects per color 
								
									0: begin
										// this is written regardless of blob rank.
										wren_tracking_output = 0;
										tracking_output_addr_a = 0;
										tracking_output_data_write = ASCII_MARKER_176;
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									1: begin
										// write pulse
										wren_tracking_output = 1;
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									3: begin
										// this is written regardless of blob rank.
										wren_tracking_output = 0;
										tracking_output_addr_a = tracking_output_addr_a + 1;
										tracking_output_data_write = PROTOCOL_VERSION_1;
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									4: begin
										// write pulse
										wren_tracking_output = 1;
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									5: begin
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
										end
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									6: begin
										wren_tracking_output = 1;	
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									7: begin
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
									8: begin
										wren_tracking_output = 1;	
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									9: begin
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
									10: begin
										wren_tracking_output = 1;	
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									11: begin
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
									12: begin
										wren_tracking_output = 1;	
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									13: begin
										wren_tracking_output = 0;
										tracking_output_addr_a = 26;
										tracking_output_data_write = ASCII_10;
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									14: begin
										wren_tracking_output = 1;	
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									15: begin
										wren_tracking_output = 0;
										tracking_output_addr_a = 27;
										tracking_output_data_write = ASCII_13;
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									16: begin
										wren_tracking_output = 1;
										store_blobs_mode1 = store_blobs_mode1 + 1;
									end
									16: begin
										wren_tracking_output = 0;
										store_blobs_mode1 = 0;
										blob_count = blob_count + 1;
										main_state = GET_NEW_BLOB_INFO;
									end
								endcase
							end */
					endcase //end main case statment
				end else begin // end if blob_count < ...
					tracking_output_done = 1;
					address = 18'b0;
					data_write = 32'b0;
					wren = 1'b0;
				end // end else
			end else begin
				tracking_output_done = 0;
				address = 18'b0;
				data_write = 32'b0;
				wren = 1'b0;
			end
		end // end if pause == 0
	end
endmodule


