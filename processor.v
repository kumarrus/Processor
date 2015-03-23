module processor (SW, LEDR, KEY, LEDG, CLOCK_50);
	input [2:0] KEY;
	input [17:0] SW;
	output [17:0] LEDR;
	output [4:0] LEDG;
	input CLOCK_50;

	process myp (CLOCK_50, KEY[0], SW[17], LEDR[17], LEDR[15:0]);
endmodule

module process (Clock, Resetn, Run, Done, led_out);
	input Clock, Resetn, Run;
	output Done;
	output [15:0] led_out;
	wire [15:0] addr, data_out, din;
	wire mem_wr_en, led_en, write;
	
	//upcount #(5) counter (~Resetn, MClock, c_out);
	//rom myRom (addr, MClock, m_out); 
	wram myRam(
		.address(addr),
		.clock(Clock),
		.data(data_out),
		.wren(),
		.q(din)
	);
	
	chipselect cs(addr[15:12], write, mem_wr_en, led_en);
	regn reg_0 (data_out, led_en, Clock, led_out);
	proc p (din, Resetn, Clock, Run, Done, write, data_out, addr);
	
endmodule

module proc (DIN, Resetn, Clock, Run, Done, W, DOUT, ADDR);
    input [15:0] DIN;
    input Resetn, Clock, Run;
    output Done, W;
	 output [15:0] ADDR, DOUT;
    
    //. . . declare variables
	 wire [15:0] BusWires;

    wire [8:0] IR;
    wire [2:0] opcode, RX, RY;
    assign opcode = IR[8:6];
    assign RX = IR[5:3];
    assign RY = IR[2:0];
    
    // Datapath vars
    wire [15:0] R0, R1, R2, R3, R4, R5, R6, R7, G, A;
    wire [15:0] AddSubOut;
    
    // ControlUnit Datapath Control Signals
    reg Done;
    wire [7:0] Rin;
    wire [7:0] Rout;
    reg [2:0] ERin, ERout;
    reg IRin, Enable_in, Enable_out, DINout, Ain, Gin, Gout, ADDRin, DOUTin, AddSub, Clear, W_D, incr_PC; 
    wire [2:0] Tstep_Q;
    wire G_ne_0;

	// ControlUnit State Logic
	parameter [2:0]	T0 = 3'b000, 
							T1 = 3'b001, 
							T2 = 3'b010, 
							T3 = 3'b011,
							T4 = 3'b100;
	parameter [2:0]	mv = 3'b000, 
							mvi = 3'b001, 
							add = 3'b010, 
							sub = 3'b011,
							ld  = 3'b100,
							st  = 3'b101,
							mvnz = 3'b110;
	upcount #(3) Tstep (Clear, Clock, Tstep_Q);
	
	dec3to8 EnableRin(ERin, Enable_in, Rin);
	dec3to8 EnableRout(ERout, Enable_out, Rout);
	
	//. . . instantiate other registers and the adder/subtracter unit
	//. . . define the bus
	regn reg_0 (BusWires, Rin[0], Clock, R0);
	regn reg_1 (BusWires, Rin[1], Clock, R1);
	regn reg_2 (BusWires, Rin[2], Clock, R2);
	regn reg_3 (BusWires, Rin[3], Clock, R3);
	regn reg_4 (BusWires, Rin[4], Clock, R4);
	regn reg_5 (BusWires, Rin[5], Clock, R5);
	regn reg_6 (BusWires, Rin[6], Clock, R6);
	//regn reg_7 (BusWires, Rin[7], Clock, R7);
	
	regn reg_A (BusWires, Ain, Clock, A);
	regn reg_G (AddSubOut, Gin, Clock, G);
	regn #(8) reg_IR (DIN[15:7], IRin, Clock, IR);
	
	regn #(1) reg_W (W_D, 1, Clock, W);
	regn reg_ADDR (BusWires, ADDRin, Clock, ADDR);
	regn reg_DOUT (BusWires, DOUTin, Clock, DOUT);

	alu AddSubALU (AddSub, BusWires, A, AddSubOut);
	megamux Multiplexers ({DINout, Rout[7:0], Gout}, DIN, R7, R6, R5, R4, R3, R2, R1, R0, G, BusWires);
	////////////////////////////////////////////////////////////////
	not_equal_0 G_not_0(G, G_ne_0);
	Program_Counter PC(Resetn, BusWires, incr_PC, Rin[7], Clock, R7);


	/* Curr state Logic */
	always@(*) begin
		// Reset all
		IRin = 0;
		Enable_in = 0;
		Enable_out = 0;
		Done = 0;
		DINout = 0;
		Ain = 0;
		Gin = 0;
		Gout = 0;
		AddSub = 0;
		Clear = 0;
		ERin = 0;
		ERout = 0;
		ADDRin = 0;
		DOUTin = 0;
		W_D = 0;
		
		case(Tstep_Q)
			T0: begin
					IRin = 1;
					if(~Run)		Clear = 1;	
				end
			T1: begin
					case(opcode)
						mv: 	begin
									ERout = RY;
									ERin = RX;
									Enable_in = 1;
									Enable_out = 1;
									Done = 1;
									Clear = 1;
								end
						mvi: 	begin
									DINout = 1;
									ERin = RX;
									Enable_in = 1;
									Done = 1;
									Clear = 1;
								end
						add:	begin
									ERout = RX;
									Enable_out = 1;
									Ain = 1;
								end
						sub: 	begin
									ERout = RX;
									Enable_out = 1;
									Ain = 1;
								end
						ld:	begin
									ERout = RY;
									Enable_out = 1;
									ADDRin = 1;
								end
						st:	begin
									ERout = RX;
									Enable_out = 1;
									DOUTin = 1;
								end
						mvnz:	begin
									if(G_ne_0) begin
										ERout = RY;
										ERin = RX;
										Enable_in = 1;
										Enable_out = 1;
									end
									Done = 1;
									Clear = 1;
								end
						default:	;
					endcase
				end
			T2: 	begin
						case(opcode)
							add: 	begin
										ERout = RY;
										Enable_out = 1;
										Gin = 1;
									end
							sub: 	begin
										ERout = RY;
										Enable_out = 1;
										Gin = 1;
										AddSub = 1;
									end
							st:	begin
										ERout = RY;
										Enable_out = 1;
										ADDRin = 1;
										W_D = 1;
									end
							default: ;
						endcase
					end
			T3: 	begin
						case(opcode)
							add: 	begin
										Gout = 1;
										ERin = RX;
										Enable_in = 1;
									end
							sub: 	begin
										Gout = 1;
										ERin = RX;
										Enable_in = 1;
									end
							ld: 	begin
										DINout = 1;
										ERin = RX;
										Enable_in = 1;
									end
							default: ;
						endcase
						Done = 1;
						Clear = 1;
					end
			default:	;
		endcase
	end

