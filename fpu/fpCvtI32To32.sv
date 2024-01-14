// ============================================================================
//        __
//   \\__/ o\    (C) 2022-2024  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fpCvtI32To32.sv
//  - convert integer to floating point
//  - parameterized width
//  - IEEE 754 representation
//  - pipelineable
//  - single cycle latency
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

import fp32Pkg::*;

module fpCvtI32To32 (clk, ce, op, rm, i, o, inexact);
input clk;
input ce;
input op;						// 1 = signed, 0 = unsigned
input [2:0] rm;			// rounding mode
input [fp32Pkg::FPWID-1:0] i;		// integer input
output FP32 o;		// float output
output reg inexact;

wire [fp32Pkg::EMSB:0] zeroXp = {fp32Pkg::EMSB{1'b1}};

wire iz;			// zero input ?
wire [fp32Pkg::MSB:0] imag;	// get magnitude of i
wire [fp32Pkg::MSB:0] imag1 = (op & i[fp32Pkg::MSB]) ? -i : i;
wire [5:0] lz;		// count the leading zeros in the number
wire [fp32Pkg::EMSB:0] wd;	// compute number of whole digits
wire so;			// copy the sign of the input (easy)
wire [2:0] rmd;

delay1 #(3)   u0 (.clk(clk), .ce(ce), .i(rm),     .o(rmd) );
delay1 #(1)   u1 (.clk(clk), .ce(ce), .i(i==0),   .o(iz) );
delay1 #(fp32Pkg::FPWID) u2 (.clk(clk), .ce(ce), .i(imag1),  .o(imag) );
delay1 #(1)   u3 (.clk(clk), .ce(ce), .i(i[fp32Pkg::FPWID-1]), .o(so) );
cntlz32Reg    u4 (.clk(clk), .ce(ce), .i(imag1), .o(lz[5:0]) );

assign wd = zeroXp - 1 + fp32Pkg::FPWID - lz;	// constant except for lz

wire [fp32Pkg::EMSB:0] xo = iz ? 0 : wd;
wire [fp32Pkg::MSB:0] simag = imag << lz;		// left align number

wire g =  simag[fp32Pkg::EMSB+2];	// guard bit (lsb)
wire r =  simag[fp32Pkg::EMSB+1];	// rounding bit
wire s = |simag[fp32Pkg::EMSB:0];	// "sticky" bit
always_comb
	inexact = r|s;
reg rnd;

// Compute the round bit
always_comb
	case (rmd)
	3'd0:	rnd = (g & r) | (r & s);	// round to nearest even
	3'd1:	rnd = 0;					// round to zero (truncate)
	3'd2:	rnd = (r | s) & !so;		// round towards +infinity
	3'd3:	rnd = (r | s) & so;			// round towards -infinity
	3'd4:   rnd = (r | s);
	default:	rnd = (g & r) | (r & s);	// round to nearest even
	endcase

// "hide" the leading one bit = MSB-1
// round the result
wire [fp32Pkg::FMSB:0] mo = simag[fp32Pkg::MSB-1:fp32Pkg::EMSB+1]+rnd;

assign o.sign = op & so;
assign o.exp = xo;
assign o.sig = mo;

endmodule
