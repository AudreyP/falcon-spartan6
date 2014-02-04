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

endmodule
