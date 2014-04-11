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
	input wire clk_fast,
	input wire clk_sync,
	input wire crystal_clk,
	input wire all_dcms_locked,
	input wire modified_clock_sram,
	input wire wren,             	     // write enable
	input wire [31:0] data_write,      // data being written to memory
	output reg [31:0] data_read,       // data being read from memory
	
	output reg pause,
	
	input wire [17:0] starting_address,
	
	output wire read_error,
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
	output wire controller_ready,
	output wire c3_clk0,
	output wire c3_rst0,
	inout rzq,
	
	output main_system_clock,
	
	/*//test 
	input wire counter_done,
	input wire start_read,
	input wire start_write,*/
	output wire [15:0] debug0,
	output wire [15:0] debug1,
	output wire [15:0] debug2
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

	wire ddr_core_rst;
	//assign ddr_core_rst = ~all_dcms_locked;
	assign ddr_core_rst = 0;

	//command connections
	wire cmd_clk;
	assign cmd_clk = modified_clock_sram;
	reg cmd_en;
	reg [2:0] cmd_instr;
	reg [5:0] cmd_bl = 1;
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
	
	reg [9:0] counter = 0;
	
	assign read_error = rd_error | rd_overflow;

	//in / out determined wrt module lpddr_s6
	lpddr_s6 u_lpddr_s6 (
		.c3_sys_clk(crystal_clk),	// IN
		.c3_sys_rst_i(ddr_core_rst),	// IN
		
		.c3_clk0(c3_clk0),		// OUTPUT
		.c3_rst0(c3_rst0),		// OUTPUT
		.c3_calib_done(calib_done),	// OUTPUT
		.mcb3_rzq(rzq),	// INOUT

		//dram connections
		.mcb3_dram_dq(dram_dq),		// INOUT
		.mcb3_dram_a(dram_a),  		// OUTPUT
		.mcb3_dram_ba(dram_ba),		// OUTPUT
		.mcb3_dram_ras_n(dram_ras_n),	// OUTPUT
		.mcb3_dram_cas_n(dram_cas_n),	// OUTPUT
		.mcb3_dram_we_n (dram_we_n), 	// OUTPUT
		.mcb3_dram_cke(dram_cke), 	// OUTPUT
		.mcb3_dram_ck(dram_ck), 	// OUTPUT
		.mcb3_dram_ck_n (dram_ck_n),	// OUTPUT
		.mcb3_dram_dqs (dram_dqs),	// OUTPUT
		.mcb3_dram_udqs(dram_udqs),	// INOUT | for X16 parts
		.mcb3_dram_udm(dram_udm),	// OUTPUT | for X16 parts
		.mcb3_dram_dm(dram_dm),		// OUTPUT
		
		// command connections
		.c3_p0_cmd_clk(cmd_clk),	// INPUT
		.c3_p0_cmd_en(cmd_en),		// INPUT
		.c3_p0_cmd_instr(cmd_instr),	// INPUT [2:0]
		.c3_p0_cmd_bl(cmd_bl),		// INPUT [5:0] --keep burst length to 1 32-bit word
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
	reg [3:0] state = 0;
	reg [15:0] data_to_ram;
	reg wr, rd;
	// reg [18:0] addr;	//already declared
	reg ddr_op_in_progress;

	assign debug0    = state;
	assign debug1    = counter;
	assign debug2[0] = read_error;
	assign debug2[1] = rd_error;
	assign debug2[2] = rd_overflow;
	assign debug2[15:3] = 0;
	
	//states
	localparam	INIT_STATE = 0,
			IDLE_STATE = 1,
			LATCH_STATE = 2,
			
			WRITE_WAIT_1 = 3,
			SET_WRITE_COMMAND = 4,
			WRITE_TRANSITION_STATE = 5,
			
			READ_STATE = 6,
			
			DDR_DATA_VALID_STATE = 7;

	reg word_read = 0;

	localparam	WRITE = 0,
			READ = 1,
			REFRESH = 4;	
	
	localparam 	LATCH_TIME = 2;

	reg wren_prev;
	reg [31:0] data_write_prev;
	reg [17:0] address_prev;

	reg pause_unbuffered;
	reg [31:0] data_read_unbuffered;
	reg [31:0] data_write_buffered;
	reg [17:0] address_buffered;
	reg wren_buffered;

	reg clk_sync_prev = 0;
	//----------------------------
	// BEGIN STATE MACHINE
	//----------------------------
	always @(posedge modified_clock_sram) begin
		//counter resets on rising edge of main clock. 
		//Divides one clock cycle into time slices determined by the modified clock rate (in this case, 10 slices per main clk cycle)
		//(counter increments on posedge of modified clock)
		if ((clk_sync == 1) && (clk_sync_prev == 0)) begin
			counter <= 0;
		end else begin
			counter <= counter + 1;
		end
		clk_sync_prev <= clk_sync;
		
		case (state)
			INIT_STATE:	begin	
						cmd_addr <= 0;
						//cmd = NOP;
						if ((calib_done == 1) && (all_dcms_locked == 1)) begin
							state <= IDLE_STATE;
						end else begin
							state <= INIT_STATE;
						end
					end
			
			IDLE_STATE:	begin
						if (pause_unbuffered == 1) begin
							// Deassert pause
							pause_unbuffered <= 0;

							// Wait one clock cycle for the deasserted pause signal to propagate to the clocked user logic.
							// If this is not done the memory controller will read stale data from the still-paused user logic!
							state <= DDR_DATA_VALID_STATE;
						end else if (counter == LATCH_TIME) begin
							state <= LATCH_STATE;
						end else begin
							state <= IDLE_STATE;
						end
					end
	
			LATCH_STATE:	begin
//  						// Rudimentary single-word data cache
//  						if ((address_buffered == address_prev) && ((wren_buffered == 0) || ((wren_buffered == 1) && (wren_prev == 1) && (data_write_buffered == data_write_prev)))) begin
//  							// Do nothing!
//  							ddr_op_in_progress <= 1;
//  							state <= DDR_DATA_VALID_STATE;
//  						end else begin
							// DEACTIVATED--see below
							//cmd_addr[29:2] <= address_buffered;	//starting address 17 bits--shove into upper 28b of 30b addr to leave room for two 0's
							//cmd_addr[1:0] <= 0;

							// Work around serious data integrity problem where the value of cmd_addr[2] is ignored
							cmd_addr[29:3] <= address_buffered;
							cmd_addr[2:0] <= 0;

							//determine read or write operation
							if (wren_buffered==1) begin	//if a write signal is received, begin write	
								wr_data <= data_write_buffered;	//write whole 32-bit word
								data_read_unbuffered <= data_write_buffered;	// When writing, pass the write data through to the read port.  This allows proper operation of the same-address write-->read turnaround portion of the data cache above
								//wr_data <= 32'hf0806020;
								wr_en <= 1;	//now that data is in data path, assert write enable
								state <= WRITE_WAIT_1;
								ddr_op_in_progress <= 1;
								pause_unbuffered <= 1;
							end else begin	//wren_buffered == 0
								cmd_instr <= READ;
								//burst length set to constant 1
								//address already set in LATCH STATE
								cmd_en <= 1;	//enable read command with addr, burst length, and instruction data set in IDLE STATE
								state <= READ_STATE;
								word_read <= 0;
								ddr_op_in_progress <= 1;
								pause_unbuffered <= 1;
							end // end else
//  						end
	
						wren_prev <= wren_buffered;
						data_write_prev <= data_write_buffered;
						address_prev <= address_buffered;
					end
			
			//-----WRITE CYCLE
			WRITE_WAIT_1: 	begin
						wr_en <= 0;	//complete wr_en pulse, delay before setting cmd (necessary)?
	
						cmd_instr <= WRITE;
						cmd_en <= 1;
	
// 						// MODE 1
// 						// Rely on the MCB to read correct data out of its own buffers
// 						// This mode is much faster but relies on proper transaction coherency handling by the MCB
// 						if (!wr_full) begin
// 							state <= DDR_DATA_VALID_STATE;
// 						end else begin
// 							// FIXME
// 							// This implementation will likely lose the current data word
// 							// Is there an "almost full" flag that can be used instead?
// 							state <= WRITE_TRANSITION_STATE;
// 						end
	
						// MODE 2
						// Ensure data is flushed to physical memory before resuming execution
						// This mode is highly accurate even with broken MCB transaction coherency, but is extremely slow
						state <= WRITE_TRANSITION_STATE;
					end

			WRITE_TRANSITION_STATE:
					begin
						cmd_en <= 0;
						if (wr_empty == 1) begin //write fifo empty--ie data is written to memory
							state <= DDR_DATA_VALID_STATE;
						end else begin
							state <= WRITE_TRANSITION_STATE;
						end
					end
	
			//----READ CYCLE
			READ_STATE: 	begin
						cmd_en <= 0;	//disable read command
						rd_en <= 1;
						if (rd_empty == 0) begin
							data_read_unbuffered <= rd_data;
							word_read <= 1;
							// Valid data was received; make sure FIFO is truly empty before continuing
							state <= READ_STATE;
						end else if (word_read == 1) begin
							// Valid data was received and FIFO is empty; proceed...
							state <= DDR_DATA_VALID_STATE;
						end else begin
							// Wait for valid data to be driven onto the bus
							state <= READ_STATE;
						end
					end
	
			//-----occurs only when an entire data word has been written or read to/from DDR
			DDR_DATA_VALID_STATE: begin
						rd_en <= 0;
						wr_en <= 0;
						cmd_en <= 0;
						ddr_op_in_progress <= 0;

						// wait 1 main clk cycle
						if (counter == 0) begin
							state <= IDLE_STATE;
						end else begin //remain in this state until the next clock cycle
							state <= DDR_DATA_VALID_STATE;
						end
					end
			default:	begin
						state <= INIT_STATE;
					end
		endcase
	end	//end always
	
	// This block MUST be clocked at twice the speed of the user logic clock (a.k.a. clk_sync) to maintain data integrity
	always @(posedge clk_fast) begin
		// Register inputs
		wren_buffered <= wren;
		address_buffered <= starting_address;
		data_write_buffered <= data_write;

		// Register outputs
		pause <= pause_unbuffered;
		data_read <= data_read_unbuffered;
	end
endmodule
