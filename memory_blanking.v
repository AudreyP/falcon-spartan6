`timescale 1ns / 1ps
/**********************************************************************
 Copyright (c) 2014 Timothy Pearson <kb9vqf@pearsoncomputing.net>

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; version 2.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 02111-1307, USA
**********************************************************************/

module memory_blanking(
	input wire clk,
	input wire pause,
	input wire [31:0] data_read,

	output reg wren,
	output reg [31:0] data_write,
	output reg [17:0] address,

	input enable,
	output reg done
	);

	reg [17:0] counter = 0;

	always @(posedge clk) begin
		if (enable == 1) begin
			if (done == 0) begin
				if (pause == 0) begin
					address = counter;
					data_write = 32'h77553311;
					//data_write = {24'h775533, address[7:0]};
					wren = 1;
					counter = counter + 1;
					if (counter >= 262142) begin
						done = 1;
					end
				end
			end
		end else begin
			done = 0;
			counter = 0;

			wren = 0;
			address = 0;
			data_write = 0;
		end
	end
endmodule