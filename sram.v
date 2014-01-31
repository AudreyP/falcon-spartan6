module sram(
    input wire [17:0] address,
    input wire wren,                  // write enable
    input wire [31:0] data_write,      // data being written to memory
    output wire [31:0] data_read,       // data being read from memory

	 inout wire [31:0] SRAM_DQ,
    output wire SRAM_CE_N,
    output wire SRAM_OE_N,
    output wire SRAM_LB_N,
    output wire SRAM_UB_N,
    output wire SRAM_WE_N,
    output wire [17:0] SRAM_ADDR,

    output wire SRAM_CE_N_2,
    output wire SRAM_LB_N_2,
    output wire SRAM_UB_N_2
	 );

	 // Chip 1
	 wire [31:0] SRAM_DQ_SW;
	 wire data_rnw;    // Data port direction (read=1 or 0=write)

	 assign  SRAM_DQ = (data_rnw) ? 32'bz : SRAM_DQ_SW;

	 assign SRAM_CE_N = 1'b0; // chip1 is always enabled
	 assign SRAM_OE_N = 1'b0; // chips are always driving output
	 assign SRAM_CE_N_2 = 1'b0; // chip2 is always enabled
		
	 assign SRAM_LB_N = 1'b0; 	// chip1 is driving the lower bytes
	 assign SRAM_UB_N = 1'b0; 	// chip1 is driving the upper bytes
	 assign SRAM_LB_N_2 = 1'b0; 	// chip2 is driving the lower bytes
	 assign SRAM_UB_N_2 = 1'b0; 	// chip2 is driving the upper bytes

	 assign data_rnw = !wren;
	 assign SRAM_WE_N = !wren;

	 assign SRAM_ADDR = address;

	 assign SRAM_DQ_SW = data_write;
	 assign data_read = SRAM_DQ;

endmodule
