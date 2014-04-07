`timescale 1ns / 1ps
//----------------------------------------------------------------------------
//
//		This file is part of the FALCON II.
//
//		The FALCON II is free software: you can redistribute it and/or modify
//		it under the terms of the GNU General Public License as published by
//		the Free Software Foundation, either version 3 of the License, or
//		(at your option) any later version.
//
//		The FALCON II is distributed in the hope that it will be useful,
//		but WITHOUT ANY WARRANTY; without even the implied warranty of
//		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//		GNU General Public License for more details.
//
//		You should have received a copy of the GNU General Public License
//		along with the FALCON II.  If not, see http://www.gnu.org/licenses/.
//
//		The FALCON II is copyright 2008-2010 by Timothy Pearson
//		tpearson@raptorengineeringinc.com
//		http://www.raptorengineeringinc.com
//
//----------------------------------------------------------------------------
//
//		The FALCON II is available as a reference design for the 
//		Raptor Engineering VDFPGA series of FPGA development boards
//		Please visit http://www.raptorengineeringinc.com for more information.
//
//----------------------------------------------------------------------------

// synthesis attribute mult_style of camera_module is lut;

module camera_module_v2(
	//input [7:0] startup_sequencer,
	output reg camera_module_detect,
	input wire pause,
	
	// RAM signals
	output reg [19:0] ddr_addr,
	output reg [31:0] ddr_data_write,
	input wire [31:0] data_read,
	output reg ddr_wren,			// NOTE: 1 is read, 0 is write!
	//debug:
	output reg [23:0] data_write,
	output reg [31:0] data_write_buffered,
	wire [4:0] state_debug,
	output reg altline,
	output reg altcol,
	output reg pixel_valid,
	output reg stuck,
	output wire red_full,
	output wire green_full,
	output wire blue_full,
	output wire red_empty,
	output wire green_empty,
	output wire blue_empty,
	output reg [31:0] href_active,
	output reg [31:0] vsync_active,
	output reg vsync_locked,
	output reg line_valid,

	
	// Camera signals
	input camera_data_pclk_unbuffered,
	input camera_data_extclk,
	input camera_data_href,
	input camera_data_vsync,
	input [11:0] camera_data_port,
	output reg camera_data_trigger,
	input [19:0] data_write_offset,
	
	// FIFO debug signals
	output wire fifo_full,
	output wire fifo_empty,
	output reg [18:0] camera_memory_address,
	input wire all_dcms_locked,
	
	output reg [19:0] addr_count,
// 	output reg [1:0] col_count,
// 	output reg [1:0] row_count,

// FIXME 1-bit FOR DEBUG ONLY
output reg col_count,
output reg row_count,
	
	// RAM speed control signal
	output reg auxramclk_speed_select,
	
	// Interface signals
	input camera_grab_enable,
	output reg camera_grab_done,
	input clk
	);
	
	`include "parameters.v"

	initial altline = 0;
	initial altcol = 0;
	initial pixel_valid = 0;
	initial camera_memory_address = 76801;
	initial vsync_locked = 0;
	initial row_count = 0;
	initial col_count = 0;
	
	BUFG CAMERA_CLOCK_BUF(
		.O(camera_data_pclk),
		.I(~camera_data_pclk_unbuffered)
		);
	
	reg camera_grab_enable_prev;
	//reg [18:0] camera_memory_address = 76801;
	reg [19:0] address_buffer;
	reg [15:0] databuffer;
	reg [3:0] camera_toggle = 0;
	reg [23:0] databuffer_mem;
	//free-running 2-bit counters
// 	reg [1:0] col_count = 0;
// 	reg [1:0] row_count = 0;
	
	reg [31:0] vsync_active_count;
	reg [31:0] href_active_count;
	
	reg camera_data_href_prev = 0;
	reg camera_data_vsync_prev = 0;
//	reg vsync_locked = 0;
	
	reg [31:0] data_read_sync;
	reg [15:0] line_counter;
