// ============================================================================
//        __
//   \\__/ o\    (C) 2018-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	DFPSqrt96.sv
//    - decimal floating point square root
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

import DFPPkg::*;

module DFPSqrt96(rst, clk, ce, ld, a, o, done, sqrinf, sqrneg);
parameter N=25;
input rst;
input clk;
input ce;
input ld;
input DFP96 a;
output DFP96UD o;
output done;
output sqrinf;
output sqrneg;

// registered outputs
reg sign_exe;
reg inf;
reg	overflow;
reg	underflow;
wire sign = 1'b0;

wire so;
wire [13:0] xo;
wire [(N+1)*4*2-1:0] mo;

// constants
wire [13:0] infXp = 12'hBFF;	// infinite / NaN - all ones
// The following is a template for a quiet nan. (MSB=1)
wire [N*4-1:0] qNaN  = {4'h1,{N*4-4{1'b0}}};

// variables
wire [13:0] ex1;	// sum of exponents
wire ex1c;
wire [(N+1)*4*2-1:0] sqrto;

// Operands
reg sa;			// sign bit
reg [11:0] xa;	// exponent bits
reg [N*4-1:0] siga;
reg a_dn;			// a/b is denormalized
reg az;
reg aInf;
reg aNan;
wire done1;
wire [7:0] lzcnt;
wire [N*4-1:0] aa;
DFP96U au;

// -----------------------------------------------------------
// - decode the input operand
// - derive basic information
// - calculate exponent
// - calculate fraction
// -----------------------------------------------------------

DFPUnpack96 u01 (a, au);
always @(posedge clk)
	if (ce) sa <= au.sign;
always @(posedge clk)
	if (ce) xa <= au.exp;
always @(posedge clk)
	if (ce) siga <= au.sig;
always @(posedge clk)
	if (ce) a_dn <= au.exp==12'd0;
always @(posedge clk)
	if (ce) az <= au.exp==12'd0 && au.sig==100'd0;
always @(posedge clk)
	if (ce) aInf <= au.infinity;
always @(posedge clk)
	if (ce) aNan <= au.nan;

assign ex1 = xa + 1'd1;
assign xo = ex1 >> 1'd1;

assign so = 1'b0;				// square root of positive numbers only
assign mo = aNan ? {4'h1,aa[N*4-1:0],{N*4{1'b0}}} : sqrto;	//(sqrto << pShiftAmt);
assign sqrinf = aInf;
assign sqrneg = !az & so;

wire [(N+1)*4-1:0] siga1 = xa[0] ? {siga,4'h0} : {4'h0,siga};

wire ldd;
delay1 #(1) u3 (.clk(clk), .ce(ce), .i(ld), .o(ldd));

// Ensure an even number of digits are processed.
dfisqrt #((N+2)&-2) u2
(
	.rst(rst),
	.clk(clk),
	.ce(ce),
	.ld(ldd),
	.a({4'h0,siga1}),
	.o(sqrto),
	.done(done)
);

always @*
casez({aNan,sqrinf,sqrneg})
3'b1??:
	begin
		o.sign <= sign;
		o.nan <= 1'b1;
		o.exp <= 12'hBFF;
		o.sig <= {siga,{N*4-4{1'b0}}};
	end
3'b01?:
	begin
		o.sign <= sign;
		o.nan <= 1'b1;
		o.exp <= 12'hBFF;
		o.sig <= {4'h1,qNaN|4'h5,{N*4-4{1'b0}}};
	end
3'b001:
	begin
		o.sign <= sign;
		o.nan <= 1'b1;
		o.exp <= 12'hBFF;
		o.sig <= {4'h1,qNaN|4'h6,{N*4-4{1'b0}}};
	end
default:
	begin
		o.sign <= 1'b0;
		o.nan <= 1'b0;
		o.exp <= xo;
		o.sig <= mo;
	end
endcase
	

endmodule

module DFPSqrt96nr(rst, clk, ce, ld, a, o, rm, done, inf, sqrinf, sqrneg);
parameter N=25;
input rst;
input clk;
input ce;
input ld;
input  DFP96 a;
output DFP96 o;
input [2:0] rm;
output done;
output inf;
output sqrinf;
output sqrneg;

wire DFP96UD o1;
wire inf1;
wire DFP96UN fpn0;
wire done1;
wire done2;

DFPSqrt96      #(.N(N)) u1 (rst, clk, ce, ld, a, o1, done1, sqrinf, sqrneg);
DFPNormalize96 #(.N(N)) u2(.clk(clk), .ce(ce), .under_i(1'b0), .i(o1), .o(fpn0) );
DFPRound96     #(.N(N)) u3(.clk(clk), .ce(ce), .rm(rm), .i(fpn0), .o(o) );
delay2      #(1)   u5(.clk(clk), .ce(ce), .i(inf1), .o(inf));
delay2		#(1)   u8(.clk(clk), .ce(ce), .i(done1), .o(done2));
assign done = done1&done2;

endmodule
