`timescale 1ns / 1ps
/**********************************************************************

 Copyright (c) 2014 Timothy Pearson <kb9vqf@pearsoncomputing.net>

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

module clock_manager_test;

	// Inputs
	reg input_clk;
	reg input_clk_stable;

	// Outputs
	wire modified_clock;
	wire modified_clock_inv;
	wire modified_clock_div_by_two;
	wire modified_clock_fast;
	wire modified_clock_fast_inv;
	wire modified_clock_sram;
	wire dcm_locked;
	wire dcm_locked_sram;
	wire [7:0] modified_clock_period;

	// Instantiate the Unit Under Test (UUT)
	clock_manager uut (
		.input_clk(input_clk), 
		.input_clk_stable(input_clk_stable), 
		.modified_clock(modified_clock), 
		.modified_clock_inv(modified_clock_inv), 
		.modified_clock_div_by_two(modified_clock_div_by_two), 
		.modified_clock_fast(modified_clock_fast), 
		.modified_clock_fast_inv(modified_clock_fast_inv), 
		.modified_clock_sram(modified_clock_sram), 
		.dcm_locked(dcm_locked), 
		.dcm_locked_sram(dcm_locked_sram), 
		.modified_clock_period(modified_clock_period)
	);

	wire global_pause;

	wire [31:0] data_read;
	reg [31:0] data_write = 0;
	reg [17:0] address = 0;
	reg wren = 0;

	wire dram_ck;
	wire dram_ck_n;

	wire dram_dqs;
	reg dram_dqs_reg = 0;
	assign dram_dqs = dram_dqs_reg;

	wire [15:0] dram_dq;
	reg dram_dq_reg = 0;
	assign dram_dq = dram_dq_reg;

	mem_manager mem_manager(
		.modified_clock_sram(modified_clock_sram),
		.clk(modified_clk),
		.clk_fast(modified_clock_fast),
		.clk_sync(modified_clock_period),
		.crystal_clk(input_clk),
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

	initial begin
		// Initialize inputs
		input_clk = 0;
		input_clk_stable = 0;

		// Wait 100 ns for global reset to finish
		#100;

		// Add stimulus here
		input_clk_stable = 0;
		#100
		input_clk_stable = 1;
		#1000
		$finish;
	end

	// 100MHz clock input
	always begin
		#5 input_clk = !input_clk;
	end

	reg [7:0] test_count = 0;
	always @(posedge modified_clock) begin
		if (global_pause == 0) begin
			test_count = test_count + 1;
			if (test_count > 2) begin
				wren = 1;
				address = test_count - 2;
			end
		end
	end

// 	reg [15:0] ddr_test_count = 0;
// 	always @(posedge dram_ck_n) begin	// Every 7.5ns
// 		ddr_test_count = ddr_test_count + 1;
// 		if (ddr_test_count == 70) begin
// 			dram_dq_reg = 16'h0a0a;
// 		end else if (ddr_test_count == 71) begin
// 			dram_dq_reg = 16'h0b0b;
// 		end else if (ddr_test_count == 72) begin
// 			dram_dq_reg = 16'h0c0c;
// 		end else if (ddr_test_count >= 73) begin
// 			dram_dq_reg = 16'h0d0d;
// 			ddr_test_count = 0;
// 		end
// 	end
// 
// 	reg [15:0] ddr_test_count_n = 0;
// 	always @(posedge dram_ck_n) begin	// Every 7.5ns
// 		ddr_test_count_n = ddr_test_count_n + 1;
// 		if (ddr_test_count_n == 70) begin
// 			dram_dqs_reg = ~dram_dqs_reg;
// 		end else if (ddr_test_count_n == 71) begin
// 			dram_dqs_reg = ~dram_dqs_reg;
// 		end else if (ddr_test_count_n == 72) begin
// 			dram_dqs_reg = ~dram_dqs_reg;
// 		end else if (ddr_test_count_n >= 73) begin
// 			dram_dqs_reg = ~dram_dqs_reg;
// 			ddr_test_count_n = 0;
// 		end
// 	end
endmodule

