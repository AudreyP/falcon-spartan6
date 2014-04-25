`timescale 1ns / 1ps
//----------------------------------------------------------------------------
//
//		This file is part of the FALCON II.
//
//		The FALCON II is free software: you can redistribute it and/or modify
//		it under the terms of the GNU General Public License as published by
//		the Free Software Foundation, either version 3 of the License, or
//		(at your option) any later version.
//
//		The FALCON II is distributed in the hope that it will be useful,
//		but WITHOUT ANY WARRANTY; without even the implied warranty of
//		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//		GNU General Public License for more details.
//
//		You should have received a copy of the GNU General Public License
//		along with the FALCON II.  If not, see http://www.gnu.org/licenses/.
//
//		The FALCON II is copyright 2008-2014 by Timothy Pearson
//		tpearson@raptorengineeringinc.com
//		http://www.raptorengineeringinc.com
//
//----------------------------------------------------------------------------
//
//		The FALCON II is available as a reference design for the
//		Raptor Engineering VDFPGA series of FPGA development boards
//		Please visit http://www.raptorengineeringinc.com for more information.
//
//----------------------------------------------------------------------------

// Rough reimplementation of RGB to HSV algorithm originally described at http://www.cs.rit.edu/~ncs/color/t_convert.html

module convert_rgb_to_hsv(
	input wire clk,
	input wire pause,
	input wire [31:0] data_read,

	output reg wren,
	output reg [31:0] data_write,
	output reg [17:0] address,

	input enable,
	output reg done
	);

	parameter ImageWidth = 320;
	parameter ImageHeight = 240;
	parameter ImageOffset = (ImageWidth*ImageHeight)+1;
	parameter HSVStorageOffset = ((ImageWidth*ImageHeight)*2)+2;
	parameter HSVStorageMask = 32'hffffffff;	// Store all HSV values
	//parameter HSVStorageMask = 32'hffffff00;	// Do not store V (intensity) values

	// Instantiate division modules
	localparam divider_size = 16;
	reg [(divider_size-1):0] divider_dividend_s;
	reg [(divider_size-1):0] divider_divisor_s;
	wire [(divider_size-1):0] divider_quotient_s;
	wire [(divider_size-1):0] divider_remainder_s;
	wire divider_zeroflag_s;

	reg [(divider_size-1):0] divider_dividend_h;
	reg [(divider_size-1):0] divider_divisor_h;
	wire [(divider_size-1):0] divider_quotient_h;
	wire [(divider_size-1):0] divider_remainder_h;
	wire divider_zeroflag_h;

	serial_divide_uu #(.size(divider_size)) serial_divide_uu_s (.dividend(divider_dividend_s), .divisor(divider_divisor_s), .quotient(divider_quotient_s), .remainder(divider_remainder_s), .zeroflag(divider_zeroflag_s));
	serial_divide_uu #(.size(divider_size)) serial_divide_uu_h (.dividend(divider_dividend_h), .divisor(divider_divisor_h), .quotient(divider_quotient_h), .remainder(divider_remainder_h), .zeroflag(divider_zeroflag_h));

	reg [17:0] counter = 0;
	reg [1:0] state = 0;

	reg [7:0] red;
	reg [7:0] green;
	reg [7:0] blue;

	reg [7:0] min;
	reg [7:0] max;
	reg [7:0] delta;

	reg red_is_max;
	reg green_is_max;
	reg blue_is_max;

	reg subtract_h_quotient;

	reg [15:0] hsv_h;
	reg [15:0] hsv_s;
	reg [15:0] hsv_v;

	always @(posedge clk) begin
		if (enable == 1) begin
			if (done == 0) begin
				if (pause == 0) begin
					case (state)
						0: begin
							wren <= 0;
							address <= counter + ImageOffset;
							state <= 1;
						end
						1: begin
							red = data_read[7:0];
							green = data_read[15:8];
							blue = data_read[31:24];

							red_is_max = 0;
							green_is_max = 0;
							blue_is_max = 0;

							if ((red > green) && (red > blue)) begin
								max = red;
								red_is_max = 1;
							end else if ((green > red) && (green > blue)) begin
								max = green;
								green_is_max = 1;
							end else begin
								max = blue;
								blue_is_max = 1;
							end

							if ((red < green) && (red < blue)) begin
								min = red;
							end else if ((green < red) && (green < blue)) begin
								min = green;
							end else begin
								min = blue;
							end

							delta = max - min;

							hsv_v = max;

							// Set up division operations
							if (max > 0) begin
								divider_dividend_s = delta * 256;
								divider_divisor_s = max;
								state <= 2;

								if (red_is_max) begin
									if (green >= blue) begin
										divider_dividend_h = (green - blue) * 256;
										subtract_h_quotient = 0;
									end else begin
										divider_dividend_h = (blue - green) * 256;
										subtract_h_quotient = 1;
									end
								end else if (green_is_max) begin
									if (blue >= red) begin
										divider_dividend_h = (blue - red) * 256;
										subtract_h_quotient = 0;
									end else begin
										divider_dividend_h = (red - blue) * 256;
										subtract_h_quotient = 1;
									end
								end else begin
									if (red >= green) begin
										divider_dividend_h = (red - green) * 256;
										subtract_h_quotient = 0;
									end else begin
										divider_dividend_h = (green - red) * 256;
										subtract_h_quotient = 1;
									end
								end
								divider_divisor_h = delta;
							end else begin
								// H and S are undefined!
								// Abort...
								hsv_h = (6 * 256) + 1;	// Unique value outside of normal hue space used to indicate lack of hue
								hsv_s = 0;

								address <= counter + HSVStorageOffset;
								data_write <= {hsv_h[7:0], 8'h00, hsv_s[7:0], hsv_v[7:0]} & HSVStorageMask;
								wren <= 1;
								state <= 1;
							end
						end
						2: begin
							// Finish calculations
							hsv_s = divider_quotient_s;
							if (red_is_max) begin
								if (subtract_h_quotient == 1) begin
									hsv_h = (6 * 256) - divider_quotient_h;
								end else begin
									hsv_h = divider_quotient_h;
								end
							end else if (green_is_max) begin
								if (subtract_h_quotient == 1) begin
									hsv_h = (2 * 256) - divider_quotient_h;
								end else begin
									hsv_h = divider_quotient_h + (2 * 256);
								end
							end else begin
								if (subtract_h_quotient == 1) begin
									hsv_h = (4 * 256) - divider_quotient_h;
								end else begin
									hsv_h = divider_quotient_h + (4 * 256);
								end
							end
							hsv_h = hsv_h / 8;

							address <= counter + HSVStorageOffset;
							data_write <= {hsv_h[7:0], 8'h00, hsv_s[7:0], hsv_v[7:0]} & HSVStorageMask;
							wren <= 1;
							counter = counter + 1;
							if (counter >= (ImageWidth*ImageHeight)) begin
								done <= 1;
							end

							state <= 0;
						end
						default: begin
							state <= 0;
						end
					endcase
				end
			end
		end else begin
			done <= 0;
			counter = 0;

			wren <= 0;
			address <= 0;
			data_write <= 0;
		end
	end
endmodule