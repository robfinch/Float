// ============================================================================
//        __
//   \\__/ o\    (C) 2017-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpSigmoid32.sv
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

import fp32Pkg::*;

`define ONE80					80'h3FFF0000000000000000
`define EIGHT80				80'h40020000000000000000
`define FIVETWELVE80	80'h40080000000000000000
`define ONE64					64'h3FF0000000000000
`define EIGHT64				64'h4020000000000000
`define FIVETWELVE64	64'h4080000000000000
`define ONE40					40'h3FE0000000
`define EIGHT40				40'h4040000000
`define ONE32					32'h7F000000
`define EIGHT32				32'h42000000
`define FIVETWELVE32	32'h48000000

module fpSigmoid32(clk, ce, a, o);
parameter FPWID = 32;
input clk;
input ce;
input FP32 a;
output FP32 o;

wire [4:0] cmp1_o;
reg [4:0] cmp2_o;

// Just the mantissa is stored in the table to economize on the storage.
// The exponent is always the same value (0x3ff). Only the top 32 bits of
// the mantissa are stored.
(* ram_style="block" *)
reg [31:0] SigmoidLUT [0:1023];

// Check if the input is in the range (-8 to +8)
// We take the absolute value by trimming off the sign bit.
fpCompare32 u1 (.a(a & 32'h7FFFFFFF), .b(`EIGHT32), .o(cmp1_o), .nan(), .snan() );

initial begin
`include "D:\Cores2022\float\fpu\SigTbl.ver"
end

// Quickly multiply number by 64 (it is in range -8 to 8) then convert to integer to get
// table index = add 6 to exponent then convert to integer
wire sa;
wire [EMSB:0] xa;
wire [FMSB:0] ma;
fpDecomp32 u4 (.i(a), .sgn(sa), .exp(xa), .man(ma), .fract(), .xz(), .vz(), .xinf(), .inf(), .nan() );

reg [9:0] lutadr;
wire [5:0] lzcnt;
wire FP32 a1;
wire FP32 i1, i2;
wire [EMSB:0] xa1 = xa + 4'd6;
assign a1 = {sa,xa1,ma};	// we know the exponent won't overflow
wire [31:0] man32a = SigmoidLUT[lutadr];
wire [31:0] man32b = lutadr==10'h3ff ? man32a : SigmoidLUT[lutadr+1];
wire [31:0] man32;
wire [12:0] eps = ma[FMSB-10:0];
wire [43:0] p = (man32b - man32a) * eps;
assign man32 = man32a + (p >> 26);
cntlz32 u3 (man32,lzcnt);

wire [31:0] man32s = man32 << (lzcnt + 2'd1);	// +1 to hide leading one

// Convert to integer
f2i32 u2
(
  .clk(clk),
  .ce(1'b1),
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

wire [7:0] ex2 = 8'h7e - lzcnt;
always_ff @(posedge clk)
if (ce) begin
	if (cmp2_o[1])  // abs(a) less than 8 ?
	  o <= {1'b0,ex2,man32s[31:9]};
	else
	  o <= sa2 ? 32'h0 : `ONE32;
end

endmodule
