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
	output TxD_primary,
	output TxD_secondary,

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

	input RxD_primary,
	input RxD_secondary,

	input wire [7:0] slide_switches,

	// ddr i/o
	output wire dram_ck,
	output wire dram_ck_n,
	output wire dram_cke,
	output wire dram_ras_n,
	output wire dram_cas_n,
	output wire dram_we_n,
	output wire dram_dm,
	output wire dram_udm,
	inout dram_dqs,
	inout dram_udqs,
	output wire [1:0] dram_ba,
	output wire [12:0] dram_a,
	inout [15:0] dram_dq,
//	output wire c3_calib_done,
//	output wire c3_clk0,
//	output wire c3_rst0,
	inout rzq,
	
	// Camera signals
	input wire [11:0] camera_data_port,	//connected
	input wire camera_data_href,	//connected
	input wire camera_data_vsync,	//connected
	input wire camera_data_pclk,	
	output wire camera_data_extclk, 
	input wire camera_data_strobe,
	output wire camera_data_trigger,
	output wire camera_data_standby,
	//signals below were associated with I2C modue in FII design
	output wire camera_data_scl,
	inout wire camera_data_sda,
	output wire camera_data_oe,
	output wire camera_data_saddr,
	output reg camera_data_reset

	, output reg modified_clock_debug
	, output reg modified_clock_sram_debug
	, output reg modified_clock_fast_debug
	, output wire global_pause	//comes from ddr memory, goes to all modules
	);

	wire c3_clk0;
	wire c3_rst0;
	wire c3_calib_done;
	
	wire main_system_clock;
	wire main_system_clock_stable;
	
	// '<=' is a nonblocking set operation (like '=') 

	//parameter InternalClkFrequency = 6250000;	// 6.25MHz
	//parameter InternalClkFrequency = 6666666;	// 6.66MHz
	//parameter InternalClkFrequency = 10000000;	// 10MHz
	parameter InternalClkFrequency = 12500000;	// 12.5MHz
	//parameter InternalClkFrequency = 13333333;	// 13.33MHz
	//parameter InternalClkFrequency = 20000000;	// 20MHz
	//parameter InternalClkFrequency = 50000000;	// 50MHz
	//parameter InternalClkFrequency = 66666666;	// 66MHz
	//parameter InternalClkFrequency = 70000000;	// 70MHz
	//parameter I2ClkCyclesToWait = (InternalClkFrequency / 100000);
	parameter I2ClkCyclesToWait = (InternalClkFrequency / 10000);
	//parameter I2ClkCyclesToWait = (InternalClkFrequency / 1000);
	//parameter I2ClkCyclesToWait = (InternalClkFrequency / 100);
	//parameter I2ClkCyclesToWait = (InternalClkFrequency / 1);

	parameter MemoryToSystemClockRatio = 8;	// Ratio of the memory controller clock to the main system clock

	wire TxD;
	assign TxD_secondary = TxD;
	assign TxD_primary = TxD;
	
	wire RxD;
	assign RxD = (slide_switches[5])?RxD_secondary:RxD_primary;

	wire clk;
	(* KEEP = "TRUE" *) wire modified_clock;
	(* KEEP = "TRUE" *) wire modified_clock_inv;
	(* KEEP = "TRUE" *) wire modified_clock_sram;
	(* KEEP = "TRUE" *) wire modified_clock_fast;
	(* KEEP = "TRUE" *) wire modified_clock_fast_inv;

	always @(posedge modified_clock) begin
		modified_clock_debug = ~modified_clock_debug;
	end

	always @(posedge modified_clock_sram) begin
		modified_clock_sram_debug = ~modified_clock_sram_debug;
	end

	always @(posedge modified_clock_fast) begin
		modified_clock_fast_debug = ~modified_clock_fast_debug;
	end
	
	reg serial_output_holdoff = 0;

	reg [23:0] cnt;
	reg [24:0] cnt2;
	reg [7:0] leds;		// Give myself an LED register
	wire [7:0] sseg;
	wire [3:0] cseg;
	reg [7:0] temp1;		// Temporary data storage

	wire dcm_locked;
	wire dcm_locked_sram;
	wire all_dcms_locked;

	wire wren;
	wire [17:0] address;
	wire [31:0] data_write;
	wire [31:0] data_read;

	reg [7:0] delay_loop = 0;

	wire [18:0] camera_data_address;
	
	reg processing_done = 1;

	reg processing_done_internal = 0;

	parameter BUFFER0_OFFSET = 0;
	parameter BUFFER1_OFFSET = 76801;
	parameter BUFFER2_OFFSET = 153602;
	parameter BUFFER3_OFFSET = 230403;

	parameter ImageBufferRGB = BUFFER1_OFFSET;
	parameter ImageBufferHSV = BUFFER2_OFFSET;

	parameter ImageWidth = 320;
	parameter ImageHeight = 240;
	parameter BlobStorageOffset = BUFFER3_OFFSET;	// used in blob_extraction and blob_sorting modules

	reg [17:0] base_image_buffer_pointer = ImageBufferRGB;

	//--------------------------------------------------------------------------
	// Auxiliary clock generation
	//--------------------------------------------------------------------------
	(* KEEP = "TRUE" *) wire modified_clock_div_by_two;
	wire clk_div_by_two;

	assign clk = modified_clock;
	assign clk_div_by_two = modified_clock_div_by_two;
	
	reg clk_div_by_four = 0;
	
	always @(posedge clk_div_by_two) begin
		clk_div_by_four = !clk_div_by_four;
	end

	//--------------------------------------------------------------------------
	// Module Instantiations
	//--------------------------------------------------------------------------
	
	//enable / dones
	reg enable_memory_blanking = 0;
	wire memory_blanking_done;

	reg enable_camera_capture = 0;
	wire camera_capture_done;

	reg enable_median_filtering = 0;
	reg median_filtering_done = 0;

	reg enable_rgb_to_hsv = 0;
	wire rgb_to_hsv_done;
	
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
	
	reg enable_blob_sorting = 0;
	wire blob_sorting_done;
	
	reg enable_tracking_output = 0;
	wire tracking_output_done;
	
	reg enable_serial_output = 0;
	reg serial_output_done = 0;


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
	wire [15:0] sram_debug1;
	wire [15:0] sram_debug2;
	wire mem_read_error;
	wire memory_controller_ready;

