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
module mem_manager(
	input wire clk,
	input wire prev_clk,
	input wire sram_clk,
	input wire modified_clock_sram,
	input wire wren,             	     // write enable
	input wire [31:0] data_write,      // data being written to memory
	output wire [31:0] data_read,       // data being read from memory
	
	output reg pause,
	
	input wire [17:0] starting_address,
	
	output wire sdr_clk,
	output wire sdr_clk_n,
	output wire cke_q,
	output wire cs_qn,
	output wire ras_qn,
	output wire cas_qn,
	output wire we_qn,
	output wire [2:0] dm_q,
	output wire [2:0] dqs_q,
	output wire [2:0] ba_q,
	output wire [12:0] a_q,
	output wire [15:0] data,
	
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
		.rst_n(1),		// |IN|external async reset, ACTIVE LOW (reset unused, so keep high)
		.clk(clk),		// |IN| system clock (e.g. 100MHz)
		.sys_rst_qn(),		// |OUT|  sync reset low active, released after DCMs are locked, may be used by other modules inside the FPGA
		.sys_clk_out(),		// |OUT|  system clock, dcm output, may be used by other modules inside the FPGA as global clock
		.clk_fb(clk_fb),	// |IN|  DCM feedback clock, must be external connected to ddr_sdr_clk !
		// User Interface signals
		.cmd(cmd),		// |IN|  User command: READ, WRITE, NOP
		.cmd_vld(1),		// |IN|  User command valid (if '1')
		.addr(addr),		// |IN|  User address, contains (ROW & BANK & COL), see Address Mapping 
		.busy_q(busy_q),	// |OUT|  Controller busy flag, commands are ignored when active
		// Data Interface
		.data_in(data_in),	// |IN|  User input data (written to DDR SDRAM)
		.data_req_q(data_req_q), // |OUT|  User data request, controls input data flow
		.data_out_q(data_out_q), // |OUT|  User data output (read from DDR SDRAM)
		.data_vld_q(data_vld_q), // |OUT|  data_out_q is valid when '1'
		// DDR SDRAM external signals (route all these to main and then ucf)
		.sdr_clk(sdr_clk),	// |OUT|  DDR SDRAM Clock
		.sdr_clk_n(sdr_clk_n),		// |OUT|  Inverted DDR SDRAM Clock
		.cke_q(cke_q),		// |OUT|  DDR SDRAM clock enable
		.cs_qn(cs_qn),		// |OUT|  DDR SDRAM /chip select
		.ras_qn(ras_qn),	// |OUT|  DDR SDRAM /ras
		.cas_qn(cas_qn),	// |OUT|  DDR SDRAM /cas
		.we_qn(we_qn),		// |OUT|  DDR SDRAM /write enable
		.dm_q(dm_q),		// |OUT|  DDR SDRAM data mask bits, all set to "0"
		.dqs_q(dqs_q),		// |OUT|  DDR SDRAM data strobe, used only for write operations
		.ba_q(ba_q),		// |OUT|  DDR SDRAM bank select
		.a_q(a_q),		// |OUT|  DDR SDRAM address bus 
		.data(data),		// |INOUT|  DDR SDRAM bidirectional data bus
		// Status signals
		.dcm_error_q()        // |OUT|  Indicates DCM Errors
		);

		//approximates an external connection between clk_fb and sdr_clk
		BUFG BUFG_inst (
		.O(clk_fb), // 1-bit output: Clock buffer output
		.I(sdr_clk)  // 1-bit input: Clock buffer input
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
	reg ddr_op_in_progress;
	
	
	reg [4:0] counter;
	
	//for asynch r/w, these must be tied low
	assign SRAM_CE_N = 0;	//chip enable
	assign RamClk = 0;
	assign RamAdv = 0;
	assign SRAM_UB_N = 0;	//either low or don't-care for r/w
	assign SRAM_LB_N = 0;	//either low or don't-care for r/w
	//for a read, OE must be LOW. For write, don't care (keep HIGH)
	//for a write, WE must be LOW. For read, must keep HIGH
	
	assign data_read = {data_out_upper, data_out_lower};
	
	assign debug0 = state;
	
	//states
	localparam	INIT_STATE = 0,
			IDLE_STATE = 1,
			NOP_STATE = 2,
			LATCH_STATE = 3,
			WRITE_UPPER_STATE = 4,
			WRITE_WAIT_1 = 5,
			WRITE_WAIT_2 = 6,
			WRITE_UPPER_DATA_VALID = 7,
			WRITE_LOWER_STATE = 8,
			WRITE_WAIT_3 = 9,
			WRITE_WAIT_4 = 10,
			WRITE_LOWER_DATA_VALID = 11,
			WRITE_WAIT_5 = 12,
			READ_UPPER_STATE = 13,
			READ_LOWER_STATE = 14,
			DDR_DATA_VALID_STATE = 15,
			WAIT_STATE = 16;

	localparam	NOP = 0,
			READ = 1,
			WRITE = 2,
			REFRESH = 3;	//unused
	
	localparam 	LATCH_TIME = 4,
					NO_RETURN = 9;
			
	//----------------------------
	// BEGIN STATE MACHINE
	//----------------------------
	always @(posedge modified_clock_sram) begin
		//counter resets on rising edge of main clock. 
		//Divides one clock cycle into time slices determined by the modified clock rate (in this case, 10 slices per main clk cycle)
		//(counter increments on posedge of modified clock)
		if (clk == 1 && prev_clk == 0) begin	
			counter = 0;
		end
		else begin
			counter = counter + 1;
		end
		
		if (counter > NO_RETURN && ddr_op_in_progress == 1) begin
			pause = 1;
		end
		
		case (state)
		INIT_STATE:	begin	
					addr = 0;
					cmd = NOP;
					state = IDLE_STATE;
				end
		
		IDLE_STATE:	begin
				pause = 0;
				if (counter >= LATCH_TIME) begin
					state = LATCH_STATE;
				end
				else begin
					state = IDLE_STATE;				
				end
				end

		LATCH_STATE:	begin
					addr[18:1] = starting_address;	//starting address 17 bits--shove into upper 17b of 18b addr to leave room for 1 increment
					addr[0] = 0;
					cmd = NOP;
					data_direction = 1;					
				
					//determine read or write operation
					if (wren==1) begin	//if a write signal is received, begin write	
						data_in = data_write[31:16];	//write upper word first
						cmd = WRITE;
						state = WRITE_UPPER_STATE;
						ddr_op_in_progress = 1;
					end
					else begin	//wren == 0
						cmd = READ;
						state = READ_UPPER_STATE;
						ddr_op_in_progress = 1;
					end // end else
				end
		
		//-----WRITE CYCLE
		WRITE_UPPER_STATE: 
				begin
					data_direction = 0;
					cmd = WRITE;
					if (busy_q == 0 && data_req_q == 1) begin
						state = WRITE_WAIT_1;
					end
					else begin
						state = WRITE_UPPER_STATE;
					end
				end

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
					if (busy_q ==0 && data_req_q == 1) begin
						state = WRITE_WAIT_3;
					end
					else begin
						state = WRITE_LOWER_STATE;
					end
				end	

		WRITE_WAIT_3:	begin
					data_direction = 0;
					state = WRITE_WAIT_4;
				end
		
		WRITE_WAIT_4:	begin
					data_direction = 0;
					state = WRITE_LOWER_DATA_VALID;
				end
		
		WRITE_LOWER_DATA_VALID: 
				begin
					data_direction = 0;
					state = DDR_DATA_VALID_STATE;
					ddr_op_in_progress = 0;
				end

		//----READ CYCLE				
		READ_UPPER_STATE:
				begin
					data_direction = 1;
					if (busy_q == 0 && data_vld_q == 1) begin
						data_out_upper = data_out_q;
						state = READ_LOWER_STATE;
					end
					else begin
						state = READ_UPPER_STATE;
					end
				end			

		READ_LOWER_STATE:
				begin
					data_direction = 1;
					if (busy_q == 0 && data_vld_q == 1) begin
						data_out_lower = data_out_q;
						state = DDR_DATA_VALID_STATE;
						ddr_op_in_progress = 0;  //entire data word has been read
					end
					else begin
						state = READ_LOWER_STATE;
					end
				end
		
		//-----occurs only when an entire data word has been written or read to/from DDR
		DDR_DATA_VALID_STATE: begin
					if (counter < NO_RETURN) begin
						pause = 0;
						state = IDLE_STATE;
					end
					else begin //counter >= point of no return (enters the "forbidden zone" and must wait 1 main clk cycle)
						state = WAIT_STATE;
					end
				end
		
		WAIT_STATE:	begin
					pause = 1;
					if (counter == NO_RETURN) begin
						state = IDLE_STATE;
					end
					else begin //remain in this state until the next "point of no return"
						state = WAIT_STATE;
					end
				end
		endcase		
	end	//end always
	

endmodule
