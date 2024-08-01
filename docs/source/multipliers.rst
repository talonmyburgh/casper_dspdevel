###################
Multiplier Library
###################
.. _multiplier:

*******
Purpose
*******
.. _multiplier_purpose:

The multiplier library contains the cmult (complex multiplication) HDL modules wrapped for Simulink. All CASPER
multiplier modules have been bundled into the cmult block with the exception of the cmult BRAM modules which
supports small bitwidths alone.

==============
Cmult
==============
This cmult wraps the ASTRON common_complex_mult module. As this does not do the data replication that the original CASPER
complex multiplier does, this complex multiplier requires a latency of at least 4 (cumulatively).

-----
Ports
-----
+----------------+--------------------------+---------------------------+----------------------------------------------------------------+
| Signal         | Type                     | Size                      | Description                                                    |
+================+==========================+===========================+================================================================+
| rst            | std_logic                | 1                         | This port drives the reset of all pipelines in the block.      |
+----------------+--------------------------+---------------------------+----------------------------------------------------------------+
| in_a           | std_logic_vector         | 2*(a_bw)                  | The first complex vector input. a_bw is the bitwidth specified |
|                |                          |                           | for a in the parameter list. Real part occupies MSB while imag |
|                |                          |                           | part occupies LSB.                                             | 
+----------------+--------------------------+---------------------------+----------------------------------------------------------------+
| in_b           | std_logic_vector         | 2*(b_bw)                  | The second complex vector input. b_bw is the bitwidth          |
|                |                          |                           | specified for a in the parameter list. Real part occupies      |
|                |                          |                           | MSB while imag part occupies LSB.                              | 
+----------------+--------------------------+---------------------------+----------------------------------------------------------------+
| in_val         | std_logic                | 1                         | Valid signal to drive multiply.                                |  
+----------------+--------------------------+---------------------------+----------------------------------------------------------------+

----------
Parameters
----------
'a' and 'b' are taken to be complex vectors. The bitwidths and binary points specified in the mask are for 
the real and imaginary parts of the complex vectors. The output is also a complex vector where the 'ab' bitwidth
and binary point are again for the real and imaginary parts. Hence, inputs and outputs are expected to be double
bitwidths specified.
The complex vector has the real part in the MSB and the imaginary part in the LSB.
+----------------+---------+----------+----------------------------------------------------------------+
| Generic        | Type    | Value    | Description                                                    |
+================+=========+==========+================================================================+
| 'a' nof bits   | Natural | 18       | The bitwidth of the 'a' real part.                             |
+----------------+---------+----------+----------------------------------------------------------------+
| 'a' bin pt     | Natural | 17       | The binary point position for the 'a' real part.               |
+----------------+---------+----------+----------------------------------------------------------------+
| 'b' nof bits   | Natural | 18       | The bitwidth of the 'b' real part.                             |
+----------------+---------+----------+----------------------------------------------------------------+
| 'b' bin pt     | Natural | 17       | The binary point position for the 'b' real part.               |
+----------------+---------+----------+----------------------------------------------------------------+
| 'ab' nof bits  | Natural | 36       | Output bitwidth for the 'ab' real part.                        |
+----------------+---------+----------+----------------------------------------------------------------+
| 'ab' bin pt    | Natural | 34       | The binary point position for the 'ab' real part.              |
+----------------+---------+----------+----------------------------------------------------------------+
| Quantisation   | String  | Truncate | The rounding method used if 'ab' bitwidth < a_bw + b_bw + 1.   |
+----------------+---------+----------+----------------------------------------------------------------+
| Overflow       | String  | Wrap     | The overflow method used.                                      |
+----------------+---------+----------+----------------------------------------------------------------+
| Conjugate      | Boolean | False    | If True, conjugate the 'b' entry before complex multiplication.|
+----------------+---------+----------+----------------------------------------------------------------+
| input_lat      | Natural | 1        | Can be 0 or 1. 0 means no registering of input, 1 means 1 clk  |
|                |         |          | of input register.                                             |
+----------------+---------+----------+----------------------------------------------------------------+
| prod _lat      | Natural | 1        | Can be 0 or 1. 0 means no registering of product output, 1     |
|                |         |          | means 1 clk of product register.                               |
+----------------+---------+----------+----------------------------------------------------------------+
| adder_lat      | Natural | 1        | Can be 0 or 1. 0 means no registering of adder output, 1 means |
|                |         |          | 1 clk of adder register.                                       |
+----------------+---------+----------+----------------------------------------------------------------+
| output_lat     | Natural | 1        | Can be 0 or greater. 0 means no registering of output,         |
|                |         |          | greater means output_lat*clk of output registering.            |
+----------------+---------+----------+----------------------------------------------------------------+
| gaussian_cmult | Boolean | False    | Use gaussian Cmult to implement 3DSP, normal to use 4DSP.      |
+----------------+---------+----------+----------------------------------------------------------------+
| IP implement   | Boolean | False    | Intel only - use ip cmult instead of behavioural HDL.          |
+----------------+---------+----------+----------------------------------------------------------------+
| Use DSP        | Boolean | True     | If true, use directive to implement multiplication using DSP48.|
+----------------+---------+----------+----------------------------------------------------------------+
