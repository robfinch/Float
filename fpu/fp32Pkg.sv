// ============================================================================
//        __
//   \\__/ o\    (C) 2020-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fp32Pkg.sv
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
//

package fp32Pkg;

`define FPWID   32

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

`define	QSUBINFS	31'h7FC00001	// - infinity - infinity
`define QINFDIVS	31'h7FC00002	// - infinity / infinity
`define QZEROZEROS	31'h7FC00003	// - zero / zero
`define QINFZEROS	31'h7FC00004	// - infinity X zero
`define QSQRTINFS	31'h7FC00005	// - square root of infinity
`define QSQRTNEGS	31'h7FC00006	// - square root of negaitve number

`define	POINT5S		32'h3F000000
`define ZEROS			32'h00000000

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
localparam EMSB = 7;
localparam FMSB = 22;
localparam FX = (FMSB+2)*2;	// the MSB of the expanded fraction
localparam EX = FX + 1 + EMSB + 1 + 1 - 1;

typedef struct packed
{
	logic sign;
	logic [EMSB:0] exp;
	logic [FMSB:0] sig;
} FP32;

typedef struct packed
{
	logic sign;
	logic [EMSB:0] exp;
	logic [FX:0] sig;
} FP32X;

// Normalizer output, three extra significand bits

typedef struct packed
{
	logic sign;
	logic [EMSB:0] exp;
	logic [FMSB+3:0] sig;
} FP32N;

endpackage
