module camera_clock_manager_v2(
	input input_clk,
	output wire main_camera_clk_unbuffered,
	output wire main_camera_clk_oneeighty_unbuffered,
	output wire camera_dcm_locked,
	output wire camera_dcm_feedback_unbuff
	);

	// generate 96MHz clock for the camera
	
	wire main_camera_clk;
	reg dcm_reset = 1;

	BUFG CAMERA_CLOCK_BUF(
		.O(main_camera_clk),
		.I(main_camera_clk_unbuffered)
		);
// 	BUFG LOOPBACK_CLOCK_CAMERA_BUF(
// 		.O(camera_dcm_feedback),
// 		.I(camera_dcm_feedback_unbuff)
// 		);

	DCM_SP #(
		// NOTE: This must generate 96MHz, not 25MHz, for monochrome cameras
		// For 96.8 MHz: CLKFX_DIVIDE = 32, CLKFX_MULTIPLY = 31
		// For 25 MHz: CLKFX_DIVIDE = 8, CLKFX_MULTIPLY = 2
		.CLKDV_DIVIDE(2.0), 			// divide the system clock by 2.0 to determine CLKDV (25 MHz)
		.CLKFX_DIVIDE(32.0), 			// the denominator of the clock multiplier used to determine CLKFX
		.CLKFX_MULTIPLY(31.0), 			// the numerator of the clock multiplier used to determine CLKFX
		//.CLKFX_MULTIPLY(16.0), 			// the numerator of the clock multiplier used to determine CLKFX
		.CLKIN_DIVIDE_BY_2("FALSE"),		// create the internal clock signal
		.CLKIN_PERIOD(10.0), 			// period of input clock in ns
		.CLKOUT_PHASE_SHIFT("NONE"), 		// phase shift of NONE
		.CLK_FEEDBACK("1X"),			// feedback of NONE, 1X 
		.DESKEW_ADJUST("SYSTEM_SYNCHRONOUS"), // SYSTEM_SYNCHRNOUS or SOURCE_SYNCHRONOUS
		.DFS_FREQUENCY_MODE("LOW"), 		// LOW frequency mode for frequency synthesis
		.DLL_FREQUENCY_MODE("LOW"), 		// LOW frequency mode for DLL
		.DUTY_CYCLE_CORRECTION("TRUE"), 	// Duty cycle correction, TRUE
		.FACTORY_JF(16'hc080),                // Unsupported - Do not change value
		.PHASE_SHIFT(0),			// Amount of fixed phase shift from -255 to 255
		.STARTUP_WAIT("FALSE") 			// Do not delay configuration DONE until DCM LOCK TRUE
	)
	SYSTEM_DCM_CAMERA(
		.CLK0(camera_dcm_feedback),	//used to be camera_dcm_feedback_unbuff 
		.CLK180(),
		.CLK270(),
		.CLK2X(),
		.CLK2X180(),
		.CLK90(),
		.CLKDV(),
		.CLKFX(main_camera_clk_unbuffered),
		.CLKFX180(main_camera_clk_oneeighty_unbuffered),
		.LOCKED(camera_dcm_locked),
		.PSDONE(),
		.STATUS(),		
		.CLKFB(camera_dcm_feedback),
		.CLKIN(input_clk),
		.DSSEN(1'b0),
		.PSCLK(1'b0),
		.PSEN(1'b0),
		.PSINCDEC(1'b0),
		.RST(dcm_reset)		
	);

	reg management_clock;
	always @(posedge input_clk) begin
		management_clock = !management_clock;
	end
		
	reg [18:0] dcm_lock_timer = 0;

	always @(posedge management_clock) begin
		if (camera_dcm_locked == 0) begin
			dcm_lock_timer = dcm_lock_timer + 1;
		end else begin
			dcm_lock_timer = 0;
			dcm_reset = 0;
		end
		if (dcm_lock_timer > 50000) begin
			dcm_reset = 1;
		end
		
		if (dcm_lock_timer > 50010) begin		// Allow 10 clock cycles to reset the DCM
			dcm_reset = 0;
			dcm_lock_timer = 0;
		end
	end

endmodule