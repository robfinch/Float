// ============================================================================
//        __
//   \\__/ o\    (C) 2013-2023  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
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

module fpCordic(rst, clk, arctan, ld, phase_i, xval_i, yval_i, xval_o, yval_o, phase_o, done);
parameter NSTAGES = 54;
parameter IW = 54;
parameter OW = 54;
parameter WW = 60;
parameter PW = 60;
parameter INV_GAIN = 54'h26dd3b6a10d798;	// 2^54 / gain
input rst;
input clk;
input arctan;
input ld;
input [PW-1:0] phase_i;
input [IW-1:0] xval_i;
input [IW-1:0] yval_i;
output reg [OW-1:0] xval_o;
output reg [OW-1:0] yval_o;
output reg [PW-1:0] phase_o;
output done;

integer nn;
wire [WW-1:0] cordic_angle [0:NSTAGES+2];
assign cordic_angle[0] = 60'h200000000000000; // 45.000000000000000000000000 deg
assign cordic_angle[1] = 60'h12e4051d9df3080; // 26.565051177077990018915443 deg
assign cordic_angle[2] = 60'h09fb385b5ee39e8; // 14.036243467926476924390045 deg
assign cordic_angle[3] = 60'h051111d41ddd9a4; // 7.125016348901797691439697 deg
assign cordic_angle[4] = 60'h028b0d430e589b0; // 3.576334374997351517322386 deg
assign cordic_angle[5] = 60'h0145d7e15904628; // 1.789910608246069401161549 deg
assign cordic_angle[6] = 60'h00a2f61e5c28263; // 0.895173710211074391551733 deg
assign cordic_angle[7] = 60'h00517c5511d442b; // 0.447614170860553051145558 deg
assign cordic_angle[8] = 60'h0028be5346d0c33; // 0.223810500368538084492442 deg
assign cordic_angle[9] = 60'h00145f2ebb30ab3; // 0.111905677066206896141942 deg
assign cordic_angle[10] = 60'h000a2f980091ba7; // 0.055952891893803667622276 deg
assign cordic_angle[11] = 60'h000517cc14a80cb; // 0.027976452617003676193175 deg
assign cordic_angle[12] = 60'h00028be60cdfec6; // 0.013988227142265016386680 deg
assign cordic_angle[13] = 60'h000145f306c172f; // 0.006994113675352918273187 deg
assign cordic_angle[14] = 60'h0000a2f9836ae91; // 0.003497056850704011263936 deg
assign cordic_angle[15] = 60'h0000517cc1b6ba7; // 0.001748528426980449539466 deg
assign cordic_angle[16] = 60'h000028be60db85f; // 0.000874264213693780258170 deg
assign cordic_angle[17] = 60'h0000145f306dc81; // 0.000437132106872334565140 deg
assign cordic_angle[18] = 60'h00000a2f9836e4a; // 0.000218566053439347843853 deg
assign cordic_angle[19] = 60'h00000517cc1b726; // 0.000109283026720071498863 deg
assign cordic_angle[20] = 60'h0000028be60db93; // 0.000054641513360085439772 deg
assign cordic_angle[21] = 60'h00000145f306dc9; // 0.000027320756680048933720 deg
assign cordic_angle[22] = 60'h000000a2f9836e4; // 0.000013660378340025242742 deg
assign cordic_angle[23] = 60'h000000517cc1b72; // 0.000006830189170012718780 deg
assign cordic_angle[24] = 60'h00000028be60db9; // 0.000003415094585006371248 deg
assign cordic_angle[25] = 60'h000000145f306dc; // 0.000001707547292503187107 deg
assign cordic_angle[26] = 60'h0000000a2f9836e; // 0.000000853773646251593765 deg
assign cordic_angle[27] = 60'h0000000517cc1b7; // 0.000000426886823125796935 deg
assign cordic_angle[28] = 60'h000000028be60db; // 0.000000213443411562898468 deg
assign cordic_angle[29] = 60'h0000000145f306d; // 0.000000106721705781449234 deg
assign cordic_angle[30] = 60'h00000000a2f9836; // 0.000000053360852890724617 deg
assign cordic_angle[31] = 60'h00000000517cc1b; // 0.000000026680426445362308 deg
assign cordic_angle[32] = 60'h0000000028be60d; // 0.000000013340213222681154 deg
assign cordic_angle[33] = 60'h00000000145f306; // 0.000000006670106611340577 deg
assign cordic_angle[34] = 60'h000000000a2f983; // 0.000000003335053305670289 deg
assign cordic_angle[35] = 60'h000000000517cc1; // 0.000000001667526652835144 deg
assign cordic_angle[36] = 60'h00000000028be60; // 0.000000000833763326417572 deg
assign cordic_angle[37] = 60'h000000000145f30; // 0.000000000416881663208786 deg
assign cordic_angle[38] = 60'h0000000000a2f98; // 0.000000000208440831604393 deg
assign cordic_angle[39] = 60'h0000000000517cc; // 0.000000000104220415802197 deg
assign cordic_angle[40] = 60'h000000000028be6; // 0.000000000052110207901098 deg
assign cordic_angle[41] = 60'h0000000000145f3; // 0.000000000026055103950549 deg
assign cordic_angle[42] = 60'h00000000000a2f9; // 0.000000000013027551975275 deg
assign cordic_angle[43] = 60'h00000000000517c; // 0.000000000006513775987637 deg
assign cordic_angle[44] = 60'h0000000000028be; // 0.000000000003256887993819 deg
assign cordic_angle[45] = 60'h00000000000145f; // 0.000000000001628443996909 deg
assign cordic_angle[46] = 60'h000000000000a2f; // 0.000000000000814221998455 deg
assign cordic_angle[47] = 60'h000000000000517; // 0.000000000000407110999227 deg
assign cordic_angle[48] = 60'h00000000000028b; // 0.000000000000203555499614 deg
assign cordic_angle[49] = 60'h000000000000145; // 0.000000000000101777749807 deg
assign cordic_angle[50] = 60'h0000000000000a2; // 0.000000000000050888874903 deg
assign cordic_angle[51] = 60'h000000000000051; // 0.000000000000025444437452 deg
assign cordic_angle[52] = 60'h000000000000028; // 0.000000000000012722218726 deg
assign cordic_angle[53] = 60'h000000000000014; // 0.000000000000006361109363 deg
//gain: 1.646760258121065412240114
//2^54/gain: 10939296367302552.000000000000000000000000
//0026dd3b6a10d798

