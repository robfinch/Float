
module fpConstROM64(a, o);
input [5:0] a;
output [63:0] o;

reg [63:0] fconst;

initial begin
fconst[1] = 64'h3ff0000000000000;	// 1.0
fconst[2] = 64'h4000000000000000;	// 2.0
// Taken from
// https://www.mdpi.com/2079-3197/9/2/21
//Reciprocal Square Root Constants
fconst[ 8]=64'h5fe33d209e450c1b;
fconst[ 9]=64'h3fea5fffb6477f8a;		// 0.824218612684476826
fconst[10]=64'h40013317a7446de0;	// 2.14994745900706619
fconst[12]=64'h5fdb3d20982e5432;
fconst[13]=64'h4002a66269e94a6d;	// 2.331242396766632
fconst[14]=64'h3ff133179db0e086;	// 1.074973693828754
// Square Root Constants
fconst[16]=64'h5fe33d165ce48760; // 
fconst[17]=64'h3fea6000e8ac0a19; // 0.82421918338542632
fconst[18]=64'h400133181243e7f8; // 2.1499482562039667
fconst[20]=64'h5fdb3d20dba7bd3c; // 
fconst[21]=64'h4002a664e155b5cf; // 2.3312471012384104
fconst[22]=64'h3ff13318002fb295; // 1.074974060752685
end

assign o = fconst[a];

endmodule
