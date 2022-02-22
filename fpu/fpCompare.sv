// ============================================================================
//        __
//   \\__/ o\    (C) 2007-2021  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpCompare.sv
//    - floating point comparison unit
//    - parameterized width
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

import fp::*;

module fpCompare(a, b, o, nan, snan);
input [FPWID-1:0] a, b;
output [63:0] o;
reg [63:0] o;
output nan;
output snan;

// Decompose the operands
wire sa;
wire sb;
wire [EMSB:0] xa;
wire [EMSB:0] xb;
wire [FMSB:0] ma;
wire [FMSB:0] mb;
wire az, bz;
wire nan_a, nan_b;

fpDecomp u1(.i(a), .sgn(sa), .exp(xa), .man(ma), .vz(az), .qnan(), .snan(), .nan(nan_a) );
fpDecomp u2(.i(b), .sgn(sb), .exp(xb), .man(mb), .vz(bz), .qnan(), .snan(), .nan(nan_b) );

wire unordered = nan_a | nan_b;

wire eq = !unordered & ((az & bz) || (a==b));	// special test for zero
wire gt1 = {xa,ma} > {xb,mb};
wire lt1 = {xa,ma} < {xb,mb};

wire lt = sa ^ sb ? sa & !(az & bz): sa ? gt1 : lt1;

always @(unordered or eq or lt or lt1)
begin
	o[0] = eq;
	o[1] = lt;
	o[2] = lt|eq;
	o[3] = lt1;
	o[4] = unordered;
	o[7:5] = 3'd0;
	o[8] = ~eq;
	o[9] = ~lt;
	o[10] = ~(lt|eq);
	o[11] = ~lt1;
	o[12] = ~unordered;
	o[62:13] = 50'd0;
	o[63] = lt;
end

// an unorder comparison will signal a nan exception
//assign nanx = op!=`FCOR && op!=`FCUN && unordered;
assign nan = nan_a|nan_b;
assign snan = (nan_a & ~ma[FMSB]) | (nan_b & ~mb[FMSB]);

endmodule
