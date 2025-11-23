// ============================================================================
//        __
//   \\__/ o\    (C) 2019-2025  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpFDP64L5.sv
//		- floating point fused multiplier + adder
//		- can issue every clock cycle
//		- latency of five
//		- IEEE 754 representation
//
//
// BSD 3-Clause License
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// 4050 LUTs / 1530 FFs / 24 DSPs                                                                          
// ============================================================================

import fp64Pkg::*;

module fpFDP64L5 (clk, ce, op, rm, a, b, c, d, o, under, over, inf, zero);
input clk;
input ce;
input op;		// operation 0 = add, 1 = subtract
input [2:0] rm;
input  FP64 a, b, c, d;
output FP64X o;
output under;
output over;
output inf;
output zero;

// constants
wire [fp64Pkg::EMSB:0] infXp = {fp64Pkg::EMSB+1{1'b1}};	// infinite / NaN - all ones
// The following is the value for an exponent of zero, with the offset
// eg. 8'h7f for eight bit exponent, 11'h7ff for eleven bit exponent, etc.
wire [fp64Pkg::EMSB:0] bias = {1'b0,{fp64Pkg::EMSB{1'b1}}};	//2^0 exponent
// The following is a template for a quiet nan. (MSB=1)
wire [fp64Pkg::FMSB:0] qNaN  = {1'b1,{fp64Pkg::FMSB{1'b0}}};

// -----------------------------------------------------------
// Clock #1
// - decode the input operands
// - derive basic information
// - the path from the inputs through the multiplier takes
//   the most time and was slowing the fmax down below 50 MHz
//   so, some regs are added here.
// -----------------------------------------------------------

wire sa1, sb1, sc1, sd1;			// sign bit
wire [fp64Pkg::EMSB:0] xa1, xb1, xc1, xd1;	// exponent bits
wire [fp64Pkg::FMSB+1:0] fracta1, fractb1, fractc1, fractd1;	// includes unhidden bit
wire a_dn1, b_dn1, c_dn1, dn_dn1;			// a/b is denormalized
wire aNan1, bNan1, cNan1, dNan1;
wire az1, bz1, cz1, dz1;
wire aInf1, bInf1, cInf1, dInf1;
reg op1;

fpDecomp64Reg u1a (.clk(clk), .ce(ce), .i(a), .sgn(sa1), .exp(xa1), .fract(fracta1), .xz(a_dn1), .vz(az1), .inf(aInf1), .nan(aNan1) );
fpDecomp64Reg u1b (.clk(clk), .ce(ce), .i(b), .sgn(sb1), .exp(xb1), .fract(fractb1), .xz(b_dn1), .vz(bz1), .inf(bInf1), .nan(bNan1) );
fpDecomp64Reg u1c (.clk(clk), .ce(ce), .i(c), .sgn(sc1), .exp(xc1), .fract(fractc1), .xz(c_dn1), .vz(cz1), .inf(cInf1), .nan(cNan1) );
fpDecomp64Reg u1d (.clk(clk), .ce(ce), .i(d), .sgn(sd1), .exp(xd1), .fract(fractd1), .xz(d_dn1), .vz(dz1), .inf(dInf1), .nan(dNan1) );

always_ff @(posedge clk)
	if (ce) op1 <= op;

// -----------------------------------------------------------
// Clock #2
// Compute the sum of the exponents.
// correct the exponent for denormalized operands
// adjust the sum by the exponent offset (subtract 127)
// mul: ex1 = xa + xb,	result should always be < 1ffh
// Form partial products (clocks 2 to 5)
// -----------------------------------------------------------

reg abz2,cdz2;
reg [fp64Pkg::EMSB+2:0] exab2, excd2;
reg realOp2;
reg [fp64Pkg::FX:0] fractab2, fractcd2;

always_comb
	abz2 <= az1|bz1;
always_comb
	cdz2 <= cz1|dz1;
