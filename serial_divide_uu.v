// Non-restoring division module
// From: http://larc.ee.nthu.edu.tw/~hhwu/divider.htm

module serial_divide_uu(dividend, divisor, quotient, remainder, zeroflag);
	parameter size = 16 ; //4bit, 8bit or 16bit
	
	input    [size-1:0]dividend;
	input    [size-1:0]divisor;
	output   [size-1:0]quotient;
	output   [size-1:0]remainder;
	output        zeroflag;
	
	reg    [size:0]p;
	reg    [size-1:0]quotient, div, remainder;
	reg         sign;
	
	integer i;
	
	assign zeroflag = divisor==32'h00000000 ? 1'b1 : 1'b0; //zero detection
	
	always@(dividend or divisor)
	begin
		 quotient = dividend;
		 div = divisor;
		 p = {32'h00000000,1'b0};
		 sign = 1'b0;
	
		 for(i=0;i<size;i=i+1)
		 begin
			  p = {p[size-1:0], quotient[size-1]};
			  quotient = {quotient[size-2:0], 1'b0};    
			  
			  if(sign == 1'b0)
					p = p + {~{1'b0,div} + 1'b1};
			  else
					p = p + {1'b0,div};
			  
	
	
			  case(p[size])
					1'b0: begin
						 quotient[0] = 1'b1;
						 sign = 1'b0;
					end
	  
					1'b1: begin
						 quotient[0] = 1'b0;
						 sign = 1'b1;
					end
			  endcase
		 end
	
	//correction
		 if(p[size] == 1'b0)
			  remainder = p[size-1:0];
		 else
		 begin
			  p = p + {1'b0,div};
			  remainder = p[size-1:0];
		 end
	//end of correction
	
	end
	
	
endmodule
