// ============================================================================
//        __
//   \\__/ o\    (C) 2006-2023  Robert Finch, Waterloo
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
//
import fp64Pkg::*;

module fpRes64(clk, ce, a, o);
input clk;
input ce;
input FP64 a;
output FP64 o;

reg [19:0] cres256;
(* ram_style="block" *)
reg [19:0] cres [0:255];
initial begin
cres[0]=20'hfffff;
cres[1]=20'hfe03f;
cres[2]=20'hfc0bd;
cres[3]=20'hfa17a;
cres[4]=20'hf8273;
cres[5]=20'hf63aa;
cres[6]=20'hf451c;
cres[7]=20'hf26c9;
cres[8]=20'hf08b1;
cres[9]=20'heead3;
cres[10]=20'hecd2e;
cres[11]=20'heafc2;
cres[12]=20'he928e;
cres[13]=20'he7592;
cres[14]=20'he58cc;
cres[15]=20'he3c3c;
cres[16]=20'he1fe1;
cres[17]=20'he03bc;
cres[18]=20'hde7cb;
cres[19]=20'hdcc0e;
cres[20]=20'hdb085;
cres[21]=20'hd952e;
cres[22]=20'hd7a09;
cres[23]=20'hd5f15;
cres[24]=20'hd4453;
cres[25]=20'hd29c2;
cres[26]=20'hd0f60;
cres[27]=20'hcf52e;
cres[28]=20'hcdb2c;
cres[29]=20'hcc157;
cres[30]=20'hca7b1;
cres[31]=20'hc8e38;
cres[32]=20'hc74ed;
cres[33]=20'hc5bce;
cres[34]=20'hc42db;
cres[35]=20'hc2a15;
cres[36]=20'hc1179;
cres[37]=20'hbf908;
cres[38]=20'hbe0c2;
cres[39]=20'hbc8a6;
cres[40]=20'hbb0b3;
cres[41]=20'hb98e9;
cres[42]=20'hb8148;
cres[43]=20'hb69d0;
cres[44]=20'hb527f;
cres[45]=20'hb3b56;
cres[46]=20'hb2454;
cres[47]=20'hb0d79;
cres[48]=20'haf6c4;
cres[49]=20'hae035;
cres[50]=20'hac9cc;
cres[51]=20'hab388;
cres[52]=20'ha9d69;
cres[53]=20'ha876e;
cres[54]=20'ha7198;
cres[55]=20'ha5be5;
cres[56]=20'ha4656;
cres[57]=20'ha30ea;
cres[58]=20'ha1ba1;
cres[59]=20'ha067b;
cres[60]=20'h9f176;
cres[61]=20'h9dc94;
cres[62]=20'h9c7d3;
cres[63]=20'h9b333;
cres[64]=20'h99eb4;
cres[65]=20'h98a55;
cres[66]=20'h97617;
cres[67]=20'h961f9;
cres[68]=20'h94dfb;
cres[69]=20'h93a1c;
cres[70]=20'h9265c;
cres[71]=20'h912bb;
cres[72]=20'h8ff38;
cres[73]=20'h8ebd4;
cres[74]=20'h8d88e;
cres[75]=20'h8c565;
cres[76]=20'h8b25a;
cres[77]=20'h89f6c;
cres[78]=20'h88c9b;
cres[79]=20'h879e7;
cres[80]=20'h8674f;
cres[81]=20'h854d4;
cres[82]=20'h84274;
cres[83]=20'h83030;
cres[84]=20'h81e07;
cres[85]=20'h80bfa;
cres[86]=20'h7fa07;
cres[87]=20'h7e82f;
cres[88]=20'h7d672;
cres[89]=20'h7c4cf;
cres[90]=20'h7b346;
cres[91]=20'h7a1d6;
cres[92]=20'h79081;
cres[93]=20'h77f44;
cres[94]=20'h76e21;
cres[95]=20'h75d17;
cres[96]=20'h74c25;
cres[97]=20'h73b4c;
cres[98]=20'h72a8b;
cres[99]=20'h719e3;
cres[100]=20'h70952;
cres[101]=20'h6f8d9;
cres[102]=20'h6e877;
cres[103]=20'h6d82d;
cres[104]=20'h6c7fa;
cres[105]=20'h6b7de;
cres[106]=20'h6a7d8;
cres[107]=20'h697e9;
cres[108]=20'h68810;
cres[109]=20'h6784e;
cres[110]=20'h668a1;
cres[111]=20'h6590b;
cres[112]=20'h6498a;
cres[113]=20'h63a1e;
cres[114]=20'h62ac8;
cres[115]=20'h61b86;
cres[116]=20'h60c5a;
cres[117]=20'h5fd43;
cres[118]=20'h5ee40;
cres[119]=20'h5df51;
cres[120]=20'h5d077;
cres[121]=20'h5c1b1;
cres[122]=20'h5b2ff;
cres[123]=20'h5a461;
cres[124]=20'h595d6;
cres[125]=20'h5875f;
cres[126]=20'h578fb;
cres[127]=20'h56aaa;
cres[128]=20'h55c6d;
cres[129]=20'h54e42;
cres[130]=20'h5402a;
cres[131]=20'h53224;
cres[132]=20'h52432;
cres[133]=20'h51651;
cres[134]=20'h50882;
cres[135]=20'h4fac6;
cres[136]=20'h4ed1c;
cres[137]=20'h4df83;
cres[138]=20'h4d1fc;
cres[139]=20'h4c486;
cres[140]=20'h4b722;
cres[141]=20'h4a9cf;
cres[142]=20'h49c8d;
cres[143]=20'h48f5c;
cres[144]=20'h4823c;
cres[145]=20'h4752c;
cres[146]=20'h4682d;
cres[147]=20'h45b3f;
cres[148]=20'h44e61;
cres[149]=20'h44193;
cres[150]=20'h434d5;
cres[151]=20'h42828;
cres[152]=20'h41b8a;
cres[153]=20'h40efc;
cres[154]=20'h4027d;
cres[155]=20'h3f60e;
cres[156]=20'h3e9af;
cres[157]=20'h3dd5f;
cres[158]=20'h3d11e;
cres[159]=20'h3c4ec;
cres[160]=20'h3b8c9;
cres[161]=20'h3acb5;
cres[162]=20'h3a0af;
cres[163]=20'h394b9;
cres[164]=20'h388d1;
cres[165]=20'h37cf7;
cres[166]=20'h3712c;
cres[167]=20'h3656f;
cres[168]=20'h359c0;
cres[169]=20'h34e1f;
cres[170]=20'h3428c;
cres[171]=20'h33707;
cres[172]=20'h32b8f;
cres[173]=20'h32026;
cres[174]=20'h314c9;
cres[175]=20'h3097b;
cres[176]=20'h2fe39;
cres[177]=20'h2f305;
cres[178]=20'h2e7df;
cres[179]=20'h2dcc5;
cres[180]=20'h2d1b8;
cres[181]=20'h2c6b8;
cres[182]=20'h2bbc5;
cres[183]=20'h2b0df;
cres[184]=20'h2a605;
cres[185]=20'h29b38;
cres[186]=20'h29078;
cres[187]=20'h285c4;
cres[188]=20'h27b1c;
cres[189]=20'h27080;
cres[190]=20'h265f1;
cres[191]=20'h25b6d;
cres[192]=20'h250f6;
cres[193]=20'h2468a;
cres[194]=20'h23c2b;
cres[195]=20'h231d7;
cres[196]=20'h2278e;
cres[197]=20'h21d52;
cres[198]=20'h21321;
cres[199]=20'h208fb;
cres[200]=20'h1fee1;
cres[201]=20'h1f4d2;
cres[202]=20'h1eace;
cres[203]=20'h1e0d5;
cres[204]=20'h1d6e8;
cres[205]=20'h1cd05;
cres[206]=20'h1c32d;
cres[207]=20'h1b961;
cres[208]=20'h1af9f;
cres[209]=20'h1a5e7;
cres[210]=20'h19c3b;
cres[211]=20'h19299;
cres[212]=20'h18901;
cres[213]=20'h17f74;
cres[214]=20'h175f1;
cres[215]=20'h16c79;
cres[216]=20'h1630b;
cres[217]=20'h159a7;
cres[218]=20'h1504d;
cres[219]=20'h146fd;
cres[220]=20'h13db8;
cres[221]=20'h1347c;
cres[222]=20'h12b4a;
cres[223]=20'h12222;
cres[224]=20'h11903;
cres[225]=20'h10fef;
cres[226]=20'h106e3;
cres[227]=20'hfde2;
cres[228]=20'hf4ea;
cres[229]=20'hebfb;
cres[230]=20'he316;
cres[231]=20'hda3a;
cres[232]=20'hd168;
cres[233]=20'hc89e;
cres[234]=20'hbfde;
cres[235]=20'hb727;
cres[236]=20'hae79;
cres[237]=20'ha5d4;
cres[238]=20'h9d38;
cres[239]=20'h94a5;
cres[240]=20'h8c1a;
cres[241]=20'h8399;
cres[242]=20'h7b20;
cres[243]=20'h72b0;
cres[244]=20'h6a48;
cres[245]=20'h61e9;
cres[246]=20'h5993;
cres[247]=20'h5145;
cres[248]=20'h48ff;
cres[249]=20'h40c2;
cres[250]=20'h388d;
cres[251]=20'h3060;
cres[252]=20'h283c;
cres[253]=20'h2020;
cres[254]=20'h180c;
cres[255]=20'h1000;
cres256=20'h007fc;
end

