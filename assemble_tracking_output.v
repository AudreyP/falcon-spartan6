module tracking_output_assembly (
	//input wires
	input wire clk,
	input wire pause,
	input wire enable_tracking_output,	
	//output regs
	output reg wren,
	output reg [31:0] data_write,
	output reg [17:0] address,
	output reg tracking_output_done
	);
		
	initial tracking_output_done = 0;

	always @(posedge clk) begin
		if (pause == 0) begin
			if (enable_tracking_output == 1) begin
				
				
				
				
			end else begin
				tracking_output_done = 1;
			end
		end // end if pause == 0
	end

endmodule


