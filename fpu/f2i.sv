// ============================================================================
//        __
//   \\__/ o\    (C) 2006-2020  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	f2i.v
//		- convert floating point to integer
//		- single cycle latency floating point unit
//		- parameterized width
//		- IEEE 754 representation
//
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                                          
//	i2f - convert integer to floating point
//  f2i - convert floating point to integer
//
// ============================================================================

import fp::*;

module f2i(clk, ce, op, i, o, overflow);
input clk;
input ce;
input op;					// 1 = signed, 0 = unsigned
input [MSB:0] i;
output [MSB:0] o;
output overflow;

wire [MSB:0] maxInt  = op ? {MSB{1'b1}} : {FPWID{1'b1}};		// maximum integer value
wire [EMSB:0] zeroXp = {EMSB{1'b1}};	// simple constant - value of exp for zero

// Decompose fp value
reg sgn;									// sign
always @(posedge clk)
	if (ce) sgn = i[MSB];
wire [EMSB:0] exp = i[MSB-1:FMSB+1];		// exponent
wire [FMSB+1:0] man = {exp!=0,i[FMSB:0]};	// mantissa including recreate hidden bit

wire iz = i[MSB-1:0]==0;					// zero value (special)

assign overflow  = exp - zeroXp > (op ? MSB : FPWID);		// lots of numbers are too big - don't forget one less bit is available due to signed values
wire underflow = exp < zeroXp - 1;			// value less than 1/2

wire [7:0] shamt = (op ? MSB : FPWID) - (exp - zeroXp);	// exp - zeroXp will be <= MSB

wire [MSB+1:0] o1 = {man,{EMSB+1{1'b0}},1'b0} >> shamt;	// keep an extra bit for rounding
wire [MSB:0] o2 = o1[MSB+1:1] + o1[0];		// round up
reg [MSB:0] o3;

always @(posedge clk)
	if (ce) begin
		if (underflow|iz)
			o3 <= 0;
		else if (overflow)
			o3 <= maxInt;
		// value between 1/2 and 1 - round up
		else if (exp==zeroXp-1)
			o3 <= 1;
		// value > 1
		else
			o3 <= o2;
	end
		
assign o = (op & sgn) ? -o3 : o3;					// adjust output for correct signed value

endmodule

