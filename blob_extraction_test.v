`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   17:37:16 04/22/2014
// Design Name:   blob_extraction
// Module Name:   /home/audrey/Xilinx Projects/falcon-spartan6/blob_extraction_test.v
// Project Name:  Falcon_Spartan6
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: blob_extraction
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module blob_extraction_test;

	// Inputs
	reg clk;
	reg clk_fast;
	reg primary_color_slots_clka;
	reg wren_primary_color_slots;
	reg [4:0] address_primary_color_slots;
	reg [23:0] data_write_primary_color_slots;
	reg pause;
	reg enable_blob_extraction;
	reg [31:0] data_read;
	reg [7:0] color_similarity_threshold;

	// Outputs
	wire wren;
	wire [31:0] data_write;
	wire [17:0] address;
	wire blob_extraction_done;
	wire [15:0] blob_count;
	wire [15:0] debug0;
	wire [15:0] debug1;
	wire [3:0] debug2;
	wire [4:0] debug3;
	wire [23:0] debug_display;
	wire [11:0] debug2_display;
	wire [11:0] debug3_display;

	// Instantiate the Unit Under Test (UUT)
	blob_extraction uut (
		.clk(clk), 
		.clk_fast(clk_fast), 
		.primary_color_slots_clka(primary_color_slots_clka), 
		.wren_primary_color_slots(wren_primary_color_slots), 
		.address_primary_color_slots(address_primary_color_slots), 
		.data_write_primary_color_slots(data_write_primary_color_slots), 
		.pause(pause), 
		.enable_blob_extraction(enable_blob_extraction), 
		.data_read(data_read), 
		.color_similarity_threshold(color_similarity_threshold), 
		.wren(wren), 
		.data_write(data_write), 
		.address(address), 
		.blob_extraction_done(blob_extraction_done), 
		.blob_count(blob_count), 
		.debug0(debug0), 
		.debug1(debug1), 
		.debug2(debug2), 
		.debug3(debug3), 
		.debug_display(debug_display), 
		.debug2_display(debug2_display), 
		.debug3_display(debug3_display)
	);

	initial begin
		// Initialize Inputs
		clk = 0;
		clk_fast = 1;
		primary_color_slots_clka = 0;
		wren_primary_color_slots = 0;
		address_primary_color_slots = 0;
		data_write_primary_color_slots = 0;
		pause = 0;
		enable_blob_extraction = 0;
		data_read = 0;
		color_similarity_threshold = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here
		enable_blob_extraction = 1;
		#13000000;
		enable_blob_extraction = 0;
		#10000
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

	reg [31:0] main_memory_array [262143:0];

	integer i;
	initial begin
		for(i=0; i<262143; i=i+1) begin
			main_memory_array[i] = 0;
		end
	end

	always @ (posedge clk_fast) begin
		if (wren == 1) begin
			main_memory_array[address] = data_write;
		end
		data_read = main_memory_array[address];
	end
      
endmodule

