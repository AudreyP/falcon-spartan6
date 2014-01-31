// RS-232 TX module
// (c) fpga4fun.com KNJN LLC - 2003, 2004, 2005, 2006

//`define DEBUG   // in DEBUG mode, we output one bit per clock cycle (useful for faster simulations)

module async_transmit(clk, TxD_start, TxD_data, TxD, TxD_busy, state);
input clk, TxD_start;
input [7:0] TxD_data;
output TxD, TxD_busy;
output [4:0] state;
//parameter ClkFrequency = 25000000;	// 25MHz
//parameter ClkFrequency = 50000000;	// 50MHz
parameter ClkFrequency = 66666666;	// 66MHz
//parameter ClkFrequency = 70000000;	// 70MHz
parameter Baud = 115200;
parameter RegisterInputData = 1;	// in RegisterInputData mode, the input doesn't have to stay valid while the character is been transmitted

// Baud generator
parameter BaudGeneratorAccWidth = 16;
reg [BaudGeneratorAccWidth:0] BaudGeneratorAcc;
`ifdef DEBUG
wire [BaudGeneratorAccWidth:0] BaudGeneratorInc = 17'h10000;
`else
wire [BaudGeneratorAccWidth:0] BaudGeneratorInc = ((Baud<<(BaudGeneratorAccWidth-4))+(ClkFrequency>>5))/(ClkFrequency>>4);
`endif

wire BaudTick = BaudGeneratorAcc[BaudGeneratorAccWidth];
wire TxD_busy;
always @(posedge clk) if(TxD_busy) BaudGeneratorAcc <= BaudGeneratorAcc[BaudGeneratorAccWidth-1:0] + BaudGeneratorInc;

// Transmitter state machine
reg [4:0] state;
wire TxD_ready = (state==0);
assign TxD_busy = ~TxD_ready;

reg [7:0] TxD_dataReg;
always @(posedge clk) if(TxD_ready & TxD_start) TxD_dataReg <= TxD_data;
wire [7:0] TxD_dataD = RegisterInputData ? TxD_dataReg : TxD_data;

always @(posedge clk) begin
	if (TxD_start == 0) state <= 5'b00000;

	case(state)
		5'b00000: if(TxD_start) state <= 5'b00001;
		5'b00001: if(BaudTick) state <= 5'b00100;
		5'b00100: if(BaudTick) state <= 5'b01000;  // start
		5'b01000: if(BaudTick) state <= 5'b01001;  // bit 0
		5'b01001: if(BaudTick) state <= 5'b01010;  // bit 1
		5'b01010: if(BaudTick) state <= 5'b01011;  // bit 2
		5'b01011: if(BaudTick) state <= 5'b01100;  // bit 3
		5'b01100: if(BaudTick) state <= 5'b01101;  // bit 4
		5'b01101: if(BaudTick) state <= 5'b01110;  // bit 5
		5'b01110: if(BaudTick) state <= 5'b01111;  // bit 6
		5'b01111: if(BaudTick) state <= 5'b00010;  // bit 7
		5'b00010: if(BaudTick) state <= 5'b00011;  // stop1
		//4'b0011: if(BaudTick) state <= 4'b0000;  // stop2
		5'b00011: if(BaudTick) state <= 5'b10000;  // stop2
		//default: if(BaudTick) state <= 4'b0000;
	endcase
end

// Output mux
reg muxbit;
always @( * )
case(state[2:0])
	3'd0: muxbit <= TxD_dataD[0];
	3'd1: muxbit <= TxD_dataD[1];
	3'd2: muxbit <= TxD_dataD[2];
	3'd3: muxbit <= TxD_dataD[3];
	3'd4: muxbit <= TxD_dataD[4];
	3'd5: muxbit <= TxD_dataD[5];
	3'd6: muxbit <= TxD_dataD[6];
	3'd7: muxbit <= TxD_dataD[7];
endcase

// Put together the start, data and stop bits
reg TxD;
always @(posedge clk) TxD <= (state<4) | (state[3] & muxbit) | state[4];  // register the output to make it glitch free

endmodule