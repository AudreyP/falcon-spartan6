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
	input wire crystal_clk,
	input wire prev_clk,
	input wire modified_clock_sram,
	input wire wren,             	     // write enable
	input wire [31:0] data_write,      // data being written to memory
	output reg [31:0] data_read,       // data being read from memory
	
	output reg pause,
	output reg [6:0] counter,
	
	input wire [17:0] starting_address,
	
	output wire read_error,
	output wire dram_ck,
	output wire dram_ck_n,
	output wire dram_cke,
	output wire cs_qn,
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
	output wire controller_ready,
	output wire c3_clk0,
	output wire c3_rst0,
	inout rzq,
	
	output main_system_clock,
	
	/*//test 
	input wire counter_done,
	input wire start_read,
	input wire start_write,*/
	output wire [15:0] debug0
	 );

	wire calib_done;
	assign controller_ready = calib_done;	

	//--------------------------------------------
	// INSTANTIATE DDR SDRAM CONTROLLER CORE
	//--------------------------------------------	
	//wires
	wire clk_fb;
	wire data_req_q;
	wire busy_q;
	wire [15:0] data_out_q;
	wire data_vld_q;

	
	//command connections
	wire cmd_clk;
	assign cmd_clk = modified_clock_sram;
	reg cmd_en;
	reg [2:0] cmd_instr;
	reg [29:0] cmd_addr;
	wire cmd_empty;
	wire cmd_full;
	
	//write connections
	wire wr_clk;
	assign wr_clk = modified_clock_sram;
	reg wr_en;
	reg [3:0] wr_mask = 4'b0;
	reg [31:0] wr_data;
	wire wr_full;
	wire wr_empty;
	wire [6:0] wr_count;
	wire wr_underrun;
	wire wr_error;
	
	//read connections
	wire rd_clk;
	assign rd_clk = modified_clock_sram;
	reg rd_en;
	wire [31:0] rd_data;
	wire rd_full;
	wire rd_empty;
	wire [6:0] rd_count;
	wire rd_overflow;
	wire rd_error;
	
	assign read_error = rd_error | rd_overflow;

	//in / out determined wrt module lpddr_s6
	lpddr_s6 u_lpddr_s6 (
		.c3_sys_clk(crystal_clk),	// IN
		.c3_sys_rst_i(0),	// IN
		
		.c3_clk0(c3_clk0),	// OUTPUT
		.c3_rst0(c3_rst0),	// OUTPUT
		.c3_calib_done(calib_done),	// OUTPUT
		.mcb3_rzq(rzq),	// INOUT

		//dram connections
		.mcb3_dram_dq(dram_dq),	// INOUT
		.mcb3_dram_a(dram_a),  	// OUTPUT
		.mcb3_dram_ba(dram_ba),	// OUTPUT
		.mcb3_dram_ras_n(dram_ras_n),	// OUTPUT
		.mcb3_dram_cas_n(dram_cas_n),	// OUTPUT
		.mcb3_dram_we_n (dram_we_n), 	// OUTPUT
		.mcb3_dram_cke(dram_cke), 		// OUTPUT
		.mcb3_dram_ck(dram_ck), 		// OUTPUT
		.mcb3_dram_ck_n (dram_ck_n),	// OUTPUT 
		.mcb3_dram_dqs (dram_dqs),		// OUTPUT
		.mcb3_dram_udqs(dram_udqs),    	// INOUT | for X16 parts
		.mcb3_dram_udm(dram_udm),     	// OUTPUT | for X16 parts
		.mcb3_dram_dm(dram_dm),		// OUTPUT
		
		// command connections
		.c3_p0_cmd_clk(cmd_clk),	// INPUT
		.c3_p0_cmd_en(cmd_en),	// INPUT
		.c3_p0_cmd_instr(cmd_instr),	// INPUT [2:0]
		.c3_p0_cmd_bl(1),		//INPUT [5:0] --keep burst length to 1 32-bit word
		.c3_p0_cmd_byte_addr(cmd_addr),	// INPUT [29:0]
		.c3_p0_cmd_empty(cmd_empty),	// OUTPUT 
		.c3_p0_cmd_full(cmd_full),	// OUTPUT
		
		 // write connections
		.c3_p0_wr_clk(wr_clk),		// INPUT 
		.c3_p0_wr_en(wr_en),		// INPUT
		.c3_p0_wr_mask(wr_mask),	// INPUT [3:0]
		.c3_p0_wr_data (wr_data),	// INPUT [31:0]
		.c3_p0_wr_full(wr_full),	// OUTPUT
		.c3_p0_wr_empty(wr_empty),	// OUTPUT
		.c3_p0_wr_count(wr_count),	// OUTPUT [6:0]
		.c3_p0_wr_underrun(wr_underrun), //OUTPUT
		.c3_p0_wr_error(wr_error),	// OUTPUT
		
		 // read connections
		.c3_p0_rd_clk(rd_clk),
		.c3_p0_rd_en(rd_en),
		.c3_p0_rd_data (rd_data),
		.c3_p0_rd_full (rd_full),
		.c3_p0_rd_empty(rd_empty),
		.c3_p0_rd_count(rd_count),
		.c3_p0_rd_overflow(rd_overflow),
		.c3_p0_rd_error(rd_error),
		
		.main_system_clock(main_system_clock)
		);


