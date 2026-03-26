// ============================================================================
//        __
//   \\__/ o\    (C) 2006-2026  Robert Finch, Waterloo
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
// exact indicates that no further approximation is required. This could be due
// to special values like divide by zero.
//
// 500 LUTs / 220 FFs
// ============================================================================
//
import fp64Pkg::*;

module fpRes64(clk, ce, dc, a, b, o, exact);
localparam EMSB = fp64Pkg::EMSB;
input clk;
input ce;
input dc;						// divide checks
input FP64 a;
input FP64 b;
output FP64 o;
output reg exact;

(* ram_style="block" *)
reg [28:0] cres [0:1023];
initial begin
cres[0]=24'h1fffff;
cres[1]=24'h1fe01f;
cres[2]=24'h1fc05f;
cres[3]=24'h1fa0be;
cres[4]=24'h1f813c;
cres[5]=24'h1f61da;
cres[6]=24'h1f4296;
cres[7]=24'h1f2372;
cres[8]=24'h1f046c;
cres[9]=24'h1ee584;
cres[10]=24'h1ec6ba;
cres[11]=24'h1ea80f;
cres[12]=24'h1e8982;
cres[13]=24'h1e6b12;
cres[14]=24'h1e4cc0;
cres[15]=24'h1e2e8b;
cres[16]=24'h1e1074;
cres[17]=24'h1df279;
cres[18]=24'h1dd49c;
cres[19]=24'h1db6db;
cres[20]=24'h1d9937;
cres[21]=24'h1d7baf;
cres[22]=24'h1d5e43;
cres[23]=24'h1d40f4;
cres[24]=24'h1d23c1;
cres[25]=24'h1d06a9;
cres[26]=24'h1ce9ad;
cres[27]=24'h1ccccc;
cres[28]=24'h1cb007;
cres[29]=24'h1c935d;
cres[30]=24'h1c76ce;
cres[31]=24'h1c5a5a;
cres[32]=24'h1c3e00;
cres[33]=24'h1c21c2;
cres[34]=24'h1c059d;
cres[35]=24'h1be993;
cres[36]=24'h1bcda3;
cres[37]=24'h1bb1cd;
cres[38]=24'h1b9611;
cres[39]=24'h1b7a6f;
cres[40]=24'h1b5ee6;
cres[41]=24'h1b4377;
cres[42]=24'h1b2821;
cres[43]=24'h1b0ce4;
cres[44]=24'h1af1c0;
cres[45]=24'h1ad6b5;
cres[46]=24'h1abbc3;
cres[47]=24'h1aa0ea;
cres[48]=24'h1a8629;
cres[49]=24'h1a6b80;
cres[50]=24'h1a50f0;
cres[51]=24'h1a3677;
cres[52]=24'h1a1c17;
cres[53]=24'h1a01cf;
cres[54]=24'h19e79e;
cres[55]=24'h19cd85;
cres[56]=24'h19b383;
cres[57]=24'h199999;
cres[58]=24'h197fc6;
cres[59]=24'h19660a;
cres[60]=24'h194c65;
cres[61]=24'h1932d7;
cres[62]=24'h191960;
cres[63]=24'h190000;
cres[64]=24'h18e6b5;
cres[65]=24'h18cd82;
cres[66]=24'h18b464;
cres[67]=24'h189b5d;
cres[68]=24'h18826c;
cres[69]=24'h186991;
cres[70]=24'h1850cb;
cres[71]=24'h18381c;
cres[72]=24'h181f81;
cres[73]=24'h1806fd;
cres[74]=24'h17ee8e;
cres[75]=24'h17d634;
cres[76]=24'h17bdef;
cres[77]=24'h17a5bf;
cres[78]=24'h178da5;
cres[79]=24'h17759f;
cres[80]=24'h175dad;
cres[81]=24'h1745d1;
cres[82]=24'h172e09;
cres[83]=24'h171655;
cres[84]=24'h16feb6;
cres[85]=24'h16e72b;
cres[86]=24'h16cfb4;
cres[87]=24'h16b851;
cres[88]=24'h16a102;
cres[89]=24'h1689c7;
cres[90]=24'h1672a0;
cres[91]=24'h165b8c;
cres[92]=24'h16448c;
cres[93]=24'h162d9f;
cres[94]=24'h1616c6;
cres[95]=24'h160000;
cres[96]=24'h15e94c;
cres[97]=24'h15d2ac;
cres[98]=24'h15bc1f;
cres[99]=24'h15a5a5;
cres[100]=24'h158f3e;
cres[101]=24'h1578e9;
cres[102]=24'h1562a7;
cres[103]=24'h154c77;
cres[104]=24'h15365a;
cres[105]=24'h15204f;
cres[106]=24'h150a56;
cres[107]=24'h14f470;
cres[108]=24'h14de9b;
cres[109]=24'h14c8d9;
cres[110]=24'h14b328;
cres[111]=24'h149d89;
cres[112]=24'h1487fc;
cres[113]=24'h147281;
cres[114]=24'h145d17;
cres[115]=24'h1447be;
cres[116]=24'h143277;
cres[117]=24'h141d41;
cres[118]=24'h14081d;
cres[119]=24'h13f309;
cres[120]=24'h13de07;
cres[121]=24'h13c915;
cres[122]=24'h13b435;
cres[123]=24'h139f65;
cres[124]=24'h138aa6;
cres[125]=24'h1375f7;
cres[126]=24'h13615a;
cres[127]=24'h134ccc;
cres[128]=24'h13384f;
cres[129]=24'h1323e3;
cres[130]=24'h130f86;
cres[131]=24'h12fb3a;
cres[132]=24'h12e6fe;
cres[133]=24'h12d2d2;
cres[134]=24'h12beb6;
cres[135]=24'h12aaaa;
cres[136]=24'h1296ae;
cres[137]=24'h1282c1;
cres[138]=24'h126ee4;
cres[139]=24'h125b17;
cres[140]=24'h124759;
cres[141]=24'h1233ab;
cres[142]=24'h12200c;
cres[143]=24'h120c7c;
cres[144]=24'h11f8fc;
cres[145]=24'h11e58b;
cres[146]=24'h11d229;
cres[147]=24'h11bed6;
cres[148]=24'h11ab92;
cres[149]=24'h11985c;
cres[150]=24'h118536;
cres[151]=24'h11721e;
cres[152]=24'h115f15;
cres[153]=24'h114c1b;
cres[154]=24'h11392f;
cres[155]=24'h112652;
cres[156]=24'h111384;
cres[157]=24'h1100c3;
cres[158]=24'h10ee11;
cres[159]=24'h10db6d;
cres[160]=24'h10c8d8;
cres[161]=24'h10b650;
cres[162]=24'h10a3d7;
cres[163]=24'h10916b;
cres[164]=24'h107f0d;
cres[165]=24'h106cbe;
cres[166]=24'h105a7c;
cres[167]=24'h104848;
cres[168]=24'h103621;
cres[169]=24'h102409;
cres[170]=24'h1011fd;
cres[171]=24'h100000;
cres[172]=24'hfee0f;
cres[173]=24'hfdc2c;
cres[174]=24'hfca57;
cres[175]=24'hfb88e;
cres[176]=24'hfa6d3;
cres[177]=24'hf9525;
cres[178]=24'hf8385;
cres[179]=24'hf71f1;
cres[180]=24'hf606a;
cres[181]=24'hf4ef0;
cres[182]=24'hf3d83;
cres[183]=24'hf2c23;
cres[184]=24'hf1acf;
cres[185]=24'hf0989;
cres[186]=24'hef84f;
cres[187]=24'hee721;
cres[188]=24'hed600;
cres[189]=24'hec4ec;
cres[190]=24'heb3e4;
cres[191]=24'hea2e8;
cres[192]=24'he91f9;
cres[193]=24'he8116;
cres[194]=24'he703f;
cres[195]=24'he5f75;
cres[196]=24'he4eb6;
cres[197]=24'he3e04;
cres[198]=24'he2d5d;
cres[199]=24'he1cc3;
cres[200]=24'he0c35;
cres[201]=24'hdfbb2;
cres[202]=24'hdeb3b;
cres[203]=24'hddad0;
cres[204]=24'hdca71;
cres[205]=24'hdba1d;
cres[206]=24'hda9d5;
cres[207]=24'hd9999;
cres[208]=24'hd8968;
cres[209]=24'hd7943;
cres[210]=24'hd6929;
cres[211]=24'hd591a;
cres[212]=24'hd4917;
cres[213]=24'hd391f;
cres[214]=24'hd2933;
cres[215]=24'hd1951;
cres[216]=24'hd097b;
cres[217]=24'hcf9b0;
cres[218]=24'hce9ef;
cres[219]=24'hcda3a;
cres[220]=24'hcca90;
cres[221]=24'hcbaf1;
cres[222]=24'hcab5c;
cres[223]=24'hc9bd3;
cres[224]=24'hc8c54;
cres[225]=24'hc7ce0;
cres[226]=24'hc6d77;
cres[227]=24'hc5e18;
cres[228]=24'hc4ec4;
cres[229]=24'hc3f7b;
cres[230]=24'hc303c;
cres[231]=24'hc2108;
cres[232]=24'hc11de;
cres[233]=24'hc02be;
cres[234]=24'hbf3a9;
cres[235]=24'hbe49e;
cres[236]=24'hbd59e;
cres[237]=24'hbc6a7;
cres[238]=24'hbb7bb;
cres[239]=24'hba8d9;
cres[240]=24'hb9a02;
cres[241]=24'hb8b34;
cres[242]=24'hb7c70;
cres[243]=24'hb6db6;
cres[244]=24'hb5f07;
cres[245]=24'hb5061;
cres[246]=24'hb41c5;
cres[247]=24'hb3333;
cres[248]=24'hb24aa;
cres[249]=24'hb162c;
cres[250]=24'hb07b7;
cres[251]=24'haf94c;
cres[252]=24'haeaea;
cres[253]=24'hadc93;
cres[254]=24'hace44;
cres[255]=24'hac000;
cres[256]=24'hab1c4;
cres[257]=24'haa392;
cres[258]=24'ha956a;
cres[259]=24'ha874b;
cres[260]=24'ha7935;
cres[261]=24'ha6b29;
cres[262]=24'ha5d26;
cres[263]=24'ha4f2c;
cres[264]=24'ha413c;
cres[265]=24'ha3354;
cres[266]=24'ha2576;
cres[267]=24'ha17a1;
cres[268]=24'ha09d5;
cres[269]=24'h9fc12;
cres[270]=24'h9ee58;
cres[271]=24'h9e0a7;
cres[272]=24'h9d2ff;
cres[273]=24'h9c55f;
cres[274]=24'h9b7c9;
cres[275]=24'h9aa3b;
cres[276]=24'h99cb6;
cres[277]=24'h98f3a;
cres[278]=24'h981c7;
cres[279]=24'h9745d;
cres[280]=24'h966fb;
cres[281]=24'h959a1;
cres[282]=24'h94c51;
cres[283]=24'h93f09;
cres[284]=24'h931c9;
cres[285]=24'h92492;
cres[286]=24'h91763;
cres[287]=24'h90a3d;
cres[288]=24'h8fd1f;
cres[289]=24'h8f00a;
cres[290]=24'h8e2fd;
cres[291]=24'h8d5f8;
cres[292]=24'h8c8fb;
cres[293]=24'h8bc07;
cres[294]=24'h8af1b;
cres[295]=24'h8a237;
cres[296]=24'h8955c;
cres[297]=24'h88888;
cres[298]=24'h87bbd;
cres[299]=24'h86ef9;
cres[300]=24'h8623e;
cres[301]=24'h8558b;
cres[302]=24'h848df;
cres[303]=24'h83c3c;
cres[304]=24'h82fa0;
cres[305]=24'h8230d;
cres[306]=24'h81681;
cres[307]=24'h809fd;
cres[308]=24'h7fd81;
cres[309]=24'h7f10d;
cres[310]=24'h7e4a0;
cres[311]=24'h7d83b;
cres[312]=24'h7cbde;
cres[313]=24'h7bf88;
cres[314]=24'h7b33b;
cres[315]=24'h7a6f4;
cres[316]=24'h79ab6;
cres[317]=24'h78e7f;
cres[318]=24'h7824f;
cres[319]=24'h77627;
cres[320]=24'h76a06;
cres[321]=24'h75ded;
cres[322]=24'h751db;
cres[323]=24'h745d1;
cres[324]=24'h739ce;
cres[325]=24'h72dd2;
cres[326]=24'h721de;
cres[327]=24'h715f1;
cres[328]=24'h70a0b;
cres[329]=24'h6fe2c;
cres[330]=24'h6f255;
cres[331]=24'h6e685;
cres[332]=24'h6dabc;
cres[333]=24'h6cefa;
cres[334]=24'h6c33f;
cres[335]=24'h6b78c;
cres[336]=24'h6abdf;
cres[337]=24'h6a039;
cres[338]=24'h6949b;
cres[339]=24'h68903;
cres[340]=24'h67d72;
cres[341]=24'h671e9;
cres[342]=24'h66666;
cres[343]=24'h65aea;
cres[344]=24'h64f75;
cres[345]=24'h64407;
cres[346]=24'h6389f;
cres[347]=24'h62d3f;
cres[348]=24'h621e5;
cres[349]=24'h61692;
cres[350]=24'h60b45;
cres[351]=24'h60000;
cres[352]=24'h5f4c0;
cres[353]=24'h5e988;
cres[354]=24'h5de56;
cres[355]=24'h5d32b;
cres[356]=24'h5c807;
cres[357]=24'h5bce9;
cres[358]=24'h5b1d1;
cres[359]=24'h5a6c0;
cres[360]=24'h59bb6;
cres[361]=24'h590b2;
cres[362]=24'h585b4;
cres[363]=24'h57abd;
cres[364]=24'h56fcc;
cres[365]=24'h564e2;
cres[366]=24'h559fe;
cres[367]=24'h54f20;
cres[368]=24'h54449;
cres[369]=24'h53978;
cres[370]=24'h52ead;
cres[371]=24'h523e8;
cres[372]=24'h5192a;
cres[373]=24'h50e72;
cres[374]=24'h503c0;
cres[375]=24'h4f914;
cres[376]=24'h4ee6f;
cres[377]=24'h4e3cf;
cres[378]=24'h4d936;
cres[379]=24'h4cea3;
cres[380]=24'h4c415;
cres[381]=24'h4b98e;
cres[382]=24'h4af0d;
cres[383]=24'h4a492;
cres[384]=24'h49a1d;
cres[385]=24'h48fad;
cres[386]=24'h48544;
cres[387]=24'h47ae1;
cres[388]=24'h47083;
cres[389]=24'h4662c;
cres[390]=24'h45bda;
cres[391]=24'h4518e;
cres[392]=24'h44748;
cres[393]=24'h43d08;
cres[394]=24'h432ce;
cres[395]=24'h42899;
cres[396]=24'h41e6a;
cres[397]=24'h41441;
cres[398]=24'h40a1d;
cres[399]=24'h40000;
cres[400]=24'h3f5e7;
cres[401]=24'h3ebd5;
cres[402]=24'h3e1c8;
cres[403]=24'h3d7c1;
cres[404]=24'h3cdbf;
cres[405]=24'h3c3c3;
cres[406]=24'h3b9cd;
cres[407]=24'h3afdc;
cres[408]=24'h3a5f0;
cres[409]=24'h39c0b;
cres[410]=24'h3922a;
cres[411]=24'h3884f;
cres[412]=24'h37e7a;
cres[413]=24'h374aa;
cres[414]=24'h36adf;
cres[415]=24'h3611a;
cres[416]=24'h3575a;
cres[417]=24'h34da0;
cres[418]=24'h343eb;
cres[419]=24'h33a3b;
cres[420]=24'h33090;
cres[421]=24'h326eb;
cres[422]=24'h31d4b;
cres[423]=24'h313b1;
cres[424]=24'h30a1b;
cres[425]=24'h3008b;
cres[426]=24'h2f700;
cres[427]=24'h2ed7b;
cres[428]=24'h2e3fa;
cres[429]=24'h2da7f;
cres[430]=24'h2d108;
cres[431]=24'h2c797;
cres[432]=24'h2be2b;
cres[433]=24'h2b4c5;
cres[434]=24'h2ab63;
cres[435]=24'h2a206;
cres[436]=24'h298ae;
cres[437]=24'h28f5c;
cres[438]=24'h2860e;
cres[439]=24'h27cc5;
cres[440]=24'h27382;
cres[441]=24'h26a43;
cres[442]=24'h26109;
cres[443]=24'h257d5;
cres[444]=24'h24ea5;
cres[445]=24'h2457a;
cres[446]=24'h23c54;
cres[447]=24'h23333;
cres[448]=24'h22a16;
cres[449]=24'h220ff;
cres[450]=24'h217ec;
cres[451]=24'h20edf;
cres[452]=24'h205d6;
cres[453]=24'h1fcd1;
cres[454]=24'h1f3d2;
cres[455]=24'h1ead7;
cres[456]=24'h1e1e1;
cres[457]=24'h1d8f0;
cres[458]=24'h1d004;
cres[459]=24'h1c71c;
cres[460]=24'h1be39;
cres[461]=24'h1b55a;
cres[462]=24'h1ac81;
cres[463]=24'h1a3ac;
cres[464]=24'h19adb;
cres[465]=24'h1920f;
cres[466]=24'h18948;
cres[467]=24'h18085;
cres[468]=24'h177c7;
cres[469]=24'h16f0e;
cres[470]=24'h16659;
cres[471]=24'h15da8;
cres[472]=24'h154fc;
cres[473]=24'h14c55;
cres[474]=24'h143b2;
cres[475]=24'h13b13;
cres[476]=24'h13279;
cres[477]=24'h129e4;
cres[478]=24'h12152;
cres[479]=24'h118c6;
cres[480]=24'h1103d;
cres[481]=24'h107b9;
cres[482]=24'hff3a;
cres[483]=24'hf6bf;
cres[484]=24'hee48;
cres[485]=24'he5d5;
cres[486]=24'hdd67;
cres[487]=24'hd4fd;
cres[488]=24'hcc98;
cres[489]=24'hc437;
cres[490]=24'hbbda;
cres[491]=24'hb381;
cres[492]=24'hab2d;
cres[493]=24'ha2dc;
cres[494]=24'h9a90;
cres[495]=24'h9249;
cres[496]=24'h8a05;
cres[497]=24'h81c6;
cres[498]=24'h798b;
cres[499]=24'h7153;
cres[500]=24'h6921;
cres[501]=24'h60f2;
cres[502]=24'h58c7;
cres[503]=24'h50a1;
cres[504]=24'h487e;
cres[505]=24'h4060;
cres[506]=24'h3846;
cres[507]=24'h3030;
cres[508]=24'h281e;
cres[509]=24'h2010;
cres[510]=24'h1806;
cres[511]=24'h1000;
cres[512]=24'h07fe;
end