// 	wire global_pause;	//comes from ddr memory, goes to all modules

	wire [7:0] modified_clock_phase;

	mem_manager #(
		.MemoryToSystemClockRatio(MemoryToSystemClockRatio)
		)
		mem_manager(
		.modified_clock_sram(modified_clock_sram),
		.clk(modified_clk),
		.clk_fast(modified_clock_fast),
		.clk_sync(modified_clock_phase),
		.crystal_clk(crystal_clk),
		.all_dcms_locked(all_dcms_locked),
		.pause(global_pause),
		.address(address), 
		.wren(wren), 
		.data_write(data_write), 
		.data_read(data_read),
		// DDR SDRAM external signals
		.dram_dq(dram_dq),		// INOUT
		.dram_a(dram_a),  		// OUTPUT
		.dram_ba(dram_ba),		// OUTPUT
		.dram_ras_n(dram_ras_n),	// OUTPUT
		.dram_cas_n(dram_cas_n),	// OUTPUT
		.dram_we_n (dram_we_n), 	// OUTPUT
		.dram_cke(dram_cke), 		// OUTPUT
		.dram_ck(dram_ck), 		// OUTPUT
		.dram_ck_n(dram_ck_n),		// OUTPUT 
		.dram_dqs(dram_dqs),		// OUTPUT
		.dram_udqs(dram_udqs),    	// INOUT | for X16 parts
		.dram_udm(dram_udm),     	// OUTPUT | for X16 parts
		.dram_dm(dram_dm),		// OUTPUT
		.rzq(rzq),
		.controller_ready(memory_controller_ready),
		.debug0(sram_debug0),
		.debug1(sram_debug1),
		.debug2(sram_debug2),
		.main_system_clock(main_system_clock),
		.main_system_clock_stable(main_system_clock_stable),
		.read_error(mem_read_error)
		);

	//------MEMORY BLANKING module
	wire wren_memory_blanking;
	wire [17:0] address_memory_blanking;
	wire [31:0] data_write_memory_blanking;
	
	memory_blanking memory_blanking(
		.clk(clk),
		.pause(global_pause),
		.address(address_memory_blanking),
		.data_write(data_write_memory_blanking),
		.wren(wren_memory_blanking),
		.data_read(data_read),
		.enable(enable_memory_blanking),
		.done(memory_blanking_done)
		);

	//------RGB TO HSV module
	wire wren_rgb_to_hsv;
	wire [17:0] address_rgb_to_hsv;
	wire [31:0] data_write_rgb_to_hsv;

	convert_rgb_to_hsv convert_rgb_to_hsv(
		.clk(clk),
		.pause(global_pause),
		.address(address_rgb_to_hsv),
		.data_write(data_write_rgb_to_hsv),
		.wren(wren_rgb_to_hsv),
		.data_read(data_read),
		.enable(enable_rgb_to_hsv),
		.done(rgb_to_hsv_done)
		);
	
	//------CAMERA CLOCK MANAGER module
	wire camera_dcm_locked;
	
	camera_clock_manager_v2 camera_clock_manager(
		.input_clk(main_system_clock),		//CLKIN
		.main_camera_clk(camera_data_extclk),	//CLKFX
		.camera_dcm_locked(camera_dcm_locked)	//LOCKED
		);
	
	//------CAMERA CAPTURE module
	wire wren_camera_capture;
	wire [17:0] address_camera_capture;
	wire [31:0] data_write_camera_capture;
	reg [17:0] startup_sequencer = 0;

	wire [19:0] camera_debug_current_address;
	wire [18:0] camera_debug_current_address_module;
	wire [8:0] camera_fifo_debug;
	
	camera_module_v2 camera_capture(
		.clk(clk),
		.pause(global_pause),
		//.startup_sequencer(startup_sequencer),
		.ddr_addr(address_camera_capture),
		.ddr_data_write(data_write_camera_capture),
		.ddr_wren(wren_camera_capture),
		.data_read(data_read),
		.camera_data_pclk_in(camera_data_pclk),
		.camera_data_extclk(camera_data_extclk),
		.camera_data_href(camera_data_href),
		.camera_data_vsync(camera_data_vsync),
		.camera_data_port(camera_data_port),
		.camera_grab_enable(enable_camera_capture),
		.camera_grab_done(camera_capture_done),
		.camera_data_trigger(camera_data_trigger),
		.data_write_offset(76800),
		.all_dcms_locked(all_dcms_locked),
		//.auxramclk_speed_select(),
		.camera_module_detect(),
		.addr_count(camera_debug_current_address),
		.camera_memory_address(camera_debug_current_address_module),
		.fifo_debug(camera_fifo_debug)
		);

	
	//--------THE FOLLOWING IS A MODIFIED EXCERPT FROM THE FALCON II SYSTEM (http://www.raptorengineeringinc.com/)
	// I2C control line muxing	
	reg [23:0] startup_sequencer_timer = 0;
	
	assign camera_data_standby = 1;		// Camera awake
	assign camera_data_oe = 0;		// Camera driving data
	assign camera_data_saddr = 0;		// Camera I2C address 90 hex (144 decimal)
	
	reg [20:0] reset_delay_timer = 0;

	reg startup_clock;
	always @(posedge main_system_clock) begin
		startup_clock = ~startup_clock;
	end

	always @(posedge startup_clock) begin
		if (reset_delay_timer < 2000000) begin
			reset_delay_timer = reset_delay_timer + 1;
			if (reset_delay_timer < 1500000) begin
				camera_data_reset = 0;		// Reset the camera module
			end else begin
				camera_data_reset = 1;		// Camera module not in reset
			end
		end else begin
			startup_sequencer_timer = startup_sequencer_timer + 1;
			if (startup_sequencer_timer >= 1677721) begin
				startup_sequencer_timer = 0;
				if (startup_sequencer < 65536) begin
					if (startup_sequencer == 0) begin
						startup_sequencer = 1;
					end else begin
						startup_sequencer = startup_sequencer * 2;
					end
				end
			end
		end
		
		if (all_dcms_locked == 0) begin
			startup_sequencer = 0;
			reset_delay_timer = 0;
		end
	end

	//---Instantiate the actual I2C module	
	reg [7:0] special_i2c_command_data = 0;
	wire [7:0] special_i2c_command_register;
	wire camera_data_sda_rnw;
	
	i2c_module #(.InternalClkFrequency(InternalClkFrequency)) 
	i2c_module (
		.startup_sequencer(startup_sequencer),
		.send_special_i2c_command(send_special_i2c_command),
		.camera_data_sda_sw(camera_data_sda_sw),
		.camera_data_scl(camera_data_scl),
		.special_i2c_command_register(special_i2c_command_register),
		.special_i2c_command_data(special_i2c_command_data),
		.clk(clk)
		);
	
	assign camera_data_sda = (camera_data_sda_rnw) ? 1'bz : camera_data_sda_sw;
	assign camera_data_sda_rnw = camera_data_sda_sw;

	//-----END FALCON II EXCERPT		
		
	//------------------EDGE DETECTION module
	wire wren_edge_detection;
	wire [17:0] address_edge_detection;
	wire [31:0] data_write_edge_detection;
	
	reg [7:0] edge_detection_threshold_red = 30; //V
	reg [7:0] edge_detection_threshold_green = 30; //S
	reg [7:0] edge_detection_threshold_blue = 30; //H
	
	edge_detection #(
		.ImageWidth(ImageWidth),
		.ImageHeight(ImageHeight))
		edge_detection(
		//input wires (as seen by module)
		.clk(clk),
		.pause(global_pause),
		.data_read(data_read),
		.base_image_buffer_pointer((slide_switches[4] == 0)?base_image_buffer_pointer:ImageBufferRGB),
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
	
	//------------------BLOB SORTING module
	wire wren_blob_sorting;
	wire [17:0] address_blob_sorting;
	wire [31:0] data_write_blob_sorting;
	
	wire [15:0] blob_extraction_blob_counter;
	reg [7:0] minimum_blob_size = 0;

	wire [4:0] blob_pointer_addr;
	wire [17:0] blob_pointer;
	wire [4:0] number_of_valid_blobs;
	
	reg find_highest = 0;
	reg find_biggest = 1;
	
	//debugging
	wire [15:0] blob_sort_debug_display;
	
	blob_sorting #(
		.BlobStorageOffset(BlobStorageOffset),
		.BUFFER0_OFFSET(BUFFER0_OFFSET),
		.BUFFER1_OFFSET(BUFFER1_OFFSET),
		.BUFFER2_OFFSET(BUFFER2_OFFSET),
		.BUFFER3_OFFSET(BUFFER3_OFFSET))
		blob_sorting(
		//input wires (as seen by module)
		.clk(clk),
		.clk_fast(modified_clock_fast),
		.pause(global_pause),
 		.blob_extraction_blob_counter(blob_extraction_blob_counter),
		.enable_blob_sorting(enable_blob_sorting),
		.minimum_blob_size(minimum_blob_size),
		.wren(wren_blob_sorting),
		.data_write(data_write_blob_sorting),
		.address(address_blob_sorting),
		.data_read(data_read),
		.number_of_valid_blobs(number_of_valid_blobs),
		.find_highest(find_highest),
		.find_biggest(find_biggest),
		// pointer memory
		.pointer_memory_read_addr_b(blob_pointer_addr),
		.pointer_memory_data_read_b(blob_pointer),
		.blob_sorting_done(blob_sorting_done),
		.debug_display(blob_sort_debug_display)
		);
	
	//------------------ASSEMBLE TRACKING OUTPUT module
	wire wren_tracking_output;
	wire [17:0] address_tracking_output;
	wire [31:0] data_write_tracking_output;

	reg [7:0] color_similarity_threshold = 0;

	reg [5:0] test_value_state = 0;
	reg [15:0] tracking_output_blob_sizes_word0 = 0;
	reg [15:0] tracking_output_blob_sizes_word1 = 0;
	reg [15:0] tracking_output_blob_sizes_word2 = 0;
	reg [15:0] tracking_output_blob_sizes_word3 = 0;
	reg [15:0] tracking_output_blob_sizes_word4 = 0;
	reg [15:0] tracking_output_blob_sizes_word5 = 0;
	
	wire [6:0] number_of_bytes_to_transmit;
	
	reg [5:0] tracking_output_blob_data_addr;
	wire [7:0] tracking_output_blob_data;
	wire [5:0] led_wire;
	
	reg [6:0] read_tracking_output = 0;
	
	tracking_output_assembly tracking_output(
		.clk(clk),
		.clk_fast(modified_clock_fast),
		.pause(global_pause),
		.enable_tracking_output(enable_tracking_output),
		.tracking_output_addr_b(tracking_output_blob_data_addr),
		.tracking_output_data_read_b(tracking_output_blob_data),
		.blob_pointer_addr(blob_pointer_addr),
		.blob_pointer(blob_pointer),
		.wren(wren_tracking_output),
		.data_read(data_read),
		.tracking_display(led_wire),
		.tracking_mode_select(slide_switches[1:0]),
		.data_write(data_write_tracking_output),
		.address(address_tracking_output),
		.number_of_bytes_to_transmit(number_of_bytes_to_transmit),
		.tracking_output_done(tracking_output_done)
		);
	
	
	//------------------X PIXEL FILLING module
	wire wren_x_pixel_filling;
	wire [17:0] address_x_pixel_filling;
	wire [31:0] data_write_x_pixel_filling;
	
	x_pixel_filling x_pixel_filling(
		//input wires
		.clk(clk),
		.pause(global_pause),
		.enable_x_pixel_filling(enable_x_pixel_filling),
		.data_read(data_read),
		//output regs
		.wren(wren_x_pixel_filling),
		.data_write(data_write_x_pixel_filling),
		.address(address_x_pixel_filling),
		.x_pixel_filling_done(x_pixel_filling_done)
		);
		
	//------------------Y PIXEL FILLING module
	wire wren_y_pixel_filling;
	wire [17:0] address_y_pixel_filling;
	wire [31:0] data_write_y_pixel_filling;
	
	y_pixel_filling y_pixel_filling(
		//input wires
		.clk(clk),
		.pause(global_pause),
		.enable_y_pixel_filling(enable_y_pixel_filling),
		.data_read(data_read),
		//output regs
		.wren(wren_y_pixel_filling),
		.data_write(data_write_y_pixel_filling),
		.address(address_y_pixel_filling),
		.y_pixel_filling_done(y_pixel_filling_done)
		);
	
	//------------------BLOB EXTRACTION module
	wire wren_blob_extraction;
	wire [17:0] address_blob_extraction;
	wire [31:0] data_write_blob_extraction;
	
	wire [15:0] debug0, debug1;
	wire [5:0] debug2;
	wire [6:0] debug3;
	wire [23:0] blob_debug;
	wire [11:0] blob_debug2;
	wire [11:0] blob_debug3;
	
	reg [4:0] address_primary_color_slots;
	reg [23:0] data_write_primary_color_slots;
	reg wren_primary_color_slots;

	reg [2:0] ignore_color_field_in_match = 3'b000;
	
	blob_extraction #(
		.ImageWidth(ImageWidth),
		.ImageHeight(ImageHeight),
		.BlobStorageOffset(BlobStorageOffset))
		blob_extraction(
		//input wires
		.clk(clk),
		.clk_fast(modified_clock_fast),	//for stack ram
// 		.clk(clk_div_by_two),
// 		.clk_fast(clk),	//for stack ram
		.pause(global_pause),
		.enable_blob_extraction(enable_blob_extraction),
		.data_read(data_read),
		.base_image_buffer_pointer(base_image_buffer_pointer),
		.color_similarity_threshold(color_similarity_threshold),
		.ignore_color_field_in_match(ignore_color_field_in_match),
		//.primary_color_slots(primary_color_slots),	//[23:0] by [5:0][3:0] ==> [575:0]
		//output regs
		.wren(wren_blob_extraction),
		.data_write(data_write_blob_extraction),
		.address(address_blob_extraction),
		.blob_extraction_done(blob_extraction_done),
		.primary_color_slots_clka(clk),
		.wren_primary_color_slots(wren_primary_color_slots),
		.address_primary_color_slots(address_primary_color_slots),
		.data_write_primary_color_slots(data_write_primary_color_slots),
		.blob_count(blob_extraction_blob_counter),
		.debug_display(blob_debug),
		.debug2_display(blob_debug2),
		.debug3_display(blob_debug3)
		);
	

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

	localparam
	STATE_POWERUP = 0,
	STATE_INITIAL = 1,
	STATE_MEMORY_BLANKING = 2,
	STATE_CAMERA_CAPTURE = 3,
	STATE_MEDIAN_FILTERING = 4,
	STATE_RGB_TO_HSV = 5,
	STATE_EDGE_DETECTION = 6,
	STATE_X_PIXEL_FILLING = 7,
	STATE_Y_PIXEL_FILLING = 8,
	STATE_BORDER_DRAWING = 9,
	STATE_BLOB_EXTRACTION = 10,
	STATE_BLOB_SORTING = 11,
	STATE_TRACKING_OUTPUT = 12,
	STATE_TRACKING_OUTPUT_TWO = 13,
	STATE_DATA_OUTPUT_CTL = 14,
	STATE_FRAME_DUMP = 15,
	STATE_SINGLE_SHOT = 16,
	STATE_ONLINE_RECOGNITION = 17;

	reg [7:0] current_main_processing_state = STATE_POWERUP;
	
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

	assign all_dcms_locked = dcm_locked && dcm_locked_sram && camera_dcm_locked;
	
	//instantiate clock manager (2014 edit)
	clock_manager  #(
		.MemoryToSystemClockRatio(MemoryToSystemClockRatio)
		)
		clock_manager(
		.input_clk(main_system_clock),
		.input_clk_stable(main_system_clock_stable),
		.modified_clock(modified_clock),
		.modified_clock_inv(modified_clock_inv),
		.modified_clock_div_by_two(modified_clock_div_by_two),
		.modified_clock_fast(modified_clock_fast),
		.modified_clock_fast_inv(modified_clock_fast_inv),
		.modified_clock_sram(modified_clock_sram),
		.dcm_locked(dcm_locked),
		.dcm_locked_sram(dcm_locked_sram),
		.modified_clock_period(modified_clock_phase)
		);

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
		
		
		if (slide_switches[4:0] == 0) begin
			display_value = debug0;
		end
		if (slide_switches[4:0] == 1) begin
			display_value = debug1;
		end
		if (slide_switches[4:0] == 2) begin
			display_value = debug2;
		end
		if (slide_switches[4:0] == 3) begin
			display_value = debug3;
		end
		if (slide_switches[4:0] == 4) begin
			display_value = current_main_processing_state;
		end
		if (slide_switches[4:0] == 5) begin
			//display_value = address[17:4];
			display_value = address[17:5];
		end
		if (slide_switches[4:0] == 6) begin
			display_value = edge_detection_threshold_red;
		end
		if (slide_switches[4:0] == 7) begin
			display_value = edge_detection_threshold_green;
		end
		if (slide_switches[4:0] == 8) begin
			display_value = edge_detection_threshold_blue;
		end
		if (slide_switches[4:0] == 9) begin
			display_value = color_similarity_threshold;
