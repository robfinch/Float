// ============================================================================
//        __
//   \\__/ o\    (C) 2019-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpFMA128L5.sv
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
// ============================================================================

import fp128Pkg::*;

module fpFMA128L5 (clk, ce, op, rm, a, b, c, o, under, over, inf, zero);
input clk;
input ce;
input op;		// operation 0 = add, 1 = subtract
input [2:0] rm;
input  FP128 a, b, c;
output FP128X o;
output under;
output over;
output inf;
output zero;

// constants
wire [fp128Pkg::EMSB:0] infXp = {fp128Pkg::EMSB+1{1'b1}};	// infinite / NaN - all ones
// The following is the value for an exponent of zero, with the offset
// eg. 8'h7f for eight bit exponent, 11'h7ff for eleven bit exponent, etc.
wire [fp128Pkg::EMSB:0] bias = {1'b0,{fp128Pkg::EMSB{1'b1}}};	//2^0 exponent
// The following is a template for a quiet nan. (MSB=1)
wire [fp128Pkg::FMSB:0] qNaN  = {1'b1,{fp128Pkg::FMSB{1'b0}}};

// -----------------------------------------------------------
// Clock #1
// - decode the input operands
// - derive basic information
// - the path from the inputs through the multiplier takes
//   the most time and was slowing the fmax down below 50 MHz
//   so, some regs are added here.
// -----------------------------------------------------------

wire sa1, sb1, sc1;			// sign bit
wire [fp128Pkg::EMSB:0] xa1, xb1, xc1;	// exponent bits
wire [fp128Pkg::FMSB+1:0] fracta1, fractb1, fractc1;	// includes unhidden bit
wire a_dn1, b_dn1, c_dn1;			// a/b is denormalized
wire aNan1, bNan1, cNan1;
wire az1, bz1, cz1;
wire aInf1, bInf1, cInf1;
reg op1;

fpDecomp128Reg u1a (.i(a), .sgn(sa1), .exp(xa1), .fract(fracta1), .xz(a_dn1), .vz(az1), .inf(aInf1), .nan(aNan1) );
fpDecomp128Reg u1b (.i(b), .sgn(sb1), .exp(xb1), .fract(fractb1), .xz(b_dn1), .vz(bz1), .inf(bInf1), .nan(bNan1) );
fpDecomp128Reg u1c (.i(c), .sgn(sc1), .exp(xc1), .fract(fractc1), .xz(c_dn1), .vz(cz1), .inf(cInf1), .nan(cNan1) );

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

reg abz2;
reg [fp128Pkg::EMSB+2:0] ex2;
reg [fp128Pkg::EMSB:0] xc2;
reg realOp2;
reg xcInf2;
reg [fp128Pkg::FX:0] fract2;

always_comb
	abz2 <= az1|bz1;
always_comb
	ex2 <= (xa1|(a_dn1&~az1)) + (xb1|(b_dn1&~bz1)) - bias;
always_comb
	xc2 <= (xc1|(c_dn1&~cz1));
always_comb
	xcInf2 = &xc1;

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
	realOp2 <= op1 ^ (sa1 ^ sb1) ^ sc1;

