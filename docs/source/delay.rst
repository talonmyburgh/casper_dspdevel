##############
Delays Library
##############
.. _delay:

*******
Purpose
*******
.. _delay_purpose:

The delays library contains all casper_delay HDL modules wrapped for Simulink.
These delay blocks are essential to the design of most DSP.

==========
Bram Delay
==========
A delay block that uses BRAM for its storage.

-----
Ports
-----
+----------------+-----------------+---------------------------+----------------------------------------------------------------+
| Signal         | Type            | Size                      | Description                                                    |
+================+=================+===========================+================================================================+
| din            | std_logic_vector| any                       | The input signal to be delayed by the delay parameter provided.|
+----------------+-----------------+---------------------------+----------------------------------------------------------------+
| en (optional)  | std_logic       | 1                         | If asynchronous operation is selected, this port will          |
|                |                 |                           | asynchronously enable (1) or disable (0) the block.            |
+----------------+-----------------+---------------------------+----------------------------------------------------------------+
| dout           | std_logic_vector| Width of din              | The delayed din signal.                                        |
+----------------+-----------------+---------------------------+----------------------------------------------------------------+

----------
Parameters
----------
+----------------+---------+--------+----------------------------------------------------------------+
| Generic        | Type    | Value  | Description                                                    |
+================+=========+========+================================================================+
| Delay          | Natural | 4      | The number of clock cycles by which you want to delay din.     |
+----------------+---------+--------+----------------------------------------------------------------+
| Bram Latency   | Natural | 2      | The internal bram read latency. Optional values are 1 and 2.   |
+----------------+---------+--------+----------------------------------------------------------------+
| Bram Primitive | String  | "block"| Dictates how the bram is placed on the FPGA. Options are       |   
|                |         |        | "block", "auto", "distributed" and "ultra".                    |
+----------------+---------+--------+----------------------------------------------------------------+
| Use DSP48      | Boolean | False  | Initialise the internal counter in DSP or LUTs. (TODO)         |
+----------------+---------+--------+----------------------------------------------------------------+
| Asynchronous   | Boolean | False  | If checked, the block provides an asynchronous enable/disable  |
| operation      |         |        | port.                                                          |
+----------------+---------+--------+----------------------------------------------------------------+

==================
Bram Delay En Plus
==================
A delay block that uses BRAM for its storage and only shifts when enabled.
However, BRAM latency cannot be enabled, so output appears bram_latency
clocks after an enable.

-----
Ports
-----
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| Signal         | Type            | Size                      | Description                                                     |
+================+=================+===========================+=================================================================+
| din            | std_logic_vector| any                       | The input signal to be delayed by the delay parameter provided. |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| en             | std_logic       | 1                         | This port will asynchronously enable (1) or disable (0) the     |
|                |                 |                           | block.                                                          |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| dout           | std_logic_vector| Width of din              | The delayed din signal delayed by :math:`bram_latency + delay`. |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| valid          | std_logic       | 1                         | The enable signal delayed by bram_latency provided (>2)         |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+

----------
Parameters
----------
+----------------+---------+--------+----------------------------------------------------------------+
| Generic        | Type    | Value  | Description                                                    |
+================+=========+========+================================================================+
| Enabled Delay  | Natural | 2      | The number of clock cycles by which you want to delay din. This|
|                |         |        | excludes the delay incurred by the provided latency            |      
+----------------+---------+--------+----------------------------------------------------------------+
| Unenabled Delay| Natural | 2      | The bram latency delay.                                        |
+----------------+---------+--------+----------------------------------------------------------------+
| Bram Primitive | String  | "block"| Dictates how the bram is placed on the FPGA. Options are       |   
|                |         |        | "block", "auto", "distributed" and "ultra".                    |
+----------------+---------+--------+----------------------------------------------------------------+

===============
Bram Delay Prog
===============
A delay block that uses BRAM for its storage and has a run-time programmable
delay.  When delay is changed, some randomly determined samples will
be inserted/dropped from the buffered stream.

-----
Ports
-----
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| Signal         | Type            | Size                      | Description                                                     |
+================+=================+===========================+=================================================================+
| din            | std_logic_vector| any                       | The input signal to be delayed by the delay parameter provided. |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| delay          | std_logic       | 1                         | This port will asynchronously enable (1) or disable (0) the     |
|                |                 |                           | block.                                                          |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| dout           | std_logic_vector| Width of din              | The delayed din signal delayed by :math:`bram_latency + delay`. |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+

----------
Parameters
----------
+----------------+---------+--------+----------------------------------------------------------------+
| Generic        | Type    | Value  | Description                                                    |
+================+=========+========+================================================================+
| Max Delay      | Natural | 7      | Maximum 2^max_delay number of clock cycles by which you want   |
|                |         |        | to delay din.                                                  |      
+----------------+---------+--------+----------------------------------------------------------------+
| BRAM Latency   | Natural | 5      | The bram latency delay.                                        |
+----------------+---------+--------+----------------------------------------------------------------+
| Bram Primitive | String  | "block"| Dictates how the bram is placed on the FPGA. Options are       |   
|                |         |        | "block", "auto", "distributed" and "ultra".                    |
+----------------+---------+--------+----------------------------------------------------------------+