always_comb
	exab2 <= (xa1|(a_dn1&~az1)) + (xb1|(b_dn1&~bz1)) - bias;
always_comb
	excd2 <= (xc1|(c_dn1&~cz1)) + (xd1|(d_dn1&~dz1)) - bias;

// Figure out which operation is really needed an add or
// subtract ?
// If the signs are the same, use the orignal op,
// otherwise flip the operation
//  a +  b = add,+
//  a + -b = sub, so of larger
// -a +  b = sub, so of larger
// -a + -b = add,-
//  a -  b = sub, so of larger
//  a - -b = add,+
// -a -  b = add,-
// -a - -b = sub, so of larger
always_comb
	realOp2 <= op1 ^ (sa1 ^ sb1) ^ (sc1 ^ sd1);

reg [127:0] fractoo_ab, fractoo_cd;
mult64x64combo umul1 (
	.a({14'd0,fracta1[fp64Pkg::FMSB+1:0]}),
	.b({14'd0,fractb1[fp64Pkg::FMSB+1:0]}),
	.o(fractoo_ab)
);
mult64x64combo umul2 (
	.a({14'd0,fractc1[fp64Pkg::FMSB+1:0]}),
	.b({14'd0,fractd1[fp64Pkg::FMSB+1:0]}),
	.o(fractoo_cd)
);

always_comb
  fractab2 <= fractoo_ab[fp64Pkg::FX:0];
always_comb
  fractcd2 <= fractoo_cd[fp64Pkg::FX:0];

// -----------------------------------------------------------
// Clock #3
// Select zero exponent
// -----------------------------------------------------------

reg [fp64Pkg::EMSB+2:0] exab3, excd3;
always_comb
	exab3 <= abz2 ? 1'd0 : exab2;
always_comb
	excd3 <= cdz2 ? 1'd0 : excd2;

// -----------------------------------------------------------
// Clock #4
// Generate partial products.
// -----------------------------------------------------------

reg [fp64Pkg::EMSB+2:0] exab4,excd4;

always_comb
	exab4 <= exab3;
always_comb
	excd4 <= excd3;

// -----------------------------------------------------------
// Clock #5
// Sum partial products (above)
// compute multiplier overflow and underflow
// -----------------------------------------------------------

// Status
reg underab5,undercd5;
reg overab5,overcd5;
reg [fp64Pkg::EMSB+2:0] exab5,excd5;
reg aInf5, bInf5, cInf5, dInf5;
reg aNan5, bNan5, cNan5, dNan5;
reg qNaNOutab5, qNaNOutcd5;
reg [fp64Pkg::FX:0] fractab5, fractcd5;
reg az5, bz5, cz5, dz5, realOp5;
reg xcInf5;
reg [2:0] rm5;
reg op5;
reg sa5, sb5, sc5, sd5;

always_ff @(posedge clk)
	if (ce) rm5 <= rm;
always_ff @(posedge clk)
	if (ce) sa5 <= sa1;
always_ff @(posedge clk)
	if (ce) sb5 <= sb1;
always_ff @(posedge clk)
	if (ce) sc5 <= sc1;
always_ff @(posedge clk)
	if (ce) sd5 <= sd1;
always_ff @(posedge clk)
	if (ce) op5 <= op1;

always_ff @(posedge clk)
	if (ce) underab5 <= exab4[fp64Pkg::EMSB+2];
always_ff @(posedge clk)
	if (ce) undercd5 <= excd4[fp64Pkg::EMSB+2];
always_ff @(posedge clk)
	if (ce) overab5 <= (&exab4[fp64Pkg::EMSB:0] | exab4[fp64Pkg::EMSB+1]) & !exab4[fp64Pkg::EMSB+2];
always_ff @(posedge clk)
	if (ce) overcd5 <= (&excd4[fp64Pkg::EMSB:0] | excd4[fp64Pkg::EMSB+1]) & !excd4[fp64Pkg::EMSB+2];
always_ff @(posedge clk)
	if (ce) exab5 <= exab4;
always_ff @(posedge clk)
	if (ce) excd5 <= excd4;
always_ff @(posedge clk)
	if (ce) aInf5 <= aInf1;
always_ff @(posedge clk)
	if (ce) bInf5 <= bInf1;
always_ff @(posedge clk)
	if (ce) cInf5 <= cInf1;
always_ff @(posedge clk)
	if (ce) dInf5 <= dInf1;

// determine when a NaN is output
reg [fp64Pkg::MSB:0] a5,b5,c5,d5;
always_ff @(posedge clk)
	if (ce) qNaNOutab5 <= (aInf1&bz1)|(bInf1&az1);
always_ff @(posedge clk)
	if (ce) qNaNOutcd5 <= (cInf1&dz1)|(dInf1&cz1);
always_ff @(posedge clk)
	if (ce) aNan5 <= aNan1;
always_ff @(posedge clk)
	if (ce) bNan5 <= bNan1;
always_ff @(posedge clk)
	if (ce) cNan5 <= cNan1;
always_ff @(posedge clk)
	if (ce) dNan5 <= dNan1;
always_ff @(posedge clk)
	if (ce) a5 <= a;
always_ff @(posedge clk)
	if (ce) b5 <= b;
always_ff @(posedge clk)
	if (ce) c5 <= c;
always_ff @(posedge clk)
	if (ce) d5 <= d;
always_ff @(posedge clk)
	if (ce) fractab5 <= fractab2;
always_ff @(posedge clk)
	if (ce) fractcd5 <= fractcd2;

always_ff @(posedge clk)
	if (ce) az5 <= az1;
always_ff @(posedge clk)
	if (ce) bz5 <= bz1;
always_ff @(posedge clk)
	if (ce) cz5 <= cz1;
always_ff @(posedge clk)
	if (ce) dz5 <= dz1;
always_ff @(posedge clk)
	if (ce) realOp5 <= realOp2;

// -----------------------------------------------------------
// Clock #6
// - figure multiplier mantissa output
// - figure multiplier exponent output
// - correct xponent and mantissa for exceptional conditions
// -----------------------------------------------------------

reg [fp64Pkg::FX:0] moab6,mocd6;
reg [fp64Pkg::EMSB+2:0] exab6,excd6;
reg underab6,undercd6;

always_comb
	underab6 <= underab5;
always_comb
	undercd6 <= undercd5;

always_comb
	casez({aNan5,bNan5,qNaNOutab5,aInf5,bInf5,overab5})
	6'b1?????:  moab6 <= {1'b1,1'b1,a5[fp64Pkg::FMSB-1:0],{fp64Pkg::FMSB+1{1'b0}}};
  6'b01????:  moab6 <= {1'b1,1'b1,b5[fp64Pkg::FMSB-1:0],{fp64Pkg::FMSB+1{1'b0}}};
	6'b001???:	moab6 <= {1'b1,qNaN|3'd4,{fp64Pkg::FMSB+1{1'b0}}};	// multiply inf * zero
	6'b0001??:	moab6 <= 0;	// mul inf's
	6'b00001?:	moab6 <= 0;	// mul inf's
	6'b000001:	moab6 <= 0;	// mul overflow
	default:	moab6 <= fractab5;
	endcase