// 			display_value = sram_debug0;
// 			display_value = blob_debug[15:8];	//red slot, green
// 			display_value = tracking_output_blob_data;
//  			display_value = blob_extraction_blob_counter;
		end
		if (slide_switches[4:0] == 10) begin
//  			display_value = blob_debug[23:16];	// red slot, blue
 			display_value = global_pause;
		end
		if (slide_switches[4:0] == 11) begin
 			display_value = blob_debug2;		// address
		end
		if (slide_switches[4:0] == 12) begin
 			display_value = blob_debug3;		// number of blobs detected that match any of the color slots
		end
		if (slide_switches[4:0] == 13) begin
// 			display_value = data_write_primary_color_slots[7:0];	// red slot, red input
//  			display_value = tracking_output_blob_data_addr;
  			display_value = blob_sort_debug_display;
		end
		if (slide_switches[4:0] == 14) begin
			display_value = data_write_primary_color_slots[15:8];	//red slot, green input
		end
		if (slide_switches[4:0] == 15) begin
			display_value = data_write_primary_color_slots[23:16];	// red slot, blue input
		end
		if (slide_switches[4:0] == 16) begin
			display_value = address_primary_color_slots;
		end
		if (slide_switches[4:0] == 17) begin
			display_value = sram_debug0;
		end
		if (slide_switches[4:0] == 18) begin
			display_value = sram_debug1;
		end
		if (slide_switches[4:0] == 19) begin
			display_value = sram_debug2;
		end

		processing_started_prior = processing_started;
		processing_ended_prior = processing_ended;
	end
	

	reg only_init_this_once = 0;

	
	reg thisiswhite = 0;
	reg pleasedelayhere = 0;


	// Main data processor
	reg [17:0] address_single_shot = 0;
	reg [17:0] address_frame_dump = 0;

	//debugging statements
	//debug 0 is 15:0
	//debug1 is 15:0
	//debug2 is 5:0
	//debug3 is 4:0
	assign debug0[0] = wren;
	assign debug0[1] = wren_edge_detection;
	assign debug0[2] = wren_tracking_output;
	assign debug0[3] = wren_x_pixel_filling;
	assign debug0[4] = wren_y_pixel_filling;
	assign debug0[5] = wren_blob_extraction;
	assign debug0[6] = wren_camera_capture;
	assign debug0[15:7] = 0;


	assign debug1[1] = camera_dcm_locked;
	assign debug1[0] = camera_capture_done;

	assign debug2[0] = run_frame_dump_internal;
	assign debug2[1] = run_single_shot_test_internal;
	assign debug2[2] = memory_controller_ready;
	assign debug2[3] = processing_done_internal;
	assign debug2[4] = global_pause;
	
	assign debug3[0] = run_frame_dump;
	assign debug3[1] = run_single_shot_test;
	assign debug3[2] = dcm_locked;
	assign debug3[3] = dcm_locked_sram;
	assign debug3[4] = camera_dcm_locked;
	assign debug3[5] = all_dcms_locked;
	assign debug3[6] = 0;

	reg [17:0] frame_dump_origin_address = 76801;

	assign address = address_edge_detection | address_blob_sorting | address_tracking_output | address_x_pixel_filling 
							| address_y_pixel_filling | address_blob_extraction | address_camera_capture | address_memory_blanking | address_rgb_to_hsv
							| address_single_shot | address_frame_dump /*| address_median_filtering*/;
						
	assign wren = wren_edge_detection | wren_blob_sorting | wren_tracking_output | wren_x_pixel_filling | wren_y_pixel_filling | wren_rgb_to_hsv
							| wren_blob_extraction | wren_camera_capture | wren_memory_blanking /*| wren_median_filtering*/;
						
	assign data_write = data_write_edge_detection | data_write_blob_sorting | data_write_tracking_output | data_write_x_pixel_filling | data_write_y_pixel_filling | data_write_rgb_to_hsv
							| data_write_blob_extraction | data_write_camera_capture | data_write_memory_blanking /*| data_write_median_filtering*/;

