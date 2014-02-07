module median_filtering(
	//input wires
	input wire clk_fifty_div_by_two,

	//output wires
	output wire wren,
	output wire data_read,
	output wire data_write
	
	
		);
		
		reg median_filtering_holdoff = 0;
		reg [7:0] median_filtering_swap_buffer;
		reg [31:0] data_read_sync_median_filtering;
		reg [71:0] median_filtering_counter_buffer_red;
		reg [71:0] median_filtering_counter_buffer_green;
		reg [71:0] median_filtering_counter_buffer_blue;
	/*
		// For every pixel, check the 9 pixels around and including it, and find the 'middle' value.
		always @(posedge clk) begin
		//always @(posedge modified_clock) begin
		//always @(posedge clk_div_by_two) begin
			data_read_sync_median_filtering = data_read;
		
			if (enable_median_filtering == 1) begin
				if (median_filtering_holdoff == 0) begin
					wren = 0;
					address = 320;								// Skip the topmost line of the image
					median_filtering_counter_tog = 320;
					median_filtering_holdoff = 1;
				end else begin
					// Load in the first pixel
					if (median_filtering_counter_toggle == 1) begin
						median_filtering_counter_buffer_red[7:0] = data_read_sync_median_filtering[7:0];			// This is the center pixel
						median_filtering_counter_buffer_green[7:0] = data_read_sync_median_filtering[15:8];
						median_filtering_counter_buffer_blue[7:0] = data_read_sync_median_filtering[31:24];
						median_filtering_counter_tog = median_filtering_counter_tog - 1;	// Set next read address (one pixel to the left)
					end

					if (median_filtering_counter_toggle == 2) begin
						median_filtering_counter_buffer_red[15:8] = data_read_sync_median_filtering[7:0];			// This is the left pixel
						median_filtering_counter_buffer_green[15:8] = data_read_sync_median_filtering[15:8];
						median_filtering_counter_buffer_blue[15:8] = data_read_sync_median_filtering[31:24];
						median_filtering_counter_tog = median_filtering_counter_tog + 2;	// Set next read address (two pixels to the right)
					end
		
					if (median_filtering_counter_toggle == 3) begin
						median_filtering_counter_buffer_red[23:16] = data_read_sync_median_filtering[7:0];			// This is the right pixel
						median_filtering_counter_buffer_green[23:16] = data_read_sync_median_filtering[15:8];
						median_filtering_counter_buffer_blue[23:16] = data_read_sync_median_filtering[31:24];
						median_filtering_counter_tog = median_filtering_counter_tog - 320;	// Set next read address (one pixel up)
					end
					
					if (median_filtering_counter_toggle == 4) begin
						median_filtering_counter_buffer_red[31:24] = data_read_sync_median_filtering[7:0];			// This is the top-right pixel
						median_filtering_counter_buffer_green[31:24] = data_read_sync_median_filtering[15:8];
						median_filtering_counter_buffer_blue[31:24] = data_read_sync_median_filtering[31:24];
						median_filtering_counter_tog = median_filtering_counter_tog - 1;	// Set next read address (one pixel to the left)
					end
					
					if (median_filtering_counter_toggle == 5) begin
						median_filtering_counter_buffer_red[39:32] = data_read_sync_median_filtering[7:0];			// This is the top pixel
						median_filtering_counter_buffer_green[39:32] = data_read_sync_median_filtering[15:8];
						median_filtering_counter_buffer_blue[39:32] = data_read_sync_median_filtering[31:24];
						median_filtering_counter_tog = median_filtering_counter_tog - 1;	// Set next read address (one pixel to the left)
					end
					
					if (median_filtering_counter_toggle == 6) begin
						median_filtering_counter_buffer_red[47:40] = data_read_sync_median_filtering[7:0];			// This is the top-left pixel
						median_filtering_counter_buffer_green[47:40] = data_read_sync_median_filtering[15:8];
						median_filtering_counter_buffer_blue[47:40] = data_read_sync_median_filtering[31:24];
						median_filtering_counter_tog = median_filtering_counter_tog + 640;	// Set next read address (two pixels down)
					end
					
					if (median_filtering_counter_toggle == 7) begin
						median_filtering_counter_buffer_red[55:48] = data_read_sync_median_filtering[7:0];			// This is the bottom-left pixel
						median_filtering_counter_buffer_green[55:48] = data_read_sync_median_filtering[15:8];
						median_filtering_counter_buffer_blue[55:48] = data_read_sync_median_filtering[31:24];
						median_filtering_counter_tog = median_filtering_counter_tog + 1;	// Set next read address (one pixel to the right)
					end
					
					if (median_filtering_counter_toggle == 8) begin
						median_filtering_counter_buffer_red[63:56] = data_read_sync_median_filtering[7:0];			// This is the bottom pixel
						median_filtering_counter_buffer_green[63:56] = data_read_sync_median_filtering[15:8];
						median_filtering_counter_buffer_blue[63:56] = data_read_sync_median_filtering[31:24];
						median_filtering_counter_tog = median_filtering_counter_tog + 1;	// Set next read address (one pixel to the right)
					end
					
					if (median_filtering_counter_toggle == 9) begin
						median_filtering_counter_buffer_red[71:64] = data_read_sync_median_filtering[7:0];			// This is the bottom-right pixel
						median_filtering_counter_buffer_green[71:64] = data_read_sync_median_filtering[15:8];
						median_filtering_counter_buffer_blue[71:64] = data_read_sync_median_filtering[31:24];
						median_filtering_counter_tog = median_filtering_counter_tog - 320;	// Set next read address (one pixel up) (this is to put the "cursor" in the correct position for the next pixel!
						
						// Now, since we have all of this data collected (finally!), we can calculate the median of the numbers
						// First the red image...LOTS of processing here!
						if (median_filtering_counter_buffer_red[15:8] > median_filtering_counter_buffer_red[23:16]) begin	// 1,2
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[15:8];
							median_filtering_counter_buffer_red[15:8] = median_filtering_counter_buffer_red[23:16];
							median_filtering_counter_buffer_red[23:16] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_red[39:32] > median_filtering_counter_buffer_red[47:40]) begin	// 4,5
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[39:32];
							median_filtering_counter_buffer_red[39:32] = median_filtering_counter_buffer_red[47:40];
							median_filtering_counter_buffer_red[47:40] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_red[63:56] > median_filtering_counter_buffer_red[71:64]) begin	// 7,8
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[63:56];
							median_filtering_counter_buffer_red[63:56] = median_filtering_counter_buffer_red[71:64];
							median_filtering_counter_buffer_red[71:64] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_red[7:0] > median_filtering_counter_buffer_red[15:8]) begin		// 0,1
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[7:0];
							median_filtering_counter_buffer_red[7:0] = median_filtering_counter_buffer_red[15:8];
							median_filtering_counter_buffer_red[15:8] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_red[31:24] > median_filtering_counter_buffer_red[39:32]) begin	// 3,4
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[31:24];
							median_filtering_counter_buffer_red[31:24] = median_filtering_counter_buffer_red[39:32];
							median_filtering_counter_buffer_red[39:32] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_red[55:48] > median_filtering_counter_buffer_red[63:56]) begin	// 6,7
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[55:48];
							median_filtering_counter_buffer_red[55:48] = median_filtering_counter_buffer_red[63:56];
							median_filtering_counter_buffer_red[63:56] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_red[15:8] > median_filtering_counter_buffer_red[23:16]) begin	// 1,2
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[15:8];
							median_filtering_counter_buffer_red[15:8] = median_filtering_counter_buffer_red[23:16];
							median_filtering_counter_buffer_red[23:16] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_red[39:32] > median_filtering_counter_buffer_red[47:40]) begin	// 4,5
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[39:32];
							median_filtering_counter_buffer_red[39:32] = median_filtering_counter_buffer_red[47:40];
							median_filtering_counter_buffer_red[47:40] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_red[63:56] > median_filtering_counter_buffer_red[71:64]) begin	// 7,8
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[63:56];
							median_filtering_counter_buffer_red[63:56] = median_filtering_counter_buffer_red[71:64];
							median_filtering_counter_buffer_red[71:64] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_red[7:0] > median_filtering_counter_buffer_red[31:24]) begin	// 0,3
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[7:0];
							median_filtering_counter_buffer_red[7:0] = median_filtering_counter_buffer_red[31:24];
							median_filtering_counter_buffer_red[31:24] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_red[47:40] > median_filtering_counter_buffer_red[71:64]) begin	// 5,8
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[47:40];
							median_filtering_counter_buffer_red[47:40] = median_filtering_counter_buffer_red[71:64];
							median_filtering_counter_buffer_red[71:64] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_red[39:32] > median_filtering_counter_buffer_red[63:56]) begin	// 4,7
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[39:32];
							median_filtering_counter_buffer_red[39:32] = median_filtering_counter_buffer_red[63:56];
							median_filtering_counter_buffer_red[63:56] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_red[31:24] > median_filtering_counter_buffer_red[55:48]) begin	// 3,6
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[31:24];
							median_filtering_counter_buffer_red[31:24] = median_filtering_counter_buffer_red[55:48];
							median_filtering_counter_buffer_red[55:48] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_red[15:8] > median_filtering_counter_buffer_red[39:32]) begin	// 1,4
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[15:8];
							median_filtering_counter_buffer_red[15:8] = median_filtering_counter_buffer_red[39:32];
							median_filtering_counter_buffer_red[39:32] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_red[23:16] > median_filtering_counter_buffer_red[47:40]) begin	// 2,5
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[23:16];
							median_filtering_counter_buffer_red[23:16] = median_filtering_counter_buffer_red[47:40];
							median_filtering_counter_buffer_red[47:40] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_red[39:32] > median_filtering_counter_buffer_red[63:56]) begin	// 4,7
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[39:32];
							median_filtering_counter_buffer_red[39:32] = median_filtering_counter_buffer_red[63:56];
							median_filtering_counter_buffer_red[63:56] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_red[39:32] > median_filtering_counter_buffer_red[23:16]) begin	// 4,2
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[39:32];
							median_filtering_counter_buffer_red[39:32] = median_filtering_counter_buffer_red[23:16];
							median_filtering_counter_buffer_red[23:16] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_red[55:48] > median_filtering_counter_buffer_red[39:32]) begin	// 6,4
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[55:48];
							median_filtering_counter_buffer_red[55:48] = median_filtering_counter_buffer_red[39:32];
							median_filtering_counter_buffer_red[39:32] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_red[39:32] > median_filtering_counter_buffer_red[23:16]) begin	// 4,2
							median_filtering_swap_buffer = median_filtering_counter_buffer_red[39:32];
							median_filtering_counter_buffer_red[39:32] = median_filtering_counter_buffer_red[23:16];
							median_filtering_counter_buffer_red[23:16] = median_filtering_swap_buffer;
						end
						// FINALLY DONE WITH THE RED ARRAY!!! YIPPEE!!!
						median_filtering_counter_temp[7:0] = median_filtering_counter_buffer_red[39:32];		// Store the median in the red slot of the data to write
						
						// Next the green image...LOTS of processing here again!
						if (median_filtering_counter_buffer_green[15:8] > median_filtering_counter_buffer_green[23:16]) begin		// 1,2
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[15:8];
							median_filtering_counter_buffer_green[15:8] = median_filtering_counter_buffer_green[23:16];
							median_filtering_counter_buffer_green[23:16] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_green[39:32] > median_filtering_counter_buffer_green[47:40]) begin	// 4,5
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[39:32];
							median_filtering_counter_buffer_green[39:32] = median_filtering_counter_buffer_green[47:40];
							median_filtering_counter_buffer_green[47:40] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_green[63:56] > median_filtering_counter_buffer_green[71:64]) begin	// 7,8
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[63:56];
							median_filtering_counter_buffer_green[63:56] = median_filtering_counter_buffer_green[71:64];
							median_filtering_counter_buffer_green[71:64] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_green[7:0] > median_filtering_counter_buffer_green[15:8]) begin		// 0,1
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[7:0];
							median_filtering_counter_buffer_green[7:0] = median_filtering_counter_buffer_green[15:8];
							median_filtering_counter_buffer_green[15:8] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_green[31:24] > median_filtering_counter_buffer_green[39:32]) begin	// 3,4
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[31:24];
							median_filtering_counter_buffer_green[31:24] = median_filtering_counter_buffer_green[39:32];
							median_filtering_counter_buffer_green[39:32] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_green[55:48] > median_filtering_counter_buffer_green[63:56]) begin	// 6,7
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[55:48];
							median_filtering_counter_buffer_green[55:48] = median_filtering_counter_buffer_green[63:56];
							median_filtering_counter_buffer_green[63:56] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_green[15:8] > median_filtering_counter_buffer_green[23:16]) begin		// 1,2
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[15:8];
							median_filtering_counter_buffer_green[15:8] = median_filtering_counter_buffer_green[23:16];
							median_filtering_counter_buffer_green[23:16] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_green[39:32] > median_filtering_counter_buffer_green[47:40]) begin	// 4,5
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[39:32];
							median_filtering_counter_buffer_green[39:32] = median_filtering_counter_buffer_green[47:40];
							median_filtering_counter_buffer_green[47:40] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_green[63:56] > median_filtering_counter_buffer_green[71:64]) begin	// 7,8
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[63:56];
							median_filtering_counter_buffer_green[63:56] = median_filtering_counter_buffer_green[71:64];
							median_filtering_counter_buffer_green[71:64] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_green[7:0] > median_filtering_counter_buffer_green[31:24]) begin		// 0,3
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[7:0];
							median_filtering_counter_buffer_green[7:0] = median_filtering_counter_buffer_green[31:24];
							median_filtering_counter_buffer_green[31:24] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_green[47:40] > median_filtering_counter_buffer_green[71:64]) begin	// 5,8
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[47:40];
							median_filtering_counter_buffer_green[47:40] = median_filtering_counter_buffer_green[71:64];
							median_filtering_counter_buffer_green[71:64] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_green[39:32] > median_filtering_counter_buffer_green[63:56]) begin	// 4,7
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[39:32];
							median_filtering_counter_buffer_green[39:32] = median_filtering_counter_buffer_green[63:56];
							median_filtering_counter_buffer_green[63:56] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_green[31:24] > median_filtering_counter_buffer_green[55:48]) begin	// 3,6
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[31:24];
							median_filtering_counter_buffer_green[31:24] = median_filtering_counter_buffer_green[55:48];
							median_filtering_counter_buffer_green[55:48] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_green[15:8] > median_filtering_counter_buffer_green[39:32]) begin		// 1,4
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[15:8];
							median_filtering_counter_buffer_green[15:8] = median_filtering_counter_buffer_green[39:32];
							median_filtering_counter_buffer_green[39:32] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_green[23:16] > median_filtering_counter_buffer_green[47:40]) begin	// 2,5
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[23:16];
							median_filtering_counter_buffer_green[23:16] = median_filtering_counter_buffer_green[47:40];
							median_filtering_counter_buffer_green[47:40] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_green[39:32] > median_filtering_counter_buffer_green[63:56]) begin	// 4,7
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[39:32];
							median_filtering_counter_buffer_green[39:32] = median_filtering_counter_buffer_green[63:56];
							median_filtering_counter_buffer_green[63:56] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_green[39:32] > median_filtering_counter_buffer_green[23:16]) begin	// 4,2
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[39:32];
							median_filtering_counter_buffer_green[39:32] = median_filtering_counter_buffer_green[23:16];
							median_filtering_counter_buffer_green[23:16] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_green[55:48] > median_filtering_counter_buffer_green[39:32]) begin	// 6,4
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[55:48];
							median_filtering_counter_buffer_green[55:48] = median_filtering_counter_buffer_green[39:32];
							median_filtering_counter_buffer_green[39:32] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_green[39:32] > median_filtering_counter_buffer_green[23:16]) begin	// 4,2
							median_filtering_swap_buffer = median_filtering_counter_buffer_green[39:32];
							median_filtering_counter_buffer_green[39:32] = median_filtering_counter_buffer_green[23:16];
							median_filtering_counter_buffer_green[23:16] = median_filtering_swap_buffer;
						end
						// FINALLY DONE WITH THE GREEN ARRAY!!! YIPPEE!!!
						median_filtering_counter_temp[15:8] = median_filtering_counter_buffer_green[39:32];		// Store the median in the green slot of the data to write
						
						// Finally the blue image...again, LOTS of processing here!
						if (median_filtering_counter_buffer_blue[15:8] > median_filtering_counter_buffer_blue[23:16]) begin	// 1,2
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[15:8];
							median_filtering_counter_buffer_blue[15:8] = median_filtering_counter_buffer_blue[23:16];
							median_filtering_counter_buffer_blue[23:16] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_blue[39:32] > median_filtering_counter_buffer_blue[47:40]) begin	// 4,5
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[39:32];
							median_filtering_counter_buffer_blue[39:32] = median_filtering_counter_buffer_blue[47:40];
							median_filtering_counter_buffer_blue[47:40] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_blue[63:56] > median_filtering_counter_buffer_blue[71:64]) begin	// 7,8
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[63:56];
							median_filtering_counter_buffer_blue[63:56] = median_filtering_counter_buffer_blue[71:64];
							median_filtering_counter_buffer_blue[71:64] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_blue[7:0] > median_filtering_counter_buffer_blue[15:8]) begin		// 0,1
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[7:0];
							median_filtering_counter_buffer_blue[7:0] = median_filtering_counter_buffer_blue[15:8];
							median_filtering_counter_buffer_blue[15:8] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_blue[31:24] > median_filtering_counter_buffer_blue[39:32]) begin	// 3,4
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[31:24];
							median_filtering_counter_buffer_blue[31:24] = median_filtering_counter_buffer_blue[39:32];
							median_filtering_counter_buffer_blue[39:32] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_blue[55:48] > median_filtering_counter_buffer_blue[63:56]) begin	// 6,7
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[55:48];
							median_filtering_counter_buffer_blue[55:48] = median_filtering_counter_buffer_blue[63:56];
							median_filtering_counter_buffer_blue[63:56] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_blue[15:8] > median_filtering_counter_buffer_blue[23:16]) begin	// 1,2
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[15:8];
							median_filtering_counter_buffer_blue[15:8] = median_filtering_counter_buffer_blue[23:16];
							median_filtering_counter_buffer_blue[23:16] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_blue[39:32] > median_filtering_counter_buffer_blue[47:40]) begin	// 4,5
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[39:32];
							median_filtering_counter_buffer_blue[39:32] = median_filtering_counter_buffer_blue[47:40];
							median_filtering_counter_buffer_blue[47:40] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_blue[63:56] > median_filtering_counter_buffer_blue[71:64]) begin	// 7,8
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[63:56];
							median_filtering_counter_buffer_blue[63:56] = median_filtering_counter_buffer_blue[71:64];
							median_filtering_counter_buffer_blue[71:64] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_blue[7:0] > median_filtering_counter_buffer_blue[31:24]) begin	// 0,3
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[7:0];
							median_filtering_counter_buffer_blue[7:0] = median_filtering_counter_buffer_blue[31:24];
							median_filtering_counter_buffer_blue[31:24] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_blue[47:40] > median_filtering_counter_buffer_blue[71:64]) begin	// 5,8
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[47:40];
							median_filtering_counter_buffer_blue[47:40] = median_filtering_counter_buffer_blue[71:64];
							median_filtering_counter_buffer_blue[71:64] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_blue[39:32] > median_filtering_counter_buffer_blue[63:56]) begin	// 4,7
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[39:32];
							median_filtering_counter_buffer_blue[39:32] = median_filtering_counter_buffer_blue[63:56];
							median_filtering_counter_buffer_blue[63:56] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_blue[31:24] > median_filtering_counter_buffer_blue[55:48]) begin	// 3,6
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[31:24];
							median_filtering_counter_buffer_blue[31:24] = median_filtering_counter_buffer_blue[55:48];
							median_filtering_counter_buffer_blue[55:48] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_blue[15:8] > median_filtering_counter_buffer_blue[39:32]) begin	// 1,4
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[15:8];
							median_filtering_counter_buffer_blue[15:8] = median_filtering_counter_buffer_blue[39:32];
							median_filtering_counter_buffer_blue[39:32] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_blue[23:16] > median_filtering_counter_buffer_blue[47:40]) begin	// 2,5
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[23:16];
							median_filtering_counter_buffer_blue[23:16] = median_filtering_counter_buffer_blue[47:40];
							median_filtering_counter_buffer_blue[47:40] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_blue[39:32] > median_filtering_counter_buffer_blue[63:56]) begin	// 4,7
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[39:32];
							median_filtering_counter_buffer_blue[39:32] = median_filtering_counter_buffer_blue[63:56];
							median_filtering_counter_buffer_blue[63:56] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_blue[39:32] > median_filtering_counter_buffer_blue[23:16]) begin	// 4,2
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[39:32];
							median_filtering_counter_buffer_blue[39:32] = median_filtering_counter_buffer_blue[23:16];
							median_filtering_counter_buffer_blue[23:16] = median_filtering_swap_buffer;
						end
						if (median_filtering_counter_buffer_blue[55:48] > median_filtering_counter_buffer_blue[39:32]) begin	// 6,4
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[55:48];
							median_filtering_counter_buffer_blue[55:48] = median_filtering_counter_buffer_blue[39:32];
							median_filtering_counter_buffer_blue[39:32] = median_filtering_swap_buffer;
						end
						// ---
						if (median_filtering_counter_buffer_blue[39:32] > median_filtering_counter_buffer_blue[23:16]) begin	// 4,2
							median_filtering_swap_buffer = median_filtering_counter_buffer_blue[39:32];
							median_filtering_counter_buffer_blue[39:32] = median_filtering_counter_buffer_blue[23:16];
							median_filtering_counter_buffer_blue[23:16] = median_filtering_swap_buffer;
						end
						// FINALLY DONE WITH THE BLUE ARRAY!!! YIPPEE!!!
						median_filtering_counter_temp[31:24] = median_filtering_counter_buffer_blue[39:32];		// Store the median in the blue slot of the data to write
						
						// Make sure none of our pixels are set to 255, as 255 is a reserved value for "edge found".
						if (median_filtering_counter_temp[7:0] == 255) begin
							median_filtering_counter_temp[7:0] = 254;
						end
						if (median_filtering_counter_temp[15:8] == 255) begin
							median_filtering_counter_temp[15:8] = 254;
						end
						if (median_filtering_counter_temp[31:24] == 255) begin
							median_filtering_counter_temp[31:24] = 254;
						end
					end

					if (median_filtering_counter_togg == 76481) begin		// All done!	It is 76481 because we don't need to process the last line of the image, as it would just be garbage anyway!
						median_filtering_coun = 0;
						median_filtering_counter_tog = 0;
						median_filtering_counter_togg = 0;
						median_filtering_counter_toggle = 0;
						median_filtering_done = 1;
						median_filtering_holdoff = 0;
						wren = 0;
					end

					median_filtering_counter_toggle = median_filtering_counter_toggle + 1;
					if (median_filtering_counter_toggle < 10) begin
						address = median_filtering_counter_tog;
						wren = 0;
					end
					if (median_filtering_counter_toggle == 10) begin
						address = median_filtering_counter_togg + 76801;
						data_write = median_filtering_counter_temp;
						wren = 1;
					end
					if (median_filtering_counter_toggle == 11) begin
						wren = 0;
						address = median_filtering_counter_tog;
						median_filtering_counter_togg = median_filtering_counter_togg + 1;
						median_filtering_counter_toggle = 0;
					end
				end
			end else begin
				median_filtering_done = 0;
				address = 18'bz;
				data_write = 32'bz;
				wren = 1'bz;
			end
		end
	*/

endmodule
