// ============================================================================
//        __
//   \\__/ o\    (C) 2024  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	f2i48.sv
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

import fp48Pkg::*;

module f2i48(clk, ce, op, i, o, overflow);
input clk;
input ce;
input op;					// 1 = signed, 0 = unsigned
input [fp48Pkg::MSB:0] i;
output [fp48Pkg::MSB:0] o;
output overflow;

wire [fp48Pkg::MSB:0] maxInt  = op ? {fp48Pkg::MSB{1'b1}} : {fp48Pkg::FPWID{1'b1}};		// maximum integer value
wire [fp48Pkg::EMSB:0] zeroXp = {fp48Pkg::EMSB{1'b1}};	// simple constant - value of exp for zero

// Decompose fp value
reg sgn;									// sign
always_ff @(posedge clk)
	if (ce) sgn = i[fp48Pkg::MSB];
wire [fp48Pkg::EMSB:0] exp = i[fp48Pkg::MSB-1:fp48Pkg::FMSB+1];		// exponent
wire [fp48Pkg::FMSB+1:0] man = {exp!=0,i[fp48Pkg::FMSB:0]};	// mantissa including recreate hidden bit

wire iz = i[fp48Pkg::MSB-1:0]==0;					// zero value (special)

assign overflow  = exp - zeroXp > (op ? fp48Pkg::MSB : fp48Pkg::FPWID);		// lots of numbers are too big - don't forget one less bit is available due to signed values
wire underflow = exp < zeroXp - 1;			// value less than 1/2

wire [7:0] shamt = (op ? fp48Pkg::MSB : fp48Pkg::FPWID) - (exp - zeroXp);	// exp - zeroXp will be <= MSB

wire [fp48Pkg::MSB+1:0] o1 = {man,{fp48Pkg::EMSB+1{1'b0}},1'b0} >> shamt;	// keep an extra bit for rounding
wire [fp48Pkg::MSB:0] o2 = o1[fp48Pkg::MSB+1:1] + o1[0];		// round up
reg [fp48Pkg::MSB:0] o3;

always_ff @(posedge clk)
	if (ce) begin
		if (underflow|iz)
			o3 <= 48'd0;
		else if (overflow)
			o3 <= maxInt;
		// value between 1/2 and 1 - round up
		else if (exp==zeroXp-1)
			o3 <= 48'd1;
		// value > 1
		else
			o3 <= o2;
	end
		
assign o = (op & sgn) ? -o3 : o3;					// adjust output for correct signed value

endmodule