always_comb
	casez({cNan5,dNan5,qNaNOutcd5,cInf5,dInf5,overcd5})
	6'b1?????:  mocd6 <= {1'b1,1'b1,a5[fp64Pkg::FMSB-1:0],{fp64Pkg::FMSB+1{1'b0}}};
  6'b01????:  mocd6 <= {1'b1,1'b1,b5[fp64Pkg::FMSB-1:0],{fp64Pkg::FMSB+1{1'b0}}};
	6'b001???:	mocd6 <= {1'b1,qNaN|3'd4,{fp64Pkg::FMSB+1{1'b0}}};	// multiply inf * zero
	6'b0001??:	mocd6 <= 0;	// mul inf's
	6'b00001?:	mocd6 <= 0;	// mul inf's
	6'b000001:	mocd6 <= 0;	// mul overflow
	default:	mocd6 <= fractcd5;
	endcase

always_comb
	casez({qNaNOutab5|aNan5|bNan5,aInf5,bInf5,overab5,underab5})
	5'b1????:	exab6 <= infXp;	// qNaN - infinity * zero
	5'b01???:	exab6 <= infXp;	// 'a' infinite
	5'b001??:	exab6 <= infXp;	// 'b' infinite
	5'b0001?:	exab6 <= infXp;	// result overflow
	5'b00001:	exab6 <= exab5;		//0;		// underflow
	default:	exab6 <= exab5;		// situation normal
	endcase

