// This is the module that handles the incoming camera data and saves it to SRAM

module camera_data(
    output reg [18:0] camera_data_address,
    input wire camera_data_dma_enable,                  // DMA enable
	 input wire [7:0] camera_data_y_port,
	 input wire [7:0] camera_data_uv_port,
	 input wire camera_data_href,
	 input wire camera_data_vsync,
	 input wire camera_data_pclk
	 );

	 //always @* begin
	 //	camera_data_address <= 12;
    //end
endmodule
