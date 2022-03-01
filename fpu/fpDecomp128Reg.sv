// ============================================================================
//        __
//   \\__/ o\    (C) 2006-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpDecomp128Reg.v
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

import fp128Pkg::*;

module fpDecomp128(i, sgn, exp, man, fract, xz, mz, vz, inf, xinf, qnan, snan, nan);
input FP128 i;
output sgn;
output [fp128Pkg::EMSB:0] exp;
output [fp128Pkg::FMSB:0] man;
output [fp128Pkg::FMSB+1:0] fract;	// mantissa with hidden bit recovered
output xz;		// denormalized - exponent is zero
output mz;		// mantissa is zero
output vz;		// value is zero (both exponent and mantissa are zero)
output inf;		// all ones exponent, zero mantissa
output xinf;	// all ones exponent
output qnan;	// nan
output snan;	// signalling nan
output nan;

// Decompose input
assign sgn = i.sign;
assign exp = i.exp;
assign man = i.sig;
assign xz = !(|exp);	// denormalized - exponent is zero
assign mz = !(|man);	// mantissa is zero
assign vz = xz & mz;	// value is zero (both exponent and mantissa are zero)
assign inf = &exp & mz;	// all ones exponent, zero mantissa
assign xinf = &exp;
assign qnan = &exp &  man[fp128Pkg::FMSB];
assign snan = &exp & !man[fp128Pkg::FMSB] & !mz;
assign nan = &exp & !mz;
assign fract = {!xz,i.sig};

endmodule


module fpDecomp128Reg(clk, ce, i, o, sgn, exp, man, fract, xz, mz, vz, inf, xinf, qnan, snan, nan);
input clk;
input ce;
input FP128 i;

output reg FP128 o;
output reg sgn;
output reg [fp128Pkg::EMSB:0] exp;
output reg [fp128Pkg::FMSB:0] man;
output reg [fp128Pkg::FMSB+1:0] fract;	// mantissa with hidden bit recovered
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
		sgn = i.sign;
		exp = i.exp;
		man = i.sig;
		xz = !(|exp);	// denormalized - exponent is zero
		mz = !(|man);	// mantissa is zero
		vz = xz & mz;	// value is zero (both exponent and mantissa are zero)
		inf = &exp & mz;	// all ones exponent, zero mantissa
		xinf = &exp;
		qnan = &exp &  man[fp128Pkg::FMSB];
		snan = &exp & !man[fp128Pkg::FMSB] & !mz;
		nan = &exp & !mz;
		fract = {|exp,i.sig};
	end

endmodule