always_comb
	casez({qNaNOutcd5|cNan5|dNan5,cInf5,dInf5,overcd5,undercd5})
	5'b1????:	excd6 <= infXp;	// qNaN - infinity * zero
	5'b01???:	excd6 <= infXp;	// 'a' infinite
	5'b001??:	excd6 <= infXp;	// 'b' infinite
	5'b0001?:	excd6 <= infXp;	// result overflow
	5'b00001:	excd6 <= excd5;		//0;		// underflow
	default:	excd6 <= excd5;		// situation normal
	endcase

// -----------------------------------------------------------
// Clock #7
// - prep for addition, determine greater operand
// -----------------------------------------------------------
reg exab_gt_excd7;
reg xeq7;
reg mab_gt_mcd7;
reg meq7;
reg az7, bz7, cz7, dz7;
reg realOp7;
reg abInf7,cdInf7;

// which has greater magnitude ? Used for sign calc
always_comb
	exab_gt_excd7 <= $signed(exab6) > $signed(excd6);
always_comb
	xeq7 <= exab6==excd6;
always_comb
	mab_gt_mcd7 <= moab6 > mocd6;
always_comb
	meq7 <= moab6 == mocd6;
always_comb
	az7 <= az5;
always_comb
	bz7 <= bz5;
always_comb
	cz7 <= cz5;
always_comb
	dz7 <= dz5;
always_comb
	realOp7 <= realOp5;
always_comb
	abInf7 <= &exab6;
always_comb
	cdInf7 <= &excd6;
	
// -----------------------------------------------------------
// Clock #8
// - prep for addition, determine greater operand
// - determine if result will be zero
// -----------------------------------------------------------

reg a_gt_b8;
reg resZero8;
reg exab_gt_excd8;
reg [fp64Pkg::EMSB+2:0] exab8, excd8;
reg [2:0] rm8;
reg op8;
reg sab8, scd8;

always_comb
	exab8 <= exab6;
always_comb
	excd8 <= excd6;
always_comb
	rm8 <= rm5;
always_comb
	op8 <= op5;
always_comb
	sab8 <= sa5 ^ sb5;
always_comb
	scd8 <= sc5 ^ sd5;

always_comb
	exab_gt_excd8 <= exab_gt_excd7;
always_comb
	a_gt_b8 <= exab_gt_excd7 || (xeq7 && mab_gt_mcd7);

// Find out if the result will be zero.
always_comb
	resZero8 <= (realOp7 & xeq7 & meq7) ||	// subtract, same magnitude
			   ((az7 | bz7) & (cz7 | dz7));		// a or b zero and c or d zero

// -----------------------------------------------------------
// CLock #9
// Compute output exponent and sign
//
// The output exponent is the larger of the two exponents,
// unless a subtract operation is in progress and the two
// numbers are equal, in which case the exponent should be
// zero.
// -----------------------------------------------------------

