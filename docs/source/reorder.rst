####################
Reorder Library
####################
.. _reorder:

*******
Purpose
*******
.. _reorder_purpose:

The reorder library contains all casper_reorder HDL modules wrapped for Simulink.
These blocks deal with reordering elements .

===========
Barrel Switcher
===========
Treats inputs and outputs like indices, shifting from one index at the input, to an offset index at the output,
wrapping around the extremes.

-----
Ports
-----
+-------------+-----------------+---------------------------+--------------------------------------------------+
| Signal      | Type            | Size                      | Description                                      |
+=============+=================+===========================+==================================================+
| i_data      | t_slv_arr       | (any, any)                | The input std_logic matrix (vector of slvs).     |
+-------------+-----------------+---------------------------+--------------------------------------------------+
| i_sel       | std_logic_vector| ceil_log2(i_data'range(1))| The offset to effect.                            |
+-------------+-----------------+---------------------------+--------------------------------------------------+
| i_sync      | std_logic       | 1                         | Pulsed input signaling the change in 'i_sel'.    |
+-------------+-----------------+---------------------------+--------------------------------------------------+
| o_sync      | std_logic       | 1                         | Pulsed output signaling shift has been effected. |
+-------------+-----------------+---------------------------+--------------------------------------------------+
| o_data      | t_slv_arr       | (any, any)                | The output std_logic matrix (vector of slvs).    |
+-------------+-----------------+---------------------------+--------------------------------------------------+

----------
Parameters
----------
+---------------------+------------------+------------------------------------------------------------+
| Generic             | Type             | Description                                                |
+=====================+==================+============================================================+
| Asynchronous        | Boolean          | Whether or not the underlying multiplexers are             |
|                     |                  | combinatoral or not.                                       |
+---------------------+------------------+------------------------------------------------------------+

===========
Square Transposer
===========
Each input is expected to stream as many elements as there are inputs, effecting a square matrix input,
where the columns and rows are fed in in parallel (across the input ports) and synchronously (across time),
respectively. The output corner turns the square matrix, such that the columns become the rows.


+=====+=====+=====+====+====+=+=====+=====+=====+=====+======+
|     | Ti4 | Ti3 | Ti2| Ti1||| To4 |	To3 | To2 | To1 |      |
+=====+=====+=====+====+====+=+=====+=====+=====+=====+======+
| In1 | d12 | d8  | d4 | d0 ||| d3  |	d2  | d1  | d0  | Out1 |
+-----+-----+-----+----+----+-+-----+-----+-----+-----+------+
| In2 | d13 | d9  | d5 | d1 ||| d7  |	d6  | d5  | d4  | Out2 |
+-----+-----+-----+----+----+-+-----+-----+-----+-----+------+
| In3 | d14 | d10 | d6 | d2 ||| d11 |	d10 | d9  | d8  | Out3 |
+-----+-----+-----+----+----+-+-----+-----+-----+-----+------+
| In4 | d15 | d11 | d7 | d3 ||| d15 |	d14 | d13 | d12 | Out4 |
+=====+=====+=====+====+====+=+=====+=====+=====+=====+======+
|     | Ti4 | Ti3 | Ti2| Ti1||| To4 |	To3 | To2 | To1 |      |
+=====+=====+=====+====+====+=+=====+=====+=====+=====+======+

-----
Ports
-----
+-------------+-----------------+---------------------------+---------------------------------------------------+
| Signal      | Type            | Size                      | Description                                       |
+=============+=================+===========================+===================================================+
| i_data      | t_slv_arr       | (any, any)                | The input std_logic matrix (vector of slvs).      |
+-------------+-----------------+---------------------------+---------------------------------------------------+
| i_sync      | std_logic       | 1                         | Pulsed input signaling the first input elements.  |
+-------------+-----------------+---------------------------+---------------------------------------------------+
| o_sync      | std_logic       | 1                         | Pulsed output signaling the first output elements.|
+-------------+-----------------+---------------------------+---------------------------------------------------+
| o_data      | t_slv_arr       | (any, any)                | The output std_logic matrix (vector of slvs).     |
+-------------+-----------------+---------------------------+---------------------------------------------------+

----------
Parameters
----------
+---------------------+------------------+------------------------------------------------------------+
| Generic             | Type             | Description                                                |
+=====================+==================+============================================================+
| Asynchronous        | Boolean          | Whether or not the underlying multiplexers are             |
|                     |                  | combinatoral or not.                                       |
+---------------------+------------------+------------------------------------------------------------+

===========
Reorder
===========

Reorders input streams according to a static vector of indices: the input streams are buffered in 
incrementing sequence and then read out according to the elements of the 'reorder_map'.

-----
Ports
-----
+-------------+-----------------+---------------------------+---------------------------------------------------+
| Signal      | Type            | Size                      | Description                                       |
+=============+=================+===========================+===================================================+
| i_data      | t_slv_arr       | (any, any)                | The input std_logic matrix (vector of slvs).      |
+-------------+-----------------+---------------------------+---------------------------------------------------+
| i_sync      | std_logic       | 1                         | Pulsed input signaling the first input elements.  |
+-------------+-----------------+---------------------------+---------------------------------------------------+
| i_en        | std_logic       | 1                         | Switch signaling something...                     |
+-------------+-----------------+---------------------------+---------------------------------------------------+
| o_sync      | std_logic       | 1                         | Pulsed output signaling the first output elements.|
+-------------+-----------------+---------------------------+---------------------------------------------------+
| o_valid     | std_logic       | 1                         | ...                                               |
+-------------+-----------------+---------------------------+---------------------------------------------------+
| o_data      | t_slv_arr       | (any, any)                | The output std_logic matrix (vector of slvs).     |
+-------------+-----------------+---------------------------+---------------------------------------------------+

----------
Parameters
----------
+---------------------+------------------+------------------------------------------------------------+
| Generic             | Type             | Description                                                |
+=====================+==================+============================================================+
| Map Latency         | Natural          | Whether or not the underlying multiplexers are             |
+---------------------+------------------+------------------------------------------------------------+
| BRAM Latency        | Natural          | Whether or not the underlying multiplexers are             |
+---------------------+------------------+------------------------------------------------------------+
| Fanout Latency      | Natural          | Whether or not the underlying multiplexers are             |
+---------------------+------------------+------------------------------------------------------------+
| Double Buffer       | Boolean          | Whether or not to double buffer the inputs. Particularly   |
|                     |                  | with order-3 reorder mappings, this reduces fanout.        |
+---------------------+------------------+------------------------------------------------------------+
| Block RAM           | Boolean          | Whether or not the RAM/ROM is directed to distributed or   |
|                     |                  | Block-RAM memory resources.                                |
+---------------------+------------------+------------------------------------------------------------+
| Software Controlled | Boolean          | Whether or not the sequence is controlled by a shared-BRAM.|
|                     |                  | Requires double-buffer to be enabled. Not yet implemented. |
+---------------------+------------------+------------------------------------------------------------+