wire sa,sb;
wire [EMSB:0] xa,xb;
wire [fp64Pkg::FMSB:0] ma,mb;
reg [fp64Pkg::FMSB:0] ma3,mb3;
wire infa,infb;
wire vza,vzb,mbz;
wire nana,nanb;
reg nana3,nanb3;
FP64 ox;
reg sel_ox;
wire [4:0] lzk;

fpDecomp64 u1 (.i(a), .sgn(sa), .exp(xa), .man(ma), .fract(), .xz(), .mz(), .vz(vza), .xinf(), .inf(infa), .nan(nana) );
fpDecomp64 u2 (.i(b), .sgn(sb), .exp(xb), .man(mb), .fract(), .xz(), .mz(mbz), .vz(vzb), .xinf(), .inf(infb), .nan(nanb) );
cntlz24 u5 (.i(k0), .o(lzk));

wire signed [EMSB+1:0] bias = {1'b0,{EMSB{1'b1}}};
wire signed [EMSB+1:0] x1 = xb - bias;
wire signed [EMSB+1:0] exp = nanb ? xb : bias - x1 - 2'd1;	// make exponent negative
wire signed [EMSB+1:0] exn = nanb ? xb : bias - x1;					// make exponent negative
wire sb3;
wire signed [EMSB+1:0] exp3;
wire [9:0] index = mb[fp64Pkg::FMSB:fp64Pkg::FMSB-8];
reg [21:0] k0;