reg so9;
reg [fp64Pkg::EMSB+2:0] exab9,excd9,ex9;
reg [fp64Pkg::EMSB+2:0] exab9a,excd9a;
reg exab_gt_excd9;
reg a_gt_b9;
reg [fp64Pkg::FX:0] moab9,mocd9;
reg underab9,undercd9;
reg xeq9;
reg realOp9;
reg Nanab9,Nancd9;
reg abInf9,cdInf9;
reg op9;
reg resZero9;

always_ff @(posedge clk)
	if (ce) op9 <= op5;
always_ff @(posedge clk)
	if (ce) abInf9 <= abInf7;
always_ff @(posedge clk)
	if (ce) cdInf9 <= cdInf7;
always_ff @(posedge clk)
	if (ce) Nanab9 <= qNaNOutab5|aNan5|bNan5;
always_ff @(posedge clk)
	if (ce) Nancd9 <= qNaNOutcd5|cNan5|dNan5;
always_ff @(posedge clk)
	if (ce) realOp9 <= realOp7;
always_ff @(posedge clk)
	if (ce) exab_gt_excd9 <= exab_gt_excd8;
always_ff @(posedge clk)
	if (ce) a_gt_b9 <= a_gt_b8;
always_ff @(posedge clk)
	if (ce) excd9 <= excd8;
always_ff @(posedge clk)
	if (ce) exab9a <= exab8;
always_ff @(posedge clk)
	if (ce) excd9a <= excd8;
always_ff @(posedge clk)
	if (ce) moab9 <= moab6;
always_ff @(posedge clk)
	if (ce) mocd9 <= mocd6;
always_ff @(posedge clk)
	if (ce) underab9 <= underab6;
always_ff @(posedge clk)
	if (ce) undercd9 <= undercd6;
always_ff @(posedge clk)
	if (ce) xeq9 <= xeq7;
always_ff @(posedge clk)
	if (ce) resZero9 <= resZero8;
always_ff @(posedge clk)
	if (ce) ex9 <= resZero8 ? 1'd0 : exab_gt_excd8 ? exab8 : excd8;

// Compute output sign
always_ff @(posedge clk)
	if (ce)
		case ({resZero8,sab8,op8,scd8})	// synopsys full_case parallel_case
		4'b0000: so9 <= 0;			// + + + = +
		4'b0001: so9 <= !a_gt_b8;	// + + - = sign of larger
		4'b0010: so9 <= !a_gt_b8;	// + - + = sign of larger
		4'b0011: so9 <= 0;			// + - - = +
		4'b0100: so9 <= a_gt_b8;		// - + + = sign of larger
		4'b0101: so9 <= 1;			// - + - = -
		4'b0110: so9 <= 1;			// - - + = -
		4'b0111: so9 <= a_gt_b8;		// - - - = sign of larger
		4'b1000: so9 <= 0;			//  A +  B, sign = +
		4'b1001: so9 <= rm8==3;		//  A + -B, sign = + unless rounding down
		4'b1010: so9 <= rm8==3;		//  A -  B, sign = + unless rounding down
		4'b1011: so9 <= 0;			// +A - -B, sign = +
		4'b1100: so9 <= rm8==3;		// -A +  B, sign = + unless rounding down
		4'b1101: so9 <= 1;			// -A + -B, sign = -
		4'b1110: so9 <= 1;			// -A - +B, sign = -
		4'b1111: so9 <= rm8==3;		// -A - -B, sign = + unless rounding down
		endcase

// -----------------------------------------------------------
// Clock #10
// Compute the difference in exponents, provides shift amount
// Note that exab9a will be negative for an underflow condition
// so it's added rather than subtracted from excd9 as -(-num)
// is the same as an add. The underflow is tracked rather than
// using extra bits in the exponent.
// -----------------------------------------------------------
reg [fp64Pkg::EMSB+2:0] xdiff10;
reg [fp64Pkg::FX:0] mfs;
reg ops10;
wire xab_underflow = exab9a[fp64Pkg::EMSB+2];
wire xcd_underflow = excd9a[fp64Pkg::EMSB+2];

