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

//DO NOT MOVE SERIAL OUTPUT OR MAIN STATE MACHINE

module main(
	input crystal_clk, 
	output LD0, 
	output LD1, 
	output LD2, 
	output LD3, 
	output LD4, 
	output LD5, 
	output LD6, 
	output LD7, 
	output TxD,

	output SEG0,
	output SEG1,
	output SEG2,
	output SEG3,
	output SEG4,
	output SEG5,
	output SEG6,
	output SEG7,

	output SCTL0,
	output SCTL1,
	output SCTL2,
	output SCTL3,

	input RxD,

	// ddr i/o
	output wire dram_ck,
	output wire dram_ck_n,
	output wire dram_cke,
	output wire dram_ras_n,
	output wire dram_cas_n,
	output wire dram_we_n,
	output wire dram_dm,
	output wire dram_udm,
	output wire dram_dqs,
	output wire dram_udqs,
	output wire [1:0] dram_ba,
	output wire [12:0] dram_a,
	output wire [15:0] dram_dq,
//	output wire c3_calib_done,
//	output wire c3_clk0,
//	output wire c3_rst0,
	inout rzq,

	input wire [7:0] slide_switches
	);

		wire c3_clk0;
		wire c3_rst0;
		wire c3_calib_done;
		
		wire main_system_clock;
		
		// '<=' is a nonblocking set operation (like '=') 

		parameter InternalClkFrequency = 6666666;	// 6.66MHz
		//parameter InternalClkFrequency = 50000000;	// 50MHz
		//parameter InternalClkFrequency = 66666666;	// 66MHz
		//parameter InternalClkFrequency = 70000000;	// 70MHz
		//parameter I2ClkCyclesToWait = (InternalClkFrequency / 100000);
		parameter I2ClkCyclesToWait = (InternalClkFrequency / 10000);
		//parameter I2ClkCyclesToWait = (InternalClkFrequency / 1000);
		//parameter I2ClkCyclesToWait = (InternalClkFrequency / 100);
		//parameter I2ClkCyclesToWait = (InternalClkFrequency / 1);


		wire clk;		
		wire prev_clk;
		assign prev_clk = clk;

		//reg border_drawing_holdoff = 0;	//Not used anywhere??
		
		reg serial_output_holdoff = 0;

		reg [23:0] cnt;
		reg [24:0] cnt2;
		reg [7:0] leds;		// Give myself an LED register
		wire [7:0] sseg;
		wire [3:0] cseg;
		reg [7:0] temp1;		// Temporary data storage

		

		wire wren;
		wire [17:0] address;
		wire [31:0] data_write;
		wire [31:0] data_read;
		reg [31:0] data_read_sync;

		reg [7:0] delay_loop = 0;

		wire [18:0] camera_data_address;
		
		reg processing_done = 1;

		reg processing_done_internal = 0;

		//--------------------------------------------------------------------------
		// Auxiliary clock generation
		//--------------------------------------------------------------------------
		reg clk_div_by_two = 0;

		assign clk = modified_clock;

		//always @(posedge modified_clock_two) begin
		always @(negedge modified_clock_two) begin
			modified_clock_two_div_by_two = !modified_clock_two_div_by_two;
		end
		
		always @(posedge clk) begin
			clk_div_by_two = !clk_div_by_two;
		end
		
		reg clk_div_by_four = 0;
		
		always @(posedge clk_div_by_two) begin
			clk_div_by_four = !clk_div_by_four;
		end

		//--------------------------------------------------------------------------
		// Module Instantiations
		//--------------------------------------------------------------------------
		
		wire [17:0] divider_dividend;	//was originally a reg. Is it ok to make it a wire?
		wire [17:0] divider_divisor;		//was originally a reg. Is it ok to make it a wire?
		wire [17:0] divider_quotient;
		wire [17:0] divider_remainder;
		wire divider_zeroflag;
		
		wire [17:0] divider_dividend_two;	//connects blob_extraction (where it is is set) to serial_divide_uu (where quotient is assigned the value of this as an input wire)
		wire [17:0] divider_divisor_two; //connects blob_extraction (where it is set) to serial_divide_uu (where div is assigned the value of this as an input wire)
		wire [17:0] divider_quotient_two;
		wire [17:0] divider_remainder_two;
		wire divider_zeroflag_two;
		
		//enable / dones
		reg enable_camera_capture = 0;
		wire camera_capture_done;

		reg enable_median_filtering = 0;
		reg median_filtering_done = 0;
		
		reg enable_edge_detection = 0;
		wire edge_detection_done ;
		
		reg enable_x_pixel_filling = 0;
		wire x_pixel_filling_done;
		
		reg enable_y_pixel_filling = 0;
		wire y_pixel_filling_done;
		
		reg enable_border_drawing = 0;
		reg border_drawing_done = 0;
		
		reg enable_blob_extraction = 0;
		wire blob_extraction_done;
		
		reg enable_tracking_output = 0;
		wire tracking_output_done;
		
		reg enable_serial_output = 0;
		reg serial_output_done = 0;
		
		wire global_pause;	//comes from ddr memory, goes to ALL modules


		//------------------7-segment display module
		reg [13:0] display_value = 0;
		reg show_decimal = 0;

		seven_segment_output seven_segment_output(
			.clk(clk_div_by_four),
			.display_value(display_value),
			.show_decimal(show_decimal),
			.sseg(sseg),
			.cseg(cseg)
			);
		
		//------------------Memory module
		wire [15:0] sram_debug0;

		mem_manager mem_manager(
			.modified_clock_sram(modified_clock_sram),
			.clk(clk),
			.crystal_clk(crystal_clk),
			.prev_clk(prev_clk),
			.pause(global_pause),
			.counter(mem_counter),
			.starting_address(address), 
			.wren(wren), 
			.data_write(data_write), 
			.data_read(data_read),
			// DDR SDRAM external signals
			.dram_dq(dram_dq),	// INOUT
			.dram_a(dram_a),  	// OUTPUT
			.dram_ba(dram_ba),	// OUTPUT
			.dram_ras_n(dram_ras_n),	// OUTPUT
			.dram_cas_n(dram_cas_n),	// OUTPUT
			.dram_we_n (dram_we_n), 	// OUTPUT
			.dram_cke(dram_cke), 		// OUTPUT
			.dram_ck(dram_ck), 		// OUTPUT
			.dram_ck_n (dram_ck_n),	// OUTPUT 
			.dram_dqs (dram_dqs),		// OUTPUT
			.dram_udqs(dram_udqs),    	// INOUT | for X16 parts
			.dram_udm(dram_udm),     	// OUTPUT | for X16 parts
			.dram_dm(dram_dm),		// OUTPUT
			.rzq(rzq),
			.debug0(sram_debug0),
			.main_system_clock(main_system_clock)
			);
				
		//------------------EDGE DETECTION module
		wire wren_edge_detection;
		wire [17:0] address_edge_detection;
		wire [31:0] data_out_edge_detection;
		
		reg [7:0] edge_detection_threshold_red = 30; 
		reg [7:0] edge_detection_threshold_green = 30;
		reg [7:0] edge_detection_threshold_blue = 0;
		
		edge_detection edge_detection(
			//input wires (as seen by module)
			.clk(clk_div_by_two),
			.pause(global_pause),
			.data_read(data_read),
			.enable_edge_detection(enable_edge_detection),
			.edge_detection_threshold_red(edge_detection_threshold_red),
			.edge_detection_threshold_green(edge_detection_threshold_green),
			.edge_detection_threshold_blue(edge_detection_threshold_blue),
			//ouput regs (as seen by module)
			.wren(wren_edge_detection),
			.data_write(data_write_edge_detection),
			.address(address_edge_detection),
			.edge_detection_done(edge_detection_done)
			);
		
		
		//------------------TRACKING OUTPUT module
		wire wren_tracking_output;
		wire [17:0] address_tracking_output;
		wire [31:0] data_out_tracking_output;
		
		reg find_highest = 0;
		reg find_biggest = 1;
		
		wire [15:0] blob_extraction_blob_counter;
		
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
				
		
		wire [63:0] x_centroids_array;
		wire [63:0] y_centroids_array;
		wire [127:0] s_centroids_array;
		
		reg [575:0] primary_color_slots;
		reg [7:0] color_similarity_threshold = 0;
		reg [7:0] minimum_blob_size = 0;
	
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
						
		wire [288:0] tracking_output_blob_sizes /*[17:0]*/;
	
		tracking_output tracking_output(
			//input wires (as seen by module)
			.clk(clk_div_by_two),
			.pause(global_pause),
			.blob_extraction_blob_counter(blob_extraction_blob_counter),
			.enable_tracking_output(enable_tracking_output),
			.find_biggest(find_biggest),
			.find_highest(find_highest),
			.minimum_blob_size(minimum_blob_size),	
			.slide_switches(slide_switches),		
			.data_read(data_read),		
			//output regs
			.wren(wren_tracking_output),
			.data_write(data_write_tracking_output),
			.address(address_tracking_output),
			.x_centroids_array(x_centroids_array),  
			.y_centroids_array(y_centroids_array),  
			.s_centroids_array(s_centroids_array),
			.tracking_output_blob_sizes(tracking_output_blob_sizes),	//[15:0] by [17:0]
			.tracking_output_done(tracking_output_done)
			);			
		
		// X PIXEL FILLING module
		wire wren_x_pixel_filling;
		wire [17:0] address_x_pixel_filling;
		wire [31:0] data_out_x_pixel_filling;
		
		x_pixel_filling x_pixel_filling(
			//input wires
			.clk_div_by_two(clk_div_by_two),
			.pause(global_pause),
			.enable_x_pixel_filling(enable_x_pixel_filling),
			.data_read(data_read),	
			//output regs
			.wren(wren_x_pixel_filling),
			.data_write(data_write_x_pixel_filling),
			.address(address_x_pixel_filling),
			.x_pixel_filling_done(x_pixel_filling_done)
			);
			
		//Y PIXEL FILLING module
		wire wren_y_pixel_filling;
		wire [17:0] address_y_pixel_filling;
		wire [31:0] data_out_y_pixel_filling;
		
		y_pixel_filling y_pixel_filling(
			//input wires
			.clk_div_by_two(clk_div_by_two),
			.pause(global_pause),
			.enable_y_pixel_filling(enable_y_pixel_filling),
			.data_read(data_read),
			//output regs
			.wren(wren_y_pixel_filling),
			.data_write(data_write_y_pixel_filling),
			.address(address_y_pixel_filling),
			.y_pixel_filling_done(y_pixel_filling_done)
			);
		
		// BLOB EXTRACTION module
		wire wren_blob_extraction;
		wire [17:0] address_blob_extraction;
		wire [31:0] data_out_blob_extraction;
		
		reg modified_clock_two_div_by_two = 0;
		
		wire [15:0] debug0, debug1;
		wire [4:0] debug2;
		wire [4:0] debug3;
		
		wire primary_color_slots_clka;
		assign primary_color_slots_clka = clk;
		
		blob_extraction blob_extraction(
			//input wires
			.modified_clock_two_div_by_two(modified_clock_two_div_by_two),
			.modified_clock_two(modified_clock_two),	//for stack ram
			.primary_color_slots_clka(primary_color_slots_clka),
			.pause(global_pause),
			.enable_blob_extraction(enable_blob_extraction),
			.data_read(data_read),
			.divider_quotient(divider_quotient),
			.divider_quotient_two(divider_quotient_two),
			.color_similarity_threshold(color_similarity_threshold),
			//.primary_color_slots(primary_color_slots),	//[23:0] by [5:0][3:0] ==> [575:0]
			//output regs
			.wren(wren_blob_extraction),
			.data_write(data_write_blob_extraction),
			.address(address_blob_extraction),
			.blob_extraction_done(blob_extraction_done),
			.divider_dividend(divider_dividend),
			.divider_divisor(divider_divisor),
			.divider_dividend_two(divider_dividend_two),
			.divider_divisor_two(divider_divisor_two),
			.wren_primary_color_slots(wren_primary_color_slots),
			.address_primary_color_slots(address_primary_color_slots),
			.data_write_primary_color_slots(data_write_primary_color_slots)
		/*	.debug0(debug0),
			.debug1(debug1),
			.debug2(debug2),
			.debug3(debug3)*/
			/*.stack_ram_douta(stack_ram_douta),
			.stack_ram_addra(stack_ram_addra),
			.stack_ram_wea(stack_ram_wea),
			.stack_ram_dina(stack_ram_dina)*/
			);
		
				 
		serial_divide_uu serial_divide_uu (.dividend(divider_dividend), .divisor(divider_divisor), .quotient(divider_quotient), .remainder(divider_remainder), .zeroflag(divider_zeroflag));

				 
		serial_divide_uu serial_divide_uu_two (.dividend(divider_dividend_two), .divisor(divider_divisor_two), .quotient(divider_quotient_two), .remainder(divider_remainder_two), .zeroflag(divider_zeroflag_two));

		

		always @(posedge clk) cnt<=cnt+1;

		always @(posedge clk) cnt2<=cnt2+1;


		reg [7:0] camera_toggle = 0;
		reg tx_toggle = 0;

		reg [18:0] camera_vertical_address;
		reg [18:0] camera_horizontal_address;
		reg [17:0] camera_memory_address = 76801;
		reg camera_vsync_detected;

		//wire [3:0] PWM_input = cnt2[24] ? cnt2[24:21] : ~cnt2[24:21];    // ramp the PWM input up and down
		//reg [4:0] PWM;

		wire RxD_data_ready;
		wire [7:0] RxD_data;
		wire RxD_endofpacket;
		wire RxD_idle;

		reg TxD_start;
		reg [7:0] TxD_data;
		wire TxD_busy;
		wire [4:0] TxD_state;
		
		reg [7:0] tempdata;
		
		reg [19:0] serial_output_index = 0;
		reg [19:0] serial_output_index_mem = 0;
		reg [19:0] serial_output_index_toggle = 0;
		reg serial_output_enabled = 0;

		reg [7:0] datatimer = 0;
		reg [15:0] databuffer;
		reg [31:0] databuffer_mem;


		reg [7:0] current_main_processing_state = STATE_INITIAL;

		reg [17:0] median_filtering_coun = 0;
		reg [17:0] median_filtering_counter_t = 0;
		reg [17:0] median_filtering_counter_to = 0;
		reg [17:0] median_filtering_counter_tog = 0;
		reg [17:0] median_filtering_counter_togg = 0;
		reg [17:0] median_filtering_counter_toggle = 0;
		reg [31:0] median_filtering_counter_temp = 0;
		
		reg [8:0] red_value = 0;
		reg [8:0] green_value = 0;
		reg [8:0] blue_value = 0;
				
		reg [5:0] border_drawing_counter_tog = 0;
		reg [17:0] border_drawing_counter_togg = 0;
		reg [17:0] border_drawing_counter_toggle = 0;
		reg [31:0] border_drawing_counter_temp = 0;	
				
		reg run_frame_dump = 0;
		reg run_single_shot_test = 0;
		reg run_online_recognition = 0;
		
		reg run_frame_dump_internal = 0;
		reg run_single_shot_test_internal = 0;
		reg run_online_recognition_internal = 0;
		
		assign SEG0 = sseg[0];	
		assign SEG1 = sseg[1];
		assign SEG2 = sseg[2];
		assign SEG3 = sseg[3];
		assign SEG4 = sseg[4];
		assign SEG5 = sseg[5];
		assign SEG6 = sseg[6];
		assign SEG7 = sseg[7];
		
		//always @(posedge clk) PWM <= PWM[3:0]+PWM_input;
		assign SCTL0 = cseg[0];
		assign SCTL1 = cseg[1];
		assign SCTL2 = cseg[2];
		assign SCTL3 = cseg[3];

		/*assign LD0 = (leds[0] & ~PWM[4]); // Assign the LEDs to their places in the register
		assign LD1 = (leds[1] & ~PWM[4]);
		assign LD2 = (leds[2] & ~PWM[4]);
		assign LD3 = (leds[3] & ~PWM[4]);
		assign LD4 = (leds[4] & ~PWM[4]);
		assign LD5 = (leds[5] & ~PWM[4]);
		assign LD6 = (leds[6] & ~PWM[4]);
		assign LD7 = (leds[7] & ~PWM[4]);*/
		
		assign LD0 = leds[0]; // Assign the LEDs to their places in the register
		assign LD1 = leds[1];
		assign LD2 = leds[2];
		assign LD3 = leds[3];
		assign LD4 = leds[4];
		assign LD5 = leds[5];
		assign LD6 = leds[6];
		assign LD7 = leds[7];
		
		reg enable_rgb = 0;
		reg enable_ycrcb = 1;
				
		wire modified_clock;
		
		wire dcm_locked, dcm_locked_two, dcm_locked_sram;
		
		//instantiate clock manager (2014 edit)
		clock_manager clock_manager(
			.input_clk(main_system_clock),
			.modified_clock(modified_clock),
			.modified_clock_two(modified_clock_two),
			.modified_clock_sram(modified_clock_sram),
			.dcm_locked(dcm_locked),
			.dcm_locked_two(dcm_locked_two),
			.dcm_locked_sram(dcm_locked_sram)
			);
	
		//instantiate color test pattern to replace camera feed during testing
		// 2014 edit
		wire wren_color_pattern;
		wire [17:0] address_color_pattern;
		wire [31:0] data_write_color_pattern;

		color_pattern camera_capture(
			.clk(clk),
			.reset(0),
			.enable(enable_camera_capture),
			.starting_address(0),
			.data_write(data_write_color_pattern),
			.addr(address_color_pattern),
			.wren(wren_color_pattern),
			.done(camera_capture_done));
		
		reg reset_system = 0;
		
		reg processing_started = 0;
		reg processing_ended = 0;
		
		reg [13:0] timer_value = 0;
		reg [13:0] display_value_timer = 0;
		reg [13:0] display_value_user = 0;
		reg timer_running = 0;
		reg [31:0] timer_divider = 0;
		
		reg processing_started_prior = 0;
		reg processing_ended_prior = 0;
		
		// Calculate the time it took to run an iteration of the algorithm
		//always @(posedge clk) begin
		always @(negedge clk) begin
			if ((processing_started_prior == 0) && (processing_started == 1)) begin
				timer_value = 0;
				timer_running = 1;
			end
			
			if (timer_running == 1) begin
				timer_divider = timer_divider + 1;
				//if (timer_divider > 50000) begin
				if (timer_divider > 66666) begin
				//if (timer_divider > 70000) begin
					timer_divider = 0;
					timer_value = timer_value + 1;
				end
			end
			
			if ((processing_ended_prior == 0) && (processing_ended == 1)) begin
				timer_running = 0;
				display_value_timer = timer_value;
			end

			if ((slide_switches[7:6] == 3) || (slide_switches[5] == 1)) begin
				show_decimal = 0;
			end else begin
				show_decimal = 1;
			end
			
			if (slide_switches[7] == 1) begin
				if (slide_switches[6] == 0) begin
					// Display the current version
					display_value = 1100;		// v1.100
					//display_value = current_main_processing_state;
				end else begin
					display_value = RxD_data;
				end
			end else begin
				display_value = display_value_timer;
			end
			
			if (slide_switches[5] == 1) begin
				display_value = display_value_user;
			end
			
			if (slide_switches[4] == 1) begin
				display_value = current_main_processing_state;
			end
			
			if (slide_switches[3] == 1) begin
				display_value = debug3;
			end
			
			if (slide_switches[2] == 1) begin
				display_value = debug2;
			end
			
			if (slide_switches[1] == 1) begin
				display_value = debug1;
			end
			
			if (slide_switches[0] == 1) begin
				display_value = debug0;
			end
			
			processing_started_prior = processing_started;
			processing_ended_prior = processing_ended;
		end
		
		reg [7:0] special_i2c_command_register = 0;
		reg [7:0] special_i2c_command_data = 0;
		reg send_special_i2c_command = 0;
		reg only_init_this_once = 0;

		//always @(posedge clk) begin
		//	datatimer = datatimer + 1;
		//	if (datatimer > 1) begin
		//		datatimer = 0;
		//	end
		//end
		
		
		
		reg thisiswhite = 0;
		reg pleasedelayhere = 0;
		
		reg [63:0] first_x_centroids_array;
		reg [63:0] first_y_centroids_array;
		reg [127:0] first_s_centroids_array;

		// Main data processor
		reg wren_single_shot;
		reg [17:0] address_single_shot;
		reg [31:0] data_write_single_shot;
		
		reg wren_frame_dump;
		reg [17:0] address_frame_dump;
		reg [31:0] data_write_frame_dump;

		//debugging statements
		//debug 0 is 15:0
		//debug1 is 15:0
		//debug2 is 3:0
		//debug3 is 4:0
		assign debug0[0] = wren;
		assign debug0[1] = wren_edge_detection;
		assign debug0[2] = wren_tracking_output;
		assign debug0[3] = wren_x_pixel_filling;
		assign debug0[4] = wren_y_pixel_filling;
		assign debug0[5] = wren_blob_extraction;
		assign debug0[6] = wren_color_pattern;
		assign debug0[7] = wren_frame_dump;
		assign debug0[8] = wren_single_shot;
		assign debug0[15:9] = 0;

		assign debug1[8:0] = sram_debug0;
		assign debug1[15:9] = mem_counter;

		assign debug2[0] = run_frame_dump_internal;
		assign debug2[1] = run_single_shot_test_internal;
		assign debug2[2] = 0;
		assign debug2[3] = processing_done_internal;
		assign debug2[4] = global_pause;

		assign debug3[0] = run_frame_dump;
		assign debug3[1] = run_single_shot_test;
		assign debug3[2] = dcm_locked;
		assign debug3[3] = dcm_locked_two;
		assign debug3[4] = dcm_locked_sram;


		assign address = address_edge_detection | address_tracking_output | address_x_pixel_filling 
								| address_y_pixel_filling | address_blob_extraction | address_color_pattern 
								| address_frame_dump | address_single_shot | address_primary_color_slots /*| address_median_filtering*/;
								
		assign wren = wren_edge_detection | wren_tracking_output | wren_x_pixel_filling | wren_y_pixel_filling 
								| wren_blob_extraction | wren_color_pattern | wren_frame_dump | wren_single_shot | wren_primary_color_slots 
								/*| wren_median_filtering*/;
								
		assign data_write = data_write_edge_detection | data_write_tracking_output | data_write_x_pixel_filling 
									| data_write_y_pixel_filling | data_write_blob_extraction | data_write_color_pattern 
									| data_write_frame_dump | data_write_single_shot | data_write_primary_color_slots /*| data_write_median_filtering*/;	

				
		localparam
		STATE_INITIAL = 0,
		STATE_CAMERA_CAPTURE =1,
		STATE_MEDIAN_FILTERING = 2,
		STATE_EDGE_DETECTION = 3,
		STATE_X_PIXEL_FILLING = 4,
		STATE_Y_PIXEL_FILLING = 5,
		STATE_BORDER_DRAWING = 6,
		STATE_BLOB_EXTRACTION = 7,
		STATE_TRACKING_OUTPUT = 8,
		STATE_ASSEMBLE_DATA = 9,
		STATE_TRACKING_OUTPUT_TWO = 10,
		STATE_DATA_OUTPUT_CTL = 11,
		STATE_FRAME_DUMP = 12,
		STATE_SINGLE_SHOT = 13,
		STATE_ONLINE_RECOGNITION = 14;
		always @(posedge clk_div_by_two) begin
			data_read_sync = data_read;

			//if ((processing_done_internal == 0)) begin
			//if (camera_transfer_done == 1) begin
					processing_done = 0;
					
					//leds[5:0] = current_main_processing_state + 1;
					
					if(current_main_processing_state == STATE_INITIAL) begin
						//camera controls -- these run once per loop
						run_frame_dump_internal = 0;
						run_single_shot_test_internal = 0;
						run_online_recognition_internal = 0;
						
						if (run_frame_dump == 1) begin
							run_frame_dump_internal = 1;
						end
						
						if (run_single_shot_test == 1) begin
							run_single_shot_test_internal = 1;
						end
						
						if (run_online_recognition == 1) begin
							run_online_recognition_internal = 1;
						end
						
						if ((run_frame_dump_internal == 1) || (run_single_shot_test_internal == 1) || (run_online_recognition_internal == 1)) begin
							current_main_processing_state = STATE_CAMERA_CAPTURE;
						end
					end
					
					if (current_main_processing_state == STATE_CAMERA_CAPTURE) begin
						//leds[5] = 1;
						enable_camera_capture = 1;
						if (camera_capture_done == 1) begin
							enable_camera_capture = 0;
							//current_main_processing_state = STATE_MEDIAN_FILTERING;
							current_main_processing_state = STATE_DATA_OUTPUT_CTL;	 // ****DEBUG ONLY**** (tpearson 03/09/14 01:41)
						end		
					end	
		
		
					if (current_main_processing_state == STATE_MEDIAN_FILTERING) begin
						//leds[5] = 1;
						//enable_median_filtering = 1;
						//if (median_filtering_done == 1) begin
						//	enable_median_filtering = 0;
							current_main_processing_state = STATE_EDGE_DETECTION;
						//end		
						
					end					
					
					if (current_main_processing_state == STATE_EDGE_DETECTION) begin
						//leds[5] = 1;
						enable_edge_detection = 1;
						if (edge_detection_done == 1) begin
							enable_edge_detection = 0;
							current_main_processing_state = STATE_X_PIXEL_FILLING;
						end
					end
					
					if (current_main_processing_state == STATE_X_PIXEL_FILLING) begin
						//leds[5] = 1;
						enable_x_pixel_filling = 1;
						if (x_pixel_filling_done == 1) begin
							enable_x_pixel_filling = 0;
							current_main_processing_state = STATE_Y_PIXEL_FILLING;
						end
					end
					
					if (current_main_processing_state == STATE_Y_PIXEL_FILLING) begin
						//leds[5] = 1;
						enable_y_pixel_filling = 1;
						if (y_pixel_filling_done == 1) begin
							enable_y_pixel_filling = 0;
							//SKIPS BORDER DRAWING STATE
							
							//DEBUG - SKIP BLOB EXTRACTION
							//current_main_processing_state = STATE_BLOB_EXTRACTION;
							current_main_processing_state = STATE_TRACKING_OUTPUT;
						end
					end		
					
					if (current_main_processing_state == STATE_BORDER_DRAWING) begin
						current_main_processing_state = STATE_BLOB_EXTRACTION;
					end
					
					/*if (current_main_processing_state == 4) begin
						//leds[5] = 1;
						enable_border_drawing = 1;
						if (border_drawing_done == 1) begin
							enable_border_drawing = 0;
							current_main_processing_state = 5;
						end
					end		*/
					
					if (current_main_processing_state == STATE_BLOB_EXTRACTION) begin
						//leds[5] = 1;
						enable_blob_extraction = 1;
						if (blob_extraction_done == 1) begin
							enable_blob_extraction = 0;
							current_main_processing_state = STATE_TRACKING_OUTPUT;
						end
					end
					
					if (current_main_processing_state == STATE_TRACKING_OUTPUT) begin
						//leds[5] = 1;
						enable_tracking_output = 1;
						if (tracking_output_done == 1) begin
							enable_tracking_output = 0;
							current_main_processing_state = STATE_ASSEMBLE_DATA;
						end
						
						leds[0] = 0;
						leds[1] = 0;
						leds[2] = 0;		
						leds[3] = 0;
						leds[4] = 0;
						leds[5] = 0;					
					end
					
					if (current_main_processing_state == STATE_ASSEMBLE_DATA) begin
						first_x_centroids_array[X_CENTROIDS_WORD_0 : 0] = x_centroids_array[X_CENTROIDS_WORD_0 : 0];		
						first_y_centroids_array[Y_CENTROIDS_WORD_0 : 0] = y_centroids_array[Y_CENTROIDS_WORD_0 : 0];
						first_s_centroids_array[S_CENTROIDS_WORD_0 : 0] = s_centroids_array[S_CENTROIDS_WORD_0 : 0];
						first_x_centroids_array[X_CENTROIDS_WORD_1 : 1+X_CENTROIDS_WORD_0] = x_centroids_array[X_CENTROIDS_WORD_1 : 1+X_CENTROIDS_WORD_0];
						first_y_centroids_array[Y_CENTROIDS_WORD_1 : 1+Y_CENTROIDS_WORD_0] = y_centroids_array[Y_CENTROIDS_WORD_1 : 1+Y_CENTROIDS_WORD_0];
						first_s_centroids_array[S_CENTROIDS_WORD_1 : 1+S_CENTROIDS_WORD_0] = s_centroids_array[S_CENTROIDS_WORD_1 : 1+S_CENTROIDS_WORD_0];
						first_x_centroids_array[X_CENTROIDS_WORD_2 : 1+X_CENTROIDS_WORD_1] = x_centroids_array[X_CENTROIDS_WORD_2 : 1+X_CENTROIDS_WORD_1];
						first_y_centroids_array[Y_CENTROIDS_WORD_2 : 1+Y_CENTROIDS_WORD_1] = y_centroids_array[Y_CENTROIDS_WORD_2 : 1+Y_CENTROIDS_WORD_1];
						first_s_centroids_array[S_CENTROIDS_WORD_2 : 1+S_CENTROIDS_WORD_1] = s_centroids_array[S_CENTROIDS_WORD_2 : 1+S_CENTROIDS_WORD_1];
						first_x_centroids_array[X_CENTROIDS_WORD_3 : 1+X_CENTROIDS_WORD_2] = x_centroids_array[X_CENTROIDS_WORD_3 : 1+X_CENTROIDS_WORD_2];
						first_y_centroids_array[Y_CENTROIDS_WORD_3 : 1+Y_CENTROIDS_WORD_2] = y_centroids_array[Y_CENTROIDS_WORD_3 : 1+Y_CENTROIDS_WORD_2];
						first_s_centroids_array[S_CENTROIDS_WORD_3 : 1+S_CENTROIDS_WORD_2] = s_centroids_array[S_CENTROIDS_WORD_3 : 1+S_CENTROIDS_WORD_2];
						first_x_centroids_array[X_CENTROIDS_WORD_4 : 1+X_CENTROIDS_WORD_3] = x_centroids_array[X_CENTROIDS_WORD_4 : 1+X_CENTROIDS_WORD_3];
						first_y_centroids_array[Y_CENTROIDS_WORD_4 : 1+Y_CENTROIDS_WORD_3] = y_centroids_array[Y_CENTROIDS_WORD_4 : 1+Y_CENTROIDS_WORD_3];
						first_s_centroids_array[S_CENTROIDS_WORD_4 : 1+S_CENTROIDS_WORD_3] = s_centroids_array[S_CENTROIDS_WORD_4 : 1+S_CENTROIDS_WORD_3];
						first_x_centroids_array[X_CENTROIDS_WORD_5 : 1+X_CENTROIDS_WORD_4] = x_centroids_array[X_CENTROIDS_WORD_5 : 1+X_CENTROIDS_WORD_4];
						first_y_centroids_array[Y_CENTROIDS_WORD_5 : 1+Y_CENTROIDS_WORD_4 ] = y_centroids_array[Y_CENTROIDS_WORD_5 : 1+Y_CENTROIDS_WORD_4];
						first_s_centroids_array[S_CENTROIDS_WORD_5 : 1+S_CENTROIDS_WORD_4] = s_centroids_array[S_CENTROIDS_WORD_5 : 1+S_CENTROIDS_WORD_4];
						
						if (tracking_output_blob_sizes[BLOB_SIZE_WORD_0 : 0] != 0) leds[0] = 1;
						if (tracking_output_blob_sizes[BLOB_SIZE_WORD_1 : 1+BLOB_SIZE_WORD_0] != 0) leds[1] = 1;
						if (tracking_output_blob_sizes[BLOB_SIZE_WORD_2 : 1+BLOB_SIZE_WORD_1] != 0) leds[2] = 1;
						if (tracking_output_blob_sizes[BLOB_SIZE_WORD_3 : 1+BLOB_SIZE_WORD_2] != 0) leds[3] = 1;
						if (tracking_output_blob_sizes[BLOB_SIZE_WORD_4: 1+BLOB_SIZE_WORD_3] != 0) leds[4] = 1;
						if (tracking_output_blob_sizes[BLOB_SIZE_WORD_5: 1+BLOB_SIZE_WORD_4] != 0) leds[5] = 1;
						
						if (tracking_output_done == 0) begin		// Wait for the module to reset before continuing
							current_main_processing_state = STATE_TRACKING_OUTPUT_TWO;
							pleasedelayhere = 1;
						end
					end
					
					if (current_main_processing_state == STATE_TRACKING_OUTPUT_TWO) begin
						if (pleasedelayhere == 0) begin
							//leds[5] = 1;
							enable_tracking_output = 1;
							if (tracking_output_done == 1) begin
								enable_tracking_output = 0;
								current_main_processing_state = STATE_DATA_OUTPUT_CTL;
							end
						end
						
						if (pleasedelayhere == 1) begin
							pleasedelayhere = 0;
						end
					end
					
					if (current_main_processing_state == STATE_DATA_OUTPUT_CTL) begin
						if (run_frame_dump_internal == 1) begin
							current_main_processing_state = STATE_FRAME_DUMP;
						end
							
						if (run_single_shot_test_internal == 1) begin
							current_main_processing_state = STATE_SINGLE_SHOT;
						end
							
						if (run_online_recognition_internal == 1) begin
							current_main_processing_state = STATE_ONLINE_RECOGNITION;
						end
							
						if ((run_frame_dump_internal == 0) && (run_single_shot_test_internal == 0) && (run_online_recognition_internal == 0)) begin
							// Run again!
							current_main_processing_state = STATE_INITIAL;
							
							// 2014 edit
							//these used to be set to Z
							/*address = 18'b0;
							data_write = 32'b0;
							wren = 1'b0;*/
														
							current_main_processing_state = STATE_INITIAL;
							processing_done_internal = 1;
							
							//processing_ended = 1;
						end
					end
		
					if (current_main_processing_state == STATE_FRAME_DUMP) begin
						leds[7] = 1;
						serial_output_enabled = 1;
						
						if (serial_output_holdoff == 0) begin
							serial_output_holdoff = 1;
							//address_frame_dump = 0;
							address_frame_dump = 76801;
							//address_frame_dump = 153602;
							//address_frame_dump = 230403;
							serial_output_index = 0;
							serial_output_index_toggle = 0;
							processing_ended = 1;
						end else begin
							if (serial_output_enabled == 1) begin
								// Transmit the entire contents of the image buffer to the serial port
								if (tx_toggle == 0) begin
									if (serial_output_index_toggle == 0) begin
										TxD_data = data_read_sync[31:24];
									end
									
									if (serial_output_index_toggle == 1) begin
										TxD_data = data_read_sync[15:8];
									end
									
									if (serial_output_index_toggle == 2) begin
										TxD_data = data_read_sync[7:0];
									end
									
									TxD_start = 1;
									tx_toggle = 1;
		
									serial_output_index_toggle = serial_output_index_toggle + 1;
									if (serial_output_index_toggle > 2) begin
										serial_output_index_toggle = 0;
										serial_output_index_mem = serial_output_index_mem + 1;
									end
									serial_output_index = serial_output_index + 1;
		
									wren_frame_dump = 0;				// Read data from RAM
									//address_frame_dump = serial_output_index_mem + 0;
									address_frame_dump = serial_output_index_mem + 76801;
									//address_frame_dump = serial_output_index_mem + 153602;
									//address_frame_dump = serial_output_index_mem + 230403;
								end else begin
									if (TxD_state == 5'b10000) begin	// Wait for transmission of byte to complete
										TxD_start = 0;
										tx_toggle = 0;
									end
								end
			
								//if (serial_output_index >= 307200) begin
								if (serial_output_index >= 230400) begin
								//if (serial_output_index >= 76800) begin
									if (TxD_state == 5'b10000) begin	// Wait for transmission of byte to complete
										processing_ended = 0;		// We only need to pulse this
										leds[7] = 0;
										TxD_start = 0;
										tx_toggle = 0;
										serial_output_holdoff = 0;
										serial_output_index = 0;
										serial_output_index_mem = 0;
										serial_output_index_toggle = 0;
										serial_output_enabled = 0;
										current_main_processing_state = STATE_INITIAL;
										
										// 2014 edit
										// used to be set to z
										address_frame_dump = 18'b0;
										data_write_frame_dump = 32'b0;
										wren_frame_dump = 1'b0;
										
										processing_done_internal = 1;
									end
								end
							end
						end
					end
					
					if (current_main_processing_state == STATE_SINGLE_SHOT) begin
						leds[7] = 1;
						serial_output_enabled = 1;
						
						if (serial_output_holdoff == 0) begin
							serial_output_holdoff = 1;
							address_single_shot = 0;
							//address = 76801;
							//address = 153602;
							//address = 230403;
							serial_output_index_toggle = 0;
							serial_output_index = 0;
							thisiswhite = 0;
							processing_ended = 1;
						end else begin
							if (serial_output_enabled == 1) begin
								// Transmit the entire contents of the image buffer to the serial port
								if (tx_toggle == 0) begin
									if (serial_output_index_toggle == 0) begin
										wren_single_shot = 0;
										address_single_shot = ((data_read_sync * 3) + 200000);
										//address = address + 76801;
										
										if (data_read_sync == 1) begin
											thisiswhite = 1;
										end else begin
											thisiswhite = 0;
										end
									end
									
									if (serial_output_index_toggle == 1) begin
										// Do nothing
										wren_single_shot = 0;
									end
									
									if (serial_output_index_toggle == 2) begin
										if (thisiswhite == 0) begin
											TxD_data = data_read_sync[15:8];
											//TxD_data = data_read_sync[7:0];
										end else begin
											TxD_data = 255;
										end
									end
									
									if (serial_output_index_toggle == 3) begin
										if (thisiswhite == 0) begin
											TxD_data = data_read_sync[23:16];
											//TxD_data = data_read_sync[7:0];
										end else begin
											TxD_data = 255;
										end
									end
									
									if (serial_output_index_toggle == 4) begin
										if (thisiswhite == 0) begin
											TxD_data = data_read_sync[31:24];
											//TxD_data = data_read_sync[7:0];
										end else begin
											TxD_data = 255;
										end
									end
									
									if (serial_output_index_toggle > 1) begin
										TxD_start = 1;
										tx_toggle = 1;
									end
		
									serial_output_index_toggle = serial_output_index_toggle + 1;
									if (serial_output_index_toggle > 4) begin
										serial_output_index_toggle = 0;
										serial_output_index = serial_output_index + 1;
										serial_output_index_mem = serial_output_index_mem + 1;
									end
		
									if (serial_output_index_toggle == 0) begin
										wren_single_shot = 0;				// Read data from RAM
										address_single_shot = serial_output_index_mem + 0;
										//address_single_shot = serial_output_index_mem + 76801;
										//address_single_shot = serial_output_index_mem + 153602;
										//address_single_shot = serial_output_index_mem + 230403;
									end
								end else begin
									if (TxD_state == 5'b10000) begin	// Wait for transmission of byte to complete
										TxD_start = 0;
										tx_toggle = 0;
									end
								end
			
								//if (serial_output_index >= 307200) begin
								if (serial_output_index >= 76800) begin
									if (TxD_state == 5'b10000) begin	// Wait for transmission of byte to complete
										processing_ended = 0;		// We only need to pulse this
										leds[7] = 0;
										TxD_start = 0;
										tx_toggle = 0;
										serial_output_holdoff = 0;
										serial_output_index = 0;
										serial_output_index_mem = 0;
										serial_output_index_toggle = 0;
										serial_output_enabled = 0;
										current_main_processing_state = STATE_INITIAL;
										// 2014 edit
										address_single_shot = 18'b0;
										data_write_single_shot = 32'b0;
										wren_single_shot = 1'b0;
										processing_done_internal = 1;
									end
								end
							end
						end
					end
					
					if (current_main_processing_state == STATE_ONLINE_RECOGNITION) begin
						leds[7] = 1;
						serial_output_enabled = 1;
						if (serial_output_holdoff == 0) begin
							serial_output_holdoff = 1;
							serial_output_index_toggle = 0;
							serial_output_index = 0;
							processing_ended = 1;
							serial_output_index = 0;
						end else begin
							if (serial_output_enabled == 1) begin
								processing_ended = 0;		// We only needed to pulse this
										
								// Transmit the entire contents of the image buffer to the serial port
								if (tx_toggle == 0) begin
									if (serial_output_index_toggle == 0) begin
										//if (slide_switches[0] == 0) begin		// Output mode is 'less data' (compatibility mode)
											TxD_data = 176;
										//end else begin
										//	TxD_data = 177;			// Signal 'more data' output mode
										//end
									end
									
									if (serial_output_index_toggle == 1) begin
										if ((slide_switches[0] == 0) && (slide_switches[1] == 0) && (slide_switches[2] == 0)) begin
											TxD_data = 1;
										end
										
										if ((slide_switches[0] == 1) && (slide_switches[1] == 1) && (slide_switches[2] == 1)) begin
											TxD_data = 2;
										end
										
										if ((slide_switches[0] == 1) && (slide_switches[1] == 1) && (slide_switches[2] == 0)) begin
											TxD_data = 3;
										end
										
										TxD_data = TxD_data | 32;
									end
											
									if (serial_output_index_toggle == 2) begin
										TxD_data = first_x_centroids_array[X_CENTROIDS_WORD_0 : 0];
									end
											
									if (serial_output_index_toggle == 3) begin
										TxD_data = first_y_centroids_array[Y_CENTROIDS_WORD_0 : 0];
									end
											
									if (slide_switches[0] == 1) begin
										if (serial_output_index_toggle == 4) begin
											TxD_data = first_x_centroids_array[X_CENTROIDS_WORD_1 : 1+X_CENTROIDS_WORD_0];
										end
											
										if (serial_output_index_toggle == 5) begin
											TxD_data = first_y_centroids_array[Y_CENTROIDS_WORD_1 : 1+Y_CENTROIDS_WORD_0];
										end
												
										if (serial_output_index_toggle == 6) begin
											TxD_data = first_x_centroids_array[X_CENTROIDS_WORD_2 : 1+X_CENTROIDS_WORD_1];
										end
											
										if (serial_output_index_toggle == 7) begin
											TxD_data = first_y_centroids_array[Y_CENTROIDS_WORD_2 : 1+Y_CENTROIDS_WORD_1];
										end
									end else begin
										if (serial_output_index_toggle == 4) begin
											serial_output_index_toggle = 8;
										end
									end
											
									if (serial_output_index_toggle == 8) begin
										TxD_data = first_x_centroids_array[X_CENTROIDS_WORD_3 : 1+X_CENTROIDS_WORD_2];
									end
											
									if (serial_output_index_toggle == 9) begin
										TxD_data = first_y_centroids_array[X_CENTROIDS_WORD_3 : 1+X_CENTROIDS_WORD_2];
									end
											
									if (serial_output_index_toggle == 10) begin
										TxD_data = first_x_centroids_array[X_CENTROIDS_WORD_4 : 1+X_CENTROIDS_WORD_3];
									end
									
									if (serial_output_index_toggle == 11) begin
										TxD_data = first_y_centroids_array[Y_CENTROIDS_WORD_4 : 1+Y_CENTROIDS_WORD_3];
									end
											
									if (slide_switches[0] == 1) begin
										if (serial_output_index_toggle == 12) begin
											TxD_data = first_x_centroids_array[5];
										end
										
										if (serial_output_index_toggle == 13) begin
											TxD_data = first_y_centroids_array[Y_CENTROIDS_WORD_5 : 1+Y_CENTROIDS_WORD_4];
										end
									end else begin
										if (serial_output_index_toggle == 12) begin
											serial_output_index_toggle = 14;
										end
									end
											
									// ---  Second set of centroids
											
									if (serial_output_index_toggle == 14) begin
										TxD_data = x_centroids_array[X_CENTROIDS_WORD_0 : 0];
									end
											
									if (serial_output_index_toggle == 15) begin
										TxD_data = y_centroids_array[Y_CENTROIDS_WORD_0 : 0];
									end
											
									if (slide_switches[0] == 1) begin
										if (serial_output_index_toggle == 16) begin
											TxD_data = x_centroids_array[X_CENTROIDS_WORD_1 : 1+X_CENTROIDS_WORD_0];
										end
												
										if (serial_output_index_toggle == 17) begin
											TxD_data = y_centroids_array[Y_CENTROIDS_WORD_1 : 1+Y_CENTROIDS_WORD_0];
										end
												
										if (serial_output_index_toggle == 18) begin
											TxD_data = x_centroids_array[X_CENTROIDS_WORD_2 : 1+X_CENTROIDS_WORD_1];
										end
												
										if (serial_output_index_toggle == 19) begin
											TxD_data = y_centroids_array[Y_CENTROIDS_WORD_2 : 1+Y_CENTROIDS_WORD_1];
										end
									end else begin
										if (serial_output_index_toggle == 16) begin
											serial_output_index_toggle = 20;
										end
									end
											
									if (serial_output_index_toggle == 20) begin
										TxD_data = x_centroids_array[X_CENTROIDS_WORD_3 : 1+X_CENTROIDS_WORD_2];
									end
											
									if (serial_output_index_toggle == 21) begin
										TxD_data = y_centroids_array[Y_CENTROIDS_WORD_3 : 1+Y_CENTROIDS_WORD_2];
									end
											
									if (serial_output_index_toggle == 22) begin
										TxD_data = x_centroids_array[X_CENTROIDS_WORD_4 : 1+X_CENTROIDS_WORD_3];
									end
											
									if (serial_output_index_toggle == 23) begin
										TxD_data = y_centroids_array[Y_CENTROIDS_WORD_4 : 1+Y_CENTROIDS_WORD_3];
									end
											
									if (slide_switches[0] == 1) begin
										if (serial_output_index_toggle == 24) begin
											TxD_data = x_centroids_array[X_CENTROIDS_WORD_5 : 1+X_CENTROIDS_WORD_4];
										end
												
										if (serial_output_index_toggle == 25) begin
											TxD_data = y_centroids_array[Y_CENTROIDS_WORD_5 : 1+Y_CENTROIDS_WORD_4];
										end
									end else begin
										if (serial_output_index_toggle == 24) begin
											serial_output_index_toggle = 26;
										end
									end
									
									// -- Now the size data
									// -- First ones
									
									if (serial_output_index_toggle == 26) begin
										TxD_data = first_s_centroids_array[S_CENTROIDS_WORD_0 : S_CENTROIDS_WORD_0 - 7];	//upper byte
									end
									
									if (serial_output_index_toggle == 27) begin
										TxD_data = first_s_centroids_array[S_CENTROIDS_WORD_0 - 8 : S_CENTROIDS_WORD_0 - 15];		//lower byte
									end
									
									if (serial_output_index_toggle == 28) begin
										TxD_data = first_s_centroids_array[S_CENTROIDS_WORD_1 : S_CENTROIDS_WORD_1 - 7];	//upper byte
									end
									
									if (serial_output_index_toggle == 29) begin
										TxD_data = first_s_centroids_array[S_CENTROIDS_WORD_1 - 8 : S_CENTROIDS_WORD_1 - 15];		//lower byte
									end
									
									if (serial_output_index_toggle == 30) begin
										TxD_data = first_s_centroids_array[S_CENTROIDS_WORD_2 : S_CENTROIDS_WORD_2 - 7];
									end
									
									if (serial_output_index_toggle == 31) begin
										TxD_data = first_s_centroids_array[S_CENTROIDS_WORD_2 - 8 : S_CENTROIDS_WORD_2 - 15];
									end
									
									if (serial_output_index_toggle == 32) begin
										TxD_data = first_s_centroids_array[S_CENTROIDS_WORD_3 : S_CENTROIDS_WORD_3 - 7];
									end
									
									if (serial_output_index_toggle == 33) begin
										TxD_data = first_s_centroids_array[S_CENTROIDS_WORD_3 - 8 : S_CENTROIDS_WORD_3 - 15];
									end
									
									if (serial_output_index_toggle == 34) begin
										TxD_data = first_s_centroids_array[S_CENTROIDS_WORD_4 : S_CENTROIDS_WORD_4 - 7];
									end
									
									if (serial_output_index_toggle == 35) begin
										TxD_data = first_s_centroids_array[S_CENTROIDS_WORD_4 - 8 : S_CENTROIDS_WORD_4 - 15];
									end
									
									if (serial_output_index_toggle == 36) begin
										TxD_data = first_s_centroids_array[S_CENTROIDS_WORD_5 : S_CENTROIDS_WORD_5 - 7];
									end
									
									if (serial_output_index_toggle == 37) begin
										TxD_data = first_s_centroids_array[S_CENTROIDS_WORD_5 - 8 : S_CENTROIDS_WORD_5 - 15];
									end
									
									// -- Last ones
									if (serial_output_index_toggle == 38) begin
										TxD_data = s_centroids_array[S_CENTROIDS_WORD_0 : S_CENTROIDS_WORD_0 - 7];
									end
									
									if (serial_output_index_toggle == 39) begin
										TxD_data = s_centroids_array[S_CENTROIDS_WORD_0 - 8 : S_CENTROIDS_WORD_0 - 15];
									end
									
									if (serial_output_index_toggle == 40) begin
										TxD_data = s_centroids_array[S_CENTROIDS_WORD_1 : S_CENTROIDS_WORD_1 - 7];
									end
									
									if (serial_output_index_toggle == 41) begin
										TxD_data = s_centroids_array[S_CENTROIDS_WORD_1 - 8 : S_CENTROIDS_WORD_1 - 15];
									end
									
									if (serial_output_index_toggle == 42) begin
										TxD_data = s_centroids_array[S_CENTROIDS_WORD_2 : S_CENTROIDS_WORD_2 - 7];
									end
									
									if (serial_output_index_toggle == 43) begin
										TxD_data = s_centroids_array[S_CENTROIDS_WORD_2 - 8 : S_CENTROIDS_WORD_2 - 15];
									end
									
									if (serial_output_index_toggle == 44) begin
										TxD_data = s_centroids_array[S_CENTROIDS_WORD_3 : S_CENTROIDS_WORD_3 - 7];
									end
									
									if (serial_output_index_toggle == 45) begin
										TxD_data = s_centroids_array[S_CENTROIDS_WORD_3 - 8 : S_CENTROIDS_WORD_3 - 15];
									end
									
									if (serial_output_index_toggle == 46) begin
										TxD_data = s_centroids_array[S_CENTROIDS_WORD_4 : S_CENTROIDS_WORD_4 - 7];
									end
									
									if (serial_output_index_toggle == 47) begin
										TxD_data = s_centroids_array[S_CENTROIDS_WORD_4 - 8 : S_CENTROIDS_WORD_4 - 15];
									end
									
									if (serial_output_index_toggle == 48) begin
										TxD_data = s_centroids_array[S_CENTROIDS_WORD_5 : S_CENTROIDS_WORD_5 - 7];
									end
									
									if (serial_output_index_toggle == 49) begin
										TxD_data = s_centroids_array[S_CENTROIDS_WORD_5 - 8 : S_CENTROIDS_WORD_5 - 15];
									end
									
									// -- Done!
											
									if (serial_output_index_toggle != 50) begin
										TxD_start = 1;
										tx_toggle = 1;
									end
			
									serial_output_index_toggle = serial_output_index_toggle + 1;
									//leds[5:1] = serial_output_index_toggle;
								end else begin
									if (TxD_state == 5'b10000) begin	// Wait for transmission of byte to complete
										TxD_start = 0;
										tx_toggle = 0;
									end
								end
					
								if (serial_output_index_toggle > 49) begin
									if (TxD_start == 0) begin	// Wait for transmission of byte to complete
										TxD_start = 0;
										tx_toggle = 0;
										serial_output_holdoff = 0;
										//serial_output_index = 0;
										//serial_output_index_mem = 0;
										//serial_output_index_toggle = 0;
										serial_output_enabled = 0;
										serial_output_index_toggle = 0;
										//leds[5:1] = 0;
										leds[7] = 0;
			
										/*address = 18'bz;
										data_write = 32'bz;
										wren = 1'bz;*/
										current_main_processing_state = STATE_INITIAL;
										processing_done_internal = 1;
										
										processing_ended = 0;
									end
								end
							end
						end
					end
			//end else begin
			//	if (processing_done_internal == 1) begin
			//		processing_done = 0;				
			//	end	//end else
			//end	//end if(processing_done_internal == 0)
		end	//end of always 

		//for the primary_color_slots array
		localparam [5:0] PRIMARY_COLOR_SLOTS_WORD_SIZE = 24; 
		
		localparam [3:0] 	ARRAY_SPEC_1_MAX = 5, 	//don't actually know whether it's 5 or 3, just picked one.
					ARRAY_SPEC_2_MAX = 3;	//fortunately, in the formula where it's used, it doesn't matter 		


		async_transmit #(.ClkFrequency(InternalClkFrequency/2)) asyncTX(.clk(clk_div_by_two), .TxD_start(TxD_start), .TxD_data(TxD_data), .TxD(TxD), .TxD_busy(TxD_busy), .state(TxD_state));
		async_receiver #(.ClkFrequency(InternalClkFrequency/2)) asyncRX(.clk(clk_div_by_two), .RxD(RxD), .RxD_data_ready(RxD_data_ready), .RxD_data(RxD_data), .RxD_endofpacket(RxD_endofpacket), .RxD_idle(RxD_idle));

		reg [7:0] serial_receiver_timer = 21;
		reg serial_character_received = 0;
		reg [7:0] serial_receiver_toggler = 0;
		reg [7:0] serial_command_buffer = 0;
		reg [2:0] next_byte_is_command = 0;
		reg [7:0] next_byte_is_command_pev_command = 0;
		reg [15:0] special_i2c_command_timer = 0;
		
		reg [5:0] array_spec_1;
		reg [5:0] array_spec_2;
		reg [575:0] one_dim_array_spec;
							
		
		// Receive serial commands
		always @(posedge clk_div_by_two) begin
			if (serial_receiver_timer > 40) begin
				run_frame_dump = 0;				// These must only be pulsed, NOT stuck on!
				run_single_shot_test = 0;
				reset_system = 0;
			end else begin
				serial_receiver_timer = serial_receiver_timer + 1;
			end
			
			if (special_i2c_command_timer == 0) begin
				send_special_i2c_command = 0;
			end else begin
				send_special_i2c_command = 1;
				special_i2c_command_timer = special_i2c_command_timer - 1;
			end
			
			if (RxD_data_ready == 1) begin
				if (serial_character_received == 0) begin
					// Parse the command and see what it is
					serial_character_received = 1;
					//leds[5:1] = RxD_data;
					if (RxD_data == 13) begin
						// Carriage Return!  The serial_command_buffer holds the command!  Parse it!
						if (current_main_processing_state < STATE_DATA_OUTPUT_CTL) begin
							if (next_byte_is_command == 0) begin
								if (serial_command_buffer == 67) begin
									// Frame dump requested
									run_frame_dump = 1;
									serial_receiver_timer = 0;
								end
								
								if (serial_command_buffer == 48) begin
									// Single shot test requested
									run_single_shot_test = 1;
									serial_receiver_timer = 0;
								end
								
								if (serial_command_buffer == 52) begin
									// Online recognition requested
									run_online_recognition = 1;
									serial_receiver_timer = 0;
								end
								
								if (serial_command_buffer == 53) begin
									// Online recognition HALT requested
									run_online_recognition = 0;
									serial_receiver_timer = 0;
								end
								
								if (serial_command_buffer == 74) begin		// Enable RGB mode
									enable_rgb = 1;
									enable_ycrcb = 0;
									reset_system = 1;
									serial_receiver_timer = 0;
								end
								
								if (serial_command_buffer == 75) begin		// Enable YCrCb mode
									enable_rgb = 0;
									enable_ycrcb = 1;
									reset_system = 1;
									serial_receiver_timer = 0;
								end
								
								if (serial_command_buffer == 88) begin		// Enable 'find biggest' mode
									find_highest = 0;
									find_biggest = 1;
								end
								
								if (serial_command_buffer == 87) begin		// Enable 'find highest' mode
									find_highest = 1;
									find_biggest = 0;
								end
								
								if (serial_command_buffer == 89) begin	
									next_byte_is_command = 1;
									next_byte_is_command_pev_command = 89;
								end
								
								if (serial_command_buffer == 65) begin	
									next_byte_is_command = 1;
									next_byte_is_command_pev_command = 65;
								end
								
								if (serial_command_buffer == 73) begin	
									next_byte_is_command = 1;
									next_byte_is_command_pev_command = 73;
								end
								
								if (serial_command_buffer == 66) begin	
									next_byte_is_command = 1;
									next_byte_is_command_pev_command = 66;
								end
								
								if (serial_command_buffer == 78) begin	
									next_byte_is_command = 1;
									next_byte_is_command_pev_command = 78;
								end
								
								if (serial_command_buffer == 72) begin	
									next_byte_is_command = 1;
									next_byte_is_command_pev_command = 72;
								end
								
								if (serial_command_buffer == 59) begin	
									next_byte_is_command = 1;
									next_byte_is_command_pev_command = 59;
								end
								
								// Color slot modify requests
								if ((serial_command_buffer > 90) && (serial_command_buffer < 140)) begin	
									next_byte_is_command = 1;
									next_byte_is_command_pev_command = serial_command_buffer;
									
									array_spec_1 = ((next_byte_is_command_pev_command / 8) - 11);
									array_spec_2 = (next_byte_is_command_pev_command[2:0] - 3);	
																	
									one_dim_array_spec = (PRIMARY_COLOR_SLOTS_WORD_SIZE*(ARRAY_SPEC_1_MAX*array_spec_2 + array_spec_1 + array_spec_2 +1)) - 1;
									//converts primary_color_slots[array_spec_1][array_spec_2] to
									//primary_color_slots[one_dim_array_spec -: 8]
									
									//----WRONGOOO
									// array_spec_3 = (array_spec_1+1)*(array_spec_2+1) - 1;
									//equive to array_spec_3:
									//  ((next_byte_is_command_pev_command / 8) - 10)*(next_byte_is_command_pev_command[2:0] - 2) - 1
									
									
									
								end
							end else begin							
								if (next_byte_is_command == 3) begin
									if ((next_byte_is_command_pev_command > 90) && (next_byte_is_command_pev_command < 140)) begin
										// Blue
										primary_color_slots[one_dim_array_spec -: 8] 
																	= serial_command_buffer;		//old syntax: [array_spec_1][array_spec_2][23:16]
										next_byte_is_command = 0;
									end
								end
								
								if (next_byte_is_command == 2) begin
									// Color slot modify requests
									if ((next_byte_is_command_pev_command > 90) && (next_byte_is_command_pev_command < 140)) begin
										// Green
										primary_color_slots[(one_dim_array_spec - 8) -: 8] 
																= serial_command_buffer;	// old syntax: [array_spec_1][array_spec_2][15:8]
										next_byte_is_command = 3;
									end
									
									if (next_byte_is_command_pev_command == 89) begin
										display_value_user[13:8] = serial_command_buffer;
										next_byte_is_command = 0;
									end
									
									if (next_byte_is_command_pev_command == 59) begin
										special_i2c_command_data = serial_command_buffer;
										special_i2c_command_timer = 65535;
										next_byte_is_command = 0;
									end
								end
								
								if (next_byte_is_command == 1) begin
									// The previous byte was the command--now load in the number!
									if (next_byte_is_command_pev_command == 65) begin
										edge_detection_threshold_red = serial_command_buffer;
										next_byte_is_command = 0;
									end
									
									if (next_byte_is_command_pev_command == 73) begin
										edge_detection_threshold_green = serial_command_buffer;
										next_byte_is_command = 0;
									end
									
									if (next_byte_is_command_pev_command == 66) begin
										edge_detection_threshold_blue = serial_command_buffer;
										next_byte_is_command = 0;
									end
									
									if (next_byte_is_command_pev_command == 78) begin
										minimum_blob_size = serial_command_buffer;
										next_byte_is_command = 0;
									end
									
									if (next_byte_is_command_pev_command == 72) begin
										color_similarity_threshold = serial_command_buffer;
										next_byte_is_command = 0;
									end
									
									if (next_byte_is_command_pev_command == 89) begin
										display_value_user = serial_command_buffer;
										next_byte_is_command = 2;
									end
									
									if (next_byte_is_command_pev_command == 59) begin
										special_i2c_command_register = serial_command_buffer;
										next_byte_is_command = 2;
									end
									
									// Color slot modify requests
									if ((next_byte_is_command_pev_command > 90) && (next_byte_is_command_pev_command < 140)) begin
										// Red
										primary_color_slots[(one_dim_array_spec - 16) -: 8] 
																= serial_command_buffer;	// old syntax: [array_spec_1][array_spec_2][7:0]
										next_byte_is_command = 2;
									end
								end
							end
						end
					end
					
					if (RxD_data != 10) begin		// Ignore linefeeds
						serial_command_buffer = RxD_data;
					end
				
					serial_receiver_toggler = serial_receiver_toggler + 1;
				end
			end
			
			if (RxD_data_ready == 0) begin
				serial_character_received = 0;
			end
		end

endmodule