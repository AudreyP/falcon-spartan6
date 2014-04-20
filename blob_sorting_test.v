`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   18:28:38 04/19/2014
// Design Name:   blob_sorting
// Module Name:   /home/audrey/Xilinx Projects/Falcon_Spartan6/blob_sorting_test.v
// Project Name:  Falcon_Spartan6
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: blob_sorting
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module blob_sorting_test;

	// Inputs
	reg clk;
	reg clk_fast;
	reg pause;
	reg [15:0] blob_extraction_blob_counter;
	reg enable_blob_sorting;
	reg [7:0] minimum_blob_size;
	reg [7:0] slide_switches;
	reg [31:0] data_read;

	// Outputs
	wire wren;
	wire [31:0] data_write;
	wire [17:0] address;
	wire blob_sorting_done;

	// Instantiate the Unit Under Test (UUT)
	blob_sorting uut (
		.clk(clk), 
		.clk_fast(clk_fast), 
		.pause(pause), 
		.blob_extraction_blob_counter(blob_extraction_blob_counter), 
		.enable_blob_sorting(enable_blob_sorting), 
		.minimum_blob_size(minimum_blob_size), 
		.slide_switches(slide_switches), 
		.data_read(data_read), 
		.wren(wren), 
		.data_write(data_write), 
		.address(address), 
		.blob_sorting_done(blob_sorting_done)
	);

	initial begin
		// Initialize Inputs
		clk = 0;
		clk_fast = 0;
		pause = 0;
		blob_extraction_blob_counter = 6;
		enable_blob_sorting = 0;
		minimum_blob_size = 0;
		slide_switches = 0; //0: find biggest blob; 1: find smallest blob; 2: find highest blob; 3: find lowest blob
		data_read = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
		enable_blob_sorting = 1;
		#3000;
		$finish;

	end
      
	// 200MHz clock input
	always begin
		#5 clk_fast = !clk_fast;
	end
	// 100MHz clock input
	always begin
		#10 clk = !clk;
	end
	
	always @ (negedge clk) begin
		case (address)
			// blob 1
			200000: data_read = 32'h10201001;
			200001: data_read = 32'h10101010;
			200002: data_read = 32'h10103030;
			// blob 2
			200003: data_read = 32'h10102000;
			200004: data_read = 32'h20202020;
			200005: data_read = 32'h37236955;
			// blob 3
			200006: data_read = 32'h15253006;
			200007: data_read = 32'h30303030;
			200008: data_read = 32'h37236955;
			// blob 4
			200009: data_read = 32'h10204005;
			200010: data_read = 32'h40404040;
			200011: data_read = 32'ha07803e8;
			// blob 5
			200012: data_read = 32'h10205001;
			200013: data_read = 32'h60606060;
			200014: data_read = 32'h37236955;
			// blob 6
			200015: data_read = 32'h10206001;
			200016: data_read = 32'h50501050;
			200017: data_read = 32'h37236955;
			// termination
			200018: data_read = 32'hffffffff;
			200019: data_read = 32'hffffffff;
			200020: data_read = 32'hffffffff;
		endcase	
	end
	
endmodule

