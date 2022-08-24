# Float

Here is some code written in System Verilog to perform floating-point and decimal floating-point arithmetic.

The fpu directory contains floating-point code.
The dfpu directory contains decimal floating-point code.

There are two versions of modules, one pipelined and one combinational logic.
The combinational logic versions allow the pipeline depth to be varied based on the number of register layers added at the output. The re-timing option in synthesis should then pipeline the module.

The pipelined version is named as in 'fpFMA64.sv' while the combinational logic version has 'combo' appended to the name as in 'fpFMA64combo.sv'.

The operation size is indicated in the module name.
'fpFMA32.sv' is the 32-bit single precision pipelined version of the core.