reg [255:0] fractoo;
mult128x128combo umul1 (
	.a({14'd0,fracta1[fp128Pkg::FMSB+1:0]}),
	.b({14'd0,fractb1[fp128Pkg::FMSB+1:0]}),
	.o(fractoo)
);

always_comb
  fract2 <= fractoo[fp128Pkg::FX:0];

// -----------------------------------------------------------
// Clock #3
// Select zero exponent
// -----------------------------------------------------------

reg [fp128Pkg::EMSB+2:0] ex3;
reg [fp128Pkg::EMSB:0] xc3;
always_comb
	ex3 <= abz2 ? 1'd0 : ex2;
always_comb
	xc3 <= xc2;

// -----------------------------------------------------------
// Clock #4
// Generate partial products.
// -----------------------------------------------------------

reg [fp128Pkg::EMSB+2:0] ex4;
reg [fp128Pkg::EMSB:0] xc4;

always_comb
	ex4 <= ex3;
always_comb
	xc4 <= xc3;

// -----------------------------------------------------------
// Clock #5
// Sum partial products (above)
// compute multiplier overflow and underflow
// -----------------------------------------------------------

// Status
reg under5;
reg over5;
reg [fp128Pkg::EMSB+2:0] ex5;
reg [fp128Pkg::EMSB:0] xc5;
reg aInf5, bInf5, cInf5;
reg aNan5, bNan5;
reg qNaNOut5;
reg [fp128Pkg::FX:0] fract5;
reg [fp128Pkg::FMSB+1:0] fractc5;	// includes unhidden bit
reg az5, bz5, cz5, realOp5;
reg xcInf5;
reg [2:0] rm5;
reg op5;
reg sa5, sb5, sc5;
reg cNan5;

always_ff @(posedge clk)
	if (ce) cNan5 <= cNan1;
always_ff @(posedge clk)
	if (ce) rm5 <= rm;
always_ff @(posedge clk)
	if (ce) sa5 <= sa1;
always_ff @(posedge clk)
	if (ce) sb5 <= sb1;
always_ff @(posedge clk)
	if (ce) sc5 <= sc1;
always_ff @(posedge clk)
	if (ce) op5 <= op1;

always_ff @(posedge clk)
	if (ce) under5 <= ex4[fp128Pkg::EMSB+2];
always_ff @(posedge clk)
	if (ce) over5 <= (&ex4[fp128Pkg::EMSB:0] | ex4[fp128Pkg::EMSB+1]) & !ex4[fp128Pkg::EMSB+2];
always_ff @(posedge clk)
	if (ce) ex5 <= ex4;
always_ff @(posedge clk)
	if (ce) xc5 <= xc4;
always_ff @(posedge clk)
	if (ce) fract5 <= fract2;
always_ff @(posedge clk)
	if (ce) aInf5 <= aInf1;
always_ff @(posedge clk)
	if (ce) bInf5 <= bInf1;
always_ff @(posedge clk)
	if (ce) cInf5 <= cInf1;

// determine when a NaN is output
reg [fp128Pkg::MSB:0] a5,b5;
always_ff @(posedge clk)
	if (ce) qNaNOut5 <= (aInf1&bz1)|(bInf1&az1);
always_ff @(posedge clk)
	if (ce) aNan5 <= aNan1;
always_ff @(posedge clk)
	if (ce) bNan5 <= bNan1;
always_ff @(posedge clk)
	if (ce) a5 <= a;
always_ff @(posedge clk)
	if (ce) b5 <= b;
always_ff @(posedge clk)
	if (ce) fractc5 <= fractc1;

always_ff @(posedge clk)
	if (ce) az5 <= az1;
always_ff @(posedge clk)
	if (ce) bz5 <= bz1;
always_ff @(posedge clk)
	if (ce) cz5 <= cz1;
always_ff @(posedge clk)
	if (ce) realOp5 <= realOp2;
always_ff @(posedge clk)
	if (ce) xcInf5 <= xcInf2;

// -----------------------------------------------------------
// Clock #6
// - figure multiplier mantissa output
// - figure multiplier exponent output
// - correct xponent and mantissa for exceptional conditions
// -----------------------------------------------------------

reg [fp128Pkg::FX:0] mo6;
reg [fp128Pkg::EMSB+2:0] ex6;
reg [fp128Pkg::EMSB:0] xc6;
reg [fp128Pkg::FMSB+1:0] fractc6;
reg under6;

always_comb
	fractc6 <= fractc5;
always_comb
	under6 <= under5;

always_comb
	xc6 <= xc5;

always_comb
	casez({aNan5,bNan5,qNaNOut5,aInf5,bInf5,over5})
	6'b1?????:  mo6 <= {1'b1,1'b1,a5[fp128Pkg::FMSB-1:0],{fp128Pkg::FMSB+1{1'b0}}};
  6'b01????:  mo6 <= {1'b1,1'b1,b5[fp128Pkg::FMSB-1:0],{fp128Pkg::FMSB+1{1'b0}}};
	6'b001???:	mo6 <= {1'b1,qNaN|3'd4,{FMSB+1{1'b0}}};	// multiply inf * zero
	6'b0001??:	mo6 <= 0;	// mul inf's
	6'b00001?:	mo6 <= 0;	// mul inf's
	6'b000001:	mo6 <= 0;	// mul overflow
	default:	mo6 <= fract5;
	endcase

always_comb
	casez({qNaNOut5|aNan5|bNan5,aInf5,bInf5,over5,under5})
	5'b1????:	ex6 <= infXp;	// qNaN - infinity * zero
	5'b01???:	ex6 <= infXp;	// 'a' infinite
	5'b001??:	ex6 <= infXp;	// 'b' infinite
	5'b0001?:	ex6 <= infXp;	// result overflow
	5'b00001:	ex6 <= ex5;		//0;		// underflow
	default:	ex6 <= ex5;		// situation normal
	endcase

