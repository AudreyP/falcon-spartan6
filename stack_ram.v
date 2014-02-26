`timescale 1ns / 1ps
`timescale 1ns / 1ps
/**********************************************************************

 (c) 2013 Timothy Pearson, Raptor Engineering
 (c) 2014 Audrey Pearson

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

module stack_ram(
	input clka,
	input [(RAM_WIDTH - 1) : 0] dina,	//[16:0]
	input [(RAM_ADDR_BITS - 1) : 0] addra,	//[13:0]
	input wea,
	output reg [(RAM_WIDTH - 1) : 0] douta
	);

	parameter RAM_ADDR_BITS = 14;
	parameter RAM_WIDTH = 17;
	
	// Xilinx specific directive
	(* RAM_STYLE="BLOCK" *)
	
	reg [RAM_WIDTH-1:0] data_storage_ram [(2**RAM_ADDR_BITS)-1:0];
	
	always @(posedge clka) begin
	if (wea) begin
			data_storage_ram[addra] <= dina;
			douta <= dina;
	end else begin
			douta <= data_storage_ram[addra];
		end
	end

endmodule
