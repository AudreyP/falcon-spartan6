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

	// sram i/o
	inout wire [15:0] SRAM_DQ,
	output wire SRAM_CE_N,
	output wire SRAM_OE_N,
	output wire SRAM_LB_N,
	output wire SRAM_UB_N,
	output wire SRAM_WE_N,
	output wire [18:0] SRAM_ADDR,
	output wire RamClk,
	output wire RamAdv,


	input wire [15:0] camera_data_port,
	input wire camera_data_href,
	input wire camera_data_vsync,
	input wire camera_data_pclk,
	inout wire camera_data_sda,
	output reg camera_data_scl = 1'bz,

	input wire [7:0] slide_switches
	);

		// '<=' is a nonblocking set operation (like '=')

		//parameter InternalClkFrequency = 50000000;	// 50MHz
		parameter InternalClkFrequency = 66666666;	// 66MHz
		//parameter InternalClkFrequency = 70000000;	// 70MHz
		//parameter I2ClkCyclesToWait = (InternalClkFrequency / 100000);
		parameter I2ClkCyclesToWait = (InternalClkFrequency / 10000);
		//parameter I2ClkCyclesToWait = (InternalClkFrequency / 1000);
		//parameter I2ClkCyclesToWait = (InternalClkFrequency / 100);
		//parameter I2ClkCyclesToWait = (InternalClkFrequency / 1);

		wire clk;

		//reg border_drawing_holdoff = 0;	//Not used anywhere??
		
		reg serial_output_holdoff = 0;

		reg [23:0] cnt;
		reg [24:0] cnt2;
		reg [7:0] leds;		// Give myself an LED register
		reg [7:0] sseg;		// Give myself a 7-segment display register
		reg [3:0] cseg;		// Give myself a 7-segment control register
		reg [7:0] temp1;		// Temporary data storage

		reg [7:0] startup_sequencer = 0;
		reg [23:0] startup_sequencer_timer = 0;

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
		
		assign address = address_edge_detection | address_tracking_output | address_x_pixel_filling 
								| address_y_pixel_filling | address_blob_extraction | address_color_pattern 
								| address_frame_dump | address_single_shot /*| address_median_filtering*/;
								
		assign wren = wren_edge_detection | wren_tracking_output | wren_x_pixel_filling | wren_y_pixel_filling 
								| wren_blob_extraction | wren_color_pattern | wren_frame_dump | wren_single_shot /*| wren_median_filtering*/;
								
		assign data_write = data_write_edge_detection | data_write_tracking_output | data_write_x_pixel_filling 
									| data_write_y_pixel_filling | data_write_blob_extraction | data_write_color_pattern 
									| data_write_frame_dump | data_write_single_shot /*| data_write_median_filtering*/;	
		
		
		//------------------SRAM module
		sram sram(
			.clk(modified_clock_sram),
			.starting_address(address), 
			.wren(wren), 
			.data_write(data_write), 
			.data_read(data_read), 
			.SRAM_DQ(SRAM_DQ),
		      .SRAM_CE_N(SRAM_CE_N),
			.SRAM_OE_N(SRAM_OE_N), 
			.SRAM_LB_N(SRAM_LB_N), 
			.SRAM_UB_N(SRAM_UB_N), 
			.SRAM_WE_N(SRAM_WE_N), 
			.SRAM_ADDR(SRAM_ADDR),
			.RamClk(RamClk),
			.RamAdv(RamAdv)
			);
				
		//------------------EDGE DETECTION module
		wire wren_edge_detection;
		wire [17:0] address_edge_detection;
		wire [31:0] data_out_edge_detection;
		
		reg [7:0] edge_detection_threshold_red = 30; 
		reg [7:0] edge_detection_threshold_green = 30;
		reg [7:0] edge_detection_threshold_blue = 0;
		
		reg clk_div_by_two = 0;
		
		edge_detection edge_detection(
			//input wires (as seen by module)
			.clk_div_by_two(clk_div_by_two),
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
		
		reg crystal_clk_div_by_two = 0;
	
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
			.crystal_clk_div_by_two(crystal_clk_div_by_two),
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
		wire [3:0] debug2;
		wire [4:0] debug3;
		
		blob_extraction blob_extraction(
			//input wires
			.modified_clock_two_div_by_two(modified_clock_two_div_by_two),
			.modified_clock_two(modified_clock_two),	//for stack ram
			.enable_blob_extraction(enable_blob_extraction),
			.data_read(data_read),
			.divider_quotient(divider_quotient),
			.divider_quotient_two(divider_quotient_two),
			.color_similarity_threshold(color_similarity_threshold),
			.primary_color_slots(primary_color_slots),	//[23:0] by [5:0][3:0] ==> [575:0]
			//output regs
			.wren(wren_blob_extraction),
			.data_write(data_write_blob_extraction),
			.address(address_blob_extraction),
			.blob_extraction_done(blob_extraction_done),
			.divider_dividend(divider_dividend),
			.divider_divisor(divider_divisor),
			.divider_dividend_two(divider_dividend_two),
			.divider_divisor_two(divider_divisor_two)
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

		always @(posedge clk) startup_sequencer_timer=startup_sequencer_timer+1;
		
		//reg [15:0] I2C_Master_Clock = 0;
		reg [31:0] I2C_Master_Clock = 0;
		reg I2C_Clock_Enable = 0;
		reg External_I2C_Clock_Enable = 0;
		reg [7:0] i2c_data_transmit_status = 0;
		reg i2c_data_tx_enable = 0;
		reg [7:0] i2c_clock_state = 0;
		reg External_I2C_Clock_Enable_Prev = 0;

		reg [7:0] one_more_clock_cycle = 0;

		reg [7:0] i2c_data;
		reg [7:0] i2c_address;
		reg [7:0] i2c_register;
		reg camera_data_sda_sw = 1;
		reg camera_data_sda_rnw = 0;	// read=1

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
		wire [4:0] state;
		
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
		
		reg i_need_the_serial_transmitter_now = 0;
		
		reg enable_rgb = 0;
		reg enable_ycrcb = 1;
				
		wire modified_clock;
		
		//instantiate clock manager (2014 edit)
		clock_manager clock_manager(
			.crystal_clk(crystal_clk),
			.modified_clock(modified_clock),
			.modified_clock_two(modified_clock_two),
			.modified_clock_sram(modified_clock_sram));			
			
		assign clk = modified_clock;
	
		//instantiate color test pattern to replace camera feed during testing
		// 2014 edit
		color_pattern camera_capture(
			.clk(clk),
			.reset(reset),
			.enable(enable_camera_capture),
			.starting_address(0),
			.data_write(data_write_color_pattern),
			.addr(address_color_pattern),
			.wren(wren_color_pattern),
			.done(camera_capture_done));
		
		
		//always @(posedge modified_clock_two) begin
		always @(negedge modified_clock_two) begin
			modified_clock_two_div_by_two = !modified_clock_two_div_by_two;
		end
		
		
		always @(posedge crystal_clk) begin
			crystal_clk_div_by_two = !crystal_clk_div_by_two;
		end
		
		
		always @(posedge clk) begin
			clk_div_by_two = !clk_div_by_two;
		end
		
		reg clk_div_by_four = 0;
		
		always @(posedge clk_div_by_two) begin
			clk_div_by_four = !clk_div_by_four;
		end

		assign camera_data_sda = (camera_data_sda_rnw) ? 1'bz : camera_data_sda_sw;
		//assign camera_data_sda = (camera_data_sda_rnw) ? 0 : camera_data_sda_sw;
		
		reg reset_system = 0;

		always @(posedge clk) begin
			//if (startup_sequencer_timer == 16777215) begin
			//if (startup_sequencer_timer == 16777210) begin
			if (startup_sequencer_timer >= 1677721) begin
			//if (startup_sequencer_timer >= 167772) begin
			//if (startup_sequencer_timer >= 83886) begin
				if (startup_sequencer < 32) begin				
					if (startup_sequencer == 0) begin
						startup_sequencer = 1;
					end else begin
						startup_sequencer = startup_sequencer * 2;
					end
				end
			end
			
			if (reset_system == 1) begin
				startup_sequencer = 0;
			end
		end
		
		reg processing_started = 0;
		reg processing_ended = 0;
		
		reg [13:0] timer_value = 0;
		reg [13:0] display_value = 0;
		reg [13:0] display_value_timer = 0;
		reg [13:0] display_value_user = 0;
		reg [7:0] sevenseg_multiplex = 0;
		reg [7:0] digit1 = 0;
		reg [7:0] digit2 = 0;
		reg [7:0] digit3 = 0;
		reg [7:0] digit4 = 0;
		reg [7:0] nextseg = 0;
		reg [15:0] sevenseg_delay = 0;
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
			
			if (slide_switches[7] == 1) begin
				if (slide_switches[6] == 0) begin
					// Display the current version
					display_value = 1002;		// v1.02
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
		
		// Display the current contents of the display_value register on the 7seg display.
		always @(posedge clk) begin		
			if (display_value < 1000) digit4 = 0;
			if ((display_value > 999) && (display_value < 2000)) digit4 = 1;
			if ((display_value > 1999) && (display_value < 3000)) digit4 = 2;
			if ((display_value > 2999) && (display_value < 4000)) digit4 = 3;
			if ((display_value > 3999) && (display_value < 5000)) digit4 = 4;
			if ((display_value > 4999) && (display_value < 6000)) digit4 = 5;
			if ((display_value > 5999) && (display_value < 7000)) digit4 = 6;
			if ((display_value > 6999) && (display_value < 8000)) digit4 = 7;
			if ((display_value > 7999) && (display_value < 9000)) digit4 = 8;
			if (display_value > 8999) digit4 = 9;

			if ((display_value - (digit4 * 1000)) < 100) digit3 = 0;
			if (((display_value - (digit4 * 1000)) > 99) && ((display_value - (digit4 * 1000)) < 200)) digit3 = 1;
			if (((display_value - (digit4 * 1000)) > 199) && ((display_value - (digit4 * 1000)) < 300)) digit3 = 2;
			if (((display_value - (digit4 * 1000)) > 299) && ((display_value - (digit4 * 1000)) < 400)) digit3 = 3;
			if (((display_value - (digit4 * 1000)) > 399) && ((display_value - (digit4 * 1000)) < 500)) digit3 = 4;
			if (((display_value - (digit4 * 1000)) > 499) && ((display_value - (digit4 * 1000)) < 600)) digit3 = 5;
			if (((display_value - (digit4 * 1000)) > 599) && ((display_value - (digit4 * 1000)) < 700)) digit3 = 6;
			if (((display_value - (digit4 * 1000)) > 699) && ((display_value - (digit4 * 1000)) < 800)) digit3 = 7;
			if (((display_value - (digit4 * 1000)) > 799) && ((display_value - (digit4 * 1000)) < 900)) digit3 = 8;
			if ((display_value - (digit4 * 1000)) > 899) digit3 = 9;

			if ((display_value - (digit4 * 1000) - (digit3 * 100)) < 10) digit2 = 0;
			if (((display_value - (digit4 * 1000) - (digit3 * 100)) > 9) && ((display_value - (digit4 * 1000) - (digit3 * 100)) < 20)) digit2 = 1;
			if (((display_value - (digit4 * 1000) - (digit3 * 100)) > 19) && ((display_value - (digit4 * 1000) - (digit3 * 100)) < 30)) digit2 = 2;
			if (((display_value - (digit4 * 1000) - (digit3 * 100)) > 29) && ((display_value - (digit4 * 1000) - (digit3 * 100)) < 40)) digit2 = 3;
			if (((display_value - (digit4 * 1000) - (digit3 * 100)) > 39) && ((display_value - (digit4 * 1000) - (digit3 * 100)) < 50)) digit2 = 4;
			if (((display_value - (digit4 * 1000) - (digit3 * 100)) > 49) && ((display_value - (digit4 * 1000) - (digit3 * 100)) < 60)) digit2 = 5;
			if (((display_value - (digit4 * 1000) - (digit3 * 100)) > 59) && ((display_value - (digit4 * 1000) - (digit3 * 100)) < 70)) digit2 = 6;
			if (((display_value - (digit4 * 1000) - (digit3 * 100)) > 69) && ((display_value - (digit4 * 1000) - (digit3 * 100)) < 80)) digit2 = 7;
			if (((display_value - (digit4 * 1000) - (digit3 * 100)) > 79) && ((display_value - (digit4 * 1000) - (digit3 * 100)) < 90)) digit2 = 8;
			if ((display_value - (digit4 * 1000) - (digit3 * 100)) > 89) digit2 = 9;

			digit1 = display_value - (digit4 * 1000) - (digit3 * 100) - (digit2 * 10);
			
			if (sevenseg_multiplex == 0) begin
				nextseg = digit4;
				cseg = 14;
			end
			if (sevenseg_multiplex == 1) begin
				nextseg = digit3;
				cseg = 13;
			end
			if (sevenseg_multiplex == 2) begin
				nextseg = digit2;
				cseg = 11;
			end
			if (sevenseg_multiplex == 3) begin
				nextseg = digit1;
				cseg = 7;
			end

			if (nextseg == 0) begin
				sseg = 64;
			end
			if (nextseg == 1) begin
				sseg = 121;
			end
			if (nextseg == 2) begin
				sseg = 36;
			end
			if (nextseg == 3) begin
				sseg = 48;
			end
			if (nextseg == 4) begin
				sseg = 25;
			end
			if (nextseg == 5) begin
				sseg = 18;
			end				
			if (nextseg == 6) begin
				sseg = 2;
			end
			if (nextseg == 7) begin
				sseg = 120;
			end
			if (nextseg == 8) begin
				sseg = 0;
			end
			if (nextseg == 9) begin
				sseg = 16;
			end
			
			if ((slide_switches[7:6] == 3) || (slide_switches[5] == 1)) begin
				sseg[7] = 1;
			end else begin
				// Illuminate the correct decimal point
				if (sevenseg_multiplex == 0) begin
					sseg[7] = 0;
				end else begin
					sseg[7] = 1;
				end
			end
			
			// loop controller
			sevenseg_delay = sevenseg_delay + 1;
			if (sevenseg_delay > 6000) begin
				sevenseg_delay = 0;
				sevenseg_multiplex = sevenseg_multiplex + 1;
				if (sevenseg_multiplex > 3) begin
					sevenseg_multiplex = 0;
				end
			end
		end
		
		reg [7:0] special_i2c_command_register = 0;
		reg [7:0] special_i2c_command_data = 0;
		reg send_special_i2c_command = 0;
		reg only_init_this_once = 0;

		always @(posedge clk) begin
			if ((startup_sequencer[0] == 1) || (startup_sequencer[2] == 1) || ((startup_sequencer[4] == 1) && (only_init_this_once == 0)) || (send_special_i2c_command == 1)) begin
				External_I2C_Clock_Enable = !External_I2C_Clock_Enable;
			end else begin
				External_I2C_Clock_Enable = 0;
			end
		
			if (send_special_i2c_command == 0) begin
				if (startup_sequencer[0] == 1) begin
					i2c_address = 66;		// 42 hex
					i2c_register = 20;	// 14 hex
					i2c_data = 36;			// 24 hex [Enable QVGA mode]
				end
				
				if ((startup_sequencer[2] == 1)) begin
					i2c_address = 66;		// 42 hex
					i2c_register = 18;	// 12 hex
					if (enable_ycrcb == 0) begin
						i2c_data = 44;			// 2C hex [Enable RGB and 16-bit mode]
					end else begin
						i2c_data = 36;			// 24 hex [Enable YCrCb and 16-bit mode]
					end
				end
				
				/*if (startup_sequencer[1] == 1) begin
					i2c_address = 66;		// 42 hex
					i2c_register = 32;	// 20 hex
					i2c_data = 1;			// 01 hex [Enable High-Current clock]
				end*/
				
				/*if (startup_sequencer[1] == 1) begin
					i2c_address = 66;		// 42 hex
					i2c_register = 113;	// 71 hex
					i2c_data = 64;			// 40 hex [Enable Gated Pixel Clock]
				end*/
				
				if (only_init_this_once == 0) begin
					if (startup_sequencer[4] == 1) begin
						i2c_address = 66;		// 42 hex
						i2c_register = 21;	// 15 hex
						i2c_data = 65;			// 41 hex [Enable Falling-Edge Data Output]
					end
				end
			end
			
			if (send_special_i2c_command == 1) begin
				i2c_address = 66;		// 42 hex
				i2c_register = special_i2c_command_register;
				i2c_data = special_i2c_command_data;
			end
			
			if (startup_sequencer[5] == 1) begin
				only_init_this_once = 1;
			end
		end

		// -----------------------------------------------------
		// I2C Routines	
		// -----------------------------------------------------
		// IIIIIII    2222		CCC
		//    I		 2    2	  C   C
		//    I			 22	  C
		//    I			2		  C	C
		// IIIIIII	 222222		CCC
		// -----------------------------------------------------

		// I2C Master Clock Driver
		always @(posedge clk) begin
			if ((External_I2C_Clock_Enable == 1) && (External_I2C_Clock_Enable_Prev == 0)) begin
				I2C_Clock_Enable = 1;
				if (i2c_data_transmit_status == 30) begin
					i2c_data_transmit_status = 0;
				end
			end
			External_I2C_Clock_Enable_Prev = External_I2C_Clock_Enable;
			if (I2C_Clock_Enable == 1) begin
				I2C_Master_Clock = I2C_Master_Clock + 1;
				if (I2C_Master_Clock == (I2ClkCyclesToWait / 2)) begin
					if (camera_data_scl == 1) begin
						if (i2c_data_transmit_status == 0) begin
							// Issue a start command
							camera_data_sda_sw = 0;
							i2c_data_transmit_status = 1;
						end
						if (i2c_data_transmit_status == 29) begin
							// Send a STOP
							camera_data_sda_sw = 1;
							i2c_data_transmit_status = 30;
						end
					end
					if (camera_data_scl == 0) begin
						if (i2c_data_transmit_status == 1) begin
							// Send the first address byte
							camera_data_sda_sw = i2c_address[7];
						end
						if (i2c_data_transmit_status == 2) begin
							// Send the second address byte
							camera_data_sda_sw = i2c_address[6];
						end
						if (i2c_data_transmit_status == 3) begin
							// Send the third address byte
							camera_data_sda_sw = i2c_address[5];
						end
						if (i2c_data_transmit_status == 4) begin
							// Send the fourth address byte
							camera_data_sda_sw = i2c_address[4];
						end
						if (i2c_data_transmit_status == 5) begin
							// Send the fifth address byte
							camera_data_sda_sw = i2c_address[3];
						end
						if (i2c_data_transmit_status == 6) begin
							// Send the sixth address byte
							camera_data_sda_sw = i2c_address[2];
						end
						if (i2c_data_transmit_status == 7) begin
							// Send the seventh address byte
							camera_data_sda_sw = i2c_address[1];
						end
						if (i2c_data_transmit_status == 8) begin
							// Send the data direction byte
							camera_data_sda_sw = i2c_address[0];
						end
						if (i2c_data_transmit_status == 9) begin
							// Wait for ACK signal from slave
							camera_data_sda_sw = 1;
						end
						if (i2c_data_transmit_status == 10) begin
							// Send the first register byte
							camera_data_sda_sw = i2c_register[7];
						end
						if (i2c_data_transmit_status == 11) begin
							// Send another register byte
							camera_data_sda_sw = i2c_register[6];
						end
						if (i2c_data_transmit_status == 12) begin
							// Send another register byte
							camera_data_sda_sw = i2c_register[5];
						end
						if (i2c_data_transmit_status == 13) begin
							// Send another register byte
							camera_data_sda_sw = i2c_register[4];
						end
						if (i2c_data_transmit_status == 14) begin
							// Send another register byte
							camera_data_sda_sw = i2c_register[3];
						end
						if (i2c_data_transmit_status == 15) begin
							// Send another register byte
							camera_data_sda_sw = i2c_register[2];
						end
						if (i2c_data_transmit_status == 16) begin
							// Send another register byte
							camera_data_sda_sw = i2c_register[1];
						end
						if (i2c_data_transmit_status == 17) begin
							// Send another register byte
							camera_data_sda_sw = i2c_register[0];
						end
						if (i2c_data_transmit_status == 18) begin
							// Wait for ACK signal from slave
							camera_data_sda_sw = 1;
						end
						if (i2c_data_transmit_status == 19) begin
							// Send the first data byte
							camera_data_sda_sw = i2c_data[7];
						end
						if (i2c_data_transmit_status == 20) begin
							// Send the next data byte
							camera_data_sda_sw = i2c_data[6];
						end
						if (i2c_data_transmit_status == 21) begin
							// Send the next data byte
							camera_data_sda_sw = i2c_data[5];
						end
						if (i2c_data_transmit_status == 22) begin
							// Send the next data byte
							camera_data_sda_sw = i2c_data[4];
						end
						if (i2c_data_transmit_status == 23) begin
							// Send the next data byte
							camera_data_sda_sw = i2c_data[3];
						end
						if (i2c_data_transmit_status == 24) begin
							// Send the next data byte
							camera_data_sda_sw = i2c_data[2];
						end
						if (i2c_data_transmit_status == 25) begin
							// Send the next data byte
							camera_data_sda_sw = i2c_data[1];
						end
						if (i2c_data_transmit_status == 26) begin
							// Send the next data byte
							camera_data_sda_sw = i2c_data[0];
						end
						if (i2c_data_transmit_status == 27) begin
							// Wait for ACK signal from slave
							camera_data_sda_sw = 1;
						end
						if (i2c_data_transmit_status == 28) begin
							// Allow the clock to go high once more (in order to "receive" the ACK bit)
							camera_data_sda_sw = 0;
						end
						if (i2c_data_transmit_status < 30) begin
							i2c_data_transmit_status = i2c_data_transmit_status + 1;
						end else begin
							i2c_data_transmit_status = 0;
						end
					end
				end
				if (I2C_Master_Clock == I2ClkCyclesToWait) begin
					if (i2c_data_transmit_status >= 30) begin
						camera_data_scl = 1;
						I2C_Clock_Enable = 0;
					end
					I2C_Master_Clock = 0;
					if (i2c_clock_state == 0) begin
						i2c_clock_state = 1;
						camera_data_scl = 1;
					end else begin
						camera_data_scl = 0;
						i2c_clock_state = 0;
					end
				end
			end else begin
				camera_data_scl = 1;
				i2c_clock_state = 0;
				I2C_Master_Clock = 0;
			end
		end

		// End I2C Transmitter Routines

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

		assign debug1[0] = processing_done_internal;
		assign debug1[1] = i_need_the_serial_transmitter_now;

		assign debug2[0] = run_frame_dump_internal;
		assign debug2[1] = run_single_shot_test_internal;
		assign debug2[3:2] = 0;

		assign debug3[0] = run_frame_dump;
		assign debug3[1] = run_single_shot_test;
		assign debug3[4:2] = 0;

				
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
		//always @(posedge modified_clock) begin
		//always @(posedge clk) begin
		//always @(posedge clk_div_by_two) begin
		always @(negedge clk_div_by_two) begin
		//always @(posedge camera_data_pclk) begin
			data_read_sync = data_read;
			
					
			//if ((processing_done_internal == 0)) begin
			//if (camera_transfer_done == 1) begin
				if (i_need_the_serial_transmitter_now == 0) begin
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
							current_main_processing_state = STATE_MEDIAN_FILTERING;
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
									if (state == 5'b10000) begin	// Wait for transmission of byte to complete
										TxD_start = 0;
										tx_toggle = 0;
									end
								end
			
								//if (serial_output_index >= 307200) begin
								if (serial_output_index >= 230400) begin
								//if (serial_output_index >= 76800) begin
									if (state == 5'b10000) begin	// Wait for transmission of byte to complete
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
									if (state == 5'b10000) begin	// Wait for transmission of byte to complete
										TxD_start = 0;
										tx_toggle = 0;
									end
								end
			
								//if (serial_output_index >= 307200) begin
								if (serial_output_index >= 76800) begin
									if (state == 5'b10000) begin	// Wait for transmission of byte to complete
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
									if (state == 5'b10000) begin	// Wait for transmission of byte to complete
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
				end else begin
					// All right, I guess the other routine really needs the serial transmitter, so give it up!
					TxD_data = 7'bz;
					TxD_start = 1'bz;
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

		always @* begin
			camera_data_sda_rnw = camera_data_sda_sw;
		end

		async_transmit asyncTX(.clk(clk), .TxD_start(TxD_start), .TxD_data(TxD_data), .TxD(TxD), .TxD_busy(TxD_busy), .state(state));
		async_receiver asyncRX(.clk(clk_div_by_two), .RxD(RxD), .RxD_data_ready(RxD_data_ready), .RxD_data(RxD_data), .RxD_endofpacket(RxD_endofpacket), .RxD_idle(RxD_idle));

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