//	reg line_valid;
	reg [1:0] pixel_counter;
	
	reg [30:0] ers_exposure_length = 1000;
	reg [25:0] red_average;
	reg [25:0] green_average;
	reg [25:0] blue_average;
	reg [31:0] total_average;
	reg exposed;
	reg [31:0] ers_exposure_timer;
	reg [31:0] camera_not_present_timer;

	reg final_process_counter = 1;

	reg camera_agc_enable;
	reg camera_agc_done;
	
	reg [19:0] address;
	
	//----------------FIFO--------
	reg red_wren;
	reg [7:0] red_in;
	wire [7:0] red_out;
	
	reg green_wren;
	reg [7:0] green_in;
	wire [7:0] green_out;
	
	reg blue_wren;
	reg [7:0] blue_in;
	wire [7:0] blue_out;
	
	reg fifo_rden;
	wire [23:0] data_write_buffered_fifo;

	reg reset_fifos = 0;
	
	camera_fifo_buffer red_buffer (
		.rst(!all_dcms_locked || reset_fifos),
		.wr_clk(camera_data_pclk), // input wr_clk	(needs to run camera clock speed)
		.rd_clk(clk), // input rd_clk	(needs to run at speed of main system clk)
		.din(red_in), // input [7:0] din  (data to be eventually be written to DDR mem)
		.wr_en(red_wren), // input wr_en
		.rd_en(fifo_rden), // input rd_en
		.dout(red_out), // output [7:0] dout
		.full(red_full), // output full
		.empty(red_empty) // output empty
	);
	
	camera_fifo_buffer green_buffer (
		.rst(!all_dcms_locked || reset_fifos),
		.wr_clk(camera_data_pclk), // input wr_clk	(needs to run camera clock speed)
		.rd_clk(clk), // input rd_clk	(needs to run at speed of main system clk)
		.din(green_in), // input [7:0] din  (data to be eventually be written to DDR mem)
		.wr_en(green_wren), // input wr_en
		.rd_en(fifo_rden), // input rd_en
		.dout(green_out), // output [7:0] dout
		.full(green_full), // output full
		.empty(green_empty) // output empty
	);
	
	camera_fifo_buffer blue_buffer (
		.rst(!all_dcms_locked || reset_fifos),
		.wr_clk(camera_data_pclk), // input wr_clk	(needs to run camera clock speed)
		.rd_clk(clk), // input rd_clk	(needs to run at speed of main system clk)
		.din(blue_in), // input [7:0] din  (data to be eventually be written to DDR mem)
		.wr_en(blue_wren), // input wr_en
		.rd_en(fifo_rden), // input rd_en
		.dout(blue_out), // output [7:0] dout
		.full(blue_full), // output full
		.empty(blue_empty) // output empty
	);
	
	assign fifo_empty = red_empty || green_empty || blue_empty;
	assign fifo_full = red_full || green_full || blue_full;

	localparam	INIT_STATE = 0,
			IDLE = 1,
			WRITE = 2,
			READ = 3,
			READ_WAIT = 4;
	
	reg [4:0] state;
	assign state_debug = state;

	//----begin FIFO read controls
	//----this runs at clk
	//----MUST respect the pause signal from memory controller
	always @(posedge clk) begin
		// G2 (8 bits) is not used. To save on space, it will not be written to the fifo. 
		// The G2 space of data_write is later trimmed in main, so it will be replaced with zeros for now.
	
		if (camera_grab_enable == 1) begin
			if ((camera_grab_done == 0) && (exposed == 1)) begin
				case (state)
					INIT_STATE: 
						begin
							fifo_rden = 0;
							ddr_addr = 0;
							state = IDLE;
						end
					IDLE: 	begin
							// Reading from certain memory types (LPDDR) involves a large latency that does not exist when writing
							// Nothing is harmed by staying in write mode and writing the same data to the same address over and over
							// Therefore, do not switch to read mode at any time during the frame transfer
							if (!fifo_empty) begin
								fifo_rden = 1;
								state = READ;
							end
							else begin
								fifo_rden = 0;
								state = IDLE;
							end
							//transfer complete after 320x240 frame written
							if (addr_count >= 76800) begin
								camera_grab_done = 1;
							end
						end
					READ:	begin
							fifo_rden = 0;
							ddr_data_write = {blue_out, 8'h0, green_out, red_out};
							ddr_addr = addr_count + data_write_offset;
							ddr_wren = 1;
							addr_count = addr_count + 1;
							state = READ_WAIT;
						end
					READ_WAIT:
						begin
							if (pause == 0) begin
								state = IDLE;
							end else begin
								state = READ_WAIT;
							end
						end
				endcase
			end
		end else begin
			camera_grab_done = 0;
			addr_count = 0;
			ddr_wren = 0;
			ddr_addr = 0;

			fifo_rden = 0;
			ddr_addr = 0;
			state = INIT_STATE;
		end
	end	//end always
	//----end FIFO read controls

	// Shutter control
	always @(posedge clk) begin
		if ((camera_grab_enable == 1) && (camera_grab_done == 0)) begin
			if (exposed == 0) begin
				if (ers_exposure_timer < ((ers_exposure_length * ERS_CYCLES_PER_ROW) + ERS_EXPOSURE_MINIMUM)) begin
					reset_fifos = 1;
					camera_data_trigger = 0;		// Active low
					ers_exposure_timer = ers_exposure_timer + 1;
				end else begin
					reset_fifos = 0;
					camera_data_trigger = 1;		// Active low
					ers_exposure_timer = 0;
					exposed = 1;
				end
			end
		end else begin
			exposed = 0;
			ers_exposure_timer = 0;
			camera_data_trigger = 1;		// Active low
		end
	end

	// AGC
	always @(posedge camera_data_pclk) begin
		// Deal with the control signals...
		if (camera_agc_enable == 0) begin
			camera_agc_done = 0;
		end

		if ((camera_agc_enable == 1) && (camera_agc_done == 0)) begin
			// Do a simple AGC function here
			// total_average contains the sum of all pixels
			// It is 0 if all pixels are 0 and it is 58752000 if all pixels are 255
			// Therefore, the AGC will try to hold it to a value of 29376000,
			// which is simply ((320*240*3*255)/2)
			total_average = red_average + green_average + blue_average;
			
			// First, divide this so that the maximum is 448 and the desired value is 224
			// This will make it so that a proportional control can be applied
			total_average = total_average / 131072;
			if (total_average > 224) begin
				total_average = total_average - 224;
				if (total_average < ers_exposure_length) begin
					ers_exposure_length = ers_exposure_length - total_average;
				end else begin
					ers_exposure_length = MIN_ERS_CYCLES;
				end
			end else begin
				total_average = 224 - total_average;
				ers_exposure_length = ers_exposure_length + total_average;
			end
			
			// Limiting of shutter value
			if (ers_exposure_length < MIN_ERS_CYCLES) begin
				ers_exposure_length = MIN_ERS_CYCLES;
			end
			if (ers_exposure_length > MAX_ERS_CYCLES) begin
				ers_exposure_length = MAX_ERS_CYCLES;
			end

			// Done!
			camera_agc_done = 1;
		end
	end
	
	reg [19:0] rcount = 0;
	reg [19:0] gcount = 0;
	reg [19:0] bcount = 0;

	// Camera data input processor
	always @(posedge camera_data_pclk) begin
		databuffer = camera_data_port;

		// Capture a 320 x 240 image if enabled (8-bit tricolor)
		// One line is G1-R-G1-R-G1-R...
		// The next line is B-G2-B-G2-B-G2...
		// This is the well known Bayer pattern
		if (camera_memory_address < 76800) begin	//if complete 320x240 frame not yet written
			if ((camera_data_href_prev == 1) && (camera_data_href == 0)) begin
				//free-running 2-bit counter
				row_count = row_count + 1;
			end
			if ((camera_data_href == 1) && (camera_data_vsync == 1) && (vsync_locked == 1) && (line_valid == 1)) begin
				//free-running 2-bit counter
				col_count = col_count + 1;
				
				case (row_count)
					0: begin
						case (col_count)
							0: begin
								red_wren = 0;
								blue_wren = 0;
								if (!green_full) begin
									green_in = databuffer[11:4];
									//green_in = gcount;
									gcount = gcount + 1;
									green_wren = 1;
									green_average = green_average + green_in;
									line_counter = line_counter + 1;
								end
							end
							1: begin
								red_wren = 0;
								green_wren = 0;
								if (!blue_full) begin
									blue_in = databuffer[11:4];
									//blue_in = bcount;
									bcount = bcount + 1;
									blue_wren = 1;
									blue_average = blue_average + blue_in;
								end
							end
							2: begin
								red_wren = 0;
								green_wren = 0;
								blue_wren = 0;
							end
							// columns 2 and 3 write nothing to fifos when row = 0
						endcase		//column count
					end
					1: begin
						case (col_count)
							0: begin
								green_wren = 0;
								blue_wren = 0;
								if (!red_full) begin
									red_in = databuffer[11:4];
									//red_in = rcount;
									rcount = rcount + 1;
									red_wren = 1;
									red_average = red_average + red_in;
									camera_memory_address = camera_memory_address + 1;
									line_counter = line_counter + 1;
								end
							end
							1: begin
								red_wren = 0;
								green_wren = 0;
								blue_wren = 0;
							end
							// columns 1, 2, and 3 write nothing to fifo when row = 1
						endcase		//column count
					end
					2: begin
						red_wren = 0;
						green_wren = 0;
						blue_wren = 0;
					end
					// row case 3 ignored
				endcase	//end row case
			end else begin
				red_wren = 0;
				green_wren = 0;
				blue_wren = 0;
			end
		end else begin		// All done!
			// Do a simple AGC function here
			camera_toggle = 0;
			case (final_process_counter)
				0: begin
					camera_agc_enable = 1;
					if (camera_agc_done == 1) begin
						camera_agc_enable = 0;
						final_process_counter = 1;
					end
				end
				//reset
				1: begin
					row_count = 0;
					col_count = 0;
					rcount = 0;
					gcount = 0;
					bcount = 0;

					camera_toggle = 0;
					vsync_locked = 0;
					red_average = 0;
					green_average = 0;
					blue_average = 0;
					camera_not_present_timer = 0;
					red_wren = 0;
					green_wren = 0;
					blue_wren = 0;
				end
			endcase
		end
		
		// These if blocks and assignments operate independently 
		// of whether a 320*240 frame is being written.
		// Run at pixel clock
		if ((camera_data_href_prev == 1) && (camera_data_href == 0)) begin
			camera_module_detect = 1;
			camera_not_present_timer = 0;
		end
		if (camera_data_href == 0) begin
			line_counter = 0;
			camera_toggle = 0;
		end
		if (exposed == 1) begin
			vsync_locked = 1;
			if (camera_not_present_timer > 100000) begin
				camera_module_detect = 0;
			end
			camera_not_present_timer = camera_not_present_timer + 1;
		end
		if (line_counter < 320) begin
			line_valid = 1;
		end else begin
			line_valid = 0;
		end
		
		//debugging
		if (camera_data_href == 1) begin
			if (camera_data_href_prev == 0) begin
				//reset on rising edge
				href_active = href_active_count;
				href_active_count = 0;
			end else begin
				href_active_count = href_active_count + 1;
			end
		end
		if (camera_data_vsync == 1) begin
			if (camera_data_vsync_prev == 0) begin
				//reset on rising edge
				vsync_active = vsync_active_count;
				vsync_active_count = 0;
			end else begin
				vsync_active_count = vsync_active_count + 1;
			end
		end
		
		if ((camera_grab_enable_prev == 0) && (camera_grab_enable == 1)) begin
			camera_memory_address = 0;
			final_process_counter = 0;
			href_active_count = 0;
			vsync_active_count = 0;
		end
		camera_grab_enable_prev = camera_grab_enable;

		camera_data_href_prev = camera_data_href;
		camera_data_vsync_prev = camera_data_vsync;
	end

endmodule