==================
Bram Delay Prog DP
==================
A delay module that uses a dual port BRAM to delay the input by the delay period provided.

-----
Ports
-----
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| Signal         | Type            | Size                      | Description                                                     |
+================+=================+===========================+=================================================================+
| din            | std_logic_vector| any                       | The input signal to be delayed by the delay parameter provided. |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| delay          | std_logic_vector| Max Delay                 | The programmable delay value of length Max Delay.               |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| dout           | std_logic_vector| Width of din              | The delayed din signal delayed by :math:`bram_latency + delay`. |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+

----------
Parameters
----------
+----------------+---------+--------+----------------------------------------------------------------+
| Generic        | Type    | Value  | Description                                                    |
+================+=========+========+================================================================+
| Max Delay      | Natural | 7      | Maximum 2^max_delay number of clock cycles by which you want   |
|                |         |        | to delay din.                                                  |      
+----------------+---------+--------+----------------------------------------------------------------+
| BRAM Latency   | Natural | 5      | The bram latency delay.                                        |
+----------------+---------+--------+----------------------------------------------------------------+
| Bram Primitive | String  | "block"| Dictates how the bram is placed on the FPGA. Options are       |   
|                |         |        | "block", "auto", "distributed" and "ultra".                    |
+----------------+---------+--------+----------------------------------------------------------------+
| Is Asynchronous| Boolean | False  | If checked, the block provides an asynchronous enable/disable  |
+----------------+---------+--------+----------------------------------------------------------------+


==========
Delay Sync
==========
Delay an infrequent boolean pulse by  a run-time programmable number or provided parameter of enabled clocks.  
If the input pulse repeats before the output pulse is generated, an internal counter
resets and that output pulse is never generated. When delay is changed, some randomly determined 
samples will be inserted/dropped from the buffered stream.

-----
Ports
-----
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| Signal         | Type            | Size                      | Description                                                     |
+================+=================+===========================+=================================================================+
| din            | std_logic_vector| 1                         | The input signal to be delayed by the delay parameter provided. |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| en             | std_logic       | 1                         | This port will drive the delay process when operating           |
|                |                 |                           | asynchronously (optional).                                      |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| delay          | std_logic_vector| 1                         | The programmable delay value (optional).                        |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| dout           | std_logic_vector| Width of din              | The delayed din signal delayed by :math:`bram_latency + delay`. |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+

----------
Parameters
----------
+----------------+---------+--------+----------------------------------------------------------------+
| Generic        | Type    | Value  | Description                                                    |
+================+=========+========+================================================================+
| Delay length   | Natural | 4      | Delay number of clock cycles by which you want                 |
|                |         |        | to delay din.                                                  |      
+----------------+---------+--------+----------------------------------------------------------------+
| Asynchronous   | Boolean | False  | If checked, the block provides an asynchronous enable/disable. |
+----------------+---------+--------+----------------------------------------------------------------+
| Use delay load | Boolean | False  | If checked, the block provides a port to programmatically      |
|                |         |        | load the delay.                                                |
+----------------+---------+--------+----------------------------------------------------------------+

============
Window Delay
============
Delay a 1 bit pulse by a specified number of clock cycles. 
The output pulse will be delayed by the number of clock cycles specified by the delay parameter.

-----
Ports
-----
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| Signal         | Type            | Size                      | Description                                                     |
+================+=================+===========================+=================================================================+
| din            | std_logic_vector| 1                         | The input signal to be delayed by the delay parameter provided. |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| dout           | std_logic_vector| 1                         | The delayed din signal delayed by :math:`bram_latency + delay`. |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+

----------
Parameters
----------
+----------------+---------+--------+----------------------------------------------------------------+
| Generic        | Type    | Value  | Description                                                    |
+================+=========+========+================================================================+
| Delay length   | Natural | 4      | Delay number of clock cycles by which you want                 |
|                |         |        | to delay din.                                                  |      
+----------------+---------+--------+----------------------------------------------------------------+

========
Pipeline
========
An explicitly laid-out delay line for use in pipelining to help achieve timing closure. This is behavioural model design so tools 
will design how it is internally implemented.

-----
Ports
-----
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| Signal         | Type            | Size                      | Description                                                     |
+================+=================+===========================+=================================================================+
| d              | std_logic_vector| any                       | The input signal to be pipelined by the provided latency        |
|                |                 |                           | parameter                                                       |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+
| q              | std_logic_vector| Width of din              | The delayed d signal                                            |
+----------------+-----------------+---------------------------+-----------------------------------------------------------------+

----------
Parameters
----------
+----------------+---------+--------+----------------------------------------------------------------+
| Generic        | Type    | Value  | Description                                                    |
+================+=========+========+================================================================+     
| pipeline_len   | Natural | 4      | The natural number of clock cycles to pipeline in input by     |
+----------------+---------+--------+----------------------------------------------------------------+