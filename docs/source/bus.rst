####################
Bus Library
####################
.. _bus:

*******
Purpose
*******
.. _bus_purpose:

The bus library contains all casper_bus HDL modules wrapped for Simulink.
These blocks manipulate standard logic-vectors in conventional ways. "Sub-vector" is a term
used to refer to a slice or sub-section of the overall logic-vector.

===============
Bus Accumulator
===============
Applies individual accumulators (:ref:`Accumulator Library<accumulator>`) to sub-vectors.

-----
Ports
-----
+-------------+-----------------+------------+-------------------------------------------------+
| Signal      | Type            | Size       | Description                                     |
+=============+=================+============+=================================================+
| din         | std_logic_vector| any        | The input vector, constituted by the sub-vectors|
|             |                 |            | that are accumulated.                           |
+-------------+-----------------+------------+-------------------------------------------------+
| dout        | std_logic_vector| any        | The output vector of accumulations, each        |
|             |                 |            | expanded.                                       |  
+-------------+-----------------+------------+-------------------------------------------------+

----------
Parameters
----------
+---------------------+------------------+----------+------------------------------------------------------------+
| Generic             | Type             | Value    | Description                                                |
+=====================+==================+==========+============================================================+
| Data Type           | "UNSIGNED" or    | "SIGNED" | The switch to treat the sub-vectors as signed or unsigned. |
|                     | "SIGNED"         |          |                                                            |
+---------------------+------------------+----------+------------------------------------------------------------+
| Constituent Widths  | Comma-delimited  | 4,1,2,1  | The bit-width of each sub-vector.                          |
|                     | Integers         |          |                                                            |
+---------------------+------------------+----------+------------------------------------------------------------+
| Constituent         | Comma-delimited  | 9,6,7,6  | The bit-width of each accumulated output sub-vector.       |
| Expansion Widths    | Integers         |          |                                                            |
+---------------------+------------------+----------+------------------------------------------------------------+

==================
Bus Fill SLV Array
==================
Duplicates an input standard logic-vector to each index of an output array. This is not exposed to simulink due to
the use of the custom `t_slv_arr` type in the interface.

-----
Ports
-----
+-------------+-----------------+------------+-------------------------------------------------+
| Signal      | Type            | Size       | Description                                     |
+=============+=================+============+=================================================+
| i_data      | std_logic_vector| any        | The input vector.                               |
+-------------+-----------------+------------+-------------------------------------------------+
| o_data      | t_slv_arr       | (any, any) | The output vectors, duplications of the input.  |  
+-------------+-----------------+------------+-------------------------------------------------+

----------
Parameters
----------
+---------------------+------------------+----------+------------------------------------------------------------+
| Generic             | Type             | Value    | Description                                                |
+=====================+==================+==========+============================================================+
| Latency             | Natural          |          | The latency of the duplication.                            |
+---------------------+------------------+----------+------------------------------------------------------------+

===========
Bus Mux
===========
Multiplexes an input standard logic-array, outputing one selected (by index) standard logic vector.

-----
Ports
-----
+-------------+-----------------+------------+-------------------------------------------------+
| Signal      | Type            | Size       | Description                                     |
+=============+=================+============+=================================================+
| i_sel       | std_logic_vector| any        | The index selection.                            |
+-------------+-----------------+------------+-------------------------------------------------+
| i_data      | t_slv_arr       | (any, any) | The input vectors.                              |
+-------------+-----------------+------------+-------------------------------------------------+
| o_data      | std_logic_vector| any        | The selection, output vector.                   |  
+-------------+-----------------+------------+-------------------------------------------------+

----------
Parameters
----------
+---------------------+------------------+----------+------------------------------------------------------------+
| Generic             | Type             | Value    | Description                                                |
+=====================+==================+==========+============================================================+
| Delay               | Natural          | 1        | The latency of the multiplexion.                           |
+---------------------+------------------+----------+------------------------------------------------------------+


==================
Bus Replicate
==================
Concatenates duplications of an input standard logic-vector to an output logic-vector. This essentially flattens
the output of the Fill SLV Array component.

-----
Ports
-----
+-------------+-----------------+------------+-------------------------------------------------+
| Signal      | Type            | Size       | Description                                     |
+=============+=================+============+=================================================+
| i_data      | std_logic_vector| any        | The input vector.                               |
+-------------+-----------------+------------+-------------------------------------------------+
| o_data      | std_logic_vector| any        | The output vector, concatenated duplications of |
|             |                 |            | the input.                                      |
+-------------+-----------------+------------+-------------------------------------------------+

----------
Parameters
----------
+---------------------+------------------+----------+------------------------------------------------------------+
| Generic             | Type             | Value    | Description                                                |
+=====================+==================+==========+============================================================+
| Replication Factor  | Natural          |          | The number of duplications.                                |
+---------------------+------------------+----------+------------------------------------------------------------+
| Latency             | Natural          |          | The latency of the duplication.                            |
+---------------------+------------------+----------+------------------------------------------------------------+
