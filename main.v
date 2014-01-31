`timescale 1ns / 1ps
 
////////////////////////////////////////////////////////////////////////////////
// Company: Pearson Computing
// Engineer: Timothy Pearson
//
// Create Date:    22:21:40 05/02/06
// Design Name:    
// Module Name:    main
// Project Name:   
// Target Device:  
// Tool versions:  
// Description:
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module main(
input main_fifty_clk, 
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

input [3:0] buttons,

inout wire [31:0] SRAM_DQ,
output wire SRAM_CE_N,
output wire SRAM_OE_N,
output wire SRAM_LB_N,
output wire SRAM_UB_N,
output wire SRAM_WE_N,
output wire [17:0] SRAM_ADDR,

output wire SRAM_CE_N_2,
output wire SRAM_LB_N_2,
output wire SRAM_UB_N_2,

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

	reg median_filtering_holdoff = 0;
	reg edge_detection_holdoff = 0;
	reg x_pixel_filling_holdoff = 0;
	reg y_pixel_filling_holdoff = 0;
	reg border_drawing_holdoff = 0;
	reg blob_extraction_holdoff = 0;
	reg [2:0] tracking_output_holdoff = 0;
	reg serial_output_holdoff = 0;

	reg [23:0] cnt;
	reg [24:0] cnt2;
	reg [7:0] leds;		// Give myself an LED register
	reg [7:0] sseg;		// Give myself a 7-segment display register
	reg [3:0] cseg;		// Give myself a 7-segment control register
	reg [7:0] temp1;		// Temporary data storage

	reg [7:0] startup_sequencer = 0;
	reg [23:0] startup_sequencer_timer = 0;

	reg wren;
   reg [17:0] address;
   reg [31:0] data_write;
   wire [31:0] data_read;
	reg [31:0] data_read_sync;

	reg [7:0] delay_loop = 0;

	wire [18:0] camera_data_address;
	reg camera_data_dma_enable;

	reg camera_transfer_done = 0;
	reg processing_done = 1;

	reg camera_transfer_done_internal = 0;
	reg processing_done_internal = 0;

	sram sram(.address(address), .wren(wren), .data_write(data_write), .data_read(data_read), .SRAM_DQ(SRAM_DQ),
          .SRAM_CE_N(SRAM_CE_N), .SRAM_OE_N(SRAM_OE_N), .SRAM_LB_N(SRAM_LB_N), .SRAM_UB_N(SRAM_UB_N), .SRAM_WE_N(SRAM_WE_N), .SRAM_ADDR(SRAM_ADDR),
			 .SRAM_CE_N_2(SRAM_CE_N_2), .SRAM_LB_N_2(SRAM_LB_N_2), .SRAM_UB_N_2(SRAM_UB_N_2));
			 
	reg [17:0] divider_dividend;
	reg [17:0] divider_divisor;
	wire [17:0] divider_quotient;
	wire [17:0] divider_remainder;
	wire divider_zeroflag;
			 
	serial_divide_uu serial_divide_uu (.dividend(divider_dividend), .divisor(divider_divisor), .quotient(divider_quotient), .remainder(divider_remainder), .zeroflag(divider_zeroflag));
	
	reg [17:0] divider_dividend_two;
	reg [17:0] divider_divisor_two;
	wire [17:0] divider_quotient_two;
	wire [17:0] divider_remainder_two;
	wire divider_zeroflag_two;
			 
	serial_divide_uu serial_divide_uu_two (.dividend(divider_dividend_two), .divisor(divider_divisor_two), .quotient(divider_quotient_two), .remainder(divider_remainder_two), .zeroflag(divider_zeroflag_two));

	reg enable_median_filtering = 0;
	reg median_filtering_done = 0;
	
	reg enable_edge_detection = 0;
	reg edge_detection_done = 0;
	
	reg enable_x_pixel_filling = 0;
	reg x_pixel_filling_done = 0;
	
	reg enable_y_pixel_filling = 0;
	reg y_pixel_filling_done = 0;
	
	reg enable_border_drawing = 0;
	reg border_drawing_done = 0;
	
	reg enable_blob_extraction = 0;
	reg [3:0] enable_blob_extraction_verified = 0;
	reg blob_extraction_done = 0;
	
	reg enable_tracking_output = 0;
	reg [3:0] enable_tracking_output_verified = 0;
	reg tracking_output_done = 0;
	
	reg enable_serial_output = 0;
	reg serial_output_done = 0;

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
	
	reg [23:0] primary_color_slots [5:0][3:0];
	reg [7:0] color_similarity_threshold = 0;
	reg [7:0] minimum_blob_size = 0;

	reg [19:0] serial_output_index = 0;
	reg [19:0] serial_output_index_mem = 0;
	reg [19:0] serial_output_index_toggle = 0;
	reg serial_output_enabled = 0;

	reg [7:0] datatimer = 0;
	reg [15:0] databuffer;
	reg [31:0] databuffer_mem;

	reg [7:0] current_processing_state = 0;
	reg [7:0] current_main_processing_state = 0;

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
	
	reg [17:0] edge_detection_counter_tog = 0;
	reg [17:0] edge_detection_counter_togg = 0;
	reg [17:0] edge_detection_counter_toggle = 0;
	reg [31:0] edge_detection_counter_temp = 0;
	
	reg [7:0] edge_detection_threshold_red = 30;
	reg [7:0] edge_detection_threshold_green = 30;
	reg [7:0] edge_detection_threshold_blue = 0;
	
	reg [17:0] x_pixel_filling_counter_tog = 0;
	reg [17:0] x_pixel_filling_counter_togg = 0;
	reg [17:0] x_pixel_filling_counter_toggle = 0;
	reg [31:0] x_pixel_filling_counter_temp = 0;	
	
	reg [17:0] y_pixel_filling_counter_tog = 0;
	reg [17:0] y_pixel_filling_counter_togg = 0;
	reg [17:0] y_pixel_filling_counter_toggle = 0;
	reg [31:0] y_pixel_filling_counter_temp = 0;	
	
	reg [5:0] border_drawing_counter_tog = 0;
	reg [17:0] border_drawing_counter_togg = 0;
	reg [17:0] border_drawing_counter_toggle = 0;
	reg [31:0] border_drawing_counter_temp = 0;	
	
	reg [5:0] blob_extraction_counter_tog = 0;
	reg [5:0] blob_extraction_counter_togg = 0;
	reg [5:0] blob_extraction_counter_toggle = 0;
	reg [31:0] blob_extraction_counter_temp = 0;
	
	reg [5:0] tracking_output_counter_tog = 0;
	reg [5:0] tracking_output_counter_togg = 0;
	reg [5:0] tracking_output_counter_toggle = 0;
	reg [31:0] tracking_output_counter_temp = 0;
	
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
	
	reg find_highest = 0;
	reg find_biggest = 1;
	
	// synthesis attribute CLKFX_DIVIDE of modified_clock_dcm is 3
	// synthesis attribute CLKFX_MULTIPLY of modified_clock_dcm is 4
	// synthesis attribute CLKIN_PERIOD of modified_clock_dcm is 20
	// synthesis attribute CLK_FEEDBACK of modified_clock_dcm is NONE
	
	reg dcm_reset = 0;
	wire dcm_locked;
	wire modified_clock;
	DCM modified_clock_dcm (.CLKIN(main_fifty_clk), .CLKFX(modified_clock), .LOCKED(dcm_locked), .RST(dcm_reset));
	
	assign clk = modified_clock;
	
	reg [15:0] dcm_lock_timer = 0;
	
	always @(posedge clk) begin
		if (dcm_locked == 0) begin
			dcm_lock_timer = dcm_lock_timer + 1;
		end else begin
			dcm_lock_timer = 0;
		end
		
		if (dcm_lock_timer > 50000) begin
			dcm_reset = 1;
		end
		
		if (dcm_lock_timer > 50010) begin		// Allow 10 clock cycles to reset the DCM
			dcm_reset = 0;
			dcm_lock_timer = 0;
		end
		
		//leds[6] = dcm_locked;
	end
	
	// synthesis attribute CLKFX_DIVIDE of modified_clock_dcm_two is 2
	// synthesis attribute CLKFX_MULTIPLY of modified_clock_dcm_two is 2
	// synthesis attribute CLKIN_PERIOD of modified_clock_dcm_two is 20
	// synthesis attribute CLK_FEEDBACK of modified_clock_dcm_two is NONE
	
	reg dcm_reset_two = 0;
	wire dcm_locked_two;
	wire modified_clock_two;
	DCM modified_clock_dcm_two (.CLKIN(main_fifty_clk), .CLKFX(modified_clock_two), .LOCKED(dcm_locked_two), .RST(dcm_reset_two));
	
	reg [15:0] dcm_lock_timer_two = 0;
	
	always @(posedge clk) begin
		if (dcm_locked_two == 0) begin
			dcm_lock_timer_two = dcm_lock_timer_two + 1;
		end else begin
			dcm_lock_timer_two = 0;
		end
		
		if (dcm_lock_timer_two > 50000) begin
			dcm_reset_two = 1;
		end
		
		if (dcm_lock_timer_two > 50010) begin		// Allow 10 clock cycles to reset the DCM
			dcm_reset_two = 0;
			dcm_lock_timer_two = 0;
		end
		
		//leds[6] = dcm_locked_two;
	end
	
	reg [16:0] stack_ram_dina;
	reg [13:0] stack_ram_addra;
	reg stack_ram_wea;
	wire [16:0] stack_ram_douta;
	
	stack_ram stack_ram(.clka(modified_clock_two), .dina(stack_ram_dina), .addra(stack_ram_addra), .wea(stack_ram_wea), .douta(stack_ram_douta));
	
	reg modified_clock_two_div_by_two = 0;
	
	//always @(posedge modified_clock_two) begin
	always @(negedge modified_clock_two) begin
		modified_clock_two_div_by_two = !modified_clock_two_div_by_two;
	end
	
	reg clk_fifty_div_by_two = 0;
	
	always @(posedge main_fifty_clk) begin
		clk_fifty_div_by_two = !clk_fifty_div_by_two;
	end
	
	reg clk_div_by_two = 0;
	
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
	
	reg [15:0] blob_extraction_blob_counter = 0;
	
	reg [31:0] data_read_sync_tracking_output = 0;
	reg tracking_output_main_chunk_already_loaded = 0;
	reg [15:0] tracking_output_pointer_counter = 0;
	reg [7:0] tracking_output_counter_color;
	reg [15:0] tracking_output_counter_size;
	reg [7:0] tracking_output_counter_buffer_blue;
	
	reg tracking_output_ok_to_send_data = 0;
	
	reg [15:0] tracking_output_pointer = 0;
	
	reg [15:0] tracking_output_blob_sizes [17:0];
	reg [15:0] tracking_output_blob_location [17:0];
	
	reg [31:0] tracking_output_temp_data;
	
	reg [7:0] x_centroids_array [7:0];
	reg [7:0] y_centroids_array [7:0];
	reg [15:0] s_centroids_array [7:0];
	reg [7:0] first_x_centroids_array [7:0];
	reg [7:0] first_y_centroids_array [7:0];
	reg [15:0] first_s_centroids_array [7:0];
	
	reg [7:0] location_to_extract = 0;
	
	// Output the tracking data
	//always @(posedge clk) begin
	//always @(posedge clk_div_by_two) begin
	always @(posedge clk_fifty_div_by_two) begin
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
	
	reg [31:0] data_read_sync_blob_extraction = 0;
	reg blob_extraction_main_chunk_already_loaded = 0;
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
	
	// Here is the stack in all of its glory...we are using 9 bit numbers for X coordinate storage here, with a max. stack depth of 2000
	// We will be using 8 bit numbers for the Y coordinates
	//reg [17999:0] stack_x = 0;
	//reg [15999:0] stack_y = 0;
	//reg [11:0] stack_pointer = 0;
	
	//reg [31:0] stack = 0;
	reg [15:0] stack_pointer = 0;
	
	reg [4:0] blob_extraction_toggler = 0;
	reg [3:0] blob_extraction_inner_toggler = 0;
	
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
	
	reg ok_to_do_averaging = 0;
	
	// Now it's time to find and extract the blobs
	//always @(posedge clk_div_by_four) begin
	//always @(posedge clk_fifty_div_by_two) begin
	//always @(posedge clk_div_by_two) begin
	//always @(posedge modified_clock) begin
	//always @(posedge clk) begin
	//always @(posedge modified_clock_two) begin
	always @(posedge modified_clock_two_div_by_two) begin
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
									if ((data_read_sync_blob_extraction == 0) && (blob_extraction_x_temp > 7) && (blob_extraction_x_temp < 313) && (blob_extraction_y_temp_1 > 7) && (blob_extraction_y_temp_1 < 233)) begin
										// Write the data
										address = ((blob_extraction_y_temp_1 * 320) + blob_extraction_x_temp);
										data_write = blob_extraction_blob_counter;
										wren = 1;
										
										blob_extraction_inner_toggler = 1;
									end else begin
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
							
							if (blob_extraction_toggler == 7) begin
								// Before we can fill the last data slot, we need to find which color slot this is!
								// We will be calculating the sum of the errors for each color, winner takes all and is then compared against the threshold
								
								//for (blob_extraction_color_loop = 0; blob_extraction_color_loop < 6; blob_extraction_color_loop = blob_extraction_color_loop + 1) begin
									//for (blob_extraction_slot_loop = 0; blob_extraction_slot_loop < 8; blob_extraction_slot_loop = blob_extraction_slot_loop + 1) begin
										// Red
										if (blob_extraction_red_average_final > primary_color_slots[blob_extraction_color_loop][blob_extraction_slot_loop][7:0]) begin
											blob_extraction_current_difference = blob_extraction_red_average_final - primary_color_slots[blob_extraction_color_loop][blob_extraction_slot_loop][7:0];
										end else begin
											blob_extraction_current_difference = primary_color_slots[blob_extraction_color_loop][blob_extraction_slot_loop][7:0] - blob_extraction_red_average_final;
										end
										
										// Green
										if (blob_extraction_green_average_final > primary_color_slots[blob_extraction_color_loop][blob_extraction_slot_loop][15:8]) begin
											blob_extraction_current_difference = (blob_extraction_current_difference + (blob_extraction_green_average_final - primary_color_slots[blob_extraction_color_loop][blob_extraction_slot_loop][15:8]));
										end else begin
											blob_extraction_current_difference = (blob_extraction_current_difference + (primary_color_slots[blob_extraction_color_loop][blob_extraction_slot_loop][15:8] - blob_extraction_green_average_final));
										end
										
										// Blue
										if (blob_extraction_blue_average_final > primary_color_slots[blob_extraction_color_loop][blob_extraction_slot_loop][23:16]) begin
											blob_extraction_current_difference = (blob_extraction_current_difference + (blob_extraction_blue_average_final - primary_color_slots[blob_extraction_color_loop][blob_extraction_slot_loop][23:16]));
										end else begin
											blob_extraction_current_difference = (blob_extraction_current_difference + (primary_color_slots[blob_extraction_color_loop][blob_extraction_slot_loop][23:16] - blob_extraction_blue_average_final));
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
			address = 18'bz;
			data_write = 32'bz;
			wren = 1'bz;
		end
	end
	
	reg [31:0] data_read_sync_y_pixel_filling = 0;
	reg y_pixel_filling_main_chunk_already_loaded = 0;
	reg [7:0] y_pixel_filling_x_counter = 0;
	reg [7:0] y_pixel_filling_y_counter = 0;
	reg [31:0] y_pixel_filling_counter_buffer_red;
	reg [31:0] y_pixel_filling_counter_buffer_green;
	reg [31:0] y_pixel_filling_counter_buffer_blue;
	
	// Fill in missing edge pixels in the Y direction.
	//always @(posedge clk) begin
	always @(posedge clk_div_by_two) begin
	//always @(posedge modified_clock) begin
		data_read_sync_y_pixel_filling = data_read;
		
		if (enable_y_pixel_filling == 1) begin
			if (y_pixel_filling_holdoff == 0) begin
				wren = 0;
				address = 2240;								// Skip the topmost 7 lines of the image
				y_pixel_filling_counter_tog = 2240;
				y_pixel_filling_counter_togg = 2240;
				y_pixel_filling_holdoff = 1;
			end else begin
				// Load in the first pixel
				if (y_pixel_filling_counter_toggle == 1) begin
					y_pixel_filling_counter_buffer_red = data_read_sync_y_pixel_filling;			// This is the center pixel
					y_pixel_filling_counter_tog = y_pixel_filling_counter_tog + 320;				// Set next read address (one pixel down)
				end
				
				if (y_pixel_filling_counter_toggle == 2) begin
					y_pixel_filling_counter_buffer_green = data_read_sync_y_pixel_filling;		// This is the rightmost pixel
					y_pixel_filling_counter_tog = y_pixel_filling_counter_tog - 640;					// Set next read address (two pixels up)
				end
				
				if (y_pixel_filling_counter_toggle == 3) begin
					y_pixel_filling_counter_buffer_blue = data_read_sync_y_pixel_filling;		// This is the leftmost pixel
					y_pixel_filling_counter_tog = y_pixel_filling_counter_tog + 321;					// Set next read address (one pixel to the right and one down)
					
					// OK, we have our data, now we can see if we need to fill this pixel or not!
					y_pixel_filling_counter_temp = y_pixel_filling_counter_buffer_red;
					
					if ((y_pixel_filling_counter_buffer_blue == 1) && (y_pixel_filling_counter_buffer_green == 1)) begin
						y_pixel_filling_counter_temp = 1;
					end
				end
				
				if (y_pixel_filling_counter_togg == 74561) begin		// All done!	It is 74561 because we don't need to process the last 7 lines of the image, as they are just garbage anyway!
					y_pixel_filling_counter_tog = 0;
					y_pixel_filling_counter_togg = 0;
					y_pixel_filling_counter_toggle = 0;
					y_pixel_filling_done = 1;
					y_pixel_filling_holdoff = 0;
					wren = 0;
				end
				
				y_pixel_filling_counter_toggle = y_pixel_filling_counter_toggle + 1;
				if (y_pixel_filling_counter_toggle < 4) begin
					address = y_pixel_filling_counter_tog;
					wren = 0;
				end
				if (y_pixel_filling_counter_toggle == 4) begin
					address = y_pixel_filling_counter_togg;
					data_write = y_pixel_filling_counter_temp;
					wren = 1;
				end
				if (y_pixel_filling_counter_toggle == 5) begin
					wren = 0;
					address = y_pixel_filling_counter_tog;
					y_pixel_filling_counter_togg = y_pixel_filling_counter_togg + 1;
					y_pixel_filling_counter_toggle = 0;
				end
			end
		end else begin
			y_pixel_filling_done = 0;
			address = 18'bz;
			data_write = 32'bz;
			wren = 1'bz;
		end
	end
	
	reg [31:0] data_read_sync_x_pixel_filling = 0;
	reg x_pixel_filling_main_chunk_already_loaded = 0;
	reg [7:0] x_pixel_filling_x_counter = 0;
	reg [7:0] x_pixel_filling_y_counter = 0;
	reg [31:0] x_pixel_filling_counter_buffer_red;
	reg [31:0] x_pixel_filling_counter_buffer_green;
	reg [31:0] x_pixel_filling_counter_buffer_blue;
	
	// Fill in missing edge pixels in the X direction.
	//always @(posedge clk) begin
	always @(posedge clk_div_by_two) begin
	//always @(posedge modified_clock) begin
		data_read_sync_x_pixel_filling = data_read;
		
		if (enable_x_pixel_filling == 1) begin
			if (x_pixel_filling_holdoff == 0) begin
				wren = 0;
				address = 2240;								// Skip the topmost 7 lines of the image
				x_pixel_filling_counter_tog = 2240;
				x_pixel_filling_counter_togg = 2240;
				x_pixel_filling_holdoff = 1;
			end else begin
				// Load in the first pixel
				if (x_pixel_filling_counter_toggle == 1) begin
					x_pixel_filling_counter_buffer_red = data_read_sync_x_pixel_filling;			// This is the center pixel
					x_pixel_filling_counter_tog = x_pixel_filling_counter_tog + 1;							// Set next read address (one pixel to the right)
				end
				
				if (x_pixel_filling_counter_toggle == 2) begin
					x_pixel_filling_counter_buffer_green = data_read_sync_x_pixel_filling;		// This is the rightmost pixel
					x_pixel_filling_counter_tog = x_pixel_filling_counter_tog - 2;							// Set next read address (two pixels to the left)
				end
				
				if (x_pixel_filling_counter_toggle == 3) begin
					x_pixel_filling_counter_buffer_blue = data_read_sync_x_pixel_filling;			// This is the leftmost pixel
					x_pixel_filling_counter_tog = x_pixel_filling_counter_tog + 2;							// Set next read address (two pixels to the right)
					
					// OK, we have our data, now we can see if we need to fill this pixel or not!
					x_pixel_filling_counter_temp = x_pixel_filling_counter_buffer_red;
					
					if ((x_pixel_filling_counter_buffer_blue == 1) && (x_pixel_filling_counter_buffer_green == 1)) begin
						x_pixel_filling_counter_temp = 1;
					end
				end
				
				if (x_pixel_filling_counter_togg == 74561) begin		// All done!	It is 74561 because we don't need to process the last 7 lines of the image, as they are just garbage anyway!
					x_pixel_filling_counter_tog = 0;
					x_pixel_filling_counter_togg = 0;
					x_pixel_filling_counter_toggle = 0;
					x_pixel_filling_done = 1;
					x_pixel_filling_holdoff = 0;
					wren = 0;
				end
				
				x_pixel_filling_counter_toggle = x_pixel_filling_counter_toggle + 1;
				if (x_pixel_filling_counter_toggle < 4) begin
					address = x_pixel_filling_counter_tog;
					wren = 0;
				end
				if (x_pixel_filling_counter_toggle == 4) begin
					address = x_pixel_filling_counter_togg;
					data_write = x_pixel_filling_counter_temp;
					wren = 1;
				end
				if (x_pixel_filling_counter_toggle == 5) begin
					wren = 0;
					address = x_pixel_filling_counter_tog;
					x_pixel_filling_counter_togg = x_pixel_filling_counter_togg + 1;
					x_pixel_filling_counter_toggle = 0;
				end
			end
		end else begin
			x_pixel_filling_done = 0;
			address = 18'bz;
			data_write = 32'bz;
			wren = 1'bz;
		end
	end
	
	reg [31:0] data_read_sync_edge_detection = 0;
	reg edge_detection_main_chunk_already_loaded = 0;
	reg [7:0] edge_detection_x_counter = 0;
	reg [7:0] edge_detection_y_counter = 0;
	reg [23:0] edge_detection_counter_buffer_red;
	reg [23:0] edge_detection_counter_buffer_green;
	reg [23:0] edge_detection_counter_buffer_blue;
	reg [15:0] edge_detection_running_total_red = 0;
	reg [15:0] edge_detection_running_total_green = 0;
	reg [15:0] edge_detection_running_total_blue = 0;
	reg [15:0] edge_detection_running_total_ave_red = 0;
	reg [15:0] edge_detection_running_total_ave_green = 0;
	reg [15:0] edge_detection_running_total_ave_blue = 0;
	
	reg edge_detection_skip_this_column = 0;
	
	parameter edge_detector_averaging_window = 16;
	//parameter edge_detector_averaging_window = 15;
	//parameter edge_detector_averaging_window = 14;
	
	// For every pixel, see if it lies on an edge.
	//always @(posedge modified_clock) begin
	//always @(posedge camera_data_pclk) begin
	always @(posedge clk_div_by_two) begin
	//always @(posedge clk) begin		
		if (enable_edge_detection == 1) begin
			if (edge_detection_holdoff == 0) begin
				wren = 0;
				address = 79041;								// Skip the topmost 7 lines of the image
				edge_detection_counter_tog = 79041;
				edge_detection_counter_togg = 2240;
				edge_detection_holdoff = 1;
				edge_detection_counter_toggle = 1;
				edge_detection_main_chunk_already_loaded = 0;
				edge_detection_running_total_red = 0;
				edge_detection_running_total_green = 0;
				edge_detection_running_total_blue = 0;
			end else begin				
				data_read_sync_edge_detection = data_read;
				
				// Now find the average of the surrounding pixels (8 in either direction :ahh:)
				if (edge_detection_counter_toggle == 4) begin
					if (edge_detection_main_chunk_already_loaded == 1) begin
						// Main chunk already loaded--simply load what we need to continue
						if (edge_detection_skip_this_column == 0) begin
							if (edge_detection_y_counter < (edge_detector_averaging_window * 2)) begin
								if (edge_detection_y_counter < edge_detector_averaging_window) begin
									// Set up the next read operation
									if (edge_detection_y_counter != (edge_detector_averaging_window - 2)) begin
										address = (((edge_detection_counter_tog - (edge_detector_averaging_window / 2)) + (edge_detection_y_counter * 320)) - (((edge_detector_averaging_window / 2) - 2) * 320));
									end else begin
										address = ((edge_detection_counter_tog + (edge_detector_averaging_window / 2)) - (((edge_detector_averaging_window / 2) - 1) * 320));
									end
									
									// Load the leftmost column and subtract each value from the accumulators
									edge_detection_running_total_red = edge_detection_running_total_red - data_read[7:0];	// This is whatever pixel I previously loaded in!
									edge_detection_running_total_green = edge_detection_running_total_green - data_read[15:8];
									edge_detection_running_total_blue = edge_detection_running_total_blue - data_read[31:24];
								end else begin
									// Set up the next read operation
									address = (((edge_detection_counter_tog + (edge_detector_averaging_window / 2)) + ((edge_detection_y_counter - edge_detector_averaging_window) * 320)) - (((edge_detector_averaging_window / 2) - 2) * 320));
									
									// Load the rightmost column and add each value to the accumulators
									edge_detection_running_total_red = edge_detection_running_total_red + data_read[7:0];	// This is whatever pixel I previously loaded in!
									edge_detection_running_total_green = edge_detection_running_total_green + data_read[15:8];
									edge_detection_running_total_blue = edge_detection_running_total_blue + data_read[31:24];
								end
								edge_detection_y_counter = edge_detection_y_counter + 2;
							end else begin
								edge_detection_y_counter = 0;
								edge_detection_skip_this_column = 1;
								edge_detection_counter_toggle = edge_detection_counter_toggle + 1;	// Next stage, please!
							end
						end else begin
							edge_detection_skip_this_column = 0;
							edge_detection_counter_toggle = edge_detection_counter_toggle + 1;	// Next stage, please!
						end
					end else begin
						// for x=0 to 16
						if (edge_detection_x_counter < edge_detector_averaging_window) begin
							// for y=0 to 16
							if (edge_detection_y_counter < edge_detector_averaging_window) begin
								// Set up the next read operation...
								address = ((((edge_detection_counter_tog + edge_detection_x_counter) - ((edge_detector_averaging_window / 2) - 1)) + (edge_detection_y_counter * 320)) - (((edge_detector_averaging_window / 2) - 1) * 320));
								wren = 0;

								// Keep a running total of all the points that I visit...
								edge_detection_running_total_red = edge_detection_running_total_red + data_read[7:0];	// This is whatever pixel I previously loaded in!
								edge_detection_running_total_green = edge_detection_running_total_green + data_read[15:8];
								edge_detection_running_total_blue = edge_detection_running_total_blue + data_read[31:24];
						
								// next y
								edge_detection_y_counter = edge_detection_y_counter + 2;
							end else begin
								edge_detection_y_counter = 0;
								// next x
								edge_detection_x_counter = edge_detection_x_counter + 2;
							end
						end else begin
							edge_detection_y_counter = 0;
							edge_detection_skip_this_column = 1;
							edge_detection_main_chunk_already_loaded = 1;
							edge_detection_counter_toggle = edge_detection_counter_toggle + 1;	// Next stage, please!
						end
					end
				end
				
				// Yes, this one IS supposed to be "out of sequence", as it does not need to wait a cycle before continuing on!
				if (edge_detection_counter_toggle == 5) begin
					edge_detection_counter_temp = 0;
					
					// Now that we have all of our data, we can see if this is an edge or not!
					// Finish calculating the average
					edge_detection_running_total_ave_red = edge_detection_running_total_red / 256;
					edge_detection_running_total_ave_green = edge_detection_running_total_green / 256;
					edge_detection_running_total_ave_blue = edge_detection_running_total_blue / 256;
					
					// Add the noise floor thresholds...
					edge_detection_running_total_ave_red = edge_detection_running_total_ave_red + edge_detection_threshold_red;
					edge_detection_running_total_ave_green = edge_detection_running_total_ave_green + edge_detection_threshold_green;
					edge_detection_running_total_ave_blue = edge_detection_running_total_ave_blue + edge_detection_threshold_blue;
					
					// First the red...
					if (edge_detection_counter_buffer_red[7:0] > edge_detection_running_total_ave_red) begin
						if (edge_detection_counter_buffer_red[15:8] < edge_detection_running_total_ave_red) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
						if (edge_detection_counter_buffer_red[23:16] < edge_detection_running_total_ave_red) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
					end else begin
						if (edge_detection_counter_buffer_red[15:8] > edge_detection_running_total_ave_red) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
						if (edge_detection_counter_buffer_red[23:16] > edge_detection_running_total_ave_red) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
					end
					
					// ...next the green...
					if (edge_detection_counter_buffer_green[7:0] > edge_detection_running_total_ave_green) begin
						if (edge_detection_counter_buffer_green[15:8] < edge_detection_running_total_ave_green) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
						if (edge_detection_counter_buffer_green[23:16] < edge_detection_running_total_ave_green) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
					end else begin
						if (edge_detection_counter_buffer_green[15:8] > edge_detection_running_total_ave_green) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
						if (edge_detection_counter_buffer_green[23:16] > edge_detection_running_total_ave_green) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
					end
					
					// ...and finally the blue!
					if (edge_detection_counter_buffer_blue[7:0] > edge_detection_running_total_ave_blue) begin
						if (edge_detection_counter_buffer_blue[15:8] < edge_detection_running_total_ave_blue) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
						if (edge_detection_counter_buffer_blue[23:16] < edge_detection_running_total_ave_blue) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
					end else begin
						if (edge_detection_counter_buffer_blue[15:8] > edge_detection_running_total_ave_blue) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
						if (edge_detection_counter_buffer_blue[23:16] > edge_detection_running_total_ave_blue) begin
							edge_detection_counter_temp = 1;		// We found an edge!
						end
					end
					
					// For testing ONLY, load in the average values for this pixel and store them so that I can see them!
					//edge_detection_counter_temp[7:0] = edge_detection_running_total_ave_red;
					//edge_detection_counter_temp[15:8] = edge_detection_running_total_ave_green;
					//edge_detection_counter_temp[31:24] = edge_detection_running_total_ave_blue;
					
					edge_detection_counter_tog = edge_detection_counter_tog + 1;			// We need to read from the next pixel
					edge_detection_counter_toggle = edge_detection_counter_toggle + 1;	// Next stage, please!
				end
				
				// Load in the pixel to the right
				if (edge_detection_counter_toggle == 3) begin
					edge_detection_counter_buffer_red[23:16] = data_read[7:0];			// This is the bottom pixel
					edge_detection_counter_buffer_green[23:16] = data_read[15:8];
					edge_detection_counter_buffer_blue[23:16] = data_read[31:24];
					if (edge_detection_main_chunk_already_loaded == 0) begin
						address = edge_detection_counter_tog + (((edge_detector_averaging_window / 2) * 320) + (edge_detector_averaging_window / 2));			// Set next read address (8 down and 8 to the right)
					end else begin
						address = edge_detection_counter_tog - ((((edge_detector_averaging_window / 2) - 1) * 320) + (edge_detector_averaging_window / 2));			// Set next read address (7 up and 8 to the left)
					end
					edge_detection_counter_toggle = edge_detection_counter_toggle + 1;	// Next stage, please!
					edge_detection_x_counter = 0;
					edge_detection_y_counter = 0;
				end
				
				// Load in the pixel to the right
				if (edge_detection_counter_toggle == 2) begin
					edge_detection_counter_buffer_red[15:8] = data_read[7:0];			// This is the rightmost pixel
					edge_detection_counter_buffer_green[15:8] = data_read[15:8];
					edge_detection_counter_buffer_blue[15:8] = data_read[31:24];
					address = edge_detection_counter_tog + 320;			// Set next read address (1 down)
					edge_detection_counter_toggle = edge_detection_counter_toggle + 1;	// Next stage, please!
					edge_detection_x_counter = 0;
					edge_detection_y_counter = 0;
				end
				
				// Load in the first pixel
				if (edge_detection_counter_toggle == 1) begin
					edge_detection_counter_buffer_red[7:0] = data_read[7:0];			// This is the center pixel
					edge_detection_counter_buffer_green[7:0] = data_read[15:8];
					edge_detection_counter_buffer_blue[7:0] = data_read[31:24];
					address = edge_detection_counter_tog + 1;			// Set next read address (1 to the right)
					edge_detection_counter_toggle = edge_detection_counter_toggle + 1;	// Next stage, please!
					edge_detection_x_counter = 0;
					edge_detection_y_counter = 0;
				end
				
				if (edge_detection_counter_togg == 74561) begin		// All done!	It is 74561 because we don't need to process the last 7 lines of the image, as they would just be garbage anyway!
					edge_detection_counter_tog = 0;
					edge_detection_counter_togg = 0;
					edge_detection_counter_toggle = 0;
					edge_detection_done = 1;
					edge_detection_holdoff = 0;
					wren = 0;
				end
				
				if (edge_detection_counter_toggle == 6) begin
					address = edge_detection_counter_togg;
					data_write = edge_detection_counter_temp;
					wren = 1;
				end
				if (edge_detection_counter_toggle == 7) begin
					wren = 0;
					address = edge_detection_counter_tog;
					edge_detection_counter_togg = edge_detection_counter_togg + 1;
					edge_detection_counter_toggle = 1;
				end
				if (edge_detection_counter_toggle > 5) begin
					edge_detection_counter_toggle = edge_detection_counter_toggle + 1;
				end
			end
		end else begin
			edge_detection_done = 0;
			address = 18'bz;
			data_write = 32'bz;
			wren = 1'bz;
		end
	end
	
	reg [7:0] median_filtering_swap_buffer;
	reg [31:0] data_read_sync_median_filtering;
	reg [71:0] median_filtering_counter_buffer_red;
	reg [71:0] median_filtering_counter_buffer_green;
	reg [71:0] median_filtering_counter_buffer_blue;
/*
	// For every pixel, check the 9 pixels around and including it, and find the 'middle' value.
	always @(posedge clk) begin
	//always @(posedge modified_clock) begin
	//always @(posedge clk_div_by_two) begin
		data_read_sync_median_filtering = data_read;
	
		if (enable_median_filtering == 1) begin
			if (median_filtering_holdoff == 0) begin
				wren = 0;
				address = 320;								// Skip the topmost line of the image
				median_filtering_counter_tog = 320;
				median_filtering_holdoff = 1;
			end else begin
				// Load in the first pixel
				if (median_filtering_counter_toggle == 1) begin
					median_filtering_counter_buffer_red[7:0] = data_read_sync_median_filtering[7:0];			// This is the center pixel
					median_filtering_counter_buffer_green[7:0] = data_read_sync_median_filtering[15:8];
					median_filtering_counter_buffer_blue[7:0] = data_read_sync_median_filtering[31:24];
					median_filtering_counter_tog = median_filtering_counter_tog - 1;	// Set next read address (one pixel to the left)
				end

				if (median_filtering_counter_toggle == 2) begin
					median_filtering_counter_buffer_red[15:8] = data_read_sync_median_filtering[7:0];			// This is the left pixel
					median_filtering_counter_buffer_green[15:8] = data_read_sync_median_filtering[15:8];
					median_filtering_counter_buffer_blue[15:8] = data_read_sync_median_filtering[31:24];
					median_filtering_counter_tog = median_filtering_counter_tog + 2;	// Set next read address (two pixels to the right)
				end
	
				if (median_filtering_counter_toggle == 3) begin
					median_filtering_counter_buffer_red[23:16] = data_read_sync_median_filtering[7:0];			// This is the right pixel
					median_filtering_counter_buffer_green[23:16] = data_read_sync_median_filtering[15:8];
					median_filtering_counter_buffer_blue[23:16] = data_read_sync_median_filtering[31:24];
					median_filtering_counter_tog = median_filtering_counter_tog - 320;	// Set next read address (one pixel up)
				end
				
				if (median_filtering_counter_toggle == 4) begin
					median_filtering_counter_buffer_red[31:24] = data_read_sync_median_filtering[7:0];			// This is the top-right pixel
					median_filtering_counter_buffer_green[31:24] = data_read_sync_median_filtering[15:8];
					median_filtering_counter_buffer_blue[31:24] = data_read_sync_median_filtering[31:24];
					median_filtering_counter_tog = median_filtering_counter_tog - 1;	// Set next read address (one pixel to the left)
				end
				
				if (median_filtering_counter_toggle == 5) begin
					median_filtering_counter_buffer_red[39:32] = data_read_sync_median_filtering[7:0];			// This is the top pixel
					median_filtering_counter_buffer_green[39:32] = data_read_sync_median_filtering[15:8];
					median_filtering_counter_buffer_blue[39:32] = data_read_sync_median_filtering[31:24];
					median_filtering_counter_tog = median_filtering_counter_tog - 1;	// Set next read address (one pixel to the left)
				end
				
				if (median_filtering_counter_toggle == 6) begin
					median_filtering_counter_buffer_red[47:40] = data_read_sync_median_filtering[7:0];			// This is the top-left pixel
					median_filtering_counter_buffer_green[47:40] = data_read_sync_median_filtering[15:8];
					median_filtering_counter_buffer_blue[47:40] = data_read_sync_median_filtering[31:24];
					median_filtering_counter_tog = median_filtering_counter_tog + 640;	// Set next read address (two pixels down)
				end
				
				if (median_filtering_counter_toggle == 7) begin
					median_filtering_counter_buffer_red[55:48] = data_read_sync_median_filtering[7:0];			// This is the bottom-left pixel
					median_filtering_counter_buffer_green[55:48] = data_read_sync_median_filtering[15:8];
					median_filtering_counter_buffer_blue[55:48] = data_read_sync_median_filtering[31:24];
					median_filtering_counter_tog = median_filtering_counter_tog + 1;	// Set next read address (one pixel to the right)
				end
				
				if (median_filtering_counter_toggle == 8) begin
					median_filtering_counter_buffer_red[63:56] = data_read_sync_median_filtering[7:0];			// This is the bottom pixel
					median_filtering_counter_buffer_green[63:56] = data_read_sync_median_filtering[15:8];
					median_filtering_counter_buffer_blue[63:56] = data_read_sync_median_filtering[31:24];
					median_filtering_counter_tog = median_filtering_counter_tog + 1;	// Set next read address (one pixel to the right)
				end
				
				if (median_filtering_counter_toggle == 9) begin
					median_filtering_counter_buffer_red[71:64] = data_read_sync_median_filtering[7:0];			// This is the bottom-right pixel
					median_filtering_counter_buffer_green[71:64] = data_read_sync_median_filtering[15:8];
					median_filtering_counter_buffer_blue[71:64] = data_read_sync_median_filtering[31:24];
					median_filtering_counter_tog = median_filtering_counter_tog - 320;	// Set next read address (one pixel up) (this is to put the "cursor" in the correct position for the next pixel!
					
					// Now, since we have all of this data collected (finally!), we can calculate the median of the numbers
					// First the red image...LOTS of processing here!
					if (median_filtering_counter_buffer_red[15:8] > median_filtering_counter_buffer_red[23:16]) begin	// 1,2
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[15:8];
						median_filtering_counter_buffer_red[15:8] = median_filtering_counter_buffer_red[23:16];
						median_filtering_counter_buffer_red[23:16] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_red[39:32] > median_filtering_counter_buffer_red[47:40]) begin	// 4,5
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[39:32];
						median_filtering_counter_buffer_red[39:32] = median_filtering_counter_buffer_red[47:40];
						median_filtering_counter_buffer_red[47:40] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_red[63:56] > median_filtering_counter_buffer_red[71:64]) begin	// 7,8
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[63:56];
						median_filtering_counter_buffer_red[63:56] = median_filtering_counter_buffer_red[71:64];
						median_filtering_counter_buffer_red[71:64] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_red[7:0] > median_filtering_counter_buffer_red[15:8]) begin		// 0,1
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[7:0];
						median_filtering_counter_buffer_red[7:0] = median_filtering_counter_buffer_red[15:8];
						median_filtering_counter_buffer_red[15:8] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_red[31:24] > median_filtering_counter_buffer_red[39:32]) begin	// 3,4
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[31:24];
						median_filtering_counter_buffer_red[31:24] = median_filtering_counter_buffer_red[39:32];
						median_filtering_counter_buffer_red[39:32] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_red[55:48] > median_filtering_counter_buffer_red[63:56]) begin	// 6,7
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[55:48];
						median_filtering_counter_buffer_red[55:48] = median_filtering_counter_buffer_red[63:56];
						median_filtering_counter_buffer_red[63:56] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_red[15:8] > median_filtering_counter_buffer_red[23:16]) begin	// 1,2
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[15:8];
						median_filtering_counter_buffer_red[15:8] = median_filtering_counter_buffer_red[23:16];
						median_filtering_counter_buffer_red[23:16] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_red[39:32] > median_filtering_counter_buffer_red[47:40]) begin	// 4,5
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[39:32];
						median_filtering_counter_buffer_red[39:32] = median_filtering_counter_buffer_red[47:40];
						median_filtering_counter_buffer_red[47:40] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_red[63:56] > median_filtering_counter_buffer_red[71:64]) begin	// 7,8
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[63:56];
						median_filtering_counter_buffer_red[63:56] = median_filtering_counter_buffer_red[71:64];
						median_filtering_counter_buffer_red[71:64] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_red[7:0] > median_filtering_counter_buffer_red[31:24]) begin	// 0,3
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[7:0];
						median_filtering_counter_buffer_red[7:0] = median_filtering_counter_buffer_red[31:24];
						median_filtering_counter_buffer_red[31:24] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_red[47:40] > median_filtering_counter_buffer_red[71:64]) begin	// 5,8
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[47:40];
						median_filtering_counter_buffer_red[47:40] = median_filtering_counter_buffer_red[71:64];
						median_filtering_counter_buffer_red[71:64] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_red[39:32] > median_filtering_counter_buffer_red[63:56]) begin	// 4,7
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[39:32];
						median_filtering_counter_buffer_red[39:32] = median_filtering_counter_buffer_red[63:56];
						median_filtering_counter_buffer_red[63:56] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_red[31:24] > median_filtering_counter_buffer_red[55:48]) begin	// 3,6
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[31:24];
						median_filtering_counter_buffer_red[31:24] = median_filtering_counter_buffer_red[55:48];
						median_filtering_counter_buffer_red[55:48] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_red[15:8] > median_filtering_counter_buffer_red[39:32]) begin	// 1,4
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[15:8];
						median_filtering_counter_buffer_red[15:8] = median_filtering_counter_buffer_red[39:32];
						median_filtering_counter_buffer_red[39:32] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_red[23:16] > median_filtering_counter_buffer_red[47:40]) begin	// 2,5
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[23:16];
						median_filtering_counter_buffer_red[23:16] = median_filtering_counter_buffer_red[47:40];
						median_filtering_counter_buffer_red[47:40] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_red[39:32] > median_filtering_counter_buffer_red[63:56]) begin	// 4,7
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[39:32];
						median_filtering_counter_buffer_red[39:32] = median_filtering_counter_buffer_red[63:56];
						median_filtering_counter_buffer_red[63:56] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_red[39:32] > median_filtering_counter_buffer_red[23:16]) begin	// 4,2
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[39:32];
						median_filtering_counter_buffer_red[39:32] = median_filtering_counter_buffer_red[23:16];
						median_filtering_counter_buffer_red[23:16] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_red[55:48] > median_filtering_counter_buffer_red[39:32]) begin	// 6,4
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[55:48];
						median_filtering_counter_buffer_red[55:48] = median_filtering_counter_buffer_red[39:32];
						median_filtering_counter_buffer_red[39:32] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_red[39:32] > median_filtering_counter_buffer_red[23:16]) begin	// 4,2
						median_filtering_swap_buffer = median_filtering_counter_buffer_red[39:32];
						median_filtering_counter_buffer_red[39:32] = median_filtering_counter_buffer_red[23:16];
						median_filtering_counter_buffer_red[23:16] = median_filtering_swap_buffer;
					end
					// FINALLY DONE WITH THE RED ARRAY!!! YIPPEE!!!
					median_filtering_counter_temp[7:0] = median_filtering_counter_buffer_red[39:32];		// Store the median in the red slot of the data to write
					
					// Next the green image...LOTS of processing here again!
					if (median_filtering_counter_buffer_green[15:8] > median_filtering_counter_buffer_green[23:16]) begin		// 1,2
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[15:8];
						median_filtering_counter_buffer_green[15:8] = median_filtering_counter_buffer_green[23:16];
						median_filtering_counter_buffer_green[23:16] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_green[39:32] > median_filtering_counter_buffer_green[47:40]) begin	// 4,5
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[39:32];
						median_filtering_counter_buffer_green[39:32] = median_filtering_counter_buffer_green[47:40];
						median_filtering_counter_buffer_green[47:40] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_green[63:56] > median_filtering_counter_buffer_green[71:64]) begin	// 7,8
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[63:56];
						median_filtering_counter_buffer_green[63:56] = median_filtering_counter_buffer_green[71:64];
						median_filtering_counter_buffer_green[71:64] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_green[7:0] > median_filtering_counter_buffer_green[15:8]) begin		// 0,1
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[7:0];
						median_filtering_counter_buffer_green[7:0] = median_filtering_counter_buffer_green[15:8];
						median_filtering_counter_buffer_green[15:8] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_green[31:24] > median_filtering_counter_buffer_green[39:32]) begin	// 3,4
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[31:24];
						median_filtering_counter_buffer_green[31:24] = median_filtering_counter_buffer_green[39:32];
						median_filtering_counter_buffer_green[39:32] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_green[55:48] > median_filtering_counter_buffer_green[63:56]) begin	// 6,7
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[55:48];
						median_filtering_counter_buffer_green[55:48] = median_filtering_counter_buffer_green[63:56];
						median_filtering_counter_buffer_green[63:56] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_green[15:8] > median_filtering_counter_buffer_green[23:16]) begin		// 1,2
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[15:8];
						median_filtering_counter_buffer_green[15:8] = median_filtering_counter_buffer_green[23:16];
						median_filtering_counter_buffer_green[23:16] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_green[39:32] > median_filtering_counter_buffer_green[47:40]) begin	// 4,5
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[39:32];
						median_filtering_counter_buffer_green[39:32] = median_filtering_counter_buffer_green[47:40];
						median_filtering_counter_buffer_green[47:40] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_green[63:56] > median_filtering_counter_buffer_green[71:64]) begin	// 7,8
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[63:56];
						median_filtering_counter_buffer_green[63:56] = median_filtering_counter_buffer_green[71:64];
						median_filtering_counter_buffer_green[71:64] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_green[7:0] > median_filtering_counter_buffer_green[31:24]) begin		// 0,3
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[7:0];
						median_filtering_counter_buffer_green[7:0] = median_filtering_counter_buffer_green[31:24];
						median_filtering_counter_buffer_green[31:24] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_green[47:40] > median_filtering_counter_buffer_green[71:64]) begin	// 5,8
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[47:40];
						median_filtering_counter_buffer_green[47:40] = median_filtering_counter_buffer_green[71:64];
						median_filtering_counter_buffer_green[71:64] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_green[39:32] > median_filtering_counter_buffer_green[63:56]) begin	// 4,7
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[39:32];
						median_filtering_counter_buffer_green[39:32] = median_filtering_counter_buffer_green[63:56];
						median_filtering_counter_buffer_green[63:56] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_green[31:24] > median_filtering_counter_buffer_green[55:48]) begin	// 3,6
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[31:24];
						median_filtering_counter_buffer_green[31:24] = median_filtering_counter_buffer_green[55:48];
						median_filtering_counter_buffer_green[55:48] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_green[15:8] > median_filtering_counter_buffer_green[39:32]) begin		// 1,4
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[15:8];
						median_filtering_counter_buffer_green[15:8] = median_filtering_counter_buffer_green[39:32];
						median_filtering_counter_buffer_green[39:32] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_green[23:16] > median_filtering_counter_buffer_green[47:40]) begin	// 2,5
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[23:16];
						median_filtering_counter_buffer_green[23:16] = median_filtering_counter_buffer_green[47:40];
						median_filtering_counter_buffer_green[47:40] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_green[39:32] > median_filtering_counter_buffer_green[63:56]) begin	// 4,7
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[39:32];
						median_filtering_counter_buffer_green[39:32] = median_filtering_counter_buffer_green[63:56];
						median_filtering_counter_buffer_green[63:56] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_green[39:32] > median_filtering_counter_buffer_green[23:16]) begin	// 4,2
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[39:32];
						median_filtering_counter_buffer_green[39:32] = median_filtering_counter_buffer_green[23:16];
						median_filtering_counter_buffer_green[23:16] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_green[55:48] > median_filtering_counter_buffer_green[39:32]) begin	// 6,4
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[55:48];
						median_filtering_counter_buffer_green[55:48] = median_filtering_counter_buffer_green[39:32];
						median_filtering_counter_buffer_green[39:32] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_green[39:32] > median_filtering_counter_buffer_green[23:16]) begin	// 4,2
						median_filtering_swap_buffer = median_filtering_counter_buffer_green[39:32];
						median_filtering_counter_buffer_green[39:32] = median_filtering_counter_buffer_green[23:16];
						median_filtering_counter_buffer_green[23:16] = median_filtering_swap_buffer;
					end
					// FINALLY DONE WITH THE GREEN ARRAY!!! YIPPEE!!!
					median_filtering_counter_temp[15:8] = median_filtering_counter_buffer_green[39:32];		// Store the median in the green slot of the data to write
					
					// Finally the blue image...again, LOTS of processing here!
					if (median_filtering_counter_buffer_blue[15:8] > median_filtering_counter_buffer_blue[23:16]) begin	// 1,2
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[15:8];
						median_filtering_counter_buffer_blue[15:8] = median_filtering_counter_buffer_blue[23:16];
						median_filtering_counter_buffer_blue[23:16] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_blue[39:32] > median_filtering_counter_buffer_blue[47:40]) begin	// 4,5
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[39:32];
						median_filtering_counter_buffer_blue[39:32] = median_filtering_counter_buffer_blue[47:40];
						median_filtering_counter_buffer_blue[47:40] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_blue[63:56] > median_filtering_counter_buffer_blue[71:64]) begin	// 7,8
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[63:56];
						median_filtering_counter_buffer_blue[63:56] = median_filtering_counter_buffer_blue[71:64];
						median_filtering_counter_buffer_blue[71:64] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_blue[7:0] > median_filtering_counter_buffer_blue[15:8]) begin		// 0,1
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[7:0];
						median_filtering_counter_buffer_blue[7:0] = median_filtering_counter_buffer_blue[15:8];
						median_filtering_counter_buffer_blue[15:8] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_blue[31:24] > median_filtering_counter_buffer_blue[39:32]) begin	// 3,4
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[31:24];
						median_filtering_counter_buffer_blue[31:24] = median_filtering_counter_buffer_blue[39:32];
						median_filtering_counter_buffer_blue[39:32] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_blue[55:48] > median_filtering_counter_buffer_blue[63:56]) begin	// 6,7
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[55:48];
						median_filtering_counter_buffer_blue[55:48] = median_filtering_counter_buffer_blue[63:56];
						median_filtering_counter_buffer_blue[63:56] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_blue[15:8] > median_filtering_counter_buffer_blue[23:16]) begin	// 1,2
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[15:8];
						median_filtering_counter_buffer_blue[15:8] = median_filtering_counter_buffer_blue[23:16];
						median_filtering_counter_buffer_blue[23:16] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_blue[39:32] > median_filtering_counter_buffer_blue[47:40]) begin	// 4,5
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[39:32];
						median_filtering_counter_buffer_blue[39:32] = median_filtering_counter_buffer_blue[47:40];
						median_filtering_counter_buffer_blue[47:40] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_blue[63:56] > median_filtering_counter_buffer_blue[71:64]) begin	// 7,8
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[63:56];
						median_filtering_counter_buffer_blue[63:56] = median_filtering_counter_buffer_blue[71:64];
						median_filtering_counter_buffer_blue[71:64] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_blue[7:0] > median_filtering_counter_buffer_blue[31:24]) begin	// 0,3
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[7:0];
						median_filtering_counter_buffer_blue[7:0] = median_filtering_counter_buffer_blue[31:24];
						median_filtering_counter_buffer_blue[31:24] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_blue[47:40] > median_filtering_counter_buffer_blue[71:64]) begin	// 5,8
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[47:40];
						median_filtering_counter_buffer_blue[47:40] = median_filtering_counter_buffer_blue[71:64];
						median_filtering_counter_buffer_blue[71:64] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_blue[39:32] > median_filtering_counter_buffer_blue[63:56]) begin	// 4,7
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[39:32];
						median_filtering_counter_buffer_blue[39:32] = median_filtering_counter_buffer_blue[63:56];
						median_filtering_counter_buffer_blue[63:56] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_blue[31:24] > median_filtering_counter_buffer_blue[55:48]) begin	// 3,6
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[31:24];
						median_filtering_counter_buffer_blue[31:24] = median_filtering_counter_buffer_blue[55:48];
						median_filtering_counter_buffer_blue[55:48] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_blue[15:8] > median_filtering_counter_buffer_blue[39:32]) begin	// 1,4
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[15:8];
						median_filtering_counter_buffer_blue[15:8] = median_filtering_counter_buffer_blue[39:32];
						median_filtering_counter_buffer_blue[39:32] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_blue[23:16] > median_filtering_counter_buffer_blue[47:40]) begin	// 2,5
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[23:16];
						median_filtering_counter_buffer_blue[23:16] = median_filtering_counter_buffer_blue[47:40];
						median_filtering_counter_buffer_blue[47:40] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_blue[39:32] > median_filtering_counter_buffer_blue[63:56]) begin	// 4,7
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[39:32];
						median_filtering_counter_buffer_blue[39:32] = median_filtering_counter_buffer_blue[63:56];
						median_filtering_counter_buffer_blue[63:56] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_blue[39:32] > median_filtering_counter_buffer_blue[23:16]) begin	// 4,2
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[39:32];
						median_filtering_counter_buffer_blue[39:32] = median_filtering_counter_buffer_blue[23:16];
						median_filtering_counter_buffer_blue[23:16] = median_filtering_swap_buffer;
					end
					if (median_filtering_counter_buffer_blue[55:48] > median_filtering_counter_buffer_blue[39:32]) begin	// 6,4
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[55:48];
						median_filtering_counter_buffer_blue[55:48] = median_filtering_counter_buffer_blue[39:32];
						median_filtering_counter_buffer_blue[39:32] = median_filtering_swap_buffer;
					end
					// ---
					if (median_filtering_counter_buffer_blue[39:32] > median_filtering_counter_buffer_blue[23:16]) begin	// 4,2
						median_filtering_swap_buffer = median_filtering_counter_buffer_blue[39:32];
						median_filtering_counter_buffer_blue[39:32] = median_filtering_counter_buffer_blue[23:16];
						median_filtering_counter_buffer_blue[23:16] = median_filtering_swap_buffer;
					end
					// FINALLY DONE WITH THE BLUE ARRAY!!! YIPPEE!!!
					median_filtering_counter_temp[31:24] = median_filtering_counter_buffer_blue[39:32];		// Store the median in the blue slot of the data to write
					
					// Make sure none of our pixels are set to 255, as 255 is a reserved value for "edge found".
					if (median_filtering_counter_temp[7:0] == 255) begin
						median_filtering_counter_temp[7:0] = 254;
					end
					if (median_filtering_counter_temp[15:8] == 255) begin
						median_filtering_counter_temp[15:8] = 254;
					end
					if (median_filtering_counter_temp[31:24] == 255) begin
						median_filtering_counter_temp[31:24] = 254;
					end
				end

				if (median_filtering_counter_togg == 76481) begin		// All done!	It is 76481 because we don't need to process the last line of the image, as it would just be garbage anyway!
					median_filtering_coun = 0;
					median_filtering_counter_tog = 0;
					median_filtering_counter_togg = 0;
					median_filtering_counter_toggle = 0;
					median_filtering_done = 1;
					median_filtering_holdoff = 0;
					wren = 0;
				end

				median_filtering_counter_toggle = median_filtering_counter_toggle + 1;
				if (median_filtering_counter_toggle < 10) begin
					address = median_filtering_counter_tog;
					wren = 0;
				end
				if (median_filtering_counter_toggle == 10) begin
					address = median_filtering_counter_togg + 76801;
					data_write = median_filtering_counter_temp;
					wren = 1;
				end
				if (median_filtering_counter_toggle == 11) begin
					wren = 0;
					address = median_filtering_counter_tog;
					median_filtering_counter_togg = median_filtering_counter_togg + 1;
					median_filtering_counter_toggle = 0;
				end
			end
		end else begin
			median_filtering_done = 0;
			address = 18'bz;
			data_write = 32'bz;
			wren = 1'bz;
		end
	end
*/
	reg thisiswhite = 0;
	reg pleasedelayhere = 0;

	// Main data processor
	//always @(posedge modified_clock) begin
	//always @(posedge clk) begin
	//always @(posedge clk_div_by_two) begin
	always @(negedge clk_div_by_two) begin
	//always @(posedge camera_data_pclk) begin
		data_read_sync = data_read;
		
		if ((camera_transfer_done == 1) && (processing_done_internal == 0)) begin
		//if (camera_transfer_done == 1) begin
			if (i_need_the_serial_transmitter_now == 0) begin
				processing_done = 0;
				
				//leds[5:0] = current_main_processing_state + 1;
	
				if (current_main_processing_state == 0) begin
					//leds[5] = 1;
					//enable_median_filtering = 1;
					//if (median_filtering_done == 1) begin
					//	enable_median_filtering = 0;
						current_main_processing_state = 1;
					//end
				end					
				
				if (current_main_processing_state == 1) begin
					//leds[5] = 1;
					enable_edge_detection = 1;
					if (edge_detection_done == 1) begin
						enable_edge_detection = 0;
						current_main_processing_state = 2;
					end
				end
				
				if (current_main_processing_state == 2) begin
					//leds[5] = 1;
					enable_x_pixel_filling = 1;
					if (x_pixel_filling_done == 1) begin
						enable_x_pixel_filling = 0;
						current_main_processing_state = 3;
					end
				end
				
				if (current_main_processing_state == 3) begin
					//leds[5] = 1;
					enable_y_pixel_filling = 1;
					if (y_pixel_filling_done == 1) begin
						enable_y_pixel_filling = 0;
						current_main_processing_state = 5;
					end
				end		
				
				if (current_main_processing_state == 4) begin
					current_main_processing_state = 5;
				end
				
				/*if (current_main_processing_state == 4) begin
					//leds[5] = 1;
					enable_border_drawing = 1;
					if (border_drawing_done == 1) begin
						enable_border_drawing = 0;
						current_main_processing_state = 5;
					end
				end		*/
				
				if (current_main_processing_state == 5) begin
					//leds[5] = 1;
					enable_blob_extraction = 1;
					if (blob_extraction_done == 1) begin
						enable_blob_extraction = 0;
						current_main_processing_state = 6;
					end
				end
				
				if (current_main_processing_state == 6) begin
					//leds[5] = 1;
					enable_tracking_output = 1;
					if (tracking_output_done == 1) begin
						enable_tracking_output = 0;
						current_main_processing_state = 7;
					end
					
					leds[0] = 0;
					leds[1] = 0;
					leds[2] = 0;		
					leds[3] = 0;
					leds[4] = 0;
					leds[5] = 0;					
				end
				
				if (current_main_processing_state == 7) begin
					first_x_centroids_array[0] = x_centroids_array[0];
					first_y_centroids_array[0] = y_centroids_array[0];
					first_s_centroids_array[0] = s_centroids_array[0];
					first_x_centroids_array[1] = x_centroids_array[1];
					first_y_centroids_array[1] = y_centroids_array[1];
					first_s_centroids_array[1] = s_centroids_array[1];
					first_x_centroids_array[2] = x_centroids_array[2];
					first_y_centroids_array[2] = y_centroids_array[2];
					first_s_centroids_array[2] = s_centroids_array[2];
					first_x_centroids_array[3] = x_centroids_array[3];
					first_y_centroids_array[3] = y_centroids_array[3];
					first_s_centroids_array[3] = s_centroids_array[3];
					first_x_centroids_array[4] = x_centroids_array[4];
					first_y_centroids_array[4] = y_centroids_array[4];
					first_s_centroids_array[4] = s_centroids_array[4];
					first_x_centroids_array[5] = x_centroids_array[5];
					first_y_centroids_array[5] = y_centroids_array[5];
					first_s_centroids_array[5] = s_centroids_array[5];
					
					if (tracking_output_blob_sizes[0] != 0) leds[0] = 1;
					if (tracking_output_blob_sizes[1] != 0) leds[1] = 1;
					if (tracking_output_blob_sizes[2] != 0) leds[2] = 1;
					if (tracking_output_blob_sizes[3] != 0) leds[3] = 1;
					if (tracking_output_blob_sizes[4] != 0) leds[4] = 1;
					if (tracking_output_blob_sizes[5] != 0) leds[5] = 1;
					
					if (tracking_output_done == 0) begin		// Wait for the module to reset before continuing
						current_main_processing_state = 8;
						pleasedelayhere = 1;
					end
				end
				
				if (current_main_processing_state == 8) begin
					if (pleasedelayhere == 0) begin
						//leds[5] = 1;
						enable_tracking_output = 1;
						if (tracking_output_done == 1) begin
							enable_tracking_output = 0;
							current_main_processing_state = 9;
						end
					end
					
					if (pleasedelayhere == 1) begin
						pleasedelayhere = 0;
					end
				end
				
				if (current_main_processing_state == 9) begin
					if (run_frame_dump_internal == 1) begin
						current_main_processing_state = 10;
					end
						
					if (run_single_shot_test_internal == 1) begin
						current_main_processing_state = 11;
					end
						
					if (run_online_recognition_internal == 1) begin
						current_main_processing_state = 12;
					end
						
					if ((run_frame_dump_internal == 0) && (run_single_shot_test_internal == 0) && (run_online_recognition_internal == 0)) begin
						// Run again!
						current_main_processing_state = 0;
						address = 18'bz;
						data_write = 32'bz;
						wren = 1'bz;
						current_main_processing_state = 0;
						processing_done_internal = 1;
						
						//processing_ended = 1;
					end
				end
	
				if (current_main_processing_state == 10) begin
					leds[7] = 1;
					serial_output_enabled = 1;
					
					if (serial_output_holdoff == 0) begin
						serial_output_holdoff = 1;
						//address = 0;
						address = 76801;
						//address = 153602;
						//address = 230403;
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
	
								wren = 0;				// Read data from RAM
								//address = serial_output_index_mem + 0;
								address = serial_output_index_mem + 76801;
								//address = serial_output_index_mem + 153602;
								//address = serial_output_index_mem + 230403;
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
									current_main_processing_state = 0;
									address = 18'bz;
									data_write = 32'bz;
									wren = 1'bz;
									processing_done_internal = 1;
								end
							end
						end
					end
				end
				
				if (current_main_processing_state == 11) begin
					leds[7] = 1;
					serial_output_enabled = 1;
					
					if (serial_output_holdoff == 0) begin
						serial_output_holdoff = 1;
						address = 0;
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
									wren = 0;
									address = ((data_read_sync * 3) + 200000);
									//address = address + 76801;
									
									if (data_read_sync == 1) begin
										thisiswhite = 1;
									end else begin
										thisiswhite = 0;
									end
								end
								
								if (serial_output_index_toggle == 1) begin
									// Do nothing
									wren = 0;
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
									wren = 0;				// Read data from RAM
									address = serial_output_index_mem + 0;
									//address = serial_output_index_mem + 76801;
									//address = serial_output_index_mem + 153602;
									//address = serial_output_index_mem + 230403;
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
									current_main_processing_state = 0;
									address = 18'bz;
									data_write = 32'bz;
									wren = 1'bz;
									processing_done_internal = 1;
								end
							end
						end
					end
				end
				
				if (current_main_processing_state == 12) begin
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
									TxD_data = first_x_centroids_array[0];
								end
										
								if (serial_output_index_toggle == 3) begin
									TxD_data = first_y_centroids_array[0];
								end
										
								if (slide_switches[0] == 1) begin
									if (serial_output_index_toggle == 4) begin
										TxD_data = first_x_centroids_array[1];
									end
										
									if (serial_output_index_toggle == 5) begin
										TxD_data = first_y_centroids_array[1];
									end
											
									if (serial_output_index_toggle == 6) begin
										TxD_data = first_x_centroids_array[2];
									end
										
									if (serial_output_index_toggle == 7) begin
										TxD_data = first_y_centroids_array[2];
									end
								end else begin
									if (serial_output_index_toggle == 4) begin
										serial_output_index_toggle = 8;
									end
								end
										
								if (serial_output_index_toggle == 8) begin
									TxD_data = first_x_centroids_array[3];
								end
										
								if (serial_output_index_toggle == 9) begin
									TxD_data = first_y_centroids_array[3];
								end
										
								if (serial_output_index_toggle == 10) begin
									TxD_data = first_x_centroids_array[4];
								end
								
								if (serial_output_index_toggle == 11) begin
									TxD_data = first_y_centroids_array[4];
								end
										
								if (slide_switches[0] == 1) begin
									if (serial_output_index_toggle == 12) begin
										TxD_data = first_x_centroids_array[5];
									end
									
									if (serial_output_index_toggle == 13) begin
										TxD_data = first_y_centroids_array[5];
									end
								end else begin
									if (serial_output_index_toggle == 12) begin
										serial_output_index_toggle = 14;
									end
								end
										
								// ---  Second set of centroids
										
								if (serial_output_index_toggle == 14) begin
									TxD_data = x_centroids_array[0];
								end
										
								if (serial_output_index_toggle == 15) begin
									TxD_data = y_centroids_array[0];
								end
										
								if (slide_switches[0] == 1) begin
									if (serial_output_index_toggle == 16) begin
										TxD_data = x_centroids_array[1];
									end
											
									if (serial_output_index_toggle == 17) begin
										TxD_data = y_centroids_array[1];
									end
											
									if (serial_output_index_toggle == 18) begin
										TxD_data = x_centroids_array[2];
									end
											
									if (serial_output_index_toggle == 19) begin
										TxD_data = y_centroids_array[2];
									end
								end else begin
									if (serial_output_index_toggle == 16) begin
										serial_output_index_toggle = 20;
									end
								end
										
								if (serial_output_index_toggle == 20) begin
									TxD_data = x_centroids_array[3];
								end
										
								if (serial_output_index_toggle == 21) begin
									TxD_data = y_centroids_array[3];
								end
										
								if (serial_output_index_toggle == 22) begin
									TxD_data = x_centroids_array[4];
								end
										
								if (serial_output_index_toggle == 23) begin
									TxD_data = y_centroids_array[4];
								end
										
								if (slide_switches[0] == 1) begin
									if (serial_output_index_toggle == 24) begin
										TxD_data = x_centroids_array[5];
									end
											
									if (serial_output_index_toggle == 25) begin
										TxD_data = y_centroids_array[5];
									end
								end else begin
									if (serial_output_index_toggle == 24) begin
										serial_output_index_toggle = 26;
									end
								end
								
								// -- Now the size data
								// -- First ones
								
								if (serial_output_index_toggle == 26) begin
									TxD_data = first_s_centroids_array[0][15:8];
								end
								
								if (serial_output_index_toggle == 27) begin
									TxD_data = first_s_centroids_array[0][7:0];
								end
								
								if (serial_output_index_toggle == 28) begin
									TxD_data = first_s_centroids_array[1][15:8];
								end
								
								if (serial_output_index_toggle == 29) begin
									TxD_data = first_s_centroids_array[1][7:0];
								end
								
								if (serial_output_index_toggle == 30) begin
									TxD_data = first_s_centroids_array[2][15:8];
								end
								
								if (serial_output_index_toggle == 31) begin
									TxD_data = first_s_centroids_array[2][7:0];
								end
								
								if (serial_output_index_toggle == 32) begin
									TxD_data = first_s_centroids_array[3][15:8];
								end
								
								if (serial_output_index_toggle == 33) begin
									TxD_data = first_s_centroids_array[3][7:0];
								end
								
								if (serial_output_index_toggle == 34) begin
									TxD_data = first_s_centroids_array[4][15:8];
								end
								
								if (serial_output_index_toggle == 35) begin
									TxD_data = first_s_centroids_array[4][7:0];
								end
								
								if (serial_output_index_toggle == 36) begin
									TxD_data = first_s_centroids_array[5][15:8];
								end
								
								if (serial_output_index_toggle == 37) begin
									TxD_data = first_s_centroids_array[5][7:0];
								end
								
								// -- Last ones
								if (serial_output_index_toggle == 38) begin
									TxD_data = s_centroids_array[0][15:8];
								end
								
								if (serial_output_index_toggle == 39) begin
									TxD_data = s_centroids_array[0][7:0];
								end
								
								if (serial_output_index_toggle == 40) begin
									TxD_data = s_centroids_array[1][15:8];
								end
								
								if (serial_output_index_toggle == 41) begin
									TxD_data = s_centroids_array[1][7:0];
								end
								
								if (serial_output_index_toggle == 42) begin
									TxD_data = s_centroids_array[2][15:8];
								end
								
								if (serial_output_index_toggle == 43) begin
									TxD_data = s_centroids_array[2][7:0];
								end
								
								if (serial_output_index_toggle == 44) begin
									TxD_data = s_centroids_array[3][15:8];
								end
								
								if (serial_output_index_toggle == 45) begin
									TxD_data = s_centroids_array[3][7:0];
								end
								
								if (serial_output_index_toggle == 46) begin
									TxD_data = s_centroids_array[4][15:8];
								end
								
								if (serial_output_index_toggle == 47) begin
									TxD_data = s_centroids_array[4][7:0];
								end
								
								if (serial_output_index_toggle == 48) begin
									TxD_data = s_centroids_array[5][15:8];
								end
								
								if (serial_output_index_toggle == 49) begin
									TxD_data = s_centroids_array[5][7:0];
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
		
									address = 18'bz;
									data_write = 32'bz;
									wren = 1'bz;
									current_main_processing_state = 0;
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
		end else begin
			if ((processing_done_internal == 1) && (camera_transfer_done == 1)) begin
				processing_done = 1;
			end
			if ((processing_done_internal == 1) && (camera_transfer_done == 0)) begin
				processing_done_internal = 0;
			end
		end
	end

	// Camera data input processor
	//always @(posedge camera_data_pclk) begin
	always @(negedge camera_data_pclk) begin
		databuffer = camera_data_port;
		
		if ((processing_done == 1) && (camera_transfer_done_internal == 0) && (startup_sequencer[5] == 1)) begin
			camera_transfer_done = 0;

			if ((current_processing_state == 0) && (camera_data_dma_enable == 0)) begin		// Only run this ONCE per loop!
				run_frame_dump_internal = 0;
				run_single_shot_test_internal = 0;
				run_online_recognition_internal = 0;
				
				if (run_frame_dump == 1) begin
					camera_data_dma_enable = 1;
					run_frame_dump_internal = 1;
				end
				
				if (run_single_shot_test == 1) begin
					camera_data_dma_enable = 1;
					run_single_shot_test_internal = 1;
				end
				
				if (run_online_recognition == 1) begin
					camera_data_dma_enable = 1;
					run_online_recognition_internal = 1;
				end
			end

			if (current_processing_state != 0) begin
				// Other states enabled here, until the end of the state machine where it is then reset to 0.
				if (current_processing_state == 1) begin
					processing_started = 0;				// We only need to pulse this, not keep it 1 all the time!
					current_processing_state = 0;		// This is set to whatever the next stage is, in this case we just go grab another image (0)
					address = 18'bz;
					data_write = 32'bz;
					wren = 1'bz;
					camera_transfer_done_internal = 1;
				end
			end

			// Capture a 320 x 240 image if enabled (8-bit tricolor)
			if (camera_data_dma_enable == 1) begin
				processing_started = 1;
				leds[6] = 1;
				if (camera_vsync_detected == 1) begin
					if (camera_data_href == 1) begin
						if (camera_toggle == 0) begin
							wren = 0;
							databuffer_mem[31:16] = databuffer;
						end
						if (camera_toggle == 1) begin
							databuffer_mem[15:0] = databuffer;
							camera_memory_address = camera_memory_address + 1;
							address = camera_memory_address;
							data_write = databuffer_mem;
							wren = 1;				// Commit the data to RAM
						end

						camera_toggle = camera_toggle + 1;
						if (camera_toggle > 1) begin
							camera_toggle = 0;
						end
						if (camera_memory_address >= 153601) begin
							leds[6] = 0;
							wren = 0;
							camera_vsync_detected = 0;
							camera_toggle = 0;
							camera_data_dma_enable = 0;
							camera_memory_address = 76801;
							current_processing_state = 1;
						end
					end
				end else begin
					if (camera_data_vsync == 1) begin
						camera_vsync_detected = 1;
					end
				end
			end else begin
				camera_vertical_address = 0;
				camera_horizontal_address = 0;
				camera_memory_address = 0;
				camera_vsync_detected = 0;
				camera_toggle = 0;
			end
		end else begin
			if ((camera_transfer_done_internal == 1) && (processing_done == 1)) begin
				camera_transfer_done = 1;
			end
			if ((camera_transfer_done_internal == 1) && (processing_done == 0)) begin
				camera_transfer_done_internal = 0;
			end
		end
	end

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
					if (current_main_processing_state < 9) begin
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
							end
						end else begin							
							if (next_byte_is_command == 3) begin
								if ((next_byte_is_command_pev_command > 90) && (next_byte_is_command_pev_command < 140)) begin
									// Blue
									primary_color_slots[((next_byte_is_command_pev_command / 8) - 11)][next_byte_is_command_pev_command[2:0] - 3][23:16] = serial_command_buffer;
									next_byte_is_command = 0;
								end
							end
							
							if (next_byte_is_command == 2) begin
								// Color slot modify requests
								if ((next_byte_is_command_pev_command > 90) && (next_byte_is_command_pev_command < 140)) begin
									// Green
									primary_color_slots[((next_byte_is_command_pev_command / 8) - 11)][next_byte_is_command_pev_command[2:0] - 3][15:8] = serial_command_buffer;
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
									primary_color_slots[((next_byte_is_command_pev_command / 8) - 11)][next_byte_is_command_pev_command[2:0] - 3][7:0] = serial_command_buffer;
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