endmodule

module not_equal_0(D, Din_ne_0);
	input [15:0] D;
	output Din_ne_0;

	assign Din_ne_0 = (D != 0);
endmodule

module Program_Counter(Clear, D, incr_PC, R7in, Clock, Q);
	input Clear, Clock, incr_PC, R7in;
	input [15:0] D;
	output reg [15:0] Q;
	
	always @(posedge Clock)
		if (Clear)
			Q <= 0;
		else if(incr_PC)
			Q <= Q + 1'b1;
		else if(R7in)
			Q <= D;
endmodule

module upcount(Clear, Clock, Q);
	parameter n = 3;
	input Clear, Clock;
	output [n-1:0] Q;
	reg [n-1:0] Q;
	
	always @(posedge Clock)
		if (Clear)
			Q <= 0;
		else
			Q <= Q + 1;

endmodule

module dec3to8(W, En, Y);
	input [2:0] W;
	input En;
	output [7:0] Y;
	reg [7:0] Y;

	always @(W or En) begin
		if (En == 1)
			case(W)
				3'b111: Y = 8'b10000000;
				3'b110: Y = 8'b01000000;
				3'b101: Y = 8'b00100000;
				3'b100: Y = 8'b00010000;
				3'b011: Y = 8'b00001000;
				3'b010: Y = 8'b00000100;
				3'b001: Y = 8'b00000010;
				3'b000: Y = 8'b00000001;
			endcase
		else
			Y = 8'b00000000;
	end

endmodule

module regn(R, Rin, Clock, Q);
	parameter n = 16;
	input [n-1:0] R;
	input Rin, Clock;
	output [n-1:0] Q;
	reg [n-1:0] Q;

	always @(posedge Clock)
		if (Rin)
			Q <= R;

endmodule

module megamux(Select, IN1, IN2, IN3, IN4, IN5, IN6, IN7, IN8, IN9, IN10, OUT);
	parameter n = 16;
	input [9:0] Select;
	input [n-1:0] IN1, IN2, IN3, IN4, IN5, IN6, IN7, IN8, IN9, IN10;
	output [n-1:0] OUT;
	
	reg [n-1:0] OUT = 'b0;

	always @(*) begin
		OUT = IN1;
		case (Select)
			10'b0000000001: OUT = IN10;
			10'b0000000010: OUT = IN9;
			10'b0000000100: OUT = IN8;
			10'b0000001000: OUT = IN7;
			10'b0000010000: OUT = IN6;
			10'b0000100000: OUT = IN5;
			10'b0001000000: OUT = IN4;
			10'b0010000000: OUT = IN3;
			10'b0100000000: OUT = IN2;
			10'b1000000000: OUT = IN1;
			default:	;
		endcase
	end

endmodule

module alu(OP, IN1, IN2, OUT);
	parameter n = 16;
	input OP;
	input [n-1:0] IN1, IN2;
	output [n-1:0] OUT;
	reg [n-1:0] OUT;

	always @(*) begin
		case (OP)
			1'b0: OUT = IN1 + IN2;
			1'b1: OUT = IN1 - IN2;
		endcase
	end

endmodule

module chipselect (A, write, mem_wr_en, led_en);
	input [3:0] A;
	input write;
	output mem_wr_en, led_en;
	
	assign mem_wr_en	 = (~(A[3] | A[2] | A[1] | A[0])) & write;
	assign led_en		 = (~(A[3] | A[2] | A[1] | ~A[0])) & write;

endmodule
