// ============================================================================
//        __
//   \\__/ o\    (C) 2006-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpMultiply32.v
//		- floating point multiplier
//		- two cycle latency minimum (latency depends on precision)
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
//
//	Floating Point Multiplier
//
//	This multiplier handles denormalized numbers.
//	The output format is of an internal expanded representation
//	in preparation to be fed into a normalization unit, then
//	rounding. Basically, it's the same as the regular format
//	except the mantissa is doubled in size, the leading two
//	bits of which are assumed to be whole bits.
//
//
//	Floating Point Multiplier
//
//	Properties:
//	+-inf * +-inf = -+inf	(this is handled by exOver)
//	+-inf * 0     = QNaN
//	
// ============================================================================

import fp32Pkg::*;

module fpMultiply32(clk, ce, a, b, o, sign_exe, inf, overflow, underflow);
input clk;
input ce;
input  FP32 a, b;
output [fp32Pkg::EX:0] o;
output sign_exe;
output inf;
output overflow;
output underflow;
parameter DELAY = 13;

reg [fp32Pkg::EMSB:0] xo1;		// extra bit for sign
reg [fp32Pkg::FX:0] mo1;

// constants
wire [fp32Pkg::EMSB:0] infXp = {EMSB+1{1'b1}};	// infinite / NaN - all ones
// The following is the value for an exponent of zero, with the offset
// eg. 8'h7f for eight bit exponent, 11'h7ff for eleven bit exponent, etc.
wire [fp32Pkg::EMSB:0] bias = {1'b0,{EMSB{1'b1}}};	//2^0 exponent
// The following is a template for a quiet nan. (MSB=1)
wire [fp32Pkg::FMSB:0] qNaN  = {1'b1,{FMSB{1'b0}}};

// variables
reg [fp32Pkg::FX:0] fract1,fract1a;
wire [fp32Pkg::FX:0] fracto;
wire [fp32Pkg::EMSB+2:0] ex1;	// sum of exponents
wire [fp32Pkg::EMSB  :0] ex2;

// Decompose the operands
wire sa, sb;			// sign bit
wire [fp32Pkg::EMSB:0] xa, xb;	// exponent bits
wire [fp32Pkg::FMSB+1:0] fracta, fractb;
wire a_dn, b_dn;			// a/b is denormalized
wire aNan, bNan, aNan1, bNan1;
wire az, bz;
wire aInf, bInf, aInf1, bInf1;


// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
// Clock #1
// - decode the input operands
// - derive basic information
// - calculate exponent
// - calculate fraction
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

// -----------------------------------------------------------
// First clock
// -----------------------------------------------------------

fpDecomp32 u1a (.i(a), .sgn(sa), .exp(xa), .fract(fracta), .xz(a_dn), .vz(az), .inf(aInf), .nan(aNan) );
fpDecomp32 u1b (.i(b), .sgn(sb), .exp(xb), .fract(fractb), .xz(b_dn), .vz(bz), .inf(bInf), .nan(bNan) );

