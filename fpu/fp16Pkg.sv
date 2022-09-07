// ============================================================================
//        __
//   \\__/ o\    (C) 2020-2022  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//	fp16Pkg.sv
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

package fp16Pkg;

`define FPWID   16

`define	QINFOS		10'h3F0		// info
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

`define	QSUBINFS	16'b0111111000000001	// - infinity - infinity
`define QINFDIVS	16'b0111111000000010	// - infinity / infinity
`define QZEROZEROS	16'b0111111000000011	// - zero / zero
`define QINFZEROS	16'b0111111000000100	// - infinity X zero
`define QSQRTINFS	16'b0111111000000101	// - square root of infinity
`define QSQRTNEGS	16'b0111111000000110	// - square root of negaitve number

`define	POINT5S		16'b0011110000000000
`define ZEROS			16'b0000000000000000

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
localparam EMSB = 4;
localparam FMSB = 9;
localparam FX = (FMSB+2)*2;	// the MSB of the expanded fraction
localparam EX = FX + 1 + EMSB + 1 + 1 - 1;

typedef struct packed
{
	logic sign;
	logic [EMSB:0] exp;
	logic [FMSB:0] sig;
} FP16;

typedef struct packed
{
	logic sign;
	logic [EMSB:0] exp;
	logic [FX:0] sig;
} FP16X;

// Normalizer output, three extra significand bits

typedef struct packed
{
	logic sign;
	logic [EMSB:0] exp;
	logic [FMSB+3:0] sig;
} FP16N;

endpackage
