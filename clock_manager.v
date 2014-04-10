`timescale 1ns / 1ps
/**********************************************************************

 Copyright (c) 2014 Audrey Pearson <aud.pearson@gmail.com>
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
		output wire modified_clock,
		output wire modified_clock_div_by_two,
		output wire modified_clock_two,
		output wire modified_clock_two_div_by_two,
		output wire modified_clock_sram,
	
		output wire dcm_locked,
		output wire dcm_locked_two,
		output wire dcm_locked_sram
	);

	reg management_clock;
	always @(posedge input_clk) begin
		management_clock = !management_clock;
	end

	//-------------------------------
	// MODIFIED CLOCK
	//-------------------------------
	reg dcm_reset = 0;
	wire dcm_feedback;
	(* KEEP = "TRUE" *) reg modified_clock_bufg_in;
	
	BUFG U_BUFG_MODIFIED_CLOCK
	(
		.O (modified_clock),
		.I (modified_clock_bufg_in)
	);

	// Divide SRAM clock by 10 to obtain the main system clock
	// This locks the main system clock phase with respect to the SRAM clock
	reg [2:0] modified_clock_counter;
	always @(posedge modified_clock_sram) begin
		if (modified_clock_counter >= 4) begin
			modified_clock_counter <= 0;
			modified_clock_bufg_in <= ~modified_clock_bufg_in;
		end else begin
			modified_clock_counter <= modified_clock_counter + 1;
		end
	end
	assign dcm_locked = 1;

	//-------------------------------
	// MODIFIED CLOCK / 2
	//-------------------------------

	(* KEEP = "TRUE" *) reg modified_clock_two_div_by_two_bufg_in = 0;
	always @(posedge modified_clock_two) begin
		modified_clock_two_div_by_two_bufg_in = !modified_clock_two_div_by_two_bufg_in;
	end

	BUFG U_BUFG_MODIFIED_CLOCK_TWO_DIV_BY_TWO
	(
		.O (modified_clock_two_div_by_two),
		.I (modified_clock_two_div_by_two_bufg_in)
	);


	//-------------------------------
	// MODIFIED CLOCK TWO
	//-------------------------------
	reg dcm_reset_two = 0;
	wire dcm_feedback_two;
	(* KEEP = "TRUE" *) wire modified_clock_two_bufg_in;
	
	BUFG U_BUFG_MODIFIED_CLOCK_TWO
	(
		.O (modified_clock_two),
		.I (modified_clock_two_bufg_in)
	);

	// For now, lock the secondary system clock to the primary system clock
	assign modified_clock_two_bufg_in = modified_clock_bufg_in;
	assign dcm_locked_two = 1;

	//-------------------------------
	// MODIFIED CLOCK TWO / 2
	//-------------------------------

	(* KEEP = "TRUE" *) reg modified_clock_div_by_two_bufg_in = 0;
	always @(posedge modified_clock) begin
		modified_clock_div_by_two_bufg_in = !modified_clock_div_by_two_bufg_in;
	end

	BUFG U_BUFG_MODIFIED_CLOCK_DIV_BY_TWO
	(
		.O (modified_clock_div_by_two),
		.I (modified_clock_div_by_two_bufg_in)
	);


	//-------------------------------
	// SRAM CLOCK
	//-------------------------------
	reg dcm_reset_sram = 0;
	wire dcm_feedback_sram;
	(* KEEP = "TRUE" *) wire modified_clock_sram_bufg_in;
	
	BUFG U_BUFG_MODIFIED_CLOCK_SRAM
	(
		.O (modified_clock_sram),
		.I (modified_clock_sram_bufg_in)
	);

	DCM_SP #(
		.CLKDV_DIVIDE(2.0),                   // CLKDV divide value
									// (1.5,2,2.5,3,3.5,4,4.5,5,5.5,6,6.5,7,7.5,8,9,10,11,12,13,14,15,16).
// 		.CLKFX_DIVIDE(MAIN_DCM_DIV),                     // Divide value on CLKFX outputs - D - (1-32)
// 		.CLKFX_MULTIPLY(MAIN_DCM_MULT*SRAM_CLK_RATIO),                   // Multiply value on CLKFX outputs - M - (2-32)
		.CLKFX_DIVIDE(2),                     // Divide value on CLKFX outputs - D - (1-32)
		.CLKFX_MULTIPLY(2),                   // Multiply value on CLKFX outputs - M - (2-32)
		.CLKIN_DIVIDE_BY_2("FALSE"),          // CLKIN divide by two (TRUE/FALSE)
		.CLKIN_PERIOD(10.0),                  // Input clock period specified in nS
		.CLKOUT_PHASE_SHIFT("NONE"),          // Output phase shift (NONE, FIXED, VARIABLE)
		.CLK_FEEDBACK("1X"),                  // Feedback source (NONE, 1X, 2X)
		.DESKEW_ADJUST("SYSTEM_SYNCHRONOUS"), // SYSTEM_SYNCHRNOUS or SOURCE_SYNCHRONOUS
		.DFS_FREQUENCY_MODE("LOW"),           // Unsupported - Do not change value
		.DLL_FREQUENCY_MODE("LOW"),           // Unsupported - Do not change value
		.DSS_MODE("NONE"),                    // Unsupported - Do not change value
		.DUTY_CYCLE_CORRECTION("TRUE"),       // Unsupported - Do not change value
		.FACTORY_JF(16'hc080),                // Unsupported - Do not change value
		.PHASE_SHIFT(0),                      // Amount of fixed phase shift (-255 to 255)
		.STARTUP_WAIT("FALSE")                // Delay config DONE until DCM_SP LOCKED (TRUE/FALSE)
	)
	modified_clock_dcm_sram (
		.CLK0(dcm_feedback_sram),         // 1-bit output: 0 degree clock output
		.CLK180(),     // 1-bit output: 180 degree clock output
		.CLK270(),     // 1-bit output: 270 degree clock output
		.CLK2X(),       // 1-bit output: 2X clock frequency clock output
		.CLK2X180(), // 1-bit output: 2X clock frequency, 180 degree clock output
		.CLK90(),       // 1-bit output: 90 degree clock output
		.CLKDV(),       // 1-bit output: Divided clock output
		.CLKFX(modified_clock_sram_bufg_in),       // 1-bit output: Digital Frequency Synthesizer output (DFS)
		.CLKFX180(), // 1-bit output: 180 degree CLKFX output
		.LOCKED(dcm_locked_sram),     // 1-bit output: DCM_SP Lock Output
		.PSDONE(),     // 1-bit output: Phase shift done output
		.STATUS(),     // 8-bit output: DCM_SP status output
		.CLKFB(dcm_feedback_sram),       // 1-bit input: Clock feedback input
		.CLKIN(input_clk),       // 1-bit input: Clock input
		.DSSEN(),       // 1-bit input: Unsupported, specify to GND.
		.PSCLK(),       // 1-bit input: Phase shift clock input
		.PSEN(1'b0),         // 1-bit input: Phase shift enable
		.PSINCDEC(), // 1-bit input: Phase shift increment/decrement input
		.RST(dcm_reset_sram)            // 1-bit input: Active high reset input
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
		
		//leds[6] = dcm_locked_sram;
	end

endmodule
