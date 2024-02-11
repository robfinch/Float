`timescale 1ns / 1ps
// ============================================================================
//        __
//   \\__/ o\    (C) 2014-2024  Robert Finch, Stratford
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// SeqFPU2c.sv
//  - two complement floating point accelerator
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                              
// 620 LUTs 190 FFs (single precision)                                            
// 1100 LUTs 325 FF's (double precision)
// 1550 LUTs 450 FFs (triple precision)
// 125 MHz
// ============================================================================
//
//`define SIMULATION	1'b1

module SeqFPU2c (rst, clk, ir, i, o, sr);
parameter PREC = "S";
localparam EMSB = 
	PREC=="Q" ? 15 :
	PREC=="T" ? 15 :
	PREC=="DX" ? 15 :
	PREC=="D" ? 10 :
	PREC=="SXX" ? 9 :
	PREC=="SX" ? 9 :
	PREC=="S" ? 8 :
	PREC=="H" ? 4 :
	10;
localparam FMSB =
	PREC=="Q" ? 111 :
	PREC=="T" ? 79 :
	PREC=="DX" ? 63 :
	PREC=="D" ? 52 :
	PREC=="SXX" ? 37 :
	PREC=="SX" ? 29 :
	PREC=="S" ? 23 :
	PREC=="H" ? 9 :
	52;
localparam WID = EMSB+FMSB+2;
localparam BIAS = {1'b0,{EMSB{1'b1}}};
parameter TRUE = 1'b1;
parameter FALSE = 1'b0;
input rst;
input clk;
input [23:0] ir;
input [WID-1:0] i;
output reg [WID-1:0] o;
output reg [7:0] sr;

