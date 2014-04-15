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
module clock_manager(
		input wire input_clk,
		input wire input_clk_stable,
		output wire modified_clock,
		output wire modified_clock_inv,
		output wire modified_clock_div_by_two,
		output wire modified_clock_fast,
		output wire modified_clock_fast_inv,
		output wire modified_clock_sram,
	
		output wire dcm_locked,
		output wire dcm_locked_sram,

		output reg [7:0] modified_clock_period
	);

	parameter MemoryToSystemClockRatio = 10;

	reg management_clock;
	always @(posedge input_clk) begin
		management_clock = !management_clock;
	end

	(* KEEP = "TRUE" *) wire modified_clock_bufg_in;
	(* KEEP = "TRUE" *) wire modified_clock_inv_bufg_in;
	(* KEEP = "TRUE" *) wire modified_clock_fast_bufg_in;
	(* KEEP = "TRUE" *) wire modified_clock_fast_inv_bufg_in;
	(* KEEP = "TRUE" *) wire modified_clock_div_by_two_bufg_in;
	(* KEEP = "TRUE" *) wire modified_clock_sram_bufg_in;
	
	BUFG U_BUFG_MODIFIED_CLOCK
	(
		.O (modified_clock),
		.I (modified_clock_bufg_in)
	);

	BUFG U_BUFG_MODIFIED_CLOCK_INV
	(
		.O (modified_clock_inv),
		.I (modified_clock_inv_bufg_in)
	);

	BUFG U_BUFG_MODIFIED_CLOCK_FAST
	(
		.O (modified_clock_fast),
		.I (modified_clock_fast_bufg_in)
	);

	BUFG U_BUFG_MODIFIED_CLOCK_FAST_INV
	(
		.O (modified_clock_fast_inv),
		.I (modified_clock_fast_inv_bufg_in)
	);

	BUFG U_BUFG_MODIFIED_CLOCK_DIV_BY_TWO
	(
		.O (modified_clock_div_by_two),
		.I (modified_clock_div_by_two_bufg_in)
	);

	BUFG U_BUFG_MODIFIED_CLOCK_SRAM
	(
		.O (modified_clock_sram),
		.I (modified_clock_sram_bufg_in)
	);

	reg dcm_reset_sram = 0;
	wire main_clkfbout_clkfbin;
	assign dcm_locked = dcm_locked_sram;

	parameter INT_PLL_ADV_VCO_MULT = 4;

	PLL_ADV #
	(
		.BANDWIDTH          ("OPTIMIZED"),
		.CLKIN1_PERIOD      (10.0),
		.CLKIN2_PERIOD      (10.0),
		.CLKOUT0_DIVIDE     (1*INT_PLL_ADV_VCO_MULT),
		.CLKOUT1_DIVIDE     ((MemoryToSystemClockRatio/2)*INT_PLL_ADV_VCO_MULT),
		.CLKOUT2_DIVIDE     ((MemoryToSystemClockRatio/2)*INT_PLL_ADV_VCO_MULT),
		.CLKOUT3_DIVIDE     (MemoryToSystemClockRatio*INT_PLL_ADV_VCO_MULT),
		.CLKOUT4_DIVIDE     (MemoryToSystemClockRatio*INT_PLL_ADV_VCO_MULT),
		.CLKOUT5_DIVIDE     (MemoryToSystemClockRatio*2*INT_PLL_ADV_VCO_MULT),
		.CLKOUT0_PHASE      (0.000),
		.CLKOUT1_PHASE      (0.000),
		.CLKOUT2_PHASE      (180.000),
		.CLKOUT3_PHASE      (0.000),
		.CLKOUT4_PHASE      (180.000),
		.CLKOUT5_PHASE      (0.000),
		.CLKOUT0_DUTY_CYCLE (0.500),
		.CLKOUT1_DUTY_CYCLE (0.500),
		.CLKOUT2_DUTY_CYCLE (0.500),
		.CLKOUT3_DUTY_CYCLE (0.500),
		.CLKOUT4_DUTY_CYCLE (0.500),
		.CLKOUT5_DUTY_CYCLE (0.500),
		.SIM_DEVICE         ("SPARTAN6"),
		.COMPENSATION       ("INTERNAL"),
		.DIVCLK_DIVIDE      (1),
		.CLKFBOUT_MULT      (INT_PLL_ADV_VCO_MULT),
		.CLKFBOUT_PHASE     (0.0),
		.REF_JITTER         (0.005000)
		)
	main_clock_pll_adv
		(
		.CLKFBIN     (main_clkfbout_clkfbin),
		.CLKINSEL    (1'b1),
		.CLKIN1      (input_clk),
		.CLKIN2      (1'b0),
		.DADDR       (5'b0),
		.DCLK        (1'b0),
		.DEN         (1'b0),
		.DI          (16'b0),
		.DWE         (1'b0),
		.REL         (1'b0),
		.RST         (dcm_reset_sram),
		.CLKFBDCM    (),
		.CLKFBOUT    (main_clkfbout_clkfbin),
		.CLKOUTDCM0  (),
		.CLKOUTDCM1  (),
		.CLKOUTDCM2  (),
		.CLKOUTDCM3  (),
		.CLKOUTDCM4  (),
		.CLKOUTDCM5  (),
		.CLKOUT0     (modified_clock_sram_bufg_in),
		.CLKOUT1     (modified_clock_fast_bufg_in),
		.CLKOUT2     (modified_clock_fast_inv_bufg_in),
		.CLKOUT3     (modified_clock_bufg_in),
		.CLKOUT4     (modified_clock_inv_bufg_in),
		.CLKOUT5     (modified_clock_div_by_two_bufg_in),
		.DO          (),
		.DRDY        (),
		.LOCKED      (dcm_locked_sram)
		);

	reg [15:0] dcm_lock_timer_sram = 0;

	always @(posedge management_clock) begin
		if (dcm_locked_sram == 0) begin
			dcm_lock_timer_sram = dcm_lock_timer_sram + 1;
		end else begin
			dcm_lock_timer_sram = 0;
		end
		
		if (dcm_lock_timer_sram > 50000) begin
			dcm_reset_sram = 1;
		end
		
		if (dcm_lock_timer_sram > 50010) begin		// Allow 10 clock cycles to reset the DCM
			dcm_reset_sram = 0;
			dcm_lock_timer_sram = 0;
		end

		if (input_clk_stable == 0) begin
			dcm_lock_timer_sram = 50001;
		end
		
		//leds[6] = dcm_locked_sram;
	end

	reg modified_clock_interphase = 0;
	always @(posedge modified_clock) begin
		modified_clock_interphase <= ~modified_clock_interphase;
	end

	reg modified_clock_prev = 1;
	reg [7:0] modified_clock_counter = 0;
	always @(posedge modified_clock_sram) begin
		if (modified_clock_interphase != modified_clock_prev) begin
			modified_clock_counter <= 0;
		end else begin
			modified_clock_counter <= modified_clock_counter + 1;
		end

		if (modified_clock_counter < (MemoryToSystemClockRatio-2)) begin
			modified_clock_period <= modified_clock_counter + 2;
		end else if (modified_clock_counter == ((MemoryToSystemClockRatio-1)-1)) begin
			modified_clock_period <= 0;
		end else begin
			modified_clock_period <= 1;
		end

		modified_clock_prev <= modified_clock_interphase;
	end

endmodule