// 	always @(negedge modified_clock_sram) begin
// 		address <= address_edge_detection | address_blob_sorting | address_tracking_output | address_x_pixel_filling  | address_x_pixel_filling 
// 								| address_y_pixel_filling | address_blob_extraction | address_camera_capture | address_memory_blanking 
// 								| address_single_shot | address_frame_dump /*| address_median_filtering*/;
// 							
// 		wren <= wren_edge_detection | wren_blob_sorting | wren_tracking_output | wren_x_pixel_filling | wren_y_pixel_filling  | wren_rgb_to_hsv
// 								| wren_blob_extraction | wren_camera_capture | wren_memory_blanking /*| wren_median_filtering*/;
// 							
// 		data_write <= data_write_edge_detection | data_write_blob_sorting | data_write_tracking_output | data_write_x_pixel_filling | data_write_y_pixel_filling | data_write_rgb_to_hsv
// 								| data_write_blob_extraction | data_write_camera_capture | data_write_memory_blanking /*| data_write_median_filtering*/;
// 	end

	always @(posedge clk) begin
		//FIXME
		//tracking output debugging only
		leds[5:0] = led_wire;
		leds[6] = global_pause;
// 		if (global_pause == 0) begin
			//if ((processing_done_internal == 0)) begin
			//if (camera_transfer_done == 1) begin
				processing_done = 0;
				
				//leds[5:0] = current_main_processing_state + 1;

				if (current_main_processing_state == STATE_POWERUP) begin
					if ((all_dcms_locked == 1) && (memory_controller_ready == 1)) begin
						current_main_processing_state = STATE_INITIAL;
					end
				end
				
				else if (current_main_processing_state == STATE_INITIAL) begin
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
						//current_main_processing_state = STATE_MEMORY_BLANKING;
						current_main_processing_state = STATE_CAMERA_CAPTURE;
					end
				end

				else if (current_main_processing_state == STATE_MEMORY_BLANKING) begin
					//leds[5] = 1;
					enable_memory_blanking = 1;
					if (memory_blanking_done == 1) begin
						enable_memory_blanking = 0;
