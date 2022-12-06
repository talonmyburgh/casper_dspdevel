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