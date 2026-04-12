// ============================================================================
//        __
//   \\__/ o\    (C) 2026 Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
//
// fpConstROM64.sv
// - constants
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

import fp64Pkg::*;

module fpConstROM64(a, o);
input [6:0] a;
output FP64 o;

FP64 [127:0] fconst;

initial begin
fconst[0] = 64'h0000000000000000;	// 0.0
fconst[1] = 64'h3ff0000000000000;	// 1.0
fconst[2] = 64'h4000000000000000;	// 2.0
fconst[3] = $realtobits(0.5);
fconst[4] = $realtobits(0.25);
fconst[5]=$realtobits(6.28318530717958647693);	// 2 pi
fconst[6]=$realtobits(1.57079632679489661923);	// pi by 2
fconst[7]=$realtobits(0.78539816339744830962);	// pi by four
fconst[8]=$realtobits(0.63661977236758134308);	// 2 by pi

// POW.C
fconst[9]=$realtobits(0.69314718055994530942);	// ln 2
fconst[10]=$realtobits(0.70710678118654752440);	// rthalf

// XSIN.C
fconst[11]=$realtobits(3294198.0 / 2097152.0);	// c1
fconst[12]=$realtobits(3.139164786504813217e-7);	// c2

// SQRT.C
fconst[12]=$realtobits(1.41421356237309505);		// sqrt 2
//		y = (-0.1984742 * x + 0.8804894) * x + 0.3176687;
fconst[13]=$realtobits(-0.1984742);
fconst[14]=$realtobits(0.8804894);
fconst[15]=$realtobits(0.3176687);

// XLOG.C
/* coefficients, after Cody & Waite, Chapter 5 */
//static const double p[3] = {
fconst[16]=$realtobits(-0.78956112887491257267e+0);
fconst[17]=$realtobits(0.16383943563021534222e+2);
fconst[18]=$realtobits(-0.64124943423745581147e+2);
fconst[19]=$realtobits(0.43429448190325182765);				// log e
//static const double q[3] = {
fconst[20]=$realtobits(-0.35667977739034646171e+2);
fconst[21]=$realtobits(0.31203222091924532844e+3);
fconst[22]=$realtobits(-0.76949932108494879777e+3);
// see fconst[110] static const double c1 = 22713.0 / 32768.0;
// see fconst[111] static const double c2 = 1.428606820309417232e-6;

/* coefficients, after Cody & Waite, Chapter 10 */
// XASIN.C
//static const double p[5] = {
fconst[24] = $realtobits(-0.69674573447350646411e+0);
fconst[25] = $realtobits(0.10152522233806463645e+2);
fconst[26] = $realtobits(-0.39688862997504877339e+2);
fconst[27] = $realtobits(0.57208227877891731407e+2);
fconst[28] = $realtobits(-0.27368494524164255994e+2);
//static const double q[6] = {
fconst[32] = $realtobits(0.10000000000000000000e+1);
fconst[33] = $realtobits(-0.23823859153670238830e+2);
fconst[34] = $realtobits(0.15095270841030604719e+3);
fconst[35] = $realtobits(-0.38186303361750149284e+3);
fconst[36] = $realtobits(0.41714430248260412556e+3);
fconst[37] = $realtobits(-0.16421096714498560795e+3);

/* coefficients, after Cody & Waite, Chapter 12 */
// SINH.C
//static const double p[4] = {
fconst[40] = $realtobits(-0.78966127417357099479e+0);
fconst[41] = $realtobits(-0.16375798202630751372e+3);
fconst[42] = $realtobits(-0.11563521196851768270e+5);
fconst[43] = $realtobits(-0.35181283430177117881e+6);
//static const double q[4] = {
fconst[44] = $realtobits(1.0);
fconst[45] = $realtobits(-0.27773523119650701667e+3);
fconst[46] = $realtobits(0.36162723109421836460e+5);
fconst[47] = $realtobits(-0.21108770058106271242e+7);

// XSIN.C
//static const double c[8] = {
fconst[48] = $realtobits(-0.000000000011470879);
fconst[49] = $realtobits(0.000000002087712071);
fconst[50] = $realtobits(-0.000000275573192202);
fconst[51] = $realtobits(0.000024801587292937);
fconst[52] = $realtobits(-0.001388888888888893);
fconst[53] = $realtobits(0.041666666666667325);
fconst[54] = $realtobits(-0.500000000000000000);
fconst[55] = $realtobits(1.0);
//static const double s[8] = {
fconst[56] = $realtobits(-0.000000000000764723);
fconst[57] = $realtobits(0.000000000160592578);
fconst[58] = $realtobits(-0.000000025052108383);
fconst[59] = $realtobits(0.000002755731921890);
fconst[60] = $realtobits(-0.000198412698412699);
fconst[61] = $realtobits(0.008333333333333372);
fconst[62] = $realtobits(-0.166666666666666667);
fconst[63] = $realtobits(1.0);

// TAN.C
/* coefficients, after Cody & Waite, Chapter 9 */
//static const double p[3] = {
fconst[64] = $realtobits(-0.17861707342254426711e-4);
fconst[65] = $realtobits(0.34248878235890589960e-2);
fconst[66] = $realtobits(-0.13338350006421960681e+0);
//static const double q[4] = {
fconst[68] = $realtobits(0.49819433993786512270e-6);
fconst[69] = $realtobits(-0.31181531907010027307e-3);
fconst[70] = $realtobits(0.25663832289440112864e-1);
fconst[71] = $realtobits(-0.46671683339755294240e+0);