// 						if (slide_switches[4] == 0) begin
							current_main_processing_state = STATE_CAMERA_CAPTURE;
// 						end else begin
// 							current_main_processing_state = STATE_DATA_OUTPUT_CTL;	 // ****DEBUG ONLY****
// 						end
					end
				end
				
				else if (current_main_processing_state == STATE_CAMERA_CAPTURE) begin
					//leds[5] = 1;
					enable_camera_capture = 1;
					if (camera_capture_done == 1) begin
						enable_camera_capture = 0;
						current_main_processing_state = STATE_MEDIAN_FILTERING;
						//current_main_processing_state = STATE_DATA_OUTPUT_CTL;	 // ****DEBUG ONLY**** (tpearson 03/09/14 01:41)
					end
				end
	
				else if (current_main_processing_state == STATE_MEDIAN_FILTERING) begin
					//leds[5] = 1;
					//enable_median_filtering = 1;
					//if (median_filtering_done == 1) begin
					//	enable_median_filtering = 0;
						current_main_processing_state = STATE_RGB_TO_HSV;
					//end
				end

				else if (current_main_processing_state == STATE_RGB_TO_HSV) begin
					//leds[5] = 1;
					enable_rgb_to_hsv = 1;
					if (rgb_to_hsv_done == 1) begin
						enable_rgb_to_hsv = 0;
						current_main_processing_state = STATE_EDGE_DETECTION;
					end
				end
				
				else if (current_main_processing_state == STATE_EDGE_DETECTION) begin
					//leds[5] = 1;
					enable_edge_detection = 1;
					if (edge_detection_done == 1) begin
						enable_edge_detection = 0;
						current_main_processing_state = STATE_X_PIXEL_FILLING;
 					end
				end
				
				else if (current_main_processing_state == STATE_X_PIXEL_FILLING) begin
					//leds[5] = 1;
					enable_x_pixel_filling = 1;
					if (x_pixel_filling_done == 1) begin
						enable_x_pixel_filling = 0;
 						current_main_processing_state = STATE_Y_PIXEL_FILLING;
					end
				end
				
				else if (current_main_processing_state == STATE_Y_PIXEL_FILLING) begin
					//leds[5] = 1;
					enable_y_pixel_filling = 1;
					if (y_pixel_filling_done == 1) begin
						enable_y_pixel_filling = 0;
