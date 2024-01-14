// ============================================================================
//        __
//   \\__/ o\    (C) 2007-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpCompare16.sv
//    - floating point comparison unit
//    - IEEE 754 representation
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

import fp16Pkg::*;

module fpCompare16(a, b, o, nan, snan);
input FP16 a, b;
output [15:0] o;
reg [15:0] o;
output nan;
output snan;

// Decompose the operands
wire sa;
wire sb;
wire [fp16Pkg::EMSB:0] xa;
wire [fp16Pkg::EMSB:0] xb;
wire [fp16Pkg::FMSB:0] ma;
wire [fp16Pkg::FMSB:0] mb;
wire az, bz;
wire nan_a, nan_b;
wire infa, infb;

fpDecomp16 u1(.i(a), .sgn(sa), .exp(xa), .man(ma), .vz(az), .inf(infa), .qnan(), .snan(), .nan(nan_a) );
fpDecomp16 u2(.i(b), .sgn(sb), .exp(xb), .man(mb), .vz(bz), .inf(infb), .qnan(), .snan(), .nan(nan_b) );

wire unordered = nan_a | nan_b;

wire eq = !unordered & ((az & bz) || (a==b));	// special test for zero
wire ne = !((az & bz) || (a==b));	// special test for zero
wire gt1 = ({xa,ma} > {xb,mb}) |infa;
wire lt1 = ({xa,ma} < {xb,mb}) |infb;

wire lt = sa ^ sb ? sa & !(az & bz): sa ? gt1 : lt1;

always_comb
begin
	o = 'd0;
	o[0] = eq;
	o[1] = lt & !unordered;
	o[2] = (lt|eq) & !unordered;
	o[3] = lt1;
	o[4] = unordered;
	o[7:5] = 3'd0;
	o[8] = ne;
	o[9] = ~lt & !unordered;
	o[10] = ~(lt|eq) & !unordered;
	o[11] = ~lt1;
	o[12] = ~unordered;
end

// an unorder comparison will signal a nan exception
//assign nanx = op!=`FCOR && op!=`FCUN && unordered;
assign nan = nan_a|nan_b|(infa & infb);
assign snan = (nan_a & ~ma[fp16Pkg::FMSB]) | (nan_b & ~mb[fp16Pkg::FMSB]);

endmodule
