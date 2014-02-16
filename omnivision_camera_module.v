`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    23:40:17 02/02/2014 
// Design Name: 
// Module Name:    omnivision_camera_module 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module omnivision_camera_module(
	//NOT DONE
	
	input wire [15:0] camera_data_port,
	input wire camera_data_href,
	input wire camera_data_vsync,
	input wire camera_data_pclk,
	inout wire camera_data_sda,
	output reg camera_data_scl = 1'bz

    );

		// Camera data input processor
		//always @(posedge camera_data_pclk) begin
	
		reg camera_transfer_done_internal = 0;
		reg camera_data_dma_enable;
		reg [7:0] current_processing_state = 0;

		always @(negedge camera_data_pclk) begin
			databuffer = camera_data_port;
			
			if ((processing_done == 1) && (camera_transfer_done_internal == 0) && (startup_sequencer[5] == 1)) begin
				camera_transfer_done = 0;

				if (current_processing_state != 0) begin
					// Other states enabled here, until the end of the state machine where it is then reset to 0.
					if (current_processing_state == 1) begin
						processing_started = 0;				// We only need to pulse this, not keep it 1 all the time!
						current_processing_state = 0;		// This is set to whatever the next stage is, in this case we just go grab another image (0)
						address = 18'bz;
						data_write = 32'bz;
						wren = 1'bz;
						camera_transfer_done_internal = 1;
					end
				end

				// Capture a 320 x 240 image if enabled (8-bit tricolor)
				if (camera_data_dma_enable == 1) begin
					processing_started = 1;
					leds[6] = 1;
					if (camera_vsync_detected == 1) begin
						if (camera_data_href == 1) begin
							if (camera_toggle == 0) begin
								wren = 0;
								databuffer_mem[31:16] = databuffer;
							end
							if (camera_toggle == 1) begin
								databuffer_mem[15:0] = databuffer;
								camera_memory_address = camera_memory_address + 1;
								address = camera_memory_address;
								data_write = databuffer_mem;
								wren = 1;				// Commit the data to RAM
							end

							camera_toggle = camera_toggle + 1;
							if (camera_toggle > 1) begin
								camera_toggle = 0;
							end
							if (camera_memory_address >= 153601) begin
								leds[6] = 0;
								wren = 0;
								camera_vsync_detected = 0;
								camera_toggle = 0;
								camera_data_dma_enable = 0;
								camera_memory_address = 76801;
								current_processing_state = 1;
							end
						end
					end else begin
						if (camera_data_vsync == 1) begin
							camera_vsync_detected = 1;
						end
					end
				end else begin
					camera_vertical_address = 0;
					camera_horizontal_address = 0;
					camera_memory_address = 0;
					camera_vsync_detected = 0;
					camera_toggle = 0;
				end
			end else begin
				if ((camera_transfer_done_internal == 1) && (processing_done == 1)) begin
					camera_transfer_done = 1;
				end
				if ((camera_transfer_done_internal == 1) && (processing_done == 0)) begin
					camera_transfer_done_internal = 0;
				end
			end
		end



		reg [7:0] startup_sequencer = 0;
		reg [23:0] startup_sequencer_timer = 0;

		always @(posedge clk) startup_sequencer_timer=startup_sequencer_timer+1;
		
		//reg [15:0] I2C_Master_Clock = 0;
		reg [31:0] I2C_Master_Clock = 0;
		reg I2C_Clock_Enable = 0;
		reg External_I2C_Clock_Enable = 0;
		reg [7:0] i2c_data_transmit_status = 0;
		reg i2c_data_tx_enable = 0;
		reg [7:0] i2c_clock_state = 0;
		reg External_I2C_Clock_Enable_Prev = 0;

		reg [7:0] one_more_clock_cycle = 0;

		reg [7:0] i2c_data;
		reg [7:0] i2c_address;
		reg [7:0] i2c_register;
		reg camera_data_sda_sw = 1;
		reg camera_data_sda_rnw = 0;	// read=1
		
		assign camera_data_sda = (camera_data_sda_rnw) ? 1'bz : camera_data_sda_sw;
		//assign camera_data_sda = (camera_data_sda_rnw) ? 0 : camera_data_sda_sw;
		
		always @* begin
			camera_data_sda_rnw = camera_data_sda_sw;
		end
		
		always @(posedge clk) begin
			//if (startup_sequencer_timer == 16777215) begin
			//if (startup_sequencer_timer == 16777210) begin
			if (startup_sequencer_timer >= 1677721) begin
			//if (startup_sequencer_timer >= 167772) begin
			//if (startup_sequencer_timer >= 83886) begin
				if (startup_sequencer < 32) begin				
					if (startup_sequencer == 0) begin
						startup_sequencer = 1;
					end else begin
						startup_sequencer = startup_sequencer * 2;
					end
				end
			end
			
			if (reset_system == 1) begin
				startup_sequencer = 0;
			end
		end


		always @(posedge clk) begin
			if ((startup_sequencer[0] == 1) || (startup_sequencer[2] == 1) || ((startup_sequencer[4] == 1) && (only_init_this_once == 0)) || (send_special_i2c_command == 1)) begin
				External_I2C_Clock_Enable = !External_I2C_Clock_Enable;
			end else begin
				External_I2C_Clock_Enable = 0;
			end
		
			if (send_special_i2c_command == 0) begin
				if (startup_sequencer[0] == 1) begin
					i2c_address = 66;		// 42 hex
					i2c_register = 20;	// 14 hex
					i2c_data = 36;			// 24 hex [Enable QVGA mode]
				end
				
				if ((startup_sequencer[2] == 1)) begin
					i2c_address = 66;		// 42 hex
					i2c_register = 18;	// 12 hex
					if (enable_ycrcb == 0) begin
						i2c_data = 44;			// 2C hex [Enable RGB and 16-bit mode]
					end else begin
						i2c_data = 36;			// 24 hex [Enable YCrCb and 16-bit mode]
					end
				end
				
				/*if (startup_sequencer[1] == 1) begin
					i2c_address = 66;		// 42 hex
					i2c_register = 32;	// 20 hex
					i2c_data = 1;			// 01 hex [Enable High-Current clock]
				end*/
				
				/*if (startup_sequencer[1] == 1) begin
					i2c_address = 66;		// 42 hex
					i2c_register = 113;	// 71 hex
					i2c_data = 64;			// 40 hex [Enable Gated Pixel Clock]
				end*/
				
				if (only_init_this_once == 0) begin
					if (startup_sequencer[4] == 1) begin
						i2c_address = 66;		// 42 hex
						i2c_register = 21;	// 15 hex
						i2c_data = 65;			// 41 hex [Enable Falling-Edge Data Output]
					end
				end
			end
			
			if (send_special_i2c_command == 1) begin
				i2c_address = 66;		// 42 hex
				i2c_register = special_i2c_command_register;
				i2c_data = special_i2c_command_data;
			end
			
			if (startup_sequencer[5] == 1) begin
				only_init_this_once = 1;
			end
		end

		// -----------------------------------------------------
		// I2C Routines	
		// -----------------------------------------------------
		// IIIIIII    2222       CCC
		//    I      2    2    C    C
		//    I         22    C
		//    I       2        C    C
		// IIIIIII   222222	CCC
		// -----------------------------------------------------

		// I2C Master Clock Driver
		always @(posedge clk) begin
			if ((External_I2C_Clock_Enable == 1) && (External_I2C_Clock_Enable_Prev == 0)) begin
				I2C_Clock_Enable = 1;
				if (i2c_data_transmit_status == 30) begin
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
						if (i2c_data_transmit_status == 29) begin
							// Send a STOP
							camera_data_sda_sw = 1;
							i2c_data_transmit_status = 30;
						end
					end
					if (camera_data_scl == 0) begin
						if (i2c_data_transmit_status == 1) begin
							// Send the first address byte
							camera_data_sda_sw = i2c_address[7];
						end
						if (i2c_data_transmit_status == 2) begin
							// Send the second address byte
							camera_data_sda_sw = i2c_address[6];
						end
						if (i2c_data_transmit_status == 3) begin
							// Send the third address byte
							camera_data_sda_sw = i2c_address[5];
						end
						if (i2c_data_transmit_status == 4) begin
							// Send the fourth address byte
							camera_data_sda_sw = i2c_address[4];
						end
						if (i2c_data_transmit_status == 5) begin
							// Send the fifth address byte
							camera_data_sda_sw = i2c_address[3];
						end
						if (i2c_data_transmit_status == 6) begin
							// Send the sixth address byte
							camera_data_sda_sw = i2c_address[2];
						end
						if (i2c_data_transmit_status == 7) begin
							// Send the seventh address byte
							camera_data_sda_sw = i2c_address[1];
						end
						if (i2c_data_transmit_status == 8) begin
							// Send the data direction byte
							camera_data_sda_sw = i2c_address[0];
						end
						if (i2c_data_transmit_status == 9) begin
							// Wait for ACK signal from slave
							camera_data_sda_sw = 1;
						end
						if (i2c_data_transmit_status == 10) begin
							// Send the first register byte
							camera_data_sda_sw = i2c_register[7];
						end
						if (i2c_data_transmit_status == 11) begin
							// Send another register byte
							camera_data_sda_sw = i2c_register[6];
						end
						if (i2c_data_transmit_status == 12) begin
							// Send another register byte
							camera_data_sda_sw = i2c_register[5];
						end
						if (i2c_data_transmit_status == 13) begin
							// Send another register byte
							camera_data_sda_sw = i2c_register[4];
						end
						if (i2c_data_transmit_status == 14) begin
							// Send another register byte
							camera_data_sda_sw = i2c_register[3];
						end
						if (i2c_data_transmit_status == 15) begin
							// Send another register byte
							camera_data_sda_sw = i2c_register[2];
						end
						if (i2c_data_transmit_status == 16) begin
							// Send another register byte
							camera_data_sda_sw = i2c_register[1];
						end
						if (i2c_data_transmit_status == 17) begin
							// Send another register byte
							camera_data_sda_sw = i2c_register[0];
						end
						if (i2c_data_transmit_status == 18) begin
							// Wait for ACK signal from slave
							camera_data_sda_sw = 1;
						end
						if (i2c_data_transmit_status == 19) begin
							// Send the first data byte
							camera_data_sda_sw = i2c_data[7];
						end
						if (i2c_data_transmit_status == 20) begin
							// Send the next data byte
							camera_data_sda_sw = i2c_data[6];
						end
						if (i2c_data_transmit_status == 21) begin
							// Send the next data byte
							camera_data_sda_sw = i2c_data[5];
						end
						if (i2c_data_transmit_status == 22) begin
							// Send the next data byte
							camera_data_sda_sw = i2c_data[4];
						end
						if (i2c_data_transmit_status == 23) begin
							// Send the next data byte
							camera_data_sda_sw = i2c_data[3];
						end
						if (i2c_data_transmit_status == 24) begin
							// Send the next data byte
							camera_data_sda_sw = i2c_data[2];
						end
						if (i2c_data_transmit_status == 25) begin
							// Send the next data byte
							camera_data_sda_sw = i2c_data[1];
						end
						if (i2c_data_transmit_status == 26) begin
							// Send the next data byte
							camera_data_sda_sw = i2c_data[0];
						end
						if (i2c_data_transmit_status == 27) begin
							// Wait for ACK signal from slave
							camera_data_sda_sw = 1;
						end
						if (i2c_data_transmit_status == 28) begin
							// Allow the clock to go high once more (in order to "receive" the ACK bit)
							camera_data_sda_sw = 0;
						end
						if (i2c_data_transmit_status < 30) begin
							i2c_data_transmit_status = i2c_data_transmit_status + 1;
						end else begin
							i2c_data_transmit_status = 0;
						end
					end
				end
				if (I2C_Master_Clock == I2ClkCyclesToWait) begin
					if (i2c_data_transmit_status >= 30) begin
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