// 						if (slide_switches[5] == 0) begin
							current_main_processing_state = STATE_BORDER_DRAWING;
// 						end else begin
// 							current_main_processing_state = STATE_DATA_OUTPUT_CTL;	 // ****DEBUG ONLY****
// 						end
					end
				end		
				
				else if (current_main_processing_state == STATE_BORDER_DRAWING) begin
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
				
				else if (current_main_processing_state == STATE_BLOB_EXTRACTION) begin
					//leds[5] = 1;
					enable_blob_extraction = 1;
					if (blob_extraction_done == 1) begin
						enable_blob_extraction = 0;
// 						if (slide_switches[6] == 0) begin
							current_main_processing_state = STATE_BLOB_SORTING;
// 						end else begin
// 							current_main_processing_state = STATE_DATA_OUTPUT_CTL;	 // ****DEBUG ONLY****
// 						end
					end
				end
				
				else if (current_main_processing_state == STATE_BLOB_SORTING) begin
					enable_blob_sorting = 1;
					if (blob_sorting_done == 1) begin
						enable_blob_sorting = 0;
						current_main_processing_state = STATE_TRACKING_OUTPUT;
					end
				end
				
				else if (current_main_processing_state == STATE_TRACKING_OUTPUT) begin
					//leds[5] = 1;
					enable_tracking_output = 1;
					if (tracking_output_done == 1) begin
						enable_tracking_output = 0;
						current_main_processing_state = STATE_TRACKING_OUTPUT_TWO;
					end
				end
				
				else if (current_main_processing_state == STATE_TRACKING_OUTPUT_TWO) begin
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
				
				else if (current_main_processing_state == STATE_DATA_OUTPUT_CTL) begin
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
						processing_done_internal = 1;
						//processing_ended = 1;
					end
				end
	
				else if (current_main_processing_state == STATE_FRAME_DUMP) begin
					leds[7] = 1;
					serial_output_enabled = 1;
					
					if (serial_output_holdoff == 0) begin
						serial_output_holdoff = 1;

						// Debug
						if (slide_switches[3:2] == 0) begin
							frame_dump_origin_address = BUFFER0_OFFSET;
						end else if (slide_switches[3:2] == 1) begin
							frame_dump_origin_address = BUFFER1_OFFSET;
						end else if (slide_switches[3:2] == 2) begin
							frame_dump_origin_address = BUFFER2_OFFSET;
						end else if (slide_switches[3:2] == 3) begin
							frame_dump_origin_address = BUFFER3_OFFSET;
						end