wire [fp64Pkg::EMSB:0] xa;
wire [fp64Pkg::FMSB:0] ma;
reg [fp64Pkg::FMSB:0] ma3;
wire nan;
reg nan3;
fpDecomp64 u1 (.i(a), .sgn(sa), .exp(xa), .man(ma), .fract(), .xz(), .vz(), .xinf(), .inf(), .nan(nan) );

wire signed [fp64Pkg::EMSB+1:0] bias = {1'b0,{fp64Pkg::EMSB{1'b1}}};
wire signed [fp64Pkg::EMSB+1:0] x1 = xa - bias;
wire signed [fp64Pkg::EMSB+1:0] exp = nan ? xa : bias - x1 - 2'd1;	// make exponent negative
wire sa3;
wire signed [fp64Pkg::EMSB+1:0] exp3;
wire [9:0] index = ma[fp64Pkg::FMSB:fp64Pkg::FMSB-7];
reg [20:0] k0, k1;
always_comb
	k0 = {1'b1,cres[index]};
always_comb
	k1 = {1'b1,index==8'd255 ? cres256 : cres[index+1]};
delay1 #(fp64Pkg::EMSB+2) u3 (.clk(clk), .ce(ce), .i(exp), .o(exp3));
delay1 #(1) u4 (.clk(clk), .ce(ce), .i(sa), .o(sa3));
wire [7:0] eps = ma[fp64Pkg::FMSB-8:fp64Pkg::FMSB-8-8];
wire [28:0] p = k1 * eps;
reg [20:0] r0;
reg [20:-2] r1;
always_ff @(posedge clk)
	if(ce) r0 <= k0 - (p >> 5'd18);
always_comb
	r1 = exp3[fp64Pkg::EMSB+1] ? r0 >> -exp3 : r0;
always_ff @(posedge clk)
	if (ce) ma3 <= ma;
always_ff @(posedge clk)
	if (ce) nan3 <= nan;
		
assign o.sign = sa3;
assign o.exp = exp3[fp64Pkg::EMSB+1] ? 'd0 : exp3;
assign o.sig = (exp3[fp64Pkg::EMSB+1] || exp3=='d0) ? {r1[20:-2],{fp64Pkg::FMSB-20{1'b0}}} : nan3 ? ma3 : {r1[20:-2],{fp64Pkg::FMSB-19{1'b0}}};

endmodule