// -----------------------------------------------------------
// Clock #7
// - prep for addition, determine greater operand
// -----------------------------------------------------------
reg ex_gt_xc7;
reg xeq7;
reg ma_gt_mc7;
reg meq7;
reg az7, bz7, cz7;
reg realOp7;
reg aInf7;

// which has greater magnitude ? Used for sign calc
always_comb
	ex_gt_xc7 <= $signed(ex6) > $signed({2'b0,xc6});
always_comb
	xeq7 <= (ex6=={2'b0,xc6});
always_comb
	ma_gt_mc7 <= mo6 > {fractc6,{fp128Pkg::FMSB+1{1'b0}}};
always_comb
	meq7 <= mo6 == {fractc6,{FMSB+1{1'b0}}};
always_comb
	az7 <= az5;
always_comb
	bz7 <= bz5;
always_comb
	cz7 <= cz5;
always_comb
	realOp7 <= realOp5;
always_comb
	aInf7 <= &ex6;
	
// -----------------------------------------------------------
// Clock #8
// - prep for addition, determine greater operand
// - determine if result will be zero
// -----------------------------------------------------------

reg a_gt_b8;
reg resZero8;
reg ex_gt_xc8;
reg [fp128Pkg::EMSB+2:0] ex8;
reg [fp128Pkg::EMSB:0] xc8;
reg xcInf8;
reg [2:0] rm8;
reg op8;
reg sa8, sc8;

always_comb
	ex8 <= ex6;
always_comb
	xc8 <= xc6;
always_comb
	xcInf8 <= xcInf5;
always_comb
	rm8 <= rm5;
always_comb
	op8 <= op5;
always_comb
	sa8 <= sa5 ^ sb5;
always_comb
	sc8 <= sc5;

always_comb
	ex_gt_xc8 <= ex_gt_xc7;
always_comb
	a_gt_b8 <= ex_gt_xc7 || (xeq7 && ma_gt_mc7);

// Find out if the result will be zero.
always_comb
	resZero8 <= (realOp7 & xeq7 & meq7) ||	// subtract, same magnitude
			   ((az7 | bz7) & cz7);		// a or b zero and c zero

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
reg [fp128Pkg::EMSB+2:0] ex9;
reg [fp128Pkg::EMSB+2:0] ex9a;
reg ex_gt_xc9;
reg [fp128Pkg::EMSB:0] xc9;
reg a_gt_b9;
reg [fp128Pkg::FX:0] mo9;
reg [fp128Pkg::FMSB+1:0] fractc9;
reg under9;
reg xeq9;
reg realOp9;
reg Nan9;
reg cNan9;
reg aInf9,cInf9;
reg op9;

always_ff @(posedge clk)
	if (ce) op9 <= op5;
always_ff @(posedge clk)
	if (ce) aInf9 <= aInf7;
always_ff @(posedge clk)
	if (ce) cInf9 <= cInf5;
always_ff @(posedge clk)
	if (ce) cNan9 <= cNan5;
always_ff @(posedge clk)
	if (ce) Nan9 <= qNaNOut5|aNan5|bNan5;
always_ff @(posedge clk)
	if (ce) realOp9 <= realOp7;
always_ff @(posedge clk)
	if (ce) ex_gt_xc9 <= ex_gt_xc8;
always_ff @(posedge clk)
	if (ce) a_gt_b9 <= a_gt_b8;
always_ff @(posedge clk)
	if (ce) xc9 <= xc8;
always_ff @(posedge clk)
	if (ce) ex9a <= ex8;
always_ff @(posedge clk)
	if (ce) mo9 <= mo6;
always_ff @(posedge clk)
	if (ce) fractc9 <= fractc6;
always_ff @(posedge clk)
	if (ce) under9 <= under6;
always_ff @(posedge clk)
	if (ce) xeq9 <= xeq7;

always_ff @(posedge clk)
	if (ce) ex9 <= resZero8 ? 1'd0 : ex_gt_xc8 ? ex8 : {2'b0,xc8};

// Compute output sign
always_ff @(posedge clk)
	if (ce)
		case ({resZero8,sa8,op8,sc8})	// synopsys full_case parallel_case
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
// Note that ex9a will be negative for an underflow condition
// so it's added rather than subtracted from xc9 as -(-num)
// is the same as an add. The underflow is tracked rather than
// using extra bits in the exponent.
// -----------------------------------------------------------
reg [fp128Pkg::EMSB+2:0] xdiff10;
reg [fp128Pkg::FX:0] mfs;
reg ops10;

// If the multiplier exponent was negative (underflowed) then
// the mantissa needs to be shifted right even more (until
// the exponent is zero. The total shift would be xc9-0-
// amount underflows which is xc9 + -ex9a.

always_comb
	xdiff10 <= ex_gt_xc9 ? ex9a - xc9
										: ex9a[fp128Pkg::EMSB+2] ? xc9 + (~ex9a+2'd1)
										: xc9 - ex9a;

// Determine which fraction to denormalize (the one with the
// smaller exponent is denormalized). If the exponents are equal
// denormalize the smaller fraction.
always_comb
	mfs <= 
		xeq9 ? (a_gt_b9 ? {4'b0,fractc9,{fp128Pkg::FMSB+1{1'b0}}} : mo9)
		 : ex_gt_xc9 ? {4'b0,fractc9,{fp128Pkg::FMSB+1{1'b0}}} : mo9;

always_comb
	ops10 <= xeq9 ? (a_gt_b9 ? 1'b1 : 1'b0)
								: (ex_gt_xc9 ? 1'b1 : 1'b0);

// -----------------------------------------------------------
// Clock #11
// Limit the size of the shifter to only bits needed.
// -----------------------------------------------------------
reg [7:0] xdif11;

always_comb
	xdif11 <= xdiff10 > fp128Pkg::FX+3 ? fp128Pkg::FX+3 : xdiff10;

// -----------------------------------------------------------
// Clock #12
// Determine the sticky bit
// -----------------------------------------------------------

wire sticky;
reg sticky12;
reg [fp128Pkg::FX:0] mfs12;
reg [7:0] xdif12;

redorN #(.BSIZE(fp128Pkg::FX+1)) uredor1 (.a({1'b0,xdif11+fp128Pkg::FMSB}), .b(mfs), .o(sticky));
/*
generate
begin
if (FPWID==128)
  redor128 u121 (.a(xdif11), .b({mfs,2'b0}), .o(sticky) );
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
reg [fp128Pkg::FX+2:0] mfs13;
reg [fp128Pkg::FX:0] mo13;
reg ex_gt_xc13;
reg [fp128Pkg::FMSB+1:0] fractc13;
reg ops13;
reg a_gt_b13;
reg realOp13;
reg [fp128Pkg::EMSB+2:0] ex13;
reg Nan13, cNan13;
reg aInf13,cInf13;
reg op13;
reg so13;

always_ff @(posedge clk)
	if (ce) so13 <= so9;
always_ff @(posedge clk)
	if (ce) op13 <= op9;
always_ff @(posedge clk)
	if (ce) aInf13 <= aInf9;
always_ff @(posedge clk)
	if (ce) cInf13 <= cInf9;
always_ff @(posedge clk)
	if (ce) Nan13 <= Nan9;
always_ff @(posedge clk)
	if (ce) cNan13 <= cNan9;
always_ff @(posedge clk)
	if (ce) mo13 <= mo9;
always_ff @(posedge clk)
	if (ce) ex_gt_xc13 <= ex_gt_xc9;
always_ff @(posedge clk)
	if (ce) fractc13 <= fractc9;
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

// -----------------------------------------------------------
// Clock #14
// Sort operands
// -----------------------------------------------------------
reg [fp128Pkg::FX+2:0] oa, ob;
reg a_gt_b14;

always_comb
	a_gt_b14 <= a_gt_b13;

always_comb
	oa <= ops13 ? {mo13,2'b00} : mfs13;
always_comb
	ob <= ops13 ? mfs13 : {fractc13,{fp128Pkg::FMSB+1{1'b0}},2'b00};

// -----------------------------------------------------------
// Clock #15
// - Sort operands
// -----------------------------------------------------------
reg [fp128Pkg::FX+2:0] oaa, obb;
reg realOp15;
reg [fp128Pkg::EMSB:0] ex15;
wire [fp128Pkg::EMSB:0] ex13c = ex13[fp128Pkg::EMSB+1] ? infXp : ex13[fp128Pkg::EMSB:0];
reg overflow15;
always_comb
	realOp15 <= realOp13;
always_comb
	ex15 <= ex13c;
always_comb
	overflow15 <= (ex13[fp128Pkg::EMSB+1]| &ex13[fp128Pkg::EMSB:0]) & ~ex13[fp128Pkg::EMSB+2];
always_comb
	oaa <= a_gt_b14 ? oa : ob;
always_comb
	obb <= a_gt_b14 ? ob : oa;

// -----------------------------------------------------------
// Clock #16
// - perform add/subtract
// - addition can generate an extra bit, subtract can't go negative
// -----------------------------------------------------------
reg [fp128Pkg::FX+3:0] mab;
reg [fp128Pkg::FX:0] mo16;
reg [fp128Pkg::FMSB+1:0] fractc16;
reg Nan16;
reg cNan16;
reg aInf16, cInf16;
reg op16;
reg exinf16;

always_comb
	Nan16 <= Nan13;
always_comb
	cNan16 <= cNan13;
always_comb
	aInf16 <= aInf13;
always_comb
	cInf16 <= cInf13;
always_comb
	op16 <= op13;
always_comb
	mo16 <= mo13;
always_comb
	fractc16 <= fractc13;
always_comb
	exinf16 <= &ex15;

always_comb
	mab <= realOp15 ? oaa - obb : oaa + obb;

// -----------------------------------------------------------
// Clock #17
// - adjust for Nans
// -----------------------------------------------------------
reg [fp128Pkg::EMSB:0] ex17;
reg [fp128Pkg::FX:0] mo17;
reg so17;
reg exinf17;
reg overflow17;
always_ff @(posedge clk)
	if (ce) so17 <= so13;
always_ff @(posedge clk)
	if (ce) ex17 <= ex15;
always_ff @(posedge clk)
	if (ce) exinf17 <= exinf16;
always_ff @(posedge clk)
	if (ce) overflow17 <= overflow15;

always @(posedge clk)
if (ce)
	casez({aInf16&cInf16,Nan16,cNan16,exinf16})
	4'b1???:	mo17 <= {1'b0,op16,{fp128Pkg::FMSB-1{1'b0}},op16,{fp128Pkg::FMSB{1'b0}}};	// inf +/- inf - generate QNaN on subtract, inf on add
	4'b01??:	mo17 <= {1'b0,mo16};
	4'b001?: 	mo17 <= {1'b1,1'b1,fractc16[fp128Pkg::FMSB-1:0],{fp128Pkg::FMSB+1{1'b0}}};
	4'b0001:	mo17 <= 1'd0;
	default:	mo17 <= mab[fp128Pkg::FX+3:2];		// mab has two extra lead bits and two trailing bits
	endcase

assign o.sign = so17;
assign o.exp = ex17;
assign o.sig = mo17;

assign zero = {ex17,mo17}==1'd0;
assign inf = exinf17;
assign under = ex17==1'd0;
assign over = overflow17;

endmodule


// Multiplier with normalization and rounding.

module fpFMA128nrL8(clk, ce, op, rm, a, b, c, o, inf, zero, overflow, underflow, inexact);
input clk;
input ce;
input op;
input [2:0] rm;
input  FP128 a, b, c;
output FP128 o;
output zero;
output inf;
output overflow;
output underflow;
output inexact;

wire FP128X fma_o;
wire fma_underflow;
wire fma_overflow;
wire norm_underflow;
wire norm_inexact;
wire sign_exe1, inf1, overflow1, underflow1;
wire FP128N fpn0;
wire [2:0] rm6;

fpFMA128L5 u1
(
	.clk(clk),
	.ce(ce),
	.op(op),
	.rm(rm),
	.a(a),
	.b(b),
	.c(c),
	.o(fma_o),
	.under(fma_underflow),
	.over(fma_overflow),
	.zero(),
	.inf()
);
fpNormalize128L2 u2
(
	.clk(clk),
	.ce(ce),
	.i(fma_o),
	.o(fpn0),
	.under_i(fma_underflow),
	.under_o(norm_underflow),
	.inexact_o(norm_inexact)
);
delay6 #(3)			u8 (.clk(clk), .ce(ce), .i(rm), .o(rm6));
fpRound128L1 u3(.clk(clk), .ce(ce), .rm(rm6), .i(fpn0), .o(o) );
fpDecomp128 u4(.i(o), .xz(), .vz(zero), .inf(inf));
vtdlx1					u5 (.clk(clk), .ce(ce), .a(4'd3), .d(fma_underflow), .q(underflow));
vtdlx1					u6 (.clk(clk), .ce(ce), .a(4'd3), .d(fma_overflow), .q(overflow));
delay1		#(1)	u7 (.clk(clk), .ce(ce), .i(norm_inexact), .o(inexact));
assign overflow = inf;

endmodule

