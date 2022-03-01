// ============================================================================
//        __
//   \\__/ o\    (C) 2019-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpFMA32.sv
//		- floating point fused multiplier + adder
//		- can issue every clock cycle
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

import fp32Pkg::*;

module fpFMA32 (clk, ce, op, rm, a, b, c, o, under, over, inf, zero);
input clk;
input ce;
input op;		// operation 0 = add, 1 = subtract
input [2:0] rm;
input  FP32 a, b, c;
output FP32X o;
output under;
output over;
output inf;
output zero;

// constants
wire [fp32Pkg::EMSB:0] infXp = {fp32Pkg::EMSB+1{1'b1}};	// infinite / NaN - all ones
// The following is the value for an exponent of zero, with the offset
// eg. 8'h7f for eight bit exponent, 11'h7ff for eleven bit exponent, etc.
wire [fp32Pkg::EMSB:0] bias = {1'b0,{fp32Pkg::EMSB{1'b1}}};	//2^0 exponent
// The following is a template for a quiet nan. (MSB=1)
wire [fp32Pkg::FMSB:0] qNaN  = {1'b1,{fp32Pkg::FMSB{1'b0}}};

// -----------------------------------------------------------
// Clock #1
// - decode the input operands
// - derive basic information
// -----------------------------------------------------------

wire sa1, sb1, sc1;			// sign bit
wire [fp32Pkg::EMSB:0] xa1, xb1, xc1;	// exponent bits
wire [fp32Pkg::FMSB+1:0] fracta1, fractb1, fractc1;	// includes unhidden bit
wire a_dn1, b_dn1, c_dn1;			// a/b is denormalized
wire aNan1, bNan1, cNan1;
wire az1, bz1, cz1;
wire aInf1, bInf1, cInf1;
reg op1;

fpDecomp32Reg u1a (.clk(clk), .ce(ce), .i(a), .sgn(sa1), .exp(xa1), .fract(fracta1), .xz(a_dn1), .vz(az1), .inf(aInf1), .nan(aNan1) );
fpDecomp32Reg u1b (.clk(clk), .ce(ce), .i(b), .sgn(sb1), .exp(xb1), .fract(fractb1), .xz(b_dn1), .vz(bz1), .inf(bInf1), .nan(bNan1) );
fpDecomp32Reg u1c (.clk(clk), .ce(ce), .i(c), .sgn(sc1), .exp(xc1), .fract(fractc1), .xz(c_dn1), .vz(cz1), .inf(cInf1), .nan(cNan1) );

always @(posedge clk)
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
reg [fp32Pkg::EMSB+2:0] ex2;
reg [fp32Pkg::EMSB:0] xc2;
reg realOp2;
reg xcInf2;

always @(posedge clk)
	if (ce) abz2 <= az1|bz1;
always @(posedge clk)
	if (ce) ex2 <= (xa1|a_dn1) + (xb1|b_dn1) - bias;
always @(posedge clk)
	if (ce) xc2 <= (xc1|c_dn1);
always @(posedge clk)
	if (ce) xcInf2 = &xc1;

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
always @(posedge clk)
	if (ce) realOp2 <= op1 ^ (sa1 ^ sb1) ^ sc1;

reg [fp32Pkg::FX:0] fract5;
wire [63:0] fractoo;
mult32x32 umul1 (.clk(clk), .ce(ce), .a({9'd0,fracta1}), .b({9'd0,fractb1}), .o(fractoo));
always @(posedge clk)
  if (ce) fract5 <= fractoo[fp32Pkg::FX:0];

// -----------------------------------------------------------
// Clock #3
// Select zero exponent
// -----------------------------------------------------------

reg [fp32Pkg::EMSB+2:0] ex3;
reg [fp32Pkg::EMSB:0] xc3;
always @(posedge clk)
	if (ce) ex3 <= abz2 ? 1'd0 : ex2;
always @(posedge clk)
	if (ce) xc3 <= xc2;

// -----------------------------------------------------------
// Clock #4
// Generate partial products.
// -----------------------------------------------------------

reg [fp32Pkg::EMSB+2:0] ex4;
reg [fp32Pkg::EMSB:0] xc4;

always @(posedge clk)
	if (ce) ex4 <= ex3;
always @(posedge clk)
	if (ce) xc4 <= xc3;

