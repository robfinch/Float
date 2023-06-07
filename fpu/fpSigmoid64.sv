// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpSigmoid64.sv
//		- perform sigmoid function
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
// This module returns the sigmoid of a number using a lookup table.
// -1.0 or +1.0 is returned for entries outside of the range -8.0 to +8.0
//                                                                          
// ToTo: check pipelining of values
// ============================================================================

import fp64Pkg::*;

`define ONE64					64'h3FF0000000000000
`define EIGHT64				64'h4020000000000000
`define FIVETWELVE64	64'h4080000000000000

module fpSigmoid64(clk, ce, a, o);
parameter FPWID = 64;
input clk;
input ce;
input FP64 a;
output FP64 o;

wire [4:0] cmp1_o;
reg [4:0] cmp2_o;

// Just the mantissa is stored in the table to economize on the storage.
// The exponent is always the same value (0x3ff). Only the top 32 bits of
// the mantissa are stored.
(* ram_style="block" *)
reg [31:0] SigmoidLUT [0:1023];

// Check if the input is in the range (-8 to +8)
// We take the absolute value by trimming off the sign bit.
fpCompare64 u1 (.a(a & 64'h7FFFFFFFFFFFFFFF), .b(`EIGHT64), .o(cmp1_o), .nan(), .snan() );

initial begin
`include ".\SigTbl.ver"
end

// Quickly multiply number by 64 (it is in range -8 to 8) then convert to integer to get
// table index = add 6 to exponent then convert to integer
wire sa;
wire [EMSB:0] xa;
wire [FMSB:0] ma;
fpDecomp64 u4 (.i(a), .sgn(sa), .exp(xa), .man(ma), .fract(), .xz(), .vz(), .xinf(), .inf(), .nan() );

reg [9:0] lutadr;
wire [6:0] lzcnt;
wire FP64 a1;
wire FP64 i1, i2;
wire [EMSB:0] xa1 = xa + 4'd6;
assign a1 = {sa,xa1,ma};	// we know the exponent won't overflow
wire [31:0] man32a = SigmoidLUT[lutadr];
wire [31:0] man32b = lutadr==10'h3ff ? man32a : SigmoidLUT[lutadr+1];
wire [52:0] man53;
wire [15:0] eps = ma[FMSB-10:FMSB-10-15];
wire [47:0] p = (man32b - man32a) * eps;
assign man53 = {man32a,21'h0} + ({p,21'h0} >> (16+10));
cntlz64 u3 ({man53,11'd0},lzcnt);

wire [51:0] man52s = man53 << lzcnt;	// hide leading one

// Convert to integer
f2i64 u2
(
  .clk(clk),
  .ce(ce),
  .i(a1),
  .o(i2)
);
assign i1 = i2 + 512;

always @(posedge clk)
  if (ce) cmp2_o <= cmp1_o;

// We know the integer is in range 0 to 1023
always @(posedge clk)
  if(ce) lutadr <= i1[9:0];
reg sa1,sa2;
always @(posedge clk)
if (ce) sa1 <= a.sign;
always @(posedge clk)
if (ce) sa2 <= sa1;

wire [10:0] ex2 = 11'h3fe - lzcnt;
always_ff @(posedge clk)
if (ce) begin
	if (cmp2_o[1])  // abs(a) less than 8 ?
	  o <= {1'b0,ex2,man52s};
	else
	  o <= sa2 ? 64'h0 : `ONE64;
end

endmodule