// Compute the sum of the exponents.
// correct the exponent for denormalized operands
// adjust the sum by the exponent offset (subtract 127)
// mul: ex1 = xa + xb,	result should always be < 1ffh
`ifdef SUPPORT_DENORMALS
assign ex1 = (az|bz) ? 0 : (xa|(a_dn&~az)) + (xb|(b_dn&~bz)) - bias;
`else
assign ex1 = (az|bz) ? 0 : xa + xb - bias;
`endif

wire [63:0] fractoo;
mult32x32 umul1 (.clk(clk), .ce(ce), .a({9'd0,fracta}), .b({9'd0,fractb}), .o(fractoo));
always @(posedge clk)
  if (ce) fract1 <= fractoo[fp32Pkg::FX:0];

// Status
wire under1, over1;
wire under = ex1[fp32Pkg::EMSB+2];	// exponent underflow
wire over = (&ex1[fp32Pkg::EMSB:0] | ex1[fp32Pkg::EMSB+1]) & !ex1[fp32Pkg::EMSB+2];

ft_delay #(.WID(fp32Pkg::EMSB+1),.DEP(DELAY)) u3 (.clk(clk), .ce(ce), .i(ex1[fp32Pkg::EMSB:0]), .o(ex2) );
ft_delay #(.WID(1),.DEP(DELAY)) u2a (.clk(clk), .ce(ce), .i(aInf), .o(aInf1) );
ft_delay #(.WID(1),.DEP(DELAY)) u2b (.clk(clk), .ce(ce), .i(bInf), .o(bInf1) );
ft_delay #(.WID(1),.DEP(DELAY)) u6  (.clk(clk), .ce(ce), .i(under), .o(under1) );
ft_delay #(.WID(1),.DEP(DELAY)) u7  (.clk(clk), .ce(ce), .i(over), .o(over1) );

// determine when a NaN is output
wire qNaNOut;
FP32 a1,b1;
ft_delay #(.WID(1),.DEP(DELAY)) u5 (.clk(clk), .ce(ce), .i((aInf&bz)|(bInf&az)), .o(qNaNOut) );
ft_delay #(.WID(1),.DEP(DELAY)) u14 (.clk(clk), .ce(ce), .i(aNan), .o(aNan1) );
ft_delay #(.WID(1),.DEP(DELAY)) u15 (.clk(clk), .ce(ce), .i(bNan), .o(bNan1) );
ft_delay #(.WID($bits(a)),.DEP(DELAY))  u16 (.clk(clk), .ce(ce), .i(a), .o(a1) );
ft_delay #(.WID($bits(b)),.DEP(DELAY))  u17 (.clk(clk), .ce(ce), .i(b), .o(b1) );

// -----------------------------------------------------------
// Second clock
// - correct xponent and mantissa for exceptional conditions
// -----------------------------------------------------------

wire so1;
ft_delay #(.WID(1),.DEP(DELAY+1)) u8 (.clk(clk), .ce(ce), .i(sa ^ sb), .o(so1) );// two clock ft_delay!

always @(posedge clk)
	if (ce)
		casez({qNaNOut|aNan1|bNan1,aInf1,bInf1,over1,under1})
		5'b1????:	xo1 = infXp;	// qNaN - infinity * zero
		5'b01???:	xo1 = infXp;	// 'a' infinite
		5'b001??:	xo1 = infXp;	// 'b' infinite
		5'b0001?:	xo1 = infXp;	// result overflow
		5'b00001:	xo1 = ex2[fp32Pkg::EMSB:0];//0;		// underflow
		default:	xo1 = ex2[fp32Pkg::EMSB:0];	// situation normal
		endcase

// Force mantissa to zero when underflow or zero exponent when not supporting denormals.
always @(posedge clk)
	if (ce)
`ifdef SUPPORT_DENORMALS
		casez({aNan1,bNan1,qNaNOut,aInf1,bInf1,over1})
`else
		casez({aNan1,bNan1,qNaNOut,aInf1,bInf1,over1|under1})
`endif
		6'b1?????:  mo1 = {1'b1,a1[fp32Pkg::FMSB:0],{fp32Pkg::FMSB+1{1'b0}}};
    6'b01????:  mo1 = {1'b1,b1[fp32Pkg::FMSB:0],{fp32Pkg::FMSB+1{1'b0}}};
		6'b001???:	mo1 = {1'b1,qNaN|3'd4,{FMSB+1{1'b0}}};	// multiply inf * zero
		6'b0001??:	mo1 = 0;	// mul inf's
		6'b00001?:	mo1 = 0;	// mul inf's
		6'b000001:	mo1 = 0;	// mul overflow
		default:	mo1 = fract1;
		endcase

ft_delay #(.WID(1),.DEP(DELAY+1)) u10 (.clk(clk), .ce(ce), .i(sa & sb), .o(sign_exe) );
delay1 u11 (.clk(clk), .ce(ce), .i(over1),  .o(overflow) );
delay1 u12 (.clk(clk), .ce(ce), .i(over1),  .o(inf) );
delay1 u13 (.clk(clk), .ce(ce), .i(under1), .o(underflow) );

assign o.sign = so1;
assign o.exp = xo1;
assign o.sig = mo1;

endmodule

