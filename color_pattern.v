`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    22:52:44 01/21/2014 
// Design Name: 
// Module Name:    color_pattern 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module color_pattern(
	input wire clk,
	input wire reset,
	input wire enable,
	input wire [17:0] starting_address,
	output reg [31:0] data_write,
	output reg [17:0] addr,
	output reg wren,
	output reg done
    );
	 
	 //colors
	 localparam [23:0]	light_gray = 24'hc0c0c0,
								yellow = 24'hc0c000,
								light_blue = 24'h00c0c0,
								green = 24'h00c000,
								purple = 24'hc000c0,
								red = 24'hc00000,
								blue = 24'h0000c0,
								gray = 24'h131313,
								dark_blue = 24'h00214c,
								white = 24'hffffff,
								dark_purple = 24'h32006a,
								mid_gray1 = 24'h090909,
								mid_gray2 = 24'h1d1d1d;
								
	localparam [15:0]	img_width = 32,
							img_height = 32,
							bar_width = img_width/8,
							bar_height = img_height/2,
							bar_width_mini = img_width/32,
							bar_height_mini = img_height/4;
	
	localparam [15:0] initial_state = 0,
							bar1 = 1,
							bar1_low = 2,
							bar2 = 3,
							bar2_low = 4,
							bar3 = 5,
							bar3_low = 6,
							bar4 = 7,
							bar4_low = 8,
							bar5 = 9,
							bar5_low = 10,
							bar6 = 11,
							bar6_low = 12,
							bar7 = 13,
							bar7_low = 14,
							bar8 = 15,
							bar8_low = 16,
							bar9 = 17,
							bar9_low = 18,
							bar10 = 19,
							bar10_low = 20,
							bar11 = 21,
							bar11_low = 22,
							bar12 = 23,
							bar12_low = 24,
							bar13 = 25,
							bar13_low = 26,
							bar14 = 27,
							bar14_low = 28,
							bar15 = 29,
							bar15_low = 30,
							bar16 = 31,
							bar16_low = 32,
							bar17 = 33,
							bar17_low = 34,
							bar18 = 35,
							bar18_low = 36,
							bar19 = 37,
							bar19_low = 38,
							bar20 = 39,
							bar20_low = 40,
							bar21 = 41,
							bar21_low = 42,
							bar22 = 43,
							bar22_low = 44,
							bar23 = 45,
							bar23_low = 46,
							bar24 = 47,
							bar24_low = 48,
							bar25 = 49,
							bar25_low = 50,
							bar26 = 51,
							bar26_low = 52,
							bar27 = 53,
							bar27_low = 54,
							done_state = 55;
							
							
	
	reg [17:0] hcount, vcount, state;
	
	
	
	always @ (posedge clk) begin
		if (reset)
			state = initial_state;
		else begin
			case (state)
			initial_state: begin
				addr = starting_address;
				wren = 0;
				hcount = 0;
				vcount = 0;
				done = 0;
				state = bar1;
				end
			bar1: begin
				if (0 <= hcount && hcount < bar_width &&
					 0 <= vcount && vcount < bar_height) 
					begin
						data_write = light_gray;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar1_low;
					end
				else begin
					state = bar2;
					end
			end
			bar1_low: begin
						wren = 0;
						state = bar1;
						end
			bar2: begin
					if (bar_width <= hcount && hcount < 2*bar_width &&
								0 <= vcount && vcount < bar_height && wren == 0)
						begin
							data_write = yellow;
							addr = addr + 1;
							hcount = hcount + 1;
							wren = 1;
							state = bar2_low;
						end
					else begin
						state = bar3;
						end
					end
			bar2_low: begin
						wren = 0;
						state = bar2;
						end
			bar3: begin
						if (2*bar_width <= hcount && hcount < 3*bar_width &&
								0 <= vcount && vcount < bar_height)
							begin
								data_write = light_blue;
								addr = addr + 1;
								hcount = hcount + 1;
								wren = 1;
								state = bar3_low;
							end
						else begin
							state = bar4;
							end
					end
			bar3_low: begin
						wren = 0;
						state = bar3;
						end
			bar4: begin
					if (3*bar_width <= hcount && hcount < 4*bar_width &&
								0 <= vcount && vcount < bar_height)
						begin
							data_write = green;
							addr = addr + 1;
							hcount = hcount + 1;
							wren = 1;
							state = bar4_low;
						end
					else begin
						state = bar5;
						end
					end
			bar4_low: begin
						wren = 0;
						state = bar4;
						end
			bar5: begin
					if (4*bar_width <= hcount && hcount < 5*bar_width &&
								0 <= vcount && vcount < bar_height && wren == 0)
						begin
							data_write = purple;
							addr = addr + 1;
							hcount = hcount + 1;
							wren = 1;
							state = bar5_low;
						end
					else begin
						state = bar6;
						end
					end
			bar5_low: begin
					wren = 0;
					state = bar5;
					end
			bar6: begin
				if (5*bar_width <= hcount && hcount < 6*bar_width &&
							0 <= vcount && vcount < bar_height && wren == 0)
					begin
						data_write = red;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar6_low;
					end
				else 
					state = bar7;
				end
			bar6_low: begin
				wren = 0;
				state = bar6;
				end
			bar7: begin
				if (6*bar_width <= hcount && hcount < 7*bar_width &&
							0 <= vcount && vcount < bar_height && wren == 0)
					begin
						data_write = blue;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar7_low;
					end
				else
					state = bar8;
				end
			bar7_low: begin
				wren = 0;
				state = bar7;
				end
			bar8: begin				
					if (7*bar_width <= hcount && hcount < (8*bar_width)-1 &&
								0 <= vcount && vcount < bar_height)
						begin
							data_write = white;
							addr = addr + 1;
							hcount = hcount + 1;
							wren = 1;
							state = bar8_low;
							end
					else if (hcount == 8*bar_width-1 &&
								0 <= vcount && vcount < bar_height)
						begin
						addr = addr + 1;
						hcount = hcount + 1;
						vcount = vcount + 1;	//vertical count increments at last px of bar
						wren = 1;
						state = bar8_low;
						end
					else begin
						hcount = 0;
						if (vcount < bar_height) begin
							state = bar1;
							end
						else begin
							state = bar9;
							end
						end
					end
			bar8_low: begin
					wren = 0;
					state = bar8;
					end			
			//------end of painting top bars
			//------begin painting mid bars
			bar9: begin
					if (0 <= hcount && hcount < bar_width &&
						 bar_height <= vcount && vcount < bar_height+bar_height_mini) 
						begin
							data_write = blue;
							addr = addr + 1;
							hcount = hcount + 1;
							wren = 1;
							state = bar9_low;
						end
						else
							state = bar10;
					end
			bar9_low: begin
						wren = 0;
						state = bar9;
						end
			bar10: begin
				if (bar_width <= hcount && hcount < 2*bar_width &&
						bar_height <= vcount && vcount < bar_height+bar_height_mini && wren == 0)
					begin
						data_write = gray;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar10_low;
					end
					else 
						state = bar11;
					end
			bar10_low: begin
					wren = 0;
					state = bar10;
					end
			bar11: begin
				if (2*bar_width <= hcount && hcount < 3*bar_width &&
							bar_height <= vcount && vcount < bar_height+bar_height_mini && wren == 0)
					begin
						data_write = purple;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar11_low;
					end
					else 
						state = bar12;
				end
			bar11_low: begin
					wren = 0;
					state = bar11;
					end
			bar12: begin
				if (3*bar_width <= hcount && hcount < 4*bar_width &&
							bar_height <= vcount && vcount < bar_height+bar_height_mini && wren == 0)
					begin
						data_write = gray;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar12_low;
					end
					else
						state = bar13;
					end
			bar12_low: begin
					wren = 0;
					state = bar12;
					end
			bar13: begin
				if (4*bar_width <= hcount && hcount < 5*bar_width &&
							bar_height <= vcount && vcount < bar_height+bar_height_mini && wren == 0)
					begin
						data_write = light_blue;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar13_low;
					end
					else
						state = bar14;
					end
			bar13_low: begin
					wren = 0;
					state = bar13;
					end
			bar14: begin
				if (5*bar_width <= hcount && hcount < 6*bar_width &&
							bar_height <= vcount && vcount < bar_height+bar_height_mini && wren == 0)
					begin
						data_write = gray;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar14_low;
					end
				else
					state = bar15;
				end
			bar14_low: begin
					wren = 0;
					state = bar14;
					end
			bar15: begin					
				if (6*bar_width <= hcount && hcount < 7*bar_width &&
							bar_height <= vcount && vcount < bar_height+bar_height_mini && wren == 0)
					begin
						data_write = light_gray;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar15_low;
					end
					else
						state = bar16;
					end
			bar15_low: begin
						wren = 0;
						state = bar15;
						end
			bar16: begin
					if (7*bar_width <= hcount && hcount < 8*bar_width-1 &&
								bar_height <= vcount && vcount < bar_height+bar_height_mini)
						begin
							data_write = gray;
							addr = addr + 1;
							hcount = hcount + 1;
							wren = 1;
							state = bar16_low;
							end
					else if (hcount == 8*bar_width-1 &&
								bar_height <= vcount && vcount < bar_height+bar_height_mini)
						begin
						addr = addr + 1;
						hcount = hcount + 1;
						vcount = vcount + 1;	//vertical count increments at last px of bar
						wren = 1;
						state = bar16_low;
						end
					else begin
						hcount = 0;
						if (vcount < bar_height+bar_height_mini) begin
							state = bar9;
							end
						else begin
							state = bar17;
							end
						end
					end
			bar16_low: begin
						wren = 0;
						state = bar16;
						end
			//end painting mid bars
			//begin painting lower bars
			bar17: begin
				if (0 <= hcount && hcount < bar_width &&
					 bar_height + bar_height_mini <= vcount && vcount < 2*bar_height && wren == 0) 
					begin
						data_write = dark_blue;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar17_low;
					end
					else
						state = bar18;
					end
			bar17_low: begin
						wren = 0;
						state = bar17;
						end
			bar18: begin
				if (bar_width <= hcount && hcount < 2*bar_width &&
							bar_height + bar_height_mini <= vcount && vcount < 2*bar_height && wren == 0) 
					begin
						data_write = white;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar18_low;
					end
					else
						state = bar19;
					end
			bar18_low: begin
					wren = 0;
					state = bar18;
					end
			bar19: begin
				if (2*bar_width <= hcount && hcount < 3*bar_width &&
							bar_height + bar_height_mini <= vcount && vcount < 2*bar_height && wren == 0) 
					begin
						data_write = dark_purple;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar19_low;
					end
					else
						state = bar20;
					end
			bar19_low: begin
						wren = 0;
						state = bar19;
						end
			bar20: begin
				if (3*bar_width <= hcount && hcount < 4*bar_width &&
							bar_height + bar_height_mini <= vcount && vcount < 2*bar_height && wren == 0) 
					begin
						data_write = gray;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar20_low;
					end
					else
						state = bar21;
					end
			bar20_low: begin
						wren = 0;
						state = bar20;
						end
			//the next four bars are extra skinny
			//midgray1 - gray - midgray2 - gray	
			bar21: begin	
				if (4*bar_width <= hcount && hcount < 4*bar_width + bar_width_mini &&
							bar_height + bar_height_mini <= vcount && vcount < 2*bar_height && wren == 0) 
					begin
						data_write = mid_gray1;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar21_low;
					end
					else
						state = bar22;
					end
			bar21_low: begin
						wren = 0;
						state = bar21;
						end
			bar22: begin
				if (4*bar_width + bar_width_mini <= hcount && hcount < 4*bar_width + 2*bar_width_mini &&
							bar_height + bar_height_mini <= vcount && vcount < 2*bar_height && wren == 0) 
					begin
						data_write = gray;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar22_low;
					end
					else 
						state = bar23;
					end
			bar22_low: begin
							wren = 0;
							state = bar22;
							end
			bar23: begin
				if (4*bar_width + 2*bar_width_mini <= hcount && hcount < 4*bar_width + 3*bar_width_mini &&
							bar_height + bar_height_mini <= vcount && vcount < 2*bar_height) 
					begin
						data_write = mid_gray2;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar23_low;
					end
				else
					state = bar24;
				end
			bar23_low: begin
						wren = 0;
						state = bar23;
						end
			bar24: begin
				if (4*bar_width + 3*bar_width_mini <= hcount && hcount < 5*bar_width &&
							bar_height+bar_height_mini <= vcount && vcount < 2*bar_height) 
					begin
						data_write = mid_gray1;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar24_low;
					end
					else
						state = bar25;
					end
			bar24_low: begin
						wren = 0;
						state = bar24;
						end
			bar25: begin
				if (5*bar_width <= hcount && hcount < 6*bar_width &&
							bar_height+bar_height_mini <= vcount && vcount < 2*bar_height)
					begin
						data_write = gray;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar25_low;
					end
					else
						state = bar26;
					end
			bar25_low: begin
						wren = 0;
						state = bar25;
						end
			bar26: begin
				if (6*bar_width <= hcount && hcount < 7*bar_width &&
							bar_height+bar_height_mini <= vcount && vcount < 2*bar_height)
					begin
						data_write = light_gray;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar26_low;
					end
					else
						state = bar27;
					end
			bar26_low: begin
							wren = 0;
							state = bar26;
							end
			bar27: begin
				if (7*bar_width <= hcount && hcount < 8*bar_width-1 &&
							bar_height+bar_height_mini <= vcount && vcount < 2*bar_height)
					begin
						data_write = gray;
						addr = addr + 1;
						hcount = hcount + 1;
						wren = 1;
						state = bar27_low;
					end
				else if (hcount == 8*bar_width-1 &&
							bar_height+bar_height_mini <= vcount && vcount < 2*bar_height)
					begin
					addr = addr + 1;
					hcount = hcount + 1;
					vcount = vcount + 1;	//vertical count increments at last px of bar
					wren = 1;
					state = bar27_low;
					end
				else begin
						hcount = 0;
						if (vcount < 2*bar_height) begin
							state = bar17;
							end
						else begin
							state = done_state;
							end
						end
				end
			bar27_low: begin
						wren = 0;
						state = bar27;
						end
			done_state: begin
					data_write = 24'hz;
					done = 1;
					end
			endcase
		end //else
	end	//end always
endmodule