reg [7:0] cnt;
wire	signed [(WW-1):0]	e_xval, e_yval;
// Declare variables for all of the separate stages
reg	signed [WW-1:0]	xv [0:5];
reg	signed [WW-1:0]	yv [0:5];
reg [PW:0] ph [0:5];
reg	signed [WW-1:0]	xv5, yv5;
reg [PW:0] ph5;
reg [2:0] cr_rot;
 
assign	e_xval = { {xval_i[(IW-1)]}, xval_i, {(WW-IW-1){1'b0}} };
assign	e_yval = { {yval_i[(IW-1)]}, yval_i, {(WW-IW-1){1'b0}} };

// Round our result towards even
wire	[WW-1:0]	pre_xval, pre_yval;

assign	pre_xval = xv[4] + {{(OW){1'b0}},xv[4][(WW-OW)],{(WW-OW-1){!xv[4][WW-OW]}}};
assign	pre_yval = yv[4] + {{(OW){1'b0}},yv[4][(WW-OW)],{(WW-OW-1){!yv[4][WW-OW]}}};

always_ff @(posedge clk, posedge rst)
if (rst)
	cnt <= 'd0;
else begin
	if (ld)
		cnt <= 'd0;
	else if (!done)
		cnt <= cnt + 2'd2;
end

assign done = cnt==8'd64;

// cnt equals 10 for the first iteration.
always_comb
	if (arctan ? ~yv[4][WW-1] : ph[4][PW]) // Negative phase
	begin
		// If the phase is negative, rotate by the
		// CORDIC angle in a clockwise direction.
		xv5 = xv[4] + (yv[4] >>> (cnt - 8'd10));
		yv5 = yv[4] - (xv[4] >>> (cnt - 8'd10));
		ph5 = ph[4] + cordic_angle[cnt-8'd10];

	end
	else begin
		// On the other hand, if the phase is
		// positive ... rotate in the
		// counter-clockwise direction
		xv5 = xv[4] - (yv[4] >>> (cnt - 8'd10));
		yv5 = yv[4] + (xv[4] >>> (cnt - 8'd10));
		ph5 = ph[4] - cordic_angle[cnt-8'd10];
	end

always_ff @(posedge clk, posedge rst)
if (rst) begin
	xval_o <= 'd0;
	yval_o <= 'd0;
	phase_o <= 'd0;
	for (nn = 0; nn < 6; nn = nn + 1) begin
		xv[nn] <= 'd0;
		yv[nn] <= 'd0;
		ph[nn] <= 'd0;
	end
end
else begin
	if (ld) begin
		if (arctan) begin
		// First stage, map to within +/- 45 degrees
			case({xval_i[IW-1], yval_i[IW-1]})
			2'b01: begin // Rotate by -315 degrees
				xv[0] <=  e_xval - e_yval;
				yv[0] <=  e_xval + e_yval;
				ph[0] <= 60'hE00000000000000;
				end
			2'b10: begin // Rotate by -135 degrees
				xv[0] <= -e_xval + e_yval;
				yv[0] <= -e_xval - e_yval;
				ph[0] <= 60'h300000000000000;
				end
			2'b11: begin // Rotate by -225 degrees
				xv[0] <= -e_xval - e_yval;
				yv[0] <=  e_xval - e_yval;
				ph[0] <= 60'h500000000000000;	// 19'h50000;
				end
			// 2'b00:
			default: begin // Rotate by -45 degrees
				xv[0] <=  e_xval + e_yval;
				yv[0] <= -e_xval + e_yval;
				ph[0] <= 60'h100000000000000;
				end
			endcase
		end
		else begin
			cr_rot <= phase_i[(PW-1):(PW-3)];
			case(phase_i[(PW-1):(PW-3)])
			3'b000:
				begin	// 0 .. 45, No change 270 .. 360
					xv[0] <= e_xval;
					yv[0] <= e_yval;
					ph[0] <= phase_i;
				end
			3'b001,3'b010:
				begin	// 45 .. 90, 90 .. 135
					xv[0] <= -e_yval;
					yv[0] <= e_xval;
					ph[0] <= phase_i - 60'h400000000000000;
				end
			3'b011:
				begin	// 135 .. 180, 180 .. 225
					xv[0] <= -e_xval;
					yv[0] <= -e_yval;
					ph[0] <= phase_i - 60'h800000000000000;
				end
			3'b100:
				begin	// 180 .. 225
					xv[0] <= -e_xval;
					yv[0] <= -e_yval;
					ph[0] <= phase_i - 60'h800000000000000;
				end
			3'b101,3'b110:
				begin	// 225 .. 270, 270 .. 315
					xv[0] <= e_yval;
					yv[0] <= -e_xval;
					ph[0] <= phase_i - 60'hC00000000000000;
				end
			3'b111:
				begin	// 315 .. 360, No change
					xv[0] <= e_xval;
					yv[0] <= e_yval;
					ph[0] <= phase_i;
					ph[0][PW] <= 1'b1;	// Make phase negative
				end
			endcase
		end
	end
	xv[1] <= ({{60{xv[0][WW-1]}},xv[0]} * INV_GAIN) >>> 8'd54;
	yv[1] <= ({{60{yv[0][WW-1]}},yv[0]} * INV_GAIN) >>> 8'd54;
	ph[1] <= ph[0];
	xv[2] <= xv[1];
	yv[2] <= yv[1];
	ph[2] <= ph[1];
	xv[3] <= xv[2];
	yv[3] <= yv[2];
	ph[3] <= ph[2];
	if (cnt <= 6'd8) begin
		xv[4] <= xv[3];
		yv[4] <= yv[3];
		ph[4] <= ph[3];
	end
	else if (cnt > 6'd8 && cnt < 8'd60) begin
		if (arctan ? ~yv5[WW-1] : ph5[PW]) // Negative phase
		begin
			// If the phase is negative, rotate by the
			// CORDIC angle in a clockwise direction.
			xv[4] <= xv5 + (yv5 >>> (cnt - 8'd9));
			yv[4] <= yv5 - (xv5 >>> (cnt - 8'd9));
			ph[4] <= ph5 + cordic_angle[cnt-8'd9];

		end
		else begin
			// On the other hand, if the phase is
			// positive ... rotate in the
			// counter-clockwise direction
			xv[4] <= xv5 - (yv5 >>> (cnt - 8'd9));
			yv[4] <= yv5 + (xv5 >>> (cnt - 8'd9));
			ph[4] <= ph5 - cordic_angle[cnt-8'd9];
		end
	end
	else if (cnt==8'd60) begin
		xv[4] <= xv[4];//({{54{xv[4][WW-1]}},xv[4]} * INV_GAIN) >>> 8'd54;
		yv[4] <= yv[4];//({{54{xv[4][WW-1]}},yv[4]} * INV_GAIN) >>> 8'd54;
		ph[4] <= ph[4];
	end
	else if (cnt==8'd62) begin
		xval_o <= pre_xval[(WW-1):(WW-OW)];
		yval_o <= pre_yval[(WW-1):(WW-OW)];
		phase_o <= ph[4];
	end
	/*
	else if (cnt==8'd64) begin
		case(cr_rot)
		3'd0,3'd7:	
			begin
				xval_o <= xval_o;
				yval_o <= yval_o;
				phase_o <= phase_o;
				phase_o[PW] <= 1'b0;
			end
		3'd1,3'd2:
			begin
				xval_o <= xval_o;
				yval_o <= yval_o;
				phase_o <= phase_o + 60'h400000000000000;
			end
		3'd3:
			begin
				xval_o <= xval_o;
				yval_o <= yval_o;
				phase_o <= phase_o + 60'h800000000000000;
			end
		3'd4:
			begin
				xval_o <= xval_o;
				yval_o <= yval_o;
				phase_o <= phase_o + 60'h800000000000000;
			end
		3'd5,3'd6:
			begin
				xval_o <= xval_o;
				yval_o <= yval_o;
				phase_o <= phase_o + 60'hC00000000000000;
			end
		endcase
	end
	*/
end

endmodule
