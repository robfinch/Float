// ============================================================================
//        __
//   \\__/ o\    (C) 2020  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	mult128x128combo.sv
//  - Karatsuba multiply
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

module mult128x128combo(a, b, o);
input [127:0] a;
input [127:0] b;
output reg [255:0] o='d0;

reg [63:0] a2='d0, b2='d0;
reg [64:0] a1='d0, b1='d0;
reg [127:0] z0, z2, z0a, z2a, z0b, z2b, z0c, z2c, z0d, z2d, p3;
reg [128:0] p4;
reg [128:0] z1; // extra bit for carry
reg sgn2, sgn10;
reg sgn9;

always_comb
	a1 <= a[63: 0] - a[127:64];  // x0-x1
always_comb
	b1 <= b[127:64] - b[63: 0];  // y1-y0
always_comb
	a2 <= a1[64] ? -a1 : a1;
always_comb
	b2 <= b1[64] ? -b1 : b1;
always_comb
  sgn2 <= a1[64]^b1[64];
always_comb
	sgn9 <= sgn2;

always_comb
  sgn10 <= sgn9;

mult64x64combo u1 (
  .a(a[127:64]),
  .b(b[127:64]),
  .o(z2)          // z2 = x1 * y1
);

mult64x64combo u2 (
  .a(a[63:0]),
  .b(b[63:0]),
  .o(z0)          // z0 = x0 * y0
);

mult64x64combo u3 (
  .a(a2[63:0]),
  .b(b2[63:0]),
  .o(p3)        // p3 = abs(x0-x1) * abs(y1-y0)
);

always_comb
	p4 <= sgn9 ? -p3 : p3;

always_comb
  z2a <= z2;
always_comb
  z0a <= z0;
always_comb
  z2b <= z2a;
always_comb
  z0b <= z0a;
always_comb
  z2c <= z2b;
always_comb
  z0c <= z0b;
always_comb
	z1 <= {{128{p4[128]}},p4} + z2c + z0c;

always_comb
  z2d <= z2c;
always_comb
  z0d <= z0c;
always_comb
	o <= {z2d,z0d} + {z1,64'd0};

endmodule