// 						// Normal operation
// 						frame_dump_origin_address = 76801;

						address_frame_dump = frame_dump_origin_address;
						serial_output_index = 0;
						serial_output_index_toggle = 0;
						processing_ended = 1;
					end else begin
						if ((serial_output_enabled == 1) && (global_pause == 0)) begin
							// Transmit the entire contents of the image buffer to the serial port
							if (tx_toggle == 0) begin
								if (serial_output_index_toggle == 0) begin
									TxD_data = data_read[31:24];	// Blue
								end
								
								if (serial_output_index_toggle == 1) begin
									TxD_data = data_read[15:8];	// Green
								end
								
								if (serial_output_index_toggle == 2) begin
									TxD_data = data_read[7:0];	// Red
								end
								
								TxD_start = 1;
								tx_toggle = 1;
	
								serial_output_index_toggle = serial_output_index_toggle + 1;
								if (serial_output_index_toggle > 2) begin
									serial_output_index_toggle = 0;
									serial_output_index_mem = serial_output_index_mem + 1;
								end
								serial_output_index = serial_output_index + 1;

								address_frame_dump = serial_output_index_mem + frame_dump_origin_address;
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
									
									processing_done_internal = 1;
								end
							end
						end
					end
				end
				
				else if (current_main_processing_state == STATE_SINGLE_SHOT) begin
					leds[7] = 1;
					serial_output_enabled = 1;
					
					if (serial_output_holdoff == 0) begin
						serial_output_holdoff = 1;
						address_single_shot = 0;
						//address_single_shot = 76801;
						//address_single_shot = 153602;
						//address_single_shot = 230403;
						serial_output_index_toggle = 0;
						serial_output_index = 0;
						thisiswhite = 0;
						processing_ended = 1;
					end else begin
						if ((serial_output_enabled == 1) && (global_pause == 0)) begin
							// Transmit the entire contents of the image buffer to the serial port
							if (tx_toggle == 0) begin
								if (serial_output_index_toggle == 0) begin
									address_single_shot = ((data_read * 3) + BlobStorageOffset);
									//address = address + 76801;
									if (data_read == 1) begin
										thisiswhite = 1;
									end else begin
										thisiswhite = 0;
									end
								end
								
								if (serial_output_index_toggle == 1) begin
									// Do nothing
								end
								
								if (serial_output_index_toggle == 2) begin
									if (thisiswhite == 0) begin
										TxD_data = data_read[15:8];
										//TxD_data = data_read[7:0];
									end else begin
										TxD_data = 255;
									end
								end
								
								if (serial_output_index_toggle == 3) begin
									if (thisiswhite == 0) begin
										TxD_data = data_read[23:16];
										//TxD_data = data_read[7:0];
									end else begin
										TxD_data = 255;
									end
								end
								
								if (serial_output_index_toggle == 4) begin
									if (thisiswhite == 0) begin
										TxD_data = data_read[31:24];
										//TxD_data = data_read[7:0];
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
									address_single_shot = serial_output_index_mem + 0;
									//address_single_shot = serial_output_index_mem + 76801;
									//address_single_shot = serial_output_index_mem + 153602;
									//address_single_shot = serial_output_index_mem + 230403;
								end
							end
							else if (tx_toggle == 1) begin
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
									processing_done_internal = 1;
								end
							end
						end
					end
				end
				
				else if (current_main_processing_state == STATE_ONLINE_RECOGNITION) begin
					leds[7] = 1;
					serial_output_enabled = 1;
					if (serial_output_holdoff == 0) begin
						serial_output_holdoff = 1;
						serial_output_index_toggle = 0;
						serial_output_index = 0;
						processing_ended = 1;
						serial_output_index = 0;
						tracking_output_blob_data_addr = 0;
					end else begin
						if (serial_output_enabled == 1) begin
							processing_ended = 0;		// We only needed to pulse this
									
							// Transmit the entire contents of the tracking data buffer to the serial port
							if (tx_toggle == 0) begin
								//pull in data word from tracking output assembly into TxD_data
								TxD_data = tracking_output_blob_data;
								tracking_output_blob_data_addr = serial_output_index_toggle + 1;
								
								// -- Done!

								if (serial_output_index_toggle != number_of_bytes_to_transmit) begin
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
				
							if (serial_output_index_toggle >= number_of_bytes_to_transmit) begin
								if (TxD_start == 0) begin	// Wait for transmission of byte to complete
									TxD_start = 0;
									tx_toggle = 0;
									serial_output_holdoff = 0;
									//serial_output_index = 0;
									//serial_output_index_mem = 0;
									//serial_output_index_toggle = 0;
									serial_output_enabled = 0;
									serial_output_index_toggle = 0;
									tracking_output_blob_data_addr = 0;
									//leds[5:1] = 0;
									leds[7] = 0;
		
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
// 		end
	end	//end of always 

	async_transmit #(.ClkFrequency(InternalClkFrequency)) asyncTX(.clk(clk), .TxD_start(TxD_start), .TxD_data(TxD_data), .TxD(TxD), .TxD_busy(TxD_busy), .state(TxD_state));
	async_receiver #(.ClkFrequency(InternalClkFrequency)) asyncRX(.clk(clk), .RxD(RxD), .RxD_data_ready(RxD_data_ready), .RxD_data(RxD_data), .RxD_endofpacket(RxD_endofpacket), .RxD_idle(RxD_idle));

	reg [7:0] serial_receiver_timer = 21;
	reg serial_character_received = 0;
	reg [7:0] serial_receiver_toggler = 0;
	reg [7:0] serial_command_buffer = 0;
	reg [2:0] next_byte_is_command = 0;
	reg [7:0] next_byte_is_command_prev_command = 0;
	//reg [15:0] special_i2c_command_timer = 0;
	
	reg [5:0] array_spec_1;
	reg [5:0] array_spec_2;
	
	// Receive serial commands
	always @(posedge clk) begin
		if (serial_receiver_timer > 40) begin
			run_frame_dump = 0;				// These must only be pulsed, NOT stuck on!
			run_single_shot_test = 0;
			reset_system = 0;
		end else begin
			serial_receiver_timer = serial_receiver_timer + 1;
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
								base_image_buffer_pointer = ImageBufferRGB;
								ignore_color_field_in_match = 3'b000;	// Do not ignore any color values when matching [BGR]
								serial_receiver_timer = 0;
							end
							
							if (serial_command_buffer == 75) begin		// Enable HSV mode
								base_image_buffer_pointer = ImageBufferHSV;
								ignore_color_field_in_match = 3'b001;	// Ignore intensity value (V) when matching [HSV]
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
								next_byte_is_command_prev_command = 89;
							end
							
							if (serial_command_buffer == 65) begin	
								next_byte_is_command = 1;
								next_byte_is_command_prev_command = 65;
							end
							
							if (serial_command_buffer == 73) begin	
								next_byte_is_command = 1;
								next_byte_is_command_prev_command = 73;
							end
							
							if (serial_command_buffer == 66) begin	
								next_byte_is_command = 1;
								next_byte_is_command_prev_command = 66;
							end
							
							if (serial_command_buffer == 78) begin	
								next_byte_is_command = 1;
								next_byte_is_command_prev_command = 78;
							end
							
							if (serial_command_buffer == 72) begin	
								next_byte_is_command = 1;
								next_byte_is_command_prev_command = 72;
							end
							
							if (serial_command_buffer == 59) begin	
								next_byte_is_command = 1;
								next_byte_is_command_prev_command = 59;
							end
							
							// Color slot modify requests
							if ((serial_command_buffer > 90) && (serial_command_buffer < 140)) begin	
								next_byte_is_command = 1;
								next_byte_is_command_prev_command = serial_command_buffer;
								
								array_spec_1 = ((next_byte_is_command_prev_command / 8) - 11);
								array_spec_2 = (next_byte_is_command_prev_command[2:0] - 3);
							end
						end else begin
							if (next_byte_is_command == 3) begin
								if ((next_byte_is_command_prev_command > 90) && (next_byte_is_command_prev_command < 140)) begin
									// Blue
									address_primary_color_slots = (array_spec_1*4) + array_spec_2;
									data_write_primary_color_slots[23:16] = serial_command_buffer;		//old syntax: [array_spec_1][array_spec_2][23:16]
									wren_primary_color_slots = 1'b1;
									next_byte_is_command = 0;
								end
							end
							
							if (next_byte_is_command == 2) begin
								// Color slot modify requests
								if ((next_byte_is_command_prev_command > 90) && (next_byte_is_command_prev_command < 140)) begin
									// Green
									address_primary_color_slots = (array_spec_1*4) + array_spec_2;
									data_write_primary_color_slots[15:8] = serial_command_buffer;	// old syntax: [array_spec_1][array_spec_2][15:8]
									wren_primary_color_slots = 1'b1;
									next_byte_is_command = 3;
								end
								
								if (next_byte_is_command_prev_command == 89) begin
									display_value_user[13:8] = serial_command_buffer;
									next_byte_is_command = 0;
								end
								
							end
							
							if (next_byte_is_command == 1) begin
								// The previous byte was the command--now load in the number!
								if (next_byte_is_command_prev_command == 65) begin
									edge_detection_threshold_red = serial_command_buffer;
									next_byte_is_command = 0;
								end
								
								if (next_byte_is_command_prev_command == 73) begin
									edge_detection_threshold_green = serial_command_buffer;
									next_byte_is_command = 0;
								end
								
								if (next_byte_is_command_prev_command == 66) begin
									edge_detection_threshold_blue = serial_command_buffer;
									next_byte_is_command = 0;
								end
								
								if (next_byte_is_command_prev_command == 78) begin
									minimum_blob_size = serial_command_buffer;
									next_byte_is_command = 0;
								end
								
								if (next_byte_is_command_prev_command == 72) begin
									color_similarity_threshold = serial_command_buffer;
									next_byte_is_command = 0;
								end
								
								if (next_byte_is_command_prev_command == 89) begin
									display_value_user = serial_command_buffer;
									next_byte_is_command = 2;
								end

								// Color slot modify requests
								if ((next_byte_is_command_prev_command > 90) && (next_byte_is_command_prev_command < 140)) begin
									// Red
									address_primary_color_slots = (array_spec_1*4) + array_spec_2;
									data_write_primary_color_slots[7:0] = serial_command_buffer;	// old syntax: [array_spec_1][array_spec_2][7:0]
									wren_primary_color_slots = 1'b1;
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
			wren_primary_color_slots = 1'b0;
		end
	end

endmodule