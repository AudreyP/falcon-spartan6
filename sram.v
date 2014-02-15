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
	input wire wren,             	     // write enable
	input wire [31:0] data_write,      // data being written to memory
	output wire [31:0] data_read,       // data being read from memory
	
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

	//for asynch r/w, these must be tied low
	assign SRAM_CE_N = 0;	//chip enable
	assign RamClk = 0;
	assign RamAdv = 0;
	assign SRAM_UB_N = 0;	//either low or don't-care for r/w
	assign SRAM_LB_N = 0;	//either low or don't-care for r/w
	//for a read, OE must be LOW. For write, don't care (keep HIGH)
	//for a write, WE must be LOW. For read, must keep HIGH


	
	//registers
	reg [15:0]     data_read_upper_byte,
					data_read_lower_byte;
	reg [6:0] state;
	reg [15:0] data_to_ram;
	reg wr, rd;
	reg [18:0] addr;
	
	/*assign data_write_ub = data_write[31:16];
	assign data_write_lb = data_write[15:0];
	assign data_read = {data_read_ub, data_read_lb};
	*/
	
	
	//
// 	assign SRAM_DQ = (wr) ? 16'bz : data_to_ram;	//if zero, then write--meaning SRAM_DQ = data_to_ram.
	assign SRAM_DQ = (wr) ? 16'bz : 32'h80f02040;
	assign SRAM_ADDR = addr;
	assign data_read = {data_read_upper_byte, data_read_lower_byte};
	assign SRAM_WE_N = wr;
	assign SRAM_OE_N = rd;


	// SRAM read/write state machine
	always @(posedge clk) begin
			case (state)
			init_state: begin
							addr[18:1] = starting_address;	//starting address 17 bits--shove into upper 17b of 18b addr to leave room for 1 increment
							wr = 1;	//not write state
							rd = 1;	//not read state
							done = 0;
							state= idle_state;
						  end
			idle_state: begin
							wr = 1;	//not write state
							rd = 1;	//not read state
							if (wren==1) begin	//if a write signal is received, begin write	
								data_to_ram = data_write[31:16];	//write upper bytes first
								state = write_upper_byte_state;
								end
							else begin	//wren == 0
								state = read1_state;
								end
							end
			
			//-----WRITE CYCLE
			write_upper_byte_state: 
							begin
								wr = 0;	//write state
								rd = 1;
								state = pulse_wr1;
							 end
			pulse_wr1: 
							begin
							wr = 1;	//deactivate write
							rd = 1;
							data_to_ram = data_write[15:0];
							addr = addr + 1;
							state = write_lower_byte_state;
						   end				   
			write_lower_byte_state: 
							begin
								wr = 0;	//write state
								rd = 1;
								state = pulse_wr2;
							 end		
			pulse_wr2:
							begin
							wr = 1;	//deactivate write
							rd = 1;
							addr = addr + 1;
							state = idle_state;
							end
			
			//----READ CYCLE				
			read1_state: begin
								wr = 1;
								rd = 0;		//read state
								state = pulse_rd1;
							 end			
			pulse_rd1: 
							begin
							wr = 1;	
							rd = 1;		//deactivate read
							data_read_upper_byte = SRAM_DQ;
							addr = addr + 1;
							state = read2_state;
						   end							 
										 
			read2_state: begin
								wr = 1;
								rd = 1;		//read state
								state = pulse_rd2;
							 end
			pulse_rd2: begin
							wr = 1;	
							rd = 1;		//deactivate read
							data_read_lower_byte = SRAM_DQ;
							addr = addr + 1;
							state = idle_state;
						   end							 
			/*check_if_done: begin
							wr = 0;
							rd = 0;
							//check if read done
							if (counter_done)
								state = idle_state;
							else begin
								addr = addr + 1;
								state = read1_state;
								end	//end else
						   end*/
			endcase		
	end	//end always
	

endmodule
