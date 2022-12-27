// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	mult22x22.sv
//  - Karatsuba multiply
//  - six clock cycles
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

`define KARATSUBA	1

`ifdef KARATSUBA

module mult22x22(clk, ce, a, b, o);
input clk;
input ce;
input [21:0] a;
input [21:0] b;
output reg [43:0] o;

reg [10:0] a2, b2;
reg [11:0] a1, b1;
reg [21:0] z0, z2, z0a, z2a, z0b, z2b, z0c, z2c, z0d, z2d, p3;
reg [22:0] p4;
reg [22:0] z1;  // extra bit for carry
reg sgn2, sgn3, sgn4;

always @(posedge clk)
	if (ce) a1 <= a[10: 0] - a[21:11];  // x0-x1
always @(posedge clk)
	if (ce) b1 <= b[21:11] - b[10: 0];  // y1-y0
always @(posedge clk)
	if (ce) a2 <= a1[11] ? -a1 : a1;
always @(posedge clk)
	if (ce) b2 <= b1[11] ? -b1 : b1;
always @(posedge clk)
  if (ce) sgn2 <= a1[11]^b1[11];
always @(posedge clk)
  if (ce) sgn3 <= sgn2;
always @(posedge clk)
  if (ce) sgn4 <= sgn3;
 
mult11x11 u1 (
  .clk(clk),
  .ce(ce),
  .a(a[21:11]),
  .b(b[21:11]),
  .o(z2)          // z2 = x1 * y1
);

mult11x11 u2 (
  .clk(clk),
  .ce(ce),
  .a(a[10:0]),
  .b(b[10:0]),
  .o(z0)          // z0 = x0 * y0
);

mult11x11 u3 (
  .clk(clk),
  .ce(ce),
  .a(a2[10:0]),
  .b(b2[10:0]),
  .o(p3)        // p3 = abs(x0-x1) * abs(y1-y0)
);

always @(posedge clk)
	if (ce) p4 <= sgn3 ? -p3 : p3;

always @(posedge clk)
  if (ce) z2a <= z2;
always @(posedge clk)
  if (ce) z0a <= z0;
always @(posedge clk)
  if (ce) z2b <= z2a;
always @(posedge clk)
  if (ce) z0b <= z0a;
always @(posedge clk)
  if (ce) z2c <= z2b;
always @(posedge clk)
  if (ce) z0c <= z0b;
always @(posedge clk)
	if (ce) z1 <= {{22{p4[22]}},p4} + z2c + z0c;

always @(posedge clk)
  if (ce) z2d <= z2c;
always @(posedge clk)
  if (ce) z0d <= z0c;
always @(posedge clk)
	if (ce) o <= {z2d,z0d} + {z1,11'd0};

endmodule

`else

// This version of the multiply has a parameterized pipeline depth and allows
// the tools to perform the multiply. Relies on the ability of tools to retime.

module mult22x22(clk, ce, a, b, o);
parameter DEP = 6;
input clk;
input ce;
input [21:0] a;
input [21:0] b;
output reg [43:0] o;

reg [43:0] prod [0:DEP-1];
reg [43:0] prd;
integer n;

always_ff @(posedge clk)
	if (ce) prd <= a * b;
always_ff @(posedge clk)
	if (ce) prod[0] <= prd;
	
always_ff @(posedge clk)
	for (n = 0; n < DEP - 1; n = n + 1)
		if (ce) prod[n+1] <= prod[n];

always_ff @(posedge clk)
	if(ce) o <= prod[DEP-1];

endmodule

`endif
