// ============================================================================
//        __
//   \\__/ o\    (C) 2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fp96Pkg.sv
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
//

package fp96Pkg;

`define FPWID   96

`define	QINFOS		23'h7FC000		// info
`define QSUBINF		4'd1
`define QINFDIV		4'd2
`define QZEROZERO	4'd3
`define QINFZERO	4'd4
`define QSQRTINF	4'd5
`define QSQRTNEG	4'd6

parameter QINFDIV		= 4'd2;
parameter QZEROZERO	= 4'd3;
parameter QSQRTINF	= 4'd5;
parameter QSQRTNEG	= 4'd6;

`define	QINFOQ		80'hFF800000_0000000000_00		// info
`define	QSUBINFQ 	95'h7F_FF00000000_00_0000000001	// - infinity - infinity
`define QINFDIVQ 	95'h7F_FF00000000_00_0000000002	// - infinity / infinity
`define QZEROZEROQ  95'h7F_FF00000000_00_0000000003	// - zero / zero
`define QINFZEROQ	95'h7F_FF00000000_00_0000000004	// - infinity X zero
`define QSQRTINFQ	95'h7F_FF00000000_00_0000000005	// - square root of infinity
`define QSQRTNEGQ	95'h7F_FF00000000_00_0000000006	// - square root of negaitve number

`define AIN			3'd0
`define BIN			3'd1
`define CIN			3'd2
`define RES			3'd3
`define POINT5	3'd4
`define ZERO		3'd5

`define SUPPORT_DENORMALS   1'b1
//`define MIN_LATENCY		1'b1

parameter FPWID = `FPWID;

// This file contains defintions for fields to ease dealing with different fp
// widths. Some of the code still needs to be modified to support widths
// other than standard 32,64 or 80 bit.
localparam MSB = FPWID-1;
localparam EMSB = 14;
localparam FMSB = 79;
localparam FX = (FMSB+2)*2;	// the MSB of the expanded fraction
localparam EX = FX + 1 + EMSB + 1 + 1 - 1;

typedef struct packed
{
	logic sign;
	logic [EMSB:0] exp;
	logic [FMSB:0] sig;
} FP96;

// Intermediate expanded significand (2x+)

typedef struct packed
{
	logic sign;
	logic [EMSB:0] exp;
	logic [FX:0] sig;
} FP96X;

// Normalizer output, three extra significand bits

typedef struct packed
{
	logic sign;
	logic [EMSB:0] exp;
	logic [FMSB+3:0] sig;
} FP96N;

endpackage
