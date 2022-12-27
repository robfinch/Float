// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpMultiply96nr.v
//		- floating point multiplier with normalization and rounding.
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
// ============================================================================

import fp96Pkg::*;

module fpMultiply96nr(clk, ce, a, b, o, rm, sign_exe, inf, overflow, underflow);
input clk;
input ce;
input  FP96 a, b;
output FP96 o;
input [2:0] rm;
output sign_exe;
output inf;
output overflow;
output underflow;

wire FP96X o1;
wire sign_exe1, inf1, overflow1, underflow1;
wire FP96N fpn0;

fpMultiply96  u1 (clk, ce, a, b, o1, sign_exe1, inf1, overflow1, underflow1);
fpNormalize96 u2(.clk(clk), .ce(ce), .under_i(underflow1), .i(o1), .o(fpn0) );
fpRound96     u3(.clk(clk), .ce(ce), .rm(rm), .i(fpn0), .o(o) );
delay2      #(1)   u4(.clk(clk), .ce(ce), .i(sign_exe1), .o(sign_exe));
delay2      #(1)   u5(.clk(clk), .ce(ce), .i(inf1), .o(inf));
delay2      #(1)   u6(.clk(clk), .ce(ce), .i(overflow1), .o(overflow));
delay2      #(1)   u7(.clk(clk), .ce(ce), .i(underflow1), .o(underflow));
endmodule
