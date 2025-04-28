# Float

* Here is some code written in System Verilog to perform floating-point and decimal floating-point arithmetic.

* The fpu folder contains floating-point code.
* The dfpu folder contains decimal floating-point code.

* There are two versions of modules, one pipelined and one combinational logic.
* The combinational logic versions allow the pipeline depth to be varied based on the number of register layers added at the output. The re-timing option in synthesis should then pipeline the module.

* The pipelined version is named as in 'fpFMA64.sv' while the combinational logic version has 'combo' appended to the name as in 'fpFMA64combo.sv'.

* The operation size is indicated in the module name.
* 'fpFMA32.sv' is the 32-bit single precision pipelined version of the core.

* Some of the latencies of the cores could be lower, for example single cycle instead of two cycle, but having different latencies complicates the design of FPUs.
* It is suggested to put the cores with zero latency into another low latency function unit like a simple ALU rather than in an FPU.
Cores have the following latencies:

|Core         |Latency|Every|Purpose                     |
|-------------|-------|-----|----------------------------|
|fpCmp64      |   0   |  1  |compare two floats          |
|fpCvt32To64  |   0   |  1  |single to double conversion |
|fpCvt64To32  |   0   |  1  |double to single conversion |
|fpScaleb64   |   2   |  1  |add integer to exponent     |
|fpCvt64ToI64 |   2   |  1  |float to integer conversion |
|fpCvtI64To64 |   2   |  1  |integer to float conversion |
|fpTrunc64    |   2   |  1  |truncate decimals           |
|fpNextAfter64|   2   |  1  |next representable value    |
|fpRes64      |   2   |  1  |reciprocal estimate         |
|fpSigmoid64  |   2   |  1  |sigmoid estimate            |
|fpFMA64L5nr  |   8   |  1  |fused multiply and add      |
|fpSin64      |  ~60  | ~60 |sine (clocks are approx.)   |
|fpCos64      |  ~60  | ~60 |cosine (approx. clocks)     |

* It is suggested to implement divide using fpFMA with a state machine using an iterative method such as Newton-Raphson.
* There is a cordic core which may be able to generate other functions with proper arguments.
