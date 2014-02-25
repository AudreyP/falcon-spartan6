`timescale 1ns / 1ps
/**********************************************************************
 Copyright (C) 2014 Audrey Pearson <aud.pearson@gmail.com> 

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
module sram(
	input wire clk,
	input wire prev_clk,
	input wire sram_clk,
	input wire reset,
	input wire modified_clock_sram,
	input wire wren,             	     // write enable
	input wire [31:0] data_write,      // data being written to memory
	output wire [31:0] data_read,       // data being read from memory
	
	output reg pause,
	
	//sram controls 
	input wire [17:0] starting_address,
	inout wire [15:0] SRAM_DQ,
	output wire SRAM_CE_N,
	output wire SRAM_OE_N,
	output wire SRAM_LB_N,
	output wire SRAM_UB_N,
	output wire SRAM_WE_N,
	output wire [18:0] SRAM_ADDR,
	output wire RamClk,
	output wire RamAdv,
	
	/*//test 
	input wire counter_done,
	input wire start_read,
	input wire start_write,*/
	output wire [15:0] debug0,
	output reg done
	 );

	
	//--------------------------------------------
	// INSTANTIATE DDR SDRAM CONTROLLER CORE
	//--------------------------------------------	
	//wires
	wire clk_fb;
	wire data_req_q;
	wire busy_q;
	wire [15:0] data_out_q;
	wire data_vld_q;

	
	//registers
	reg [2:0] cmd;
	reg [18:0] addr;
	reg [15:0] data_in;
	
	ddr_sdr(
		// Clock and RESET signals |module POV|
		.rst_n(1),     		// |IN|external async reset, ACTIVE LOW (reset unused, so keep high)
		.clk(clk),			// |IN| system clock (e.g. 100MHz)
		.sys_rst_qn(),	// |OUT|  sync reset low active, released after DCMs are locked, may be used by other modules inside the FPGA
		.sys_clk_out(),	// |OUT|  system clock, dcm output, may be used by other modules inside the FPGA as global clock
		.clk_fb(clk_fb),	// |IN|  DCM feedback clock, must be external connected to ddr_sdr_clk !
		// User Interface signals
		.cmd(cmd),		// |IN|  User command: READ, WRITE, NOP
		.cmd_vld(1),		// |IN|  User command valid (if '1')
		.addr(addr),		// |IN|  User address, contains (ROW & BANK & COL), see Address Mapping 
		.busy_q(busy_q),	// |OUT|  Controller busy flag, commands are ignored when active
		// Data Interface
		.data_in(data_in),            // |IN|  User input data (written to DDR SDRAM)
		.data_req_q(data_req_q),         // |OUT|  User data request, controls input data flow
		.data_out_q(data_out_q),         // |OUT|  User data output (read from DDR SDRAM)
		.data_vld_q(data_vld_q),         // |OUT|  data_out_q is valid when '1'
		// DDR SDRAM external signals
		.sdr_clk(clk_fb),		// |OUT|  DDR SDRAM Clock
		.sdr_clk_n(),		// |OUT|  Inverted DDR SDRAM Clock
		.cke_q(),		// |OUT|  DDR SDRAM clock enable
		.cs_qn(),		// |OUT|  DDR SDRAM /chip select
		.ras_qn(),		// |OUT|  DDR SDRAM /ras
		.cas_qn(),		// |OUT|  DDR SDRAM /cas
		.we_qn(),		// |OUT|  DDR SDRAM /write enable
		.dm_q(),		// |OUT|  DDR SDRAM data mask bits, all set to "0"
		.dqs_q(),		// |OUT|  DDR SDRAM data strobe, used only for write operations
		.ba_q(),		// |OUT|  DDR SDRAM bank select
		.a_q(),			// |OUT|  DDR SDRAM address bus 
		.data(),		// |INOUT|  DDR SDRAM bidirectional data bus
		// Status signals
		.dcm_error_q()        // |OUT|  Indicates DCM Errors
		);

//***************************************************************************************//

	//-------------------------------
	// READ/WRITE STATE MACHINE
	//-------------------------------
	//registers
	reg [15:0] data_out_upper, data_out_lower;
	reg [6:0] state;
	reg [15:0] data_to_ram;
	reg wr, rd;
	// reg [18:0] addr;	//already declared
	reg data_direction;
	
	//debugging
	reg write_upper_timeout;
	reg write_lower_timeout;
	reg read_upper_timeout;
	reg read_lower_timeout;
	reg [3:0] wu_cnt;
	reg [3:0] wl_cnt;
	reg [4:0] write_counter_total;
	reg [3:0] ru_cnt;
	reg [3:0] rl_cnt;
	reg [4:0] read_counter_total;
	reg [4:0] count;
	
	//for asynch r/w, these must be tied low
	assign SRAM_CE_N = 0;	//chip enable
	assign RamClk = 0;
	assign RamAdv = 0;
	assign SRAM_UB_N = 0;	//either low or don't-care for r/w
	assign SRAM_LB_N = 0;	//either low or don't-care for r/w
	//for a read, OE must be LOW. For write, don't care (keep HIGH)
	//for a write, WE must be LOW. For read, must keep HIGH
	
	assign data_read = {data_out_upper, data_out_lower};
	
	/*
 	assign SRAM_DQ = (data_direction) ? 16'bz : data_to_ram;	//if zero, then write--meaning SRAM_DQ = data_to_ram.
	//assign SRAM_DQ = (data_direction) ? 16'bz : 32'h80f02040;
	assign SRAM_ADDR = addr;
	assign data_read = {data_read_upper_byte, data_read_lower_byte};
	assign SRAM_WE_N = wr;
	assign SRAM_OE_N = rd;
	*/
	
	assign debug0 = state;
	
	//states
	localparam	INIT_STATE = 0,
			IDLE_STATE = 1,
			WRITE_UPPER_STATE = 2,
			WRITE_WAIT_1 = 4,
			WRITE_WAIT_2 = 5,
			WRITE_UPPER_DATA_VALID = 6,
			WRITE_LOWER_STATE = 7,
			WRITE_WAIT_3 = 8,
			WRITE_WAIT_4 = 9,
			WRITE_LOWER_DATA_VALID = 10,
			WRITE_WAIT_5 = 11,
			READ_UPPER_STATE = 12,
			READ_LOWER_STATE = 13,
			EXTRA_WAIT_1 = 14,
			EXTRA_WAIT_2 = 15,
			EXTRA_WAIT_3 = 16,
			EXTRA_WAIT_4 = 17;
	//want write to take 10 clock cycles to complete
	//idle - write_upper - wait1 - wait2 - upper_valid - write_lower - wait3 - wait4 - lower_valid - wait5. Done and back to idle.
	//idle - read_upper (x4) - read_lower (x4) - read_wait. Done and back to idle. 

	localparam	NOP = 0,
			READ = 1,
			WRITE = 2,
			REFRESH = 3;	//unused
	
	//localparam starting_address = 0;
	
	wire prev_reset;
	assign prev_reset = reset;
	
	//----------------------------
	// BEGIN STATE MACHINE
	//----------------------------
	always @(posedge modified_clock_sram) begin
		if (main_clk == 1 && main_clk_prev == 0) begin
			counter = 0
		
		case (state)
		INIT_STATE:	begin	
					addr = 0;
					cmd = NOP;
					state = RESET_WAIT_STATE;
				end
		
		IDLE_STATE:	begin
				
				end

		LATCH_STATE:	begin
					addr[18:1] = starting_address;	//starting address 17 bits--shove into upper 17b of 18b addr to leave room for 1 increment
					addr[0] = 0;
					cmd = NOP;
					data_direction = 1;
					
					//reset counters
					count = 0;
					wu_cnt = 0;
					wl_cnt = 0;
					ru_cnt = 0;
					rl_cnt = 0;
					
					
					// look for refresh signal
					if (reset == 1 && prev_reset == 0) begin		//edge detected
						state = INIT_STATE;
					end
					else begin	// no refresh command detected. Commence normal operations
						//determine read or write operation
						if (wren==1) begin	//if a write signal is received, begin write	
							data_in = data_write[31:16];	//write upper word first
							cmd = WRITE;
							state = WRITE_UPPER_STATE;
						end
						else begin	//wren == 0
							cmd = READ;
							state = READ_UPPER_STATE;
						end // end else
					end //end else
				end
		
		//-----WRITE CYCLE
		WRITE_UPPER_STATE: 
				begin
					data_direction = 0;
					cmd = WRITE;
					if (busy_q == 0 && data_req_q == 1 && write_upper_timeout == 0) begin
						state = WRITE_WAIT_1;
					end
					else begin
						if (wu_cnt <= 2) begin		//wait up to two clock cycles 
							wu_cnt = wu_cnt + 1;
							state = WRITE_UPPER_STATE;
						end
						else begin
							write_upper_timeout = 1;	//error code--data_req_q took too long to go to 1
						end //end else
					end // end else	
				end //end state

		WRITE_WAIT_1: 	begin
					data_direction = 0;
					state = WRITE_WAIT_2;
				end 
		
		WRITE_WAIT_2:	begin
					data_direction = 0;
					state = WRITE_UPPER_DATA_VALID;
				end

		WRITE_UPPER_DATA_VALID: 
				begin
					data_direction = 0;
					data_in = data_write[15:0];
					addr[0] = 1;
					state = WRITE_LOWER_STATE;
				end

		WRITE_LOWER_STATE: 
				begin
					data_direction = 0;
					wl_cnt = wl_cnt + 1;
					if (data_req_q && write_lower_timeout == 0) begin
						state = WRITE_WAIT_3;
					end
					else begin
						if (wl_cnt <= 2) begin		//wait up to two clock cycles 
							state = WRITE_LOWER_STATE;
						end
						else begin
							write_lower_timeout = 1;	//error code--data_req_q took too long to go to 1
						end
					end
				end	

		WRITE_WAIT_3:	begin
					data_direction = 0;
					state = WRITE_WAIT_4;
				end
		
		WRITE_WAIT_4:	begin
					data_direction = 0;
					state = WRITE_LOWER_DATA_VALID;
					write_counter_total = wu_cnt + wl_cnt;
				end
		
		WRITE_LOWER_DATA_VALID: 
				begin
					data_direction = 0;
					if (write_counter_total == 0) begin
						state = EXTRA_WAIT_1;	//wait for 4 more clock cycles before going to idle state
					end
					else if (write_counter_total == 1) begin
						state = EXTRA_WAIT_2;
					end
					else if (write_counter_total == 2) begin
						state = EXTRA_WAIT_3;
					end
					else if (write_counter_total == 3) begin
						state = EXTRA_WAIT_4;
					end
					else  begin // write_counter_total == 4
						state = IDLE_STATE;
					end
				end
		
		EXTRA_WAIT_1:	begin
					state = EXTRA_WAIT_2;
				end
		
		EXTRA_WAIT_2:	begin
					state = EXTRA_WAIT_3;
				end
		
		EXTRA_WAIT_3:	begin
					state = EXTRA_WAIT_4;
				end
		
		EXTRA_WAIT_4:	begin
					state = IDLE_STATE;
				end

		//----READ CYCLE				
		READ_UPPER_STATE:
				begin
					data_direction = 1;
					if (busy_q == 0 && data_vld_q == 1 && read_upper_timeout == 0) begin
						data_out_upper = data_out_q;
						read_upper_timeout = 0;
						state = READ_LOWER_STATE;
					end
					else begin
						if (ru_cnt >= 4) begin
							ru_cnt = ru_cnt + 1;
							state = READ_UPPER_STATE;
						end
						else begin
							read_upper_timeout = 1;	//error code
						end
					end
				end			

		READ_LOWER_STATE:
				begin
					data_direction = 1;
					if (busy_q == 0 && data_vld_q == 1 && read_lower_timeout == 0) begin
						data_out_lower = data_out_q;
						read_lower_timeout = 0;
						state = IDLE_STATE;
					end
					else begin
						if (rl_cnt >= 4) begin
							rl_cnt = rl_cnt + 1;
							state = READ_LOWER_STATE;
						end
						else begin
							read_lower_timeout = 1;
						end
					end
				end
		endcase		
	end	//end always
	

endmodule