//***************************************************************************************//

	//-------------------------------
	// READ/WRITE STATE MACHINE
	//-------------------------------
	//registers
	reg [15:0] data_out_upper, data_out_lower;
	reg [6:0] state = 0;
	reg [15:0] data_to_ram;
	reg wr, rd;
	// reg [18:0] addr;	//already declared
	reg ddr_op_in_progress;
	
	
	assign debug0 = state;
	
	//states
	localparam	INIT_STATE = 0,
			IDLE_STATE = 1,
			NOP_STATE = 2,
			LATCH_STATE = 3,
			
			WRITE_STATE = 4,
			WRITE_WAIT_1 = 5,
			SET_WRITE_COMMAND = 6,
			SET_WRITE_WAIT = 7,
			WRITE_DATA_VALID = 8,
			
			READ_COMMAND_STATE = 9,
			READ_TRANSITION_STATE = 10,
			READ_STATE = 11,
			
			DDR_DATA_VALID_STATE = 12,
			WAIT_STATE = 13;

	localparam	WRITE = 0,
			READ = 1,
			REFRESH = 4;	
	
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
					cmd_addr = 0;
					//cmd = NOP;
					if (calib_done == 1)
						state = IDLE_STATE;
					else
						state = INIT_STATE;
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
					cmd_addr[29:2] = starting_address;	//starting address 17 bits--shove into upper 17b of 19b addr to leave room for two 0's
					cmd_addr[1:0] = 0;
				
					//determine read or write operation
					if (wren==1) begin	//if a write signal is received, begin write	
						wr_data = data_write;	//write whole 32-bit word
						//wr_data = 32'hf0806020;
						state = WRITE_STATE;
						ddr_op_in_progress = 1;
					end
					else begin	//wren == 0
						cmd_instr = READ;
						//burst length set to constant 1
						//address already set in LATCH STATE
						state = READ_COMMAND_STATE;
						ddr_op_in_progress = 1;
					end // end else
				end
		
		//-----WRITE CYCLE
		WRITE_STATE: 
				begin
					wr_en = 1;	//now that data is in data path, assert write enable
					//wr_en = 0;
					state = WRITE_WAIT_1;
				end 

		WRITE_WAIT_1: 	begin
					wr_en = 0;	//complete wr_en pulse, delay before setting cmd (necessary)?
					cmd_instr = WRITE;
					state = SET_WRITE_WAIT;
				end
		
// 		SET_WRITE_COMMAND:
// 				begin
// 					cmd_instr = WRITE;
// 					//burst length set to constant "1"
// 					//address already set in LATCH STATE
// 					state = SET_WRITE_WAIT;
// 				end
		SET_WRITE_WAIT: //wait state to ensure the data is valid
				begin
					cmd_en = 1;
					state = WRITE_DATA_VALID;
				end

		WRITE_DATA_VALID:
				begin
					cmd_en = 0;
					if (wr_empty == 1) begin //write fifo empty--ie data is written to memory
						state = DDR_DATA_VALID_STATE;
					end
					else begin
						state = WRITE_DATA_VALID;
					end
				end

		//----READ CYCLE
		READ_COMMAND_STATE:
				begin
					cmd_en = 1;	//enable read command with addr, burst length, and instruction data set in IDLE STATE
					state = READ_TRANSITION_STATE;
				end			

		READ_TRANSITION_STATE:
				begin
					cmd_en = 0;	//disable read command
					if (rd_empty == 0) begin
						state = READ_STATE;
					end
					else
						state = READ_TRANSITION_STATE;
				end
		
		READ_STATE: 	begin
					rd_en = 1;
					data_read = rd_data;
					if (rd_empty == 1)
						state = DDR_DATA_VALID_STATE;
					else
						state = READ_STATE;
				end

		//-----occurs only when an entire data word has been written or read to/from DDR
		DDR_DATA_VALID_STATE: begin
					rd_en = 0;
					wr_en = 0;
					ddr_op_in_progress = 0;
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