wire [5:0] op = ir[5:0];
wire [5:0] Rt = ir[11:6];
wire [5:0] Ra = ir[17:12];
wire [5:0] Rb = ir[23:18];
reg busy;
reg isRTAR, isFixedPoint;
reg [1:0] sign;
reg [EMSB:0] acc;
reg [7:0] y;
reg cf,vf;
reg [WID-1:0] FAC1,FAC2,E;
reg [EMSB:0] FAC1_exp;
reg [FMSB:0] FAC1_sig;
reg [EMSB:0] FAC2_exp;
reg [FMSB:0] FAC2_sig;
always_comb FAC1_exp = FAC1[WID-1:FMSB+1];
always_comb FAC1_sig = FAC1[FMSB:0];
always_comb FAC2_exp = FAC2[WID-1:FMSB+1];
always_comb FAC2_sig = FAC2[FMSB:0];
reg addOrSub;
wire [FMSB+1:0] sum = addOrSub ? FAC2_sig - FAC1_sig : FAC2_sig + FAC1_sig;
wire [FMSB+1:0] dif = FAC2_sig - E;
wire [FMSB+1:0] neg = {FMSB+1{1'b0}} - FAC1_sig;
wire [EMSB+1:0] expdif = FAC2_exp - FAC1_exp;
wire [EMSB+1:0] exp_sum = acc + FAC1_exp + {15'd0,cf};	// FMUL
wire [EMSB+1:0] exp_dif = acc - FAC1_exp - {15'd0,~cf};	// FDIV
reg [FMSB:0] rem;
wire eq = FAC1==FAC2;
wire gt = (FAC1[FMSB]^FAC2[FMSB]) ? FAC2[FMSB] : // If the signs are different, whichever one is positive
		   FAC1_exp==FAC2_exp ? (FAC1_sig > FAC2_sig) :	// if exponents are equal check mantissa
		   FAC1_exp > FAC2_exp;	// else compare exponents
wire lt = !(gt|eq);
wire zf = ~|FAC1;

reg [WID-1:0] regfile [0:63];


typedef enum logic [5:0] 
{
	IDLE = 6'd0,
	FABS = 6'd1,
	FNABS = 6'd2,
	FNEG = 6'd3,
	F2I = 6'd4,
	I2F = 6'd5,
	FDIV = 6'd6,
	SWAP = 6'd7,
	FMUL = 6'd8,
	FADD = 6'd9,
	FSUB = 6'd10,
	CVT2SM = 6'd11,
	CVT2C = 6'd12,
	FLOAD = 6'd13,
	WRITEBACK = 6'd44,
	OVCHK = 6'd45,
	MD3 = 6'd46,
	MD2 = 6'd47,
	RTLOG = 6'd48,
	OVFL = 6'd49,
	NORM = 6'd50,
	FDIV1 = 6'd51,
	MD1 = 6'd52,
	ABSSWP = 6'd53,
	ABSSWP1 = 6'd54,
	ADD = 6'd55,
	DIV1 = 6'd56,
	FMUL1 = 6'd57,
	MUL1 = 6'd58,
	FMUL3 = 6'd59,
	MDEND = 6'd60,
	SWPALG = 6'd61,
	ALGNSW = 6'd62,
	ADDEND = 6'd63
} e_state;

e_state [7:0] state_stk;
e_state state;

typedef enum logic [5:0]
{
	CMD_NONE = 6'd0,
	CMD_FABS = 6'd1,
	CMD_FNABS = 6'd2,
	CMD_FNEG = 6'd3,
	CMD_FADD = 6'd4,
	CMD_FSUB = 6'd5,
	CMD_FMUL = 6'd6,
	CMD_FDIV = 6'd7,
	CMD_F2I = 6'd8,
	CMD_I2F = 6'd9,
	CMD_SWAP = 6'd10,
	CMD_CVT2SM = 6'd11,
	CMD_CVT2C = 6'd12,
	CMD_FLOAD = 6'd13
} e_cmd;

e_cmd cmd;

// This is a clock cycle counter used in simulation to determine the number of
// cycles a given operation takes to complete.
reg [11:0] cyccnt;

always_ff @(posedge clk)
if (rst) begin
	isFixedPoint <= FALSE;
	cmd <= CMD_NONE;
	busy <= 1'b0;
	sr <= 8'h00;
	o <= {WID{1'd0}};
	FAC1 <= {WID{1'b0}};
	FAC2 <= {WID{1'b0}};
	tGoto(IDLE);
end
else begin
`ifdef SIMULATION
	cyccnt <= cyccnt + 1;
`endif
	cmd <= CMD_NONE;
	sr <= {busy,2'b0,lt,eq,gt,zf,vf};

case(state)
IDLE:
	begin
`ifdef SIMULATION
		if (cyccnt > 0)
			$display("Cycle Count=%d", cyccnt);
		cyccnt <= 12'h0;
`endif
		isFixedPoint <= FALSE;
		busy <= 1'b0;
		cmd <= e_cmd'(op);
		o <= FAC1;
		case(op)
		CMD_FADD:	begin FAC1 <= regfile[Ra]; FAC2 <= regfile[Rb]; tGosub(FADD,WRITEBACK); busy <= 1'b1; addOrSub <= 1'b0; end
		CMD_FSUB:	begin FAC1 <= regfile[Ra]; FAC2 <= regfile[Rb]; tGosub(FSUB,WRITEBACK); busy <= 1'b1; addOrSub <= 1'b0; end
		CMD_FMUL:	begin FAC1 <= regfile[Ra]; FAC2 <= regfile[Rb]; tGosub(FMUL,WRITEBACK); busy <= 1'b1; addOrSub <= 1'b0; end 
		CMD_FDIV:	begin FAC1 <= regfile[Ra]; FAC2 <= regfile[Rb]; tGosub(FDIV,WRITEBACK); busy <= 1'b1; end
		CMD_FABS:	begin FAC1 <= regfile[Ra]; tGosub(FABS,WRITEBACK); busy <= 1'b1; end
		CMD_FNABS:	begin FAC1 <= regfile[Ra]; tGosub(FNABS,WRITEBACK); busy <= 1'b1; end
		CMD_FNEG: begin FAC1 <= regfile[Ra]; tGosub(FNEG,WRITEBACK); busy <= 1'b1; end
		CMD_F2I:	begin FAC1 <= regfile[Ra]; tGosub(F2I,WRITEBACK); busy <= 1'b1; end
		CMD_I2F:	begin FAC1 <= regfile[Ra]; tGosub(I2F,WRITEBACK); busy <= 1'b1; end
		CMD_SWAP:	begin FAC1 <= regfile[Ra]; FAC2 <= regfile[Rb]; tGosub(SWAP,WRITEBACK); busy <= 1'b1; end
		CMD_CVT2SM:	begin FAC1 <= regfile[Ra]; tGosub(CVT2SM,WRITEBACK); busy <= 1'b1; end
		CMD_CVT2C:	begin FAC1 <= regfile[Ra]; tGosub(CVT2C,WRITEBACK); busy <= 1'b1; end
		CMD_FLOAD: begin FAC1 <= i; busy <= 1'b1; tGoto(WRITEBACK); end
		default:	;
		endcase
	end
WRITEBACK:
	begin
		regfile[Rt] <= FAC1;
		tGoto(IDLE);
	end

//-----------------------------------------------------------------------------
// Convert sign-magnitude to two's complement.
//-----------------------------------------------------------------------------
CVT2C:
	begin
		FAC1[FMSB] <= FAC1[WID-1];
		FAC2[FMSB] <= FAC2[WID-1];
		FAC1[WID-1:FMSB+1] <= FAC1[WID-2:FMSB];
		FAC2[WID-1:FMSB+1] <= FAC2[WID-2:FMSB];
		FAC1[FMSB-1:0] <= FAC1[WID-1] ? -FAC1[FMSB-1:0] : FAC1[FMSB-1:0];
		FAC2[FMSB-1:0] <= FAC2[WID-1] ? -FAC2[FMSB-1:0] : FAC2[FMSB-1:0];
		tReturn();
	end

//-----------------------------------------------------------------------------
// Convert two's complement to sign-magnitude.
//-----------------------------------------------------------------------------
CVT2SM:
	begin
		FAC1[WID-1] <= FAC1[FMSB];
		FAC2[WID-1] <= FAC2[FMSB];
		FAC1[WID-2:FMSB] <= FAC1[WID-1:FMSB+1];
		FAC2[WID-2:FMSB] <= FAC2[WID-1:FMSB+1];
		FAC1[FMSB-1:0] <= FAC1[FMSB] ? -FAC1[FMSB-1:0] : FAC1[FMSB-1:0];
		FAC2[FMSB-1:0] <= FAC2[FMSB] ? -FAC2[FMSB-1:0] : FAC2[FMSB-1:0];
		tReturn();
	end

//-----------------------------------------------------------------------------
// Add mantissa's and compute carry and overflow.
// This is used by both ADD and MUL.
//-----------------------------------------------------------------------------

ADD:
	begin
		FAC1[FMSB:0] <= sum[FMSB:0];
		cf <= sum[FMSB+1];
		vf <= (sum[FMSB] ^ FAC2[FMSB]) & (1'b1 ^ FAC1[FMSB] ^ FAC2[FMSB]);
		tReturn();
	end

//-----------------------------------------------------------------------------
// Absolute value
//-----------------------------------------------------------------------------
FABS:
	if (FAC1[FMSB])
		tGoto(FNEG);
	else
		tReturn();

//-----------------------------------------------------------------------------
// Negative absolute value
//-----------------------------------------------------------------------------
FNABS:
	if (~FAC1[FMSB])
		tGoto(FNEG);
	else
		tReturn();

//-----------------------------------------------------------------------------
// Negate
// Complement FAC1
//-----------------------------------------------------------------------------

FNEG:
	begin
		$display("FNEG");
		FAC1[FMSB:0] <= neg[FMSB:0];
		cf <= ~neg[FMSB+1];
		vf <= neg[FMSB]==FAC1[FMSB];
		if (isFixedPoint)
			tReturn();
		else
			tGoto(ADDEND);
	end

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------

MD1:
	begin
		$display("MD1");
		sign <= {sign[1:0],1'b0};
		tGosub(ABSSWP,ABSSWP);
	end
ABSSWP:
	begin
		if (~FAC1[FMSB])
			tGoto(ABSSWP1);
		else begin
			sign <= sign + 2'd1;
			tGosub(FNEG,ABSSWP1);
		end
	end
ABSSWP1:
	begin
		cf <= 1'b1;
		tGoto(SWAP);
	end

//-----------------------------------------------------------------------------
// Swap FAC1 and FAC2
//-----------------------------------------------------------------------------

SWAP:
	begin
		$display("Swapping FAC1 and FAC2");
		FAC1 <= FAC2;
		FAC2 <= FAC1;
		E <= FAC2[FMSB:0];
		acc <= FAC1_exp;
		tReturn();
	end

//-----------------------------------------------------------------------------
// Subtract
// - subtract first complements the FAC then performs an ADD operation.
//-----------------------------------------------------------------------------

FSUB:	tGosub(FNEG,FADD);
SWPALG:	tGosub(ALGNSW,FADD);

//-----------------------------------------------------------------------------
// Addition
//-----------------------------------------------------------------------------

FADD:
	begin
		cf <= ~expdif[EMSB+1];	// Must set carry flag from compare
		// If the exponents are too different then one of the values will
		// become zero, so the result is just the larger value. This check
		// is to prevent shifting thousands of times.
		if (expdif[EMSB] ? expdif < -FMSB : expdif[EMSB:0] > FMSB) begin
			FAC1 <= expdif[EMSB] ? FAC2 : FAC1;
			tReturn();
		end
		else if (|expdif[EMSB:0] & !isFixedPoint)
			tGoto(SWPALG);
		else begin
			if (!isFixedPoint)
				tGosub(ADD,ADDEND);
			else
				tGoto(ADD);
		end
	end
ADDEND:
	begin
		if (!vf)
			tGoto(NORM);
		else begin
			isRTAR <= FALSE;
			tGoto(RTLOG);
		end
	end
ALGNSW:
	begin
		if (!cf)
			tGoto(SWAP);
		else begin
			isRTAR <= TRUE;
			tGoto(RTLOG);
		end
	end

//-----------------------------------------------------------------------------
// Mulyiply
//-----------------------------------------------------------------------------

FMUL:	tGosub(MD1,FMUL1);
FMUL1:
	begin
		acc <= exp_sum[EMSB:0];
		cf <= exp_sum[EMSB+1];
		tGosub(MD2,MUL1);
	end
MUL1:
	begin
		// inline RTLOG1 code
		FAC1[FMSB:0] <= {1'b0,FAC1[FMSB:1]};
		E[FMSB:0] <= {FAC1[0],E[FMSB-1:1]};
		cf <= E[0];
		tGoto(FMUL3);
	end
FMUL3:
	begin
		if (cf) begin
			FAC1[FMSB:0] <= sum[FMSB:0];
			cf <= sum[FMSB+1];
			vf <= (sum[FMSB] ^ FAC2[FMSB]) & (1'b1 ^ FAC1[FMSB] ^ FAC2[FMSB]);
		end
		y <= y - 8'd1;
		if (y==8'd0)
			tGoto(MDEND);
		else
			tGoto(MUL1);
	end
MDEND:
	begin
		sign <= {1'b0,sign[1]};
		if (~sign[0])
			tGoto(NORM);
		else
			tGoto(FNEG);
	end

//-----------------------------------------------------------------------------
// Divide
//-----------------------------------------------------------------------------
FDIV:	tGosub(MD1,FDIV1);
FDIV1:
	begin
		acc <= exp_dif[EMSB:0];
		cf <= ~exp_dif[EMSB+1];
		$display("acc=%h %h %h", exp_dif, acc, FAC1_exp);
		tGosub(MD2,DIV1);
	end
DIV1:
	begin
		$display("FAC1=%h, FAC2=%h, E=%h", FAC1, FAC2, E);
		y <= y - 8'd1;
		FAC1[FMSB:0] <= {FAC1[FMSB:0],~dif[FMSB+1]};
		if (dif[FMSB+1]) begin
			FAC2[FMSB:0] <= {FAC2[FMSB-1:0],1'b0};
			if (FAC2[FMSB])
				tGoto(OVFL);
			else if (y!=8'd1)
				tGoto(DIV1);
			else begin
				rem <= dif;
				tGoto(MDEND);
			end
		end
		else begin
			FAC2[FMSB:0] <= {dif[FMSB-1:0],1'b0};
			if (dif[FMSB])
				tGoto(OVFL);
			else if (y!=8'd1)
				tGoto(DIV1);
			else begin
				rem <= dif;
				tGoto(MDEND);
			end
		end
	end

//-----------------------------------------------------------------------------
// Normalize
// - Decrement exponent and shift left
// - Normalization is normally the last step of an operation.
// - If possible the FAC is shifted by 16 bits at a time. This helps with
//   the many small constants that are usually present.
//-----------------------------------------------------------------------------
NORM:
	begin
	if (isFixedPoint)	// nothing to do for fixed point
		tReturn();
	else begin
	$display("Normalize FAC1H %h", FAC1[FMSB:FMSB-15]);
	// If the exponent is zero, we cannot shift anymore, the number will be
	// denormal.
	if (~|FAC1_exp) begin
		$display("Normal: %h",FAC1);
		tReturn();
	end
	// If reached the leading bit return.
	else if (FAC1[FMSB]!=FAC1[FMSB-1]) begin
		$display("Normal: %h",FAC1);
		tReturn();
	end
	// If the significand is zero, set the the exponent to zero. Otherwise 
	// normalization could spin for thousands of clock cycles decrementing
	// the exponent to zero. Preserve the sign bit.
	else if (~|FAC1_sig) begin
		FAC1 <= {WID{1'b0}};
		tReturn();
	end
	// If we can shift over by 16 bits, do so.
	else if (FAC1[FMSB:FMSB-15]==16'h0000 && FAC1_exp >= 5'd16) begin
		$display("shift by 16");
		FAC1[WID-2:FMSB+1] <= FAC1[WID-2:FMSB+1] - 5'd16;
		FAC1[FMSB:0] <= {FAC1[FMSB-16:0],16'h0};
		// stay in state
	end
	else begin
		FAC1[WID-2:FMSB+1] <= FAC1[WID-2:FMSB+1] - 2'd1;
		FAC1[FMSB:0] <= {FAC1[FMSB-1:0],1'b0};
		// stay in state
	end
	end
	end

//-----------------------------------------------------------------------------
// Right shift, logical or arithmetic.
//-----------------------------------------------------------------------------

RTLOG:
	begin
		FAC1[WID-1:FMSB] <= FAC1[WID-1:FMSB+1] + 2'd1;
		if (FAC1_exp=={EMSB+1{1'b1}})
			tGoto(OVFL);
		else begin
			FAC1[FMSB:0] <= {isRTAR ? FAC1[FMSB] : cf,FAC1[FMSB:1]};
			E[FMSB:0] <= {FAC1[0],E[FMSB-1:1]};
			cf <= E[0];
			tReturn();
		end
	end

//-----------------------------------------------------------------------------
// I2F
// - convert fixed point number to floating point
//-----------------------------------------------------------------------------
I2F:
	begin
		FAC1[WID-2:FMSB+1] <= BIAS+FMSB;
		tGoto(NORM);
	end


//-----------------------------------------------------------------------------
// F2I
// - convert floating point number to fixed point.
//-----------------------------------------------------------------------------

F2I:
	begin
		// If the exponent is too small then no amount of shifting will
		// result in a non-zero number. In this case we just set the 
		// FAC to zero. Otherwise FLT2FIX would spin for thousands of cycles
		// until the exponent incremented finally to 803Eh.
		if (FAC1_exp < BIAS-FMSB) begin
			FAC1 <= {WID{1'd0}};
			tReturn();
		end
		// If the exponent is too large, we can't right shift and the value
		// would overflow an integer, so we just set it to the max.
		else if (FAC1_exp > BIAS+FMSB) begin
			vf <= 1'b1;
			FAC1 <= {FAC1[WID-1],{WID-1{~FAC1[WID-1]}}};
			tReturn();
		end
		// Sign extend integer value.
		else if (FAC1_exp==BIAS+FMSB) begin
			FAC1[WID-1:FMSB+1] <= {EMSB+1{FAC1[FMSB]}};
			tReturn();
		end
		else begin
			isRTAR <= TRUE;
			tGosub(RTLOG,F2I);
		end
	end

//-----------------------------------------------------------------------------
//-----------------------------------------------------------------------------
MD2:
	begin
		FAC1[FMSB:0] <= {FMSB+1{1'b0}};
		if (isFixedPoint) begin
			y <= FMSB;
			tReturn();
		end
		else if (cf)
			tGoto(OVCHK);
		else if (acc[EMSB])
			tGoto(MD3);
		else
			tReturn();
	end
MD3:
	begin
		acc[EMSB] <= ~acc[EMSB];
		FAC1[EMSB+FMSB+1:FMSB+1] <= {~acc[EMSB],acc[EMSB-1:0]};
		y <= FMSB;
		tReturn();
	end
OVCHK:
	if (~acc[EMSB])
		tGoto(MD3);
	else
		tGoto(OVFL);
OVFL:
	begin
		vf <= 1'b1;
		tGoto(IDLE);
	end
default:
	tReturn();
endcase
end

task tGoto;
input e_state nst;
begin
	state <= nst;
	
end
endtask

task tGosub;
input e_state nst;
input e_state rstate;
begin
	state_stk[0] <= rstate;
	state_stk[1] <= state_stk[0];
	state_stk[2] <= state_stk[1];
	state_stk[3] <= state_stk[2];
	state_stk[4] <= state_stk[3];
	state_stk[5] <= state_stk[4];
	state <= nst;
end
endtask

task tReturn;
begin
	state <= state_stk[0];
	state_stk[0] <= state_stk[1];
	state_stk[1] <= state_stk[2];
	state_stk[2] <= state_stk[3];
	state_stk[3] <= state_stk[4];
	state_stk[4] <= state_stk[5];
	state_stk[5] <= IDLE;
end
endtask

endmodule