// TANH.C
/* coefficients, after Cody & Waite, Chapter 13 */
//static const double p[3] = {
fconst[73] = $realtobits(-0.96437492777225469787e+0);
fconst[74] = $realtobits(-0.99225929672236083313e+2);
fconst[75] = $realtobits(-0.16134119023996228053e+4);
fconst[75] = $realtobits(0.54930614433405484570);	// ln3by2
//static const double q[4] = {
fconst[76] = $realtobits(0.10000000000000000000e+1);
fconst[77] = $realtobits(0.11274474380534949335e+3);
fconst[78] = $realtobits(0.22337720718962312926e+4);
fconst[79] = $realtobits(0.48402357071988688686e+4);

// XATAN.C
/* coefficients, after Cody & Waite, Chapter 11 */
//static const double a[8] = {
fconst[80] = $realtobits(0.0);
fconst[81] = $realtobits(0.52359877559829887308);
fconst[82] = $realtobits(1.57079632679489661923);
fconst[83] = $realtobits(1.04719755119659774615);
fconst[84] = $realtobits(1.57079632679489661923);
fconst[85] = $realtobits(2.09439510239319549231);
fconst[86] = $realtobits(3.14159265358979323846);
fconst[87] = $realtobits(2.61799387799149436538);
//static const double p[4] = {
fconst[88] = $realtobits(-0.83758299368150059274e+0);
fconst[89] = $realtobits(-0.84946240351320683534e+1);
fconst[90] = $realtobits(-0.20505855195861651981e+2);
fconst[91] = $realtobits(-0.13688768894191926929e+2);
//static const double q[5] = {
fconst[92] = $realtobits(0.10000000000000000000e+1);
fconst[93] = $realtobits(0.15024001160028576121e+2);
fconst[94] = $realtobits(0.59578436142597344465e+2);
fconst[95] = $realtobits(0.86157349597130242515e+2);
fconst[96] = $realtobits(0.41066306682575781263e+2);
fconst[97] = $realtobits(0.26794919243112270647);		//fold
fconst[98] = $realtobits(1.73205080756887729353);		// sqrt 3
fconst[99] = $realtobits(0.73205080756887729353);		// sqrt 3 minus 1

// XDTENTO.C
fconst[100] = $realtobits(1e1);
fconst[101] = $realtobits(1e2);
fconst[102] = $realtobits(1e4);
fconst[103] = $realtobits(1e8);
fconst[104] = $realtobits(1e16);
fconst[105] = $realtobits(1e32);
fconst[106] = $realtobits(1e64);
fconst[107] = $realtobits(1e128);
fconst[108] = $realtobits(1e256);

// EXP.C
/* coefficients, after Cody & Waite, Chapter 6 */
//static const double p[3] = {
fconst[109] = $realtobits(1.4426950408889634074);			// invln2
fconst[110] = $realtobits(22713.0 / 32768.0);					// c1
fconst[111] = $realtobits(1.428606820309417232e-6);		// c2
fconst[112] = $realtobits(0.31555192765684646356e-4);
fconst[113] = $realtobits(0.75753180159422776666e-2);
fconst[114] = $realtobits(0.25000000000000000000e+0);
//static const double q[4] = {
fconst[116] = $realtobits(0.75104028399870046114e-6);
fconst[117] = $realtobits(0.63121894374398503557e-3);
fconst[118] = $realtobits(0.56817302698551221787e-1);
fconst[119] = $realtobits(0.50000000000000000000e+0);
//static const double hugexp = (double)HUGE_EXP;

fconst[120]=64'h7FF88000_00000000;	// - infinity - infinity
fconst[121]=64'h7FF90000_00000000;	// - infinity / infinity
fconst[122]=64'h7FF98000_00000000;	// - zero / zero
fconst[123]=64'h7FFA0000_00000000;	// - infinity X zero
fconst[124]=64'h7FFA8000_00000000;	// - square root of infinity
fconst[125]=64'h7FFB0000_00000000;	// - square root of negative number

/*
// Taken from
// https://www.mdpi.com/2079-3197/9/2/21
//Reciprocal Square Root Constants
fconst[128]=64'h5fe33d209e450c1b;
fconst[129]=64'h3fea5fffb6477f8a;		// 0.824218612684476826
fconst[130]=64'h40013317a7446de0;	// 2.14994745900706619
fconst[131]=64'h5fdb3d20982e5432;
fconst[132]=64'h4002a66269e94a6d;	// 2.331242396766632
fconst[133]=64'h3ff133179db0e086;	// 1.074973693828754
// Square Root Constants
fconst[136]=64'h5fe33d165ce48760; // 
fconst[137]=64'h3fea6000e8ac0a19; // 0.82421918338542632
fconst[138]=64'h400133181243e7f8; // 2.1499482562039667
fconst[140]=64'h5fdb3d20dba7bd3c; // 
fconst[141]=64'h4002a664e155b5cf; // 2.3312471012384104
fconst[142]=64'h3ff13318002fb295; // 1.074974060752685
*/
end

assign o = fconst[a];

endmodule
