// ============================================================================
//        __
//   \\__/ o\    (C) 2024  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpDecompReg.v
//    - decompose floating point value with registered outputs
//    - parameterized width
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
// ============================================================================

import fp48Pkg::*;

module fpDecomp48(i, sgn, exp, man, fract, xz, mz, vz, inf, xinf, qnan, snan, nan);
input [47:0] i;
output sgn;
output [fp48Pkg::EMSB:0] exp;
output [fp48Pkg::FMSB:0] man;
output [fp48Pkg::FMSB+1:0] fract;	// mantissa with hidden bit recovered
output xz;		// denormalized - exponent is zero
output mz;		// mantissa is zero
output vz;		// value is zero (both exponent and mantissa are zero)
output inf;		// all ones exponent, zero mantissa
output xinf;	// all ones exponent
output qnan;	// nan
output snan;	// signalling nan
output nan;

// Decompose input
assign sgn = i[fp48Pkg::MSB];
assign exp = i[fp48Pkg::MSB-1:fp48Pkg::FMSB+1];
assign man = i[fp48Pkg::FMSB:0];
assign xz = !(|exp);	// denormalized - exponent is zero
assign mz = !(|man);	// mantissa is zero
assign vz = xz & mz;	// value is zero (both exponent and mantissa are zero)
assign inf = &exp & mz;	// all ones exponent, zero mantissa
assign xinf = &exp;
assign qnan = &exp &  man[fp48Pkg::FMSB];
assign snan = &exp & !man[fp48Pkg::FMSB] & !mz;
assign nan = &exp & !mz;
assign fract = {!xz,i[fp48Pkg::FMSB:0]};

endmodule


module fpDecomp48Reg(clk, ce, i, o, sgn, exp, man, fract, xz, mz, vz, inf, xinf, qnan, snan, nan);
input clk;
input ce;
input [fp48Pkg::MSB:0] i;

output reg [fp48Pkg::MSB:0] o;
output reg sgn;
output reg [fp48Pkg::EMSB:0] exp;
output reg [fp48Pkg::FMSB:0] man;
output reg [fp48Pkg::FMSB+1:0] fract;	// mantissa with hidden bit recovered
output reg xz;		// denormalized - exponent is zero
output reg mz;		// mantissa is zero
output reg vz;		// value is zero (both exponent and mantissa are zero)
output reg inf;		// all ones exponent, zero mantissa
output reg xinf;	// all ones exponent
output reg qnan;	// nan
output reg snan;	// signalling nan
output reg nan;

// Decompose input
always @(posedge clk)
	if (ce) begin
		o <= i;
		sgn = i[fp48Pkg::MSB];
		exp = i[fp48Pkg::MSB-1:fp48Pkg::FMSB+1];
		man = i[fp48Pkg::FMSB:0];
		xz = !(|exp);	// denormalized - exponent is zero
		mz = !(|man);	// mantissa is zero
		vz = xz & mz;	// value is zero (both exponent and mantissa are zero)
		inf = &exp & mz;	// all ones exponent, zero mantissa
		xinf = &exp;
		qnan = &exp &  man[fp48Pkg::FMSB];
		snan = &exp & !man[fp48Pkg::FMSB] & !mz;
		nan = &exp & !mz;
		fract = {|exp,i[fp48Pkg::FMSB:0]};
	end

endmodule
