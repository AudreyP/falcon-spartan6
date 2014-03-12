module gradient_color_pattern (
	input wire clk,
	input wire pause,
	input wire reset,
	input wire enable,
	input wire [17:0] starting_address,	//set to 0s

	output reg [31:0] data_write,
	output reg [17:0] addr,
	output reg wren,
	output reg done
	);

	localparam PIXEL_COUNT = 320*240;
	localparam 	INITIAL_STATE = 0,
			WRITE = 1,
			DONE = 2,
			CLEANUP = 3;
	
	reg [3:0] state = 0;
	
	always @ (posedge clk) begin
		if (pause == 0) begin
			case (state)
				INITIAL_STATE: begin
					if (enable) begin
						data_write = 32'h0;
						addr = starting_address;
						wren = 0;
						state = WRITE;
					end else begin
						wren = 0;
						addr = 18'h0;
						data_write = 32'h0;
						done = 0;
					end
				end
				WRITE: begin
					data_write[31:8] = starting_address + addr;
					data_write[7:0] = 0;
					//data_write = 32'haabbccdd;
					wren = 1;
					addr = addr + 1;
					if ((addr - starting_address) < PIXEL_COUNT)
						state = WRITE;
					else
						state = DONE;
				end
				DONE: begin
					data_write = 32'h0;
					addr = 18'h0;
					wren = 0;
					done = 1;
					state = CLEANUP;
				end
				CLEANUP: begin
					if (enable) begin
						state = CLEANUP;
					end
					else begin
						done = 0;
						state = INITIAL_STATE;
					end
				end
			endcase
		end
	end
endmodule
