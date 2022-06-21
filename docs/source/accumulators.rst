###################
Accumulator Library
###################
.. _accumulator:

*******
Purpose
*******
.. _accumulator_purpose:

The accumulator library contains all casper_accumulator HDL modules wrapped for Simulink. This library contains
several instances of vector accumulator blocks which are particularly useful in the field of Radio Astronomy.

==============
Addr Bram Vacc
==============
This simple vector accumulator is based on a shift register. It outputs its previous accumulated vector after a new_acc pulse is received.

-----
Ports
-----
+----------------+--------------------------+---------------------------+----------------------------------------------------------------+
| Signal         | Type                     | Size                      | Description                                                    |
+================+==========================+===========================+================================================================+
| new_acc        | std_logic                | 1                         | This port accepts the pulse signal indicating the start of a   |
|                |                          |                           | vector for accumulation.                                       |
+----------------+--------------------------+---------------------------+----------------------------------------------------------------+
| din            | std_logic_vector         | any                       | The input into which the vector is supplied one element at a   |
|                |                          |                           | time.                                                          |  
+----------------+--------------------------+---------------------------+----------------------------------------------------------------+
| addr           | std_logic_vector         | ceil(log2(vector_length)) | Vector address port out (index).                               |  
+----------------+--------------------------+---------------------------+----------------------------------------------------------------+
| dout           | std_logic_vector         | any                       | The accumulated vector indices out.                            |  
+----------------+--------------------------+---------------------------+----------------------------------------------------------------+
| we             | std_logic                | 1                         | Signal indicates valid dout.                                   |  
+----------------+--------------------------+---------------------------+----------------------------------------------------------------+
----------
Parameters
----------
+----------------+---------+--------+----------------------------------------------------------------+
| Generic        | Type    | Value  | Description                                                    |
+================+=========+========+================================================================+
| Vector length  | Natural | 10     | The length of the vector to accumulate.                        |
+----------------+---------+--------+----------------------------------------------------------------+
| Output sign    | String  |"SIGNED"| Value options of "SIGNED" and "UNSIGNED" for dout type.        |
+----------------+---------+--------+----------------------------------------------------------------+
| Output bitwidth| Natural | 18     | Output bitwidth for dout type.                                 |
+----------------+---------+--------+----------------------------------------------------------------+
| Output bin pt  | Natural |0       | Output binary point for dout type.                             |
+----------------+---------+--------+----------------------------------------------------------------+

================
DSP48e BRAM VACC
================
A vector accumulator modeled after a shift register.  It outputs its previous accumulated vector after a new_acc pulse is received. 
Based on the simple_bram_vacc block, this version replaces the adder and mux with a single DSP48E block, allowing high-speed compilation.
Output bit width cannot exceed 32. Output binary point matches the input.
-----
Ports
-----
+----------------+--------------------------+---------------------------+----------------------------------------------------------------+
| Signal         | Type                     | Size                      | Description                                                    |
+================+==========================+===========================+================================================================+
| new_acc        | std_logic                | 1                         | This port accepts the pulse signal indicating the start of a   |
|                |                          |                           | vector for accumulation.                                       |
+----------------+--------------------------+---------------------------+----------------------------------------------------------------+
| din            | std_logic_vector         | any                       | The input into which the vector is supplied one element at a   |
|                |                          |                           | time.                                                          |  
+----------------+--------------------------+---------------------------+----------------------------------------------------------------+
| dout           | std_logic_vector         | any                       | The accumulated vector indices out.                            |  
+----------------+--------------------------+---------------------------+----------------------------------------------------------------+
| valid          | std_logic                | 1                         | Signal indicates valid dout.                                   |  
+----------------+--------------------------+---------------------------+----------------------------------------------------------------+
----------
Parameters
----------
+----------------+---------+--------+----------------------------------------------------------------+
| Generic        | Type    | Value  | Description                                                    |
+================+=========+========+================================================================+
| Vector length  | Natural | 10     | The length of the vector to accumulate.                        |
+----------------+---------+--------+----------------------------------------------------------------+
| Output sign    | String  |"SIGNED"| Value options of "SIGNED" and "UNSIGNED" for dout type.        |
+----------------+---------+--------+----------------------------------------------------------------+
| Output bitwidth| Natural | 18     | Output bitwidth for dout type.                                 |
+----------------+---------+--------+----------------------------------------------------------------+
| Output bin pt  | Natural |0       | Output binary point for dout type.                             |
+----------------+---------+--------+----------------------------------------------------------------+
| DSP48e version | Natural |1       | Options are 1 or 2 for DSP48e1 and DSP48e2 respectively.       |
+----------------+---------+--------+----------------------------------------------------------------+

