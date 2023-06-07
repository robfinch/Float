// ============================================================================
//        __
//   \\__/ o\    (C) 2018-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpSqrt64.v
//    - floating point square root
//    - parameterized width
//    - IEEE 754 representation
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

import fp64Pkg::*;

module fpSqrt64(rst, clk, clk2x, ce, ld, a, o, done, sqrinf, sqrneg);
localparam pShiftAmt = 36;
input rst;
input clk;
input clk2x;
input ce;
input ld;
input FP64 a;
output reg [fp64Pkg::EX:0] o;
output done;
output sqrinf;
output sqrneg;

// registered outputs
reg sign_exe;
reg inf;
reg	overflow;
reg	underflow;

wire so;
wire [fp64Pkg::EMSB:0] xo;
wire [fp64Pkg::FX:0] mo;

// constants
wire [fp64Pkg::EMSB:0] infXp = {fp64Pkg::EMSB+1{1'b1}};	// infinite / NaN - all ones
// The following is the value for an exponent of zero, with the offset
// eg. 8'h7f for eight bit exponent, 11'h7ff for eleven bit exponent, etc.
wire [fp64Pkg::EMSB:0] bias = {1'b0,{fp64Pkg::EMSB{1'b1}}};	//2^0 exponent
// The following is a template for a quiet nan. (MSB=1)
wire [fp64Pkg::FMSB:0] qNaN  = {1'b1,{fp64Pkg::FMSB{1'b0}}};

// variables
wire [fp64Pkg::EMSB+2:0] ex1;	// sum of exponents
wire [fp64Pkg::FX:0] sqrto;

// Operands
wire sa;			// sign bit
wire [fp64Pkg::EMSB:0] xa;	// exponent bits
wire [fp64Pkg::FMSB+1:0] fracta;
wire a_dn;			// a/b is denormalized
wire az;
wire aInf;
wire aNan;
wire done1;
wire [7:0] lzcnt;
wire [fp64Pkg::MSB:0] aa;

// -----------------------------------------------------------
// - decode the input operand
// - derive basic information
// - calculate exponent
// - calculate fraction
// -----------------------------------------------------------

fpDecomp64Reg u1
(
	.clk(clk),
	.ce(ce),
	.i(a),
	.o(aa),
	.sgn(sa),
	.exp(xa),
	.fract(fracta),
	.xz(a_dn),
	.vz(az),
	.inf(aInf),
	.nan(aNan)
);

assign ex1 = xa + 8'd1;
assign so = 1'b0;				// square root of positive numbers only
assign xo = (ex1 >> 1) + (bias >> 1);	// divide by 2 cuts the bias in half, so 1/2 of it is added back in.
assign mo = aNan ? {1'b1,aa[fp64Pkg::FMSB:0],{fp64Pkg::FMSB+1{1'b0}}} : (sqrto << pShiftAmt);
assign sqrinf = aInf;
assign sqrneg = !az & so;

wire [fp64Pkg::FMSB+2:0] fracta1 = ex1[0] ? {1'b0,fracta} << 1 : {2'b0,fracta};

wire ldd;
delay1 #(1) u3 (.clk(clk), .ce(ce), .i(ld), .o(ldd));

isqrt #(fp64Pkg::FX+1) u2
(
	.rst(rst),
	.clk(clk2x),
	.ce(ce),
	.ld(ldd),
	.a({1'b0,fracta1,{fp64Pkg::FMSB+1{1'b0}}}),
	.o(sqrto),
	.done(done)
);

always_comb
casez({aNan,sqrinf,sqrneg})
3'b1??:	o <= {sa,xa,mo};
3'b01?:	o <= {sa,1'b1,qNaN|fp64Pkg::QSQRTINF,{fp64Pkg::FMSB+1{1'b0}}};
3'b001:	o <= {sa,1'b1,qNaN|fp64Pkg::QSQRTNEG,{fp64Pkg::FMSB+1{1'b0}}};
default:	o <= {so,xo,mo};
endcase
	

endmodule

module fpSqrt64nr(rst, clk, clk2x, ce, ld, a, o, rm, done, inf, sqrinf, sqrneg);
input rst;
input clk;
input clk2x;
input ce;
input ld;
input  [fp64Pkg::MSB:0] a;
output [fp64Pkg::MSB:0] o;
input [2:0] rm;
output done;
output inf;
output sqrinf;
output sqrneg;

wire [fp64Pkg::EX:0] o1;
wire inf1;
wire [fp64Pkg::MSB+3:0] fpn0;
wire done1;
assign inf1 = &o[62:52] && ~|o[51:0];
fpSqrt64 u1 (rst, clk, clk2x, ce, ld, a, o1, done1, sqrinf, sqrneg);
fpNormalize64 u2(.clk(clk), .ce(ce), .under_i(1'b0), .i(o1), .o(fpn0) );
fpRound64     u3(.clk(clk), .ce(ce), .rm(rm), .i(fpn0), .o(o) );
delay1      #(1)   u5(.clk(clk), .ce(ce), .i(inf1), .o(inf));
ft_delay #(.WID(1),.DEP(12)) u6 (.clk(clk), .ce(ce), .i(done1), .o(done));
endmodule

