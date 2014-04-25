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
//		The FALCON II is copyright 2008-2014 by Timothy Pearson
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

// synthesis attribute mult_style of i2c_module is lut;

module i2c_module(
	input [17:0] startup_sequencer,
	input send_special_i2c_command,
	output reg camera_data_sda_sw,
	output reg camera_data_scl = 1'bz,
	input [7:0] special_i2c_command_register,
	input [15:0] special_i2c_command_data,
	input clk);
	
	parameter InternalClkFrequency = 50000000;	// 50MHz
	//parameter I2ClkCyclesToWait = (InternalClkFrequency / 1000);
	parameter I2ClkCyclesToWait = (InternalClkFrequency / 10000);

	reg only_init_this_once = 0;
	
	reg [15:0] i2c_data;
	reg [7:0] i2c_address;
	reg [7:0] i2c_register;
	
	reg [7:0] i2c_data_transmit_status = 0;
	reg External_I2C_Clock_Enable = 0;
	reg External_I2C_Clock_Enable_Prev = 0;
	
	reg [31:0] I2C_Master_Clock = 0;
	reg I2C_Clock_Enable = 0;
	reg [7:0] i2c_clock_state = 0;

	always @(posedge clk) begin
		if ((startup_sequencer[0] == 1) || (startup_sequencer[2] == 1) || (startup_sequencer[4] == 1) || (startup_sequencer[6] == 1) || (startup_sequencer[8] == 1) || (startup_sequencer[10] == 1) || (startup_sequencer[12] == 1) || (startup_sequencer[14] == 1) || (startup_sequencer[16] == 1) || (send_special_i2c_command == 1)) begin
			External_I2C_Clock_Enable = 1;
		end else begin
			External_I2C_Clock_Enable = 0;
		end
	
		if (send_special_i2c_command == 0) begin			
			if ((startup_sequencer[0] == 1) || (startup_sequencer[2] == 1)) begin
				i2c_address = 144;			// 90 hex
				i2c_register = 35;			// 23 hex
				i2c_data = 51;				// 33 hex [Column Binning and Skipping to 3]
			end
			
			if (startup_sequencer[4] == 1) begin
				i2c_address = 144;			// 90 hex
				i2c_register = 34;			// 22 hex
				i2c_data = 51;				// 33 hex [Row Binning and Skipping to 3]
			end
			
			if (startup_sequencer[6] == 1) begin
				i2c_address = 144;			// 90 hex
				i2c_register = 4;			// 04 hex
				i2c_data = 2559;			// 9FF hex [Column Size]
			end
			
			if (startup_sequencer[8] == 1) begin
				i2c_address = 144;			// 90 hex
				i2c_register = 3;			// 03 hex
				i2c_data = 1919;			// 77F hex [Row Size]
			end
			
			if (startup_sequencer[10] == 1) begin
				i2c_address = 144;			// 90 hex
				i2c_register = 1;			// 01 hex
				i2c_data = 56;				// 38 hex [Row Start for 4x Binning]
			end
			
			if (startup_sequencer[12] == 1) begin
				i2c_address = 144;			// 90 hex
				i2c_register = 32;			// 20 hex
				i2c_data = 96;				// 60 hex [Bin Summing for Low Light]
			end

			if (startup_sequencer[14] == 1) begin
				i2c_address = 144;			// 90 hex
				i2c_register = 30;			// 1E hex
				i2c_data = 16710;			// 4146 hex [Electronic Rolling Shutter Bulb Trigger Mode]
			end

			if (startup_sequencer[16] == 1) begin
				i2c_address = 144;			// 90 hex
				i2c_register = 10;			// 0A hex
				i2c_data = 32768;			// 8000 hex [Invert Pixel Clock]
			end
		end
		
		if (send_special_i2c_command == 1) begin
			i2c_address = 144;			// 90 hex
			i2c_register = special_i2c_command_register;
			i2c_data = special_i2c_command_data;
		end
		
		if (startup_sequencer[7] == 1) begin
			only_init_this_once = 1;
		end
	end

	// -----------------------------------------------------
	// I2C Routines	
	// -----------------------------------------------------
	// IIIIIII    2222		CCC
	//    I		 2    2	  C   C
	//    I			 22	  C
	//    I			2		  C	C
	// IIIIIII	 222222		CCC
	// -----------------------------------------------------

	// I2C Master Clock Driver
	always @(posedge clk) begin
		if ((External_I2C_Clock_Enable == 1) && (External_I2C_Clock_Enable_Prev == 0)) begin
			I2C_Clock_Enable = 1;
			if (i2c_data_transmit_status == 39) begin
				i2c_data_transmit_status = 0;
			end
		end
		External_I2C_Clock_Enable_Prev = External_I2C_Clock_Enable;
		if (I2C_Clock_Enable == 1) begin
			I2C_Master_Clock = I2C_Master_Clock + 1;
			if (I2C_Master_Clock == (I2ClkCyclesToWait / 2)) begin
				if (camera_data_scl == 1) begin
					if (i2c_data_transmit_status == 0) begin
						// Issue a start command
						camera_data_sda_sw = 0;
						i2c_data_transmit_status = 1;
					end
					if (i2c_data_transmit_status == 38) begin
						// Send a STOP
						camera_data_sda_sw = 1;
						i2c_data_transmit_status = 39;
					end
				end
				if (camera_data_scl == 0) begin
					case (i2c_data_transmit_status)
						1:	// Send the first address byte
							camera_data_sda_sw = i2c_address[7];
						2:	// Send the second address byte
							camera_data_sda_sw = i2c_address[6];
						3: // Send the third address byte
							camera_data_sda_sw = i2c_address[5];
						4: // Send the fourth address byte
							camera_data_sda_sw = i2c_address[4];
						5: // Send the fifth address byte
							camera_data_sda_sw = i2c_address[3];
						6: // Send the sixth address byte
							camera_data_sda_sw = i2c_address[2];
						7: // Send the seventh address byte
							camera_data_sda_sw = i2c_address[1];
						8: // Send the data direction byte
							camera_data_sda_sw = i2c_address[0];
						9: // Wait for ACK signal from slave
							camera_data_sda_sw = 1;
						10: // Send the first register byte
							camera_data_sda_sw = i2c_register[7];
						11: // Send another register byte
							camera_data_sda_sw = i2c_register[6];
						12: // Send another register byte
							camera_data_sda_sw = i2c_register[5];
						13: // Send another register byte
							camera_data_sda_sw = i2c_register[4];
						14: // Send another register byte
							camera_data_sda_sw = i2c_register[3];
						15: // Send another register byte
							camera_data_sda_sw = i2c_register[2];
						16: // Send another register byte
							camera_data_sda_sw = i2c_register[1];
						17: // Send another register byte
							camera_data_sda_sw = i2c_register[0];
						18: // Wait for ACK signal from slave
							camera_data_sda_sw = 1;
						19: // Send the first data byte
							camera_data_sda_sw = i2c_data[15];
						20: // Send the next data byte
							camera_data_sda_sw = i2c_data[14];
						21: // Send the next data byte
							camera_data_sda_sw = i2c_data[13];
						22: // Send the next data byte
							camera_data_sda_sw = i2c_data[12];
						23: // Send the next data byte
							camera_data_sda_sw = i2c_data[11];
						24: // Send the next data byte
							camera_data_sda_sw = i2c_data[10];
						25: // Send the next data byte
							camera_data_sda_sw = i2c_data[9];
						26: // Send the next data byte
							camera_data_sda_sw = i2c_data[8];
						27: // Wait for ACK signal from slave
							camera_data_sda_sw = 1;
						28: // Send the second data byte
							camera_data_sda_sw = i2c_data[7];
						29: // Send the next data byte
							camera_data_sda_sw = i2c_data[6];
						30: // Send the next data byte
							camera_data_sda_sw = i2c_data[5];
						31: // Send the next data byte
							camera_data_sda_sw = i2c_data[4];
						32: // Send the next data byte
							camera_data_sda_sw = i2c_data[3];
						33: // Send the next data byte
							camera_data_sda_sw = i2c_data[2];
						34: // Send the next data byte
							camera_data_sda_sw = i2c_data[1];
						35: // Send the next data byte
							camera_data_sda_sw = i2c_data[0];
						36: // Wait for ACK signal from slave
							camera_data_sda_sw = 1;
						37: // Allow the clock to go high once more (in order to "receive" the ACK bit)
							camera_data_sda_sw = 0;
					endcase
					if (i2c_data_transmit_status < 39) begin
						i2c_data_transmit_status = i2c_data_transmit_status + 1;
					end else begin
						i2c_data_transmit_status = 0;
					end
				end
			end
			if (I2C_Master_Clock == I2ClkCyclesToWait) begin
				if (i2c_data_transmit_status >= 39) begin
					camera_data_scl = 1;
					I2C_Clock_Enable = 0;
				end
				I2C_Master_Clock = 0;
				if (i2c_clock_state == 0) begin
					i2c_clock_state = 1;
					camera_data_scl = 1;
				end else begin
					camera_data_scl = 0;
					i2c_clock_state = 0;
				end
			end
		end else begin
			camera_data_scl = 1;
			i2c_clock_state = 0;
			I2C_Master_Clock = 0;
		end
	end

	// End I2C Transmitter Routines

endmodule