// If the multiplier exponent was negative (underflowed) then
// the significand needs to be shifted right even more (until
// the exponent is zero. The total shift would be excd9-0-
// amount underflows which is excd9 + -exab9a.

always_comb
	case({exab_gt_excd9,xab_underflow,xcd_underflow})
	3'b000:	xdiff10 <= excd9a - exab9a;
	3'b010:	xdiff10 <= excd9a + (~exab9a+2'd1);
	// If both exponents underflowed we still want the difference
	3'b011: xdiff10 <= (~excd9a+1'd1) - (~exab9a+2'd1);
	3'b100:	xdiff10 <= exab9a - excd9a;
	3'b101:	xdiff10 <= exab9a + {~excd9a+2'd1};
	// If both exponents underflowed we still want the difference
	3'b111:	xdiff10 <= (~excd9a+1'd1) - {~excd9a+2'd1};
	// ab underflowed and cd did not, but ab is flagged greater than cd; must be an error.
	// cd underflowed and ab did not, but ab is flagged smaller than cd; must be an error.
	3'b001,3'b110:
		begin
			$display("fp64: FDP exponent underflow error");
			$finish;
		end
	endcase

// Determine which fraction to denormalize (the one with the
// smaller exponent is denormalized). If the exponents are equal
// denormalize the smaller fraction.
always_comb
	mfs <= 
		xeq9 ? (a_gt_b9 ? mocd9 : moab9)
		 : exab_gt_excd9 ? mocd9 : moab9;

always_comb
	ops10 <= xeq9 ? (a_gt_b9 ? 1'b1 : 1'b0)
								: (exab_gt_excd9 ? 1'b1 : 1'b0);

// -----------------------------------------------------------
// Clock #11
// Limit the size of the shifter to only bits needed.
// -----------------------------------------------------------
reg [7:0] xdif11;

always_comb
	xdif11 <= xdiff10 > fp64Pkg::FX+3 ? fp64Pkg::FX+3 : xdiff10;

// -----------------------------------------------------------
// Clock #12
// Determine the sticky bit
// -----------------------------------------------------------

wire sticky;
reg sticky12;
reg [fp64Pkg::FX:0] mfs12;
reg [7:0] xdif12;

redorN #(.BSIZE(fp64Pkg::FX+1)) uredor1 (.a({1'b0,xdif11+fp64Pkg::FMSB}), .b(mfs), .o(sticky));
/*
generate
begin
if (FPWID==64)
  redor64 u121 (.a(xdif11), .b({mfs,2'b0}), .o(sticky) );
else if (FPWID==96)
  redor96 u121 (.a(xdif11), .b({mfs,2'b0}), .o(sticky) );
else if (FPWID==84)
  redor84 u121 (.a(xdif11), .b({mfs,2'b0}), .o(sticky) );
else if (FPWID==80)
  redor80 u121 (.a(xdif11), .b({mfs,2'b0}), .o(sticky) );
else if (FPWID==64)
  redor64 u121 (.a(xdif11), .b({mfs,2'b0}), .o(sticky) );
else if (FPWID==32)
  redor32 u121 (.a(xdif11), .b({mfs,2'b0}), .o(sticky) );
else begin
	always @* begin
  	$display("redor operation needed in fpFMA");
  	$finish;
  end
end
end
endgenerate
*/

// register inputs to shifter and shift
always_comb
	sticky12 <= sticky;
always_comb
	xdif12 <= xdif11;
always_comb
	mfs12 <= mfs;

// -----------------------------------------------------------
// Clock #13
// - denormalize operand (shift right)
// -----------------------------------------------------------
reg [fp64Pkg::FX+2:0] mfs13;
reg [fp64Pkg::FX:0] moab13,mocd13;
reg exab_gt_excd13;
reg ops13;
reg a_gt_b13;
reg realOp13;
reg [fp64Pkg::EMSB+2:0] ex13;
reg Nanab13, Nancd13;
reg abInf13,cdInf13;
reg op13;
reg so13;
reg resZero13;
reg xunderflow13;

always_ff @(posedge clk)
	if (ce) so13 <= so9;
always_ff @(posedge clk)
	if (ce) op13 <= op9;
always_ff @(posedge clk)
	if (ce) abInf13 <= abInf9;
always_ff @(posedge clk)
	if (ce) cdInf13 <= cdInf9;
always_ff @(posedge clk)
	if (ce) Nanab13 <= Nanab9;
always_ff @(posedge clk)
	if (ce) Nancd13 <= Nancd9;
always_ff @(posedge clk)
	if (ce) Nancd13 <= Nancd9;
always_ff @(posedge clk)
	if (ce) moab13 <= moab9;
always_ff @(posedge clk)
	if (ce) mocd13 <= mocd9;
always_ff @(posedge clk)
	if (ce) exab_gt_excd13 <= exab_gt_excd9;
always_ff @(posedge clk)
	if (ce) ops13 <= ops10;	

always_ff @(posedge clk)
	if (ce) mfs13 <= ({mfs12,2'b0} >> xdif12)|sticky12;
always_ff @(posedge clk)
	if (ce) a_gt_b13 <= a_gt_b9;
always_ff @(posedge clk)
	if (ce) realOp13 <= realOp9;
always_ff @(posedge clk)
	if (ce) ex13 <= ex9;
always_ff @(posedge clk)
	if (ce) resZero13 <= resZero9;
always_ff @(posedge clk)
	if (ce) xunderflow13 <= xab_underflow&xcd_underflow;

// -----------------------------------------------------------
// Clock #14
// Sort operands
// -----------------------------------------------------------
reg [fp64Pkg::FX+2:0] oa, ob;
reg a_gt_b14;

always_comb
	a_gt_b14 <= a_gt_b13;

always_comb
	oa <= ops13 ? {moab13,2'b00} : mfs13;
always_comb
	ob <= ops13 ? mfs13 : {mocd13,2'b00};

// -----------------------------------------------------------
// Clock #15
// - Sort operands
// -----------------------------------------------------------
reg [fp64Pkg::FX+2:0] oaa, obb;
reg realOp15;
reg [fp64Pkg::EMSB:0] ex15;
wire [fp64Pkg::EMSB:0] ex13c = ex13[fp64Pkg::EMSB+1] ? infXp : ex13[fp64Pkg::EMSB:0];
reg overflow15;
always_comb
	realOp15 <= realOp13;
always_comb
	ex15 <= ex13c;
always_comb
	overflow15 <= (ex13[fp64Pkg::EMSB+1]| &ex13[fp64Pkg::EMSB:0]) & ~ex13[fp64Pkg::EMSB+2];
always_comb
	oaa <= a_gt_b14 ? oa : ob;
always_comb
	obb <= a_gt_b14 ? ob : oa;

// -----------------------------------------------------------
// Clock #16
// - perform add/subtract
// - addition can generate an extra bit, subtract can't go negative
// -----------------------------------------------------------
reg [fp64Pkg::FX+3:0] mab;
reg [fp64Pkg::FX:0] moab16,mocd16;
reg Nanab16,Nancd16;
reg abInf16, cdInf16;
reg op16;
reg exinf16;

always_comb
	Nanab16 <= Nanab13;
always_comb
	Nancd16 <= Nancd13;
always_comb
	abInf16 <= abInf13;
always_comb
	cdInf16 <= cdInf13;
always_comb
	op16 <= op13;
always_comb
	moab16 <= moab13;
always_comb
	mocd16 <= mocd13;
always_comb
	exinf16 <= &ex15;

always_comb
	mab <= realOp15 ? oaa - obb : oaa + obb;

// -----------------------------------------------------------
// Clock #17
// - adjust for Nans
// -----------------------------------------------------------
reg [fp64Pkg::EMSB:0] ex17;
reg [fp64Pkg::FX:0] mo17;
reg so17;
reg exinf17;
reg overflow17;
reg resZero17;
reg xunderflow17;

always_ff @(posedge clk)
	if (ce) resZero17 <= resZero13;
always_ff @(posedge clk)
	if (ce) so17 <= so13;
always_ff @(posedge clk)
	if (ce) ex17 <= ex15;
always_ff @(posedge clk)
	if (ce) exinf17 <= exinf16;
always_ff @(posedge clk)
	if (ce) overflow17 <= overflow15;
always_ff @(posedge clk)
	if (ce) xunderflow17 <= xunderflow13;

always @(posedge clk)
if (ce)
	casez({abInf16&cdInf16,Nanab16,Nancd16,exinf16,resZero13})
	5'b1????:	mo17 <= {1'b0,op16,{fp64Pkg::FMSB-1{1'b0}},op16,{fp64Pkg::FMSB{1'b0}}};	// inf +/- inf - generate QNaN on subtract, inf on add
	5'b01???:	mo17 <= {1'b0,moab16};
	5'b001??:	mo17 <= {1'b0,mocd16};
	5'b0001?:	mo17 <= 1'd0;
	5'b00001:	mo17 <= 1'd0;
	default:	mo17 <= mab[fp64Pkg::FX+3:2];		// mab has two extra lead bits and two trailing bits
	endcase

assign o.sign = so17;
assign o.exp = xunderflow17 ? 1'd0 : ex17;
assign o.sig = mo17;

assign zero = {ex17,mo17}==1'd0;
assign inf = exinf17;
assign under = xunderflow17;//ex17==1'd0 && |mo17;
assign over = overflow17;

endmodule


// Multiplier with normalization and rounding.

module fpFDP64nrL8(clk, ce, op, rm, a, b, c, d, o, inf, zero, overflow, underflow, inexact);
input clk;
input ce;
input op;
input [2:0] rm;
input  FP64 a, b, c, d;
output FP64 o;
output zero;
output inf;
output overflow;
output underflow;
output inexact;

wire FP64X fdp_o;
wire fdp_underflow;
wire fdp_overflow;
wire norm_underflow;
wire norm_inexact;
wire sign_exe1, inf1, overflow1, underflow1;
wire FP64N fpn0;
wire [2:0] rm6;

fpFDP64L5 u1
(
	.clk(clk),
	.ce(ce),
	.op(op),
	.rm(rm),
	.a(a),
	.b(b),
	.c(c),
	.d(d),
	.o(fdp_o),
	.under(fdp_underflow),
	.over(fdp_overflow),
	.zero(),
	.inf()
);
fpNormalize64L2 u2
(
	.clk(clk),
	.ce(ce),
	.i(fdp_o),
	.o(fpn0),
	.under_i(fdp_underflow),
	.under_o(norm_underflow),
	.inexact_o(norm_inexact)
);
delay6 #(3)			u8 (.clk(clk), .ce(ce), .i(rm), .o(rm6));
fpRound64L1 u3(.clk(clk), .ce(ce), .rm(rm6), .i(fpn0), .o(o) );
fpDecomp64 u4(.i(o), .xz(), .vz(zero), .inf(inf));
vtdl #(.WID(1)) u5 (.clk(clk), .ce(ce), .a(4'd3), .d(fdp_underflow), .q(underflow));
vtdl #(.WID(1)) u6 (.clk(clk), .ce(ce), .a(4'd3), .d(fdp_overflow), .q(overflow));
delay1		#(1)	u7 (.clk(clk), .ce(ce), .i(norm_inexact), .o(inexact));
//assign overflow = inf;

endmodule

