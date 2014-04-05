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
	output reg camera_grab_in_progress,
	output reg camera_module_detect,
	input wire pause,
	
	// RAM signals
	output reg [19:0] ddr_addr,
	output reg [31:0] ddr_data_write,
	input wire [31:0] data_read,
	output reg ddr_wren,			// NOTE: 1 is read, 0 is write!
	//debug:
	output reg [31:0] data_write,
	output wire [31:0] data_write_buffered,
	wire [4:0] state_debug,
	output reg altline,
	output reg altcol,
	output reg pixel_valid,
	output reg stuck,
	
	// Camera signals
	input camera_data_pclk_unbuffered,
	input camera_data_href,
	input camera_data_vsync,
	input [11:0] camera_data_port,
	output reg camera_data_trigger,
	input [19:0] data_write_offset,
	
	// FIFO debug signals
	output wire fifo_full,
	output wire fifo_empty,
	
	output reg [19:0] addr_count,
	
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
	
	IBUFG CAMERA_CLOCK_BUF(
		.O(camera_data_pclk),
		.I(camera_data_pclk_unbuffered)
		);
	
	reg [18:0] camera_memory_address = 0;
	reg [19:0] address_buffer;
	reg [15:0] databuffer;
	reg [3:0] camera_toggle = 0;
	reg [31:0] databuffer_mem;
	
	reg camera_data_href_prev = 0;
	reg camera_data_vsync_prev = 0;
	reg vsync_locked = 0;
	
	reg [31:0] data_read_sync;
	reg [15:0] line_counter;
	reg line_valid;
	
	reg [30:0] ers_exposure_length = 1000;
	reg [25:0] red_average;
	reg [25:0] green_average;
	reg [25:0] blue_average;
	reg [31:0] total_average;
	reg exposed;
	reg [31:0] ers_exposure_timer;
	reg [31:0] camera_not_present_timer;

	reg final_process_counter;

	reg camera_agc_enable;
	reg camera_agc_done;
	
	reg wren;
	reg [19:0] address;
	
	//----------------FIFO--------
	reg fifo_wren;
	reg fifo_rden;
	wire [23:0] data_write_fifo;
	wire [23:0] data_write_buffered_fifo;
	
	// G2 (8 bits) is not used. To save on space, it will not be written to the fifo. 
	// The G2 space of data_write is later trimmed in main, so it will be replaced with zeros for now.
	assign data_write_buffered = {data_write_buffered_fifo[23:16], 8'h0, data_write_buffered_fifo[15:0]};
	assign data_write_fifo = {data_write[31:24], data_write[23:0]};
	
	camera_fifo_buffer fifo_buffer (
		.wr_clk(camera_data_pclk), // input wr_clk	(needs to run camera clock speed)
		.rd_clk(clk), // input rd_clk	(needs to run at speed of main system clk)
		.din(data_write_fifo), // input [23:0] din  (data to be eventually be written to DDR mem)
		.wr_en(fifo_wren), // input wr_en
		.rd_en(fifo_rden), // input rd_en
		.dout(data_write_buffered_fifo), // output [23:0] dout
		.full(fifo_full), // output full
		.empty(fifo_empty) // output empty
	);

	localparam	INIT_STATE = 0,
			IDLE = 1,
			WRITE = 2,
			READ = 3,
			INC_ADDR = 4;
	
	reg [4:0] state1, state2;
	reg [18:0] counter;
	assign state_debug = state1;

	//----begin FIFO write control
	//----this runs at the pixel clock 
	//----DOES NOT respect the pause signal
	always @(posedge camera_data_pclk) begin
		//debugging -- temp (FIX)
		pixel_valid = 1;

		case (state1) 
			INIT_STATE: 
				begin
					fifo_wren = 0;
					state1 = IDLE;
				end
			IDLE: 	begin
					fifo_wren = 0;
					if ((pixel_valid == 1) && (!fifo_full)) begin
						state1 = WRITE;
					end
					else begin
						state1 = IDLE;
					end
				end
			WRITE: 	begin
					fifo_wren = 1;
					state1 = IDLE;
				end
		endcase
	end	//end always
	//----end FIFO write control
	
	//----begin FIFO read control
	//----this runs at clk
	//----MUST respect the pause signal from memory controller
	always @(posedge clk) begin
		if (pause == 0) begin
			if (camera_grab_enable == 1) begin
					
				//debugging -- temp (FIX)
				counter = counter + 1;
				
				case (state2) 
					INIT_STATE: 
						begin
							fifo_rden = 0;
							ddr_addr = 0;
							state2 = IDLE;
						end
					IDLE: 	begin
							ddr_wren = 0;
							fifo_rden = 0;
							if (!fifo_empty) begin
								state2 = READ;
							end
							else begin
								state2 = IDLE;
							end
							//reset address counter after complete 320x240 frame written
							if (addr_count >= 76800 - 1) begin
								addr_count = 0;
								camera_grab_done = 1;
							end
						end
					READ:	begin
							fifo_rden = 1;
							//ddr_data_write = data_write_buffered;
							ddr_data_write = counter;
							ddr_addr = addr_count + data_write_offset;
							ddr_wren = 1;
							state2 = INC_ADDR;
						end
					INC_ADDR: 
						begin
							addr_count = addr_count + 1;
							state2 = IDLE;
						end
				endcase
				
			end else begin
				camera_grab_done = 0;
				addr_count = 0;
				ddr_wren = 0;
				ddr_addr = 0;
			end	
		end	//end if pause 0
	end	//end always
	//----end FIFO read control

/*	// Shutter control
	always @(posedge clk) begin
		if ((camera_grab_enable == 1) && (camera_grab_done == 0)) begin
			if (exposed == 0) begin
				if (ers_exposure_timer < ((ers_exposure_length * ERS_CYCLES_PER_ROW) + ERS_EXPOSURE_MINIMUM)) begin
					camera_data_trigger = 0;		// Active low
					ers_exposure_timer = ers_exposure_timer + 1;
				end else begin
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
	always @(posedge clk) begin
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
	
	// Camera data input processor
	always @(posedge camera_data_pclk) begin
		data_read_sync = data_read;
		databuffer = camera_data_port;
		
		// Deal with the control signals...
		if (camera_grab_enable == 0) begin
			camera_grab_done = 0;
		end
		
		// Capture a 320 x 240 image if enabled (8-bit tricolor)
		// One line is G1-R-G1-R-G1-R...
		// The next line is B-G2-B-G2-B-G2...
		// This is the well known Bayer pattern
		if ((camera_grab_enable == 1) && (camera_grab_done == 0)) begin
			auxramclk_speed_select = 1;
			camera_grab_in_progress = 1;
			if ((camera_data_href == 1) && (camera_data_vsync == 1) && (vsync_locked == 1) && (line_valid == 1)) begin
				case (camera_toggle)
					0: begin
 						wren = 1;
//						address = address_buffer;
						case (altline)
							0: databuffer_mem[7:0] = databuffer[11:4];		// G1
							1: databuffer_mem[31:24] = databuffer[11:4];		// B
						endcase
						// Increment the address pointer
						camera_memory_address = camera_memory_address + 1;
						camera_toggle = 1;
					end
					1: begin
						case (altline)
							0: databuffer_mem[15:8] = databuffer[11:4];		// R
							1: begin
								databuffer_mem[23:16] = databuffer[11:4];		// G2
								databuffer_mem[15:0] = data_read_sync[15:0];
								red_average = red_average + databuffer_mem[15:8];
								green_average = green_average + databuffer_mem[7:0];
								blue_average = blue_average + databuffer_mem[31:24];
							end
						endcase
						//data_write = databuffer_mem;
						data_write = camera_memory_address;
						wren = 0;										// Commit the data to RAM
						camera_toggle = 0;
					end
				endcase
				if (camera_memory_address >= 76800) begin		// All done!
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
						1: begin
							camera_grab_in_progress = 0;
							camera_toggle = 0;
							camera_grab_done = 1;
							altline = 0;
							vsync_locked = 0;
							red_average = 0;
							green_average = 0;
							blue_average = 0;
						end
					endcase
				end
				line_counter = line_counter + 1;
			end else begin
				wren = 0;
			end
			if ((camera_data_vsync_prev == 1) && (camera_data_vsync == 0)) begin
				altcol = ~altcol;
			end			
			if ((camera_data_href_prev == 1) && (camera_data_href == 0)) begin
				altline = ~altline;
 				if (altline == 1) begin
 					if (camera_memory_address > (320 - 1)) begin
 						camera_memory_address = camera_memory_address - 320;
 					end
 				end
				camera_module_detect = 1;
				camera_not_present_timer = 0;
			end
			if ((altcol == 1) && (altline == 1)) begin
				pixel_valid = 1;
			end else begin
				pixel_valid = 0;
			end
			if (camera_data_href == 0) begin
				line_counter = 0;
				camera_toggle = 0;
			end
			if (exposed == 1) begin
				vsync_locked = 1;
				if (camera_not_present_timer > 100000) begin
					camera_module_detect = 0;
					camera_grab_done = 1;
				end
				camera_not_present_timer = camera_not_present_timer + 1;
			end
			if (line_counter < 640) begin
				line_valid = 1;
			end else begin
				line_valid = 0;
			end
		end else begin
			camera_not_present_timer = 0;
			camera_grab_in_progress = 0;
			camera_memory_address = 0;
			camera_toggle = 0;
			altline = 0;
			vsync_locked = 0;
			red_average = 0;
			green_average = 0;
			blue_average = 0;
			final_process_counter = 0;
			
			// Release the SRAM lines
			address = 0;
			data_write = 0;
			wren = 1;
			
			// Reset the RAM to standard operation
			auxramclk_speed_select = 0;
		end
		
//		address_buffer = camera_memory_address + data_write_offset;
		
		camera_data_href_prev = camera_data_href;
		camera_data_vsync_prev = camera_data_vsync;

	end
*/
endmodule