// -----------------------------------------------------------
// Clock #5
// Sum partial products (above)
// compute multiplier overflow and underflow
// -----------------------------------------------------------

// Status
reg under5;
reg over5;
reg [fp32Pkg::EMSB+2:0] ex5;
reg [fp32Pkg::EMSB:0] xc5;
wire aInf5, bInf5;
wire aNan5, bNan5;
wire qNaNOut5;

always @(posedge clk)
	if (ce) under5 <= ex4[fp32Pkg::EMSB+2];
always @(posedge clk)
	if (ce) over5 <= (&ex4[fp32Pkg::EMSB:0] | ex4[fp32Pkg::EMSB+1]) & !ex4[fp32Pkg::EMSB+2];
always @(posedge clk)
	if (ce) ex5 <= ex4;
always @(posedge clk)
	if (ce) xc5 <= xc4;

delay4 u2a (.clk(clk), .ce(ce), .i(aInf1), .o(aInf5) );
delay4 u2b (.clk(clk), .ce(ce), .i(bInf1), .o(bInf5) );

// determine when a NaN is output
wire [MSB:0] a5,b5;
delay4 u5 (.clk(clk), .ce(ce), .i((aInf1&bz1)|(bInf1&az1)), .o(qNaNOut5) );
delay4 u14 (.clk(clk), .ce(ce), .i(aNan1), .o(aNan5) );
delay4 u15 (.clk(clk), .ce(ce), .i(bNan1), .o(bNan5) );
delay5 #($bits(a)) u16 (.clk(clk), .ce(ce), .i(a), .o(a5) );
delay5 #($bits(b)) u17 (.clk(clk), .ce(ce), .i(b), .o(b5) );

// -----------------------------------------------------------
// Clock #6
// - figure multiplier mantissa output
// - figure multiplier exponent output
// - correct xponent and mantissa for exceptional conditions
// -----------------------------------------------------------

reg [fp32Pkg::FX:0] mo6;
reg [fp32Pkg::EMSB+2:0] ex6;
reg [fp32Pkg::EMSB:0] xc6;
wire [fp32Pkg::FMSB+1:0] fractc6;
vtdl #(fp32Pkg::FMSB+2) u61 (.clk(clk), .ce(ce), .a(4'd4), .d(fractc1), .q(fractc6) );
delay1 u62 (.clk(clk), .ce(ce), .i(under5), .o(under6));

always @(posedge clk)
	if (ce) xc6 <= xc5;

always @(posedge clk)
	if (ce)
		casez({aNan5,bNan5,qNaNOut5,aInf5,bInf5,over5})
		6'b1?????:  mo6 <= {1'b1,1'b1,a5[fp32Pkg::FMSB-1:0],{fp32Pkg::FMSB+1{1'b0}}};
    6'b01????:  mo6 <= {1'b1,1'b1,b5[fp32Pkg::FMSB-1:0],{fp32Pkg::FMSB+1{1'b0}}};
		6'b001???:	mo6 <= {1'b1,qNaN|3'd4,{FMSB+1{1'b0}}};	// multiply inf * zero
		6'b0001??:	mo6 <= 0;	// mul inf's
		6'b00001?:	mo6 <= 0;	// mul inf's
		6'b000001:	mo6 <= 0;	// mul overflow
		default:	mo6 <= fract5;
		endcase

always @(posedge clk)
	if (ce)
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
wire az7, bz7, cz7;
wire realOp7;