always_ff @(posedge clk)
if (ce) begin
	sel_ox <= 1'b0;
	if (dc & nana & nanb) begin
		ox <= a|64'h00080000_00000000;
		sel_ox <= 1'b1;
	end
	else if (dc && nana) begin
		ox <= a|64'h00080000_00000000;
		sel_ox <= 1'b1;
	end
	else if (nanb) begin
		ox <= b|64'h00080000_00000000;
		sel_ox <= 1'b1;
	end
	else if (dc & vza & vzb) begin
		ox <= {sb,63'h7FF98000_00000000};	// zero/zero
		sel_ox <= 1'b1;
	end
	else if (vzb) begin
		ox <= {sb,63'h7FF00000_00000000};	// n/zero = infinity
		sel_ox <= 1'b1;
	end
	else if (dc & infa & infb) begin
		ox <= {sb,63'h7FF90000_00000000};	// - infinity / infinity
		sel_ox <= 1'b1;
	end
	else if (infb) begin
		ox <= {sb,63'h00000000_00000000};	// 1/infinity = zero
		sel_ox <= 1'b1;
	end
	else if (mbz) begin
		ox.sign <= sb;
		ox.exp <= exn;
		ox.sig <= 52'd0;
		sel_ox <= 1'b1;
	end
end

always_comb
	k0 = {1'b1,cres[index][20:0]};
delay1 #(fp64Pkg::EMSB+2) u3 (.clk(clk), .ce(ce), .i(exp), .o(exp3));
delay1 #(1) u4 (.clk(clk), .ce(ce), .i(sb), .o(sb3));
reg [21:0] r0;
reg [21:-14] r1;
always_ff @(posedge clk)
	if (ce) r0 <= k0;
always_comb
	r1 = (exp3=='d0 || exp3[fp64Pkg::EMSB+1]) ? {r0,12'h0} >> (-exp3 + 1): {r0,12'h0};
always_ff @(posedge clk)
	if (ce) mb3 <= mb;
always_ff @(posedge clk)
	if (ce) nanb3 <= nanb;
		
always_ff @(posedge clk)
	if (ce) begin
		if (sel_ox) begin
			o <= ox;
			exact <= 1'b1;
		end
		else begin
			o.sign <= sb3;
			o.exp <= exp3[fp64Pkg::EMSB+1] ? 'd0 : exp3;
			o.sig <= nanb3 ? mb3 : {r1[21:-14],{fp64Pkg::FMSB-32{1'b0}}};
			exact <= 1'b0;
		end
	end

endmodule
