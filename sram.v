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
	input wire reset,
	input wire wren,             	     // write enable
	input wire [31:0] data_write,      // data being written to memory
	output wire [31:0] data_read,       // data being read from memory
	
	//sram controls 
	input wire [18:0] starting_address,
	inout wire [31:0] SRAM_DQ,
	output wire SRAM_CE_N,
	output wire SRAM_OE_N,
	output wire SRAM_LB_N,
	output wire SRAM_UB_N,
	output wire SRAM_WE_N,
	output wire [18:0] SRAM_ADDR,
	output wire RamClk,
	output wire RamAdv,
	
	//test 
	input wire counter_done,
	input wire start_read,
	input wire start_write,
	output reg done
	 );

	//states
	localparam	init_state = 1,
					idle_state = 2,
					write_upper_byte_state = 3,
					write_lower_byte_state = 4,
					read1_state = 5,
					read2_state = 6,
					pulse_wr1 = 7,
					pulse_wr2 = 8,
					pulse_rd1 = 9,
					pulse_rd2 = 10,
					check_if_done = 11;
	
	//localparam starting_address = 0;

	//local wires
	wire [15:0] data_write_ub,
					data_write_lb,
					data_read_ub,
					data_read_lb;
					
	//for asynch r/w, these must be tied low
	assign SRAM_CE_N = 0;	//chip enable
	assign RamClk = 0;
	assign RamAdv = 0;
	assign SRAM_UB_N = 0;	//either low or don't-care for r/w
	assign SRAM_LB_N = 0;	//either low or don't-care for r/w

	
	
	assign data_write_ub = data_write[31:16];
	assign data_write_lb = data_write[15:0];
	assign data_read = {data_read_ub, data_read_lb};
	
	// assign wires = regs
	assign SRAM_ADDR = addr;
	assign SRAM_DQ = data;	

	reg [6:0] state;
	reg wr, rd;
	reg [15:0] data;
	reg [17:0] addr;

	// SRAM read/write state machine
	always @(posedge clk) begin
		if (reset) begin
			state = init_state;
		end	//end if reset
		else begin
			case (state)
			init_state: begin
							addr = starting_address[18:1];	//starting address 17 bits--shove into upper 17b of 18b addr to leave room for 1 increment
							data = 16'hzzzz;
							wr = 0;
							rd = 0;
							done = 0;
							state= idle_state;
						  end
			idle_state: begin
							wr = 0;
							if (start_write) begin	//if a write signal is received, begin write	
								data = data_write[31:16];	//write upper bytes first
								state = write_upper_byte_state;
								end
							else if (start_read) begin
								state = read1_state;
								end
							else begin
								state = idle_state;
								end
							end
			write_upper_byte_state: 
							begin
								wr = 1;
								state = pulse_wr1;
							 end
			pulse_wr1: 
							begin
							wr = 0;
							addr = addr + 1;
							state = write_lower_byte_state;
						   end				   
			write_lower_byte_state: 
							begin
								wr = 1;
								state = pulse_wr2;
							 end		
			pulse_wr2:
							begin
							wr = 0;
							addr = addr + 1;
							state = check_if_done;
							end
			pulse_rd1: 
							begin
							rd = 0;
							addr = addr + 1;
							state = read1_state;
						   end							 
			read1_state: begin
								rd = 1;
								state = pulse_rd1;
							 end							 
			read2_state: begin
								rd = 1;
								state = pulse_rd2;
							 end
			pulse_rd2: begin
							rd = 0;
							addr = addr + 1;
							state = check_if_done;
						   end							 
			check_if_done: begin
							wr = 0;
							rd = 0;
							//check if read done
							if (counter_done)
								state = idle_state;
							else begin
								addr = addr + 1;
								state = read1_state;
								end	//end else
						   end
			endcase		
		end	//end else	
	end	//end always
	

endmodule