// which has greater magnitude ? Used for sign calc
always @(posedge clk)
	if (ce) ex_gt_xc7 <= $signed(ex6) > $signed({2'b0,xc6});
always @(posedge clk)
	if (ce) xeq7 <= (ex6=={2'b0,xc6});
always @(posedge clk)
	if (ce) ma_gt_mc7 <= mo6 > {fractc6,{fp32Pkg::FMSB+1{1'b0}}};
always @(posedge clk)
	if (ce) meq7 <= mo6 == {fractc6,{FMSB+1{1'b0}}};
vtdl #(1) u71 (.clk(clk), .ce(ce), .a(4'd5), .d(az1), .q(az7));
vtdl #(1) u72 (.clk(clk), .ce(ce), .a(4'd5), .d(bz1), .q(bz7));
vtdl #(1) u73 (.clk(clk), .ce(ce), .a(4'd5), .d(cz1), .q(cz7));
vtdl #(1) u74 (.clk(clk), .ce(ce), .a(4'd4), .d(realOp2), .q(realOp7));

// -----------------------------------------------------------
// Clock #8
// - prep for addition, determine greater operand
// - determine if result will be zero
// -----------------------------------------------------------

reg a_gt_b8;
reg resZero8;
reg ex_gt_xc8;
wire [fp32Pkg::EMSB+2:0] ex8;
wire [fp32Pkg::EMSB:0] xc8;
wire xcInf8;
wire [2:0] rm8;
wire op8;
wire sa8, sc8;

delay2 #(fp32Pkg::EMSB+3) u81 (.clk(clk), .ce(ce), .i(ex6), .o(ex8));
delay2 #(fp32Pkg::EMSB+1) u82 (.clk(clk), .ce(ce), .i(xc6), .o(xc8));
vtdl #(1) u83 (.clk(clk), .ce(ce), .a(4'd5), .d(xcInf2), .q(xcInf8));
vtdl #(3) u84 (.clk(clk), .ce(ce), .a(4'd7), .d(rm), .q(rm8));
vtdl #(1) u85 (.clk(clk), .ce(ce), .a(4'd6), .d(op1), .q(op8));
vtdl #(1) u86 (.clk(clk), .ce(ce), .a(4'd6), .d(sa1 ^ sb1), .q(sa8));
vtdl #(1) u87 (.clk(clk), .ce(ce), .a(4'd6), .d(sc1), .q(sc8));

always @(posedge clk)
	if (ce) ex_gt_xc8 <= ex_gt_xc7;
always @(posedge clk)
	if (ce)
		a_gt_b8 <= ex_gt_xc7 || (xeq7 && ma_gt_mc7);

// Find out if the result will be zero.
always @(posedge clk)
	if (ce)
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
reg [fp32Pkg::EMSB+2:0] ex9;
reg [fp32Pkg::EMSB+2:0] ex9a;
reg ex_gt_xc9;
reg [fp32Pkg::EMSB:0] xc9;
reg a_gt_c9;
wire [fp32Pkg::FX:0] mo9;
wire [fp32Pkg::FMSB+1:0] fractc9;
wire under9;
wire xeq9;

always @(posedge clk)
	if (ce) ex_gt_xc9 <= ex_gt_xc8;
always @(posedge clk)
	if (ce) a_gt_c9 <= a_gt_b8;
always @(posedge clk)
	if (ce) xc9 <= xc8;
always @(posedge clk)
	if (ce) ex9a <= ex8;

delay3 #(fp32Pkg::FX+1) u93 (.clk(clk), .ce(ce), .i(mo6), .o(mo9));
delay3 #(fp32Pkg::FMSB+2) u94 (.clk(clk), .ce(ce), .i(fractc6), .o(fractc9));
delay3 u95 (.clk(clk), .ce(ce), .i(under6), .o(under9));
delay2 u96 (.clk(clk), .ce(ce), .i(xeq7), .o(xeq9));

always @(posedge clk)
	if (ce) ex9 <= resZero8 ? 1'd0 : ex_gt_xc8 ? ex8 : {2'b0,xc8};

// Compute output sign
always @(posedge clk)
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
reg [fp32Pkg::EMSB+2:0] xdiff10;
reg [fp32Pkg::FX:0] mfs;
reg ops10;

// If the multiplier exponent was negative (underflowed) then
// the mantissa needs to be shifted right even more (until
// the exponent is zero. The total shift would be xc9-0-
// amount underflows which is xc9 + -ex9a.

always @(posedge clk)
	if (ce) xdiff10 <= ex_gt_xc9 ? ex9a - xc9
										: ex9a[fp32Pkg::EMSB+2] ? xc9 + (~ex9a+2'd1)
										: xc9 - ex9a;

// Determine which fraction to denormalize (the one with the
// smaller exponent is denormalized). If the exponents are equal
// denormalize the smaller fraction.
always @(posedge clk)
	if (ce) mfs <= 
		xeq9 ? (a_gt_c9 ? {4'b0,fractc9,{fp32Pkg::FMSB+1{1'b0}}} : mo9)
		 : ex_gt_xc9 ? {4'b0,fractc9,{fp32Pkg::FMSB+1{1'b0}}} : mo9;

always @(posedge clk)
	if (ce) ops10 <= xeq9 ? (a_gt_c9 ? 1'b1 : 1'b0)
												: (ex_gt_xc9 ? 1'b1 : 1'b0);

// -----------------------------------------------------------
// Clock #11
// Limit the size of the shifter to only bits needed.
// -----------------------------------------------------------
reg [7:0] xdif11;

always @(posedge clk)
	if (ce) xdif11 <= xdiff10 > fp32Pkg::FX+3 ? fp32Pkg::FX+3 : xdiff10;

// -----------------------------------------------------------
// Clock #12
// Determine the sticky bit
// -----------------------------------------------------------

wire sticky, sticky12;
wire [fp32Pkg::FX:0] mfs12;
wire [7:0] xdif12;

redorN #(.BSIZE(fp32Pkg::FX+1)) uredor1 (.a({1'b0,xdif11+fp32Pkg::FMSB}), .b(mfs), .o(sticky));
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
delay1 #(1)    u122(.clk(clk), .ce(ce), .i(sticky), .o(sticky12) );
delay1 #(8)    u123(.clk(clk), .ce(ce), .i(xdif11),   .o(xdif12) );
delay2 #(fp32Pkg::FX+1) u124(.clk(clk), .ce(ce), .i(mfs), .o(mfs12) );

// -----------------------------------------------------------
// Clock #13
// - denormalize operand (shift right)
// -----------------------------------------------------------
reg [fp32Pkg::FX+2:0] mfs13;
wire [fp32Pkg::FX:0] mo13;
wire ex_gt_xc13;
wire [fp32Pkg::FMSB+1:0] fractc13;
wire ops13;

delay4 #(FX+1) u131 (.clk(clk), .ce(ce), .i(mo9), .o(mo13));
delay4 u132 (.clk(clk), .ce(ce), .i(ex_gt_xc9), .o(ex_gt_xc13));
vtdl #(fp32Pkg::FMSB+2) u133 (.clk(clk), .ce(ce), .a(4'd3), .d(fractc9), .q(fractc13));
delay3 u134 (.clk(clk), .ce(ce), .i(ops10), .o(ops13));

always @(posedge clk)
	if (ce) mfs13 <= ({mfs12,2'b0} >> xdif12)|sticky12;

// -----------------------------------------------------------
// Clock #14
// Sort operands
// -----------------------------------------------------------
reg [fp32Pkg::FX+2:0] oa, ob;
wire a_gt_b14;

vtdl #(1) u141 (.clk(clk), .ce(ce), .a(4'd5), .d(a_gt_b8), .q(a_gt_b14));

always @(posedge clk)
	if (ce) oa <= ops13 ? {mo13,2'b00} : mfs13;
always @(posedge clk)
	if (ce) ob <= ops13 ? mfs13 : {fractc13,{fp32Pkg::FMSB+1{1'b0}},2'b00};

// -----------------------------------------------------------
// Clock #15
// - Sort operands
// -----------------------------------------------------------
reg [fp32Pkg::FX+2:0] oaa, obb;
wire realOp15;
wire [fp32Pkg::EMSB:0] ex15;
wire [fp32Pkg::EMSB:0] ex9c = ex9[fp32Pkg::EMSB+1] ? infXp : ex9[fp32Pkg::EMSB:0];
wire overflow15;
vtdl #(1) u151 (.clk(clk), .ce(ce), .a(4'd7), .d(realOp7), .q(realOp15));
vtdl #(fp32Pkg::EMSB+1) u152 (.clk(clk), .ce(ce), .a(4'd5), .d(ex9c), .q(ex15));
vtdl #(fp32Pkg::EMSB+1) u153 (.clk(clk), .ce(ce), .a(4'd5), .d(ex9[fp32Pkg::EMSB+1]| &ex9[fp32Pkg::EMSB:0]), .q(overflow15));

always @(posedge clk)
	if (ce) oaa <= a_gt_b14 ? oa : ob;
always @(posedge clk)
	if (ce) obb <= a_gt_b14 ? ob : oa;

// -----------------------------------------------------------
// Clock #16
// - perform add/subtract
// - addition can generate an extra bit, subtract can't go negative
// -----------------------------------------------------------
reg [fp32Pkg::FX+3:0] mab;
wire [fp32Pkg::FX:0] mo16;
wire [fp32Pkg::FMSB+1:0] fractc16;
wire Nan16;
wire cNan16;
wire aInf16, cInf16;
wire op16;
wire exinf16;

vtdl #(1) u161 (.clk(clk), .ce(ce), .a(4'd10), .d(qNaNOut5|aNan5|bNan5), .q(Nan16));
vtdl #(1) u162 (.clk(clk), .ce(ce), .a(4'd14), .d(cNan1), .q(cNan16));
vtdl #(1) u163 (.clk(clk), .ce(ce), .a(4'd9), .d(&ex6), .q(aInf16));
vtdl #(1) u164 (.clk(clk), .ce(ce), .a(4'd14), .d(cInf1), .q(cInf16));
vtdl #(1) u165 (.clk(clk), .ce(ce), .a(4'd14), .d(op1), .q(op16));
delay3 #(fp32Pkg::FX+1) u166 (.clk(clk), .ce(ce), .i(mo13), .o(mo16));
vtdl #(fp32Pkg::FMSB+2) u167 (.clk(clk), .ce(ce), .a(4'd6), .d(fractc9), .q(fractc16));
delay1 u169 (.clk(clk), .ce(ce), .i(&ex15), .o(exinf16));

always @(posedge clk)
	if (ce) mab <= realOp15 ? oaa - obb : oaa + obb;

// -----------------------------------------------------------
// Clock #17
// - adjust for Nans
// -----------------------------------------------------------
wire [fp32Pkg::EMSB:0] ex17;
reg [fp32Pkg::FX:0] mo17;
wire so17;
wire exinf17;
wire overflow17;

vtdl #(1)        u171 (.clk(clk), .ce(ce), .a(4'd7), .d(so9), .q(so17));
delay2 #(fp32Pkg::EMSB+1) u172 (.clk(clk), .ce(ce), .i(ex15), .o(ex17));
delay1 #(1) u173 (.clk(clk), .ce(ce), .i(exinf16), .o(exinf17));
delay2 u174 (.clk(clk), .ce(ce), .i(overflow15), .o(overflow17));

always @(posedge clk)
	casez({aInf16&cInf16,Nan16,cNan16,exinf16})
	4'b1???:	mo17 <= {1'b0,op16,{fp32Pkg::FMSB-1{1'b0}},op16,{fp32Pkg::FMSB{1'b0}}};	// inf +/- inf - generate QNaN on subtract, inf on add
	4'b01??:	mo17 <= {1'b0,mo16};
	4'b001?: 	mo17 <= {1'b1,1'b1,fractc16[fp32Pkg::FMSB-1:0],{fp32Pkg::FMSB+1{1'b0}}};
	4'b0001:	mo17 <= 1'd0;
	default:	mo17 <= mab[fp32Pkg::FX+3:2];		// mab has two extra lead bits and two trailing bits
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

module fpFMA32nr(clk, ce, op, rm, a, b, c, o, inf, zero, overflow, underflow, inexact);
input clk;
input ce;
input op;
input [2:0] rm;
input  FP32 a, b, c;
output FP32 o;
output zero;
output inf;
output overflow;
output underflow;
output inexact;

wire FP32X fma_o;
wire fma_underflow;
wire fma_overflow;
wire norm_underflow;
wire norm_inexact;
wire sign_exe1, inf1, overflow1, underflow1;
wire FP32N fpn0;

fpFMA32 u1
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
fpNormalize32 u2
(
	.clk(clk),
	.ce(ce),
	.i(fma_o),
	.o(fpn0),
	.under_i(fma_underflow),
	.under_o(norm_underflow),
	.inexact_o(norm_inexact)
);
fpRound32 u3(.clk(clk), .ce(ce), .rm(rm), .i(fpn0), .o(o) );
fpDecomp32 u4(.i(o), .xz(), .vz(zero), .inf(inf));
vtdl						u5 (.clk(clk), .ce(ce), .a(4'd11), .d(fma_underflow), .q(underflow));
vtdl						u6 (.clk(clk), .ce(ce), .a(4'd11), .d(fma_overflow), .q(overflow));
delay3		#(1)	u7 (.clk(clk), .ce(ce), .i(norm_inexact), .o(inexact));
assign overflow = inf;

endmodule

