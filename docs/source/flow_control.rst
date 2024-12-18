####################
Flow Control Library
####################
.. _flowcontrol:

*******
Purpose
*******
.. _flowcontrol_purpose:

The flow-control library contains all casper_flow_control HDL modules wrapped for Simulink.
These blocks provide combinatorial entities to redirect standard logic-vectors.

===========
Bus Create
===========
Concatenates many input bus to create a unified output bus.

-----
Ports
-----
+-------------+-----------------+------------+-------------------------------------------------+
| Signal      | Type            | Size       | Description                                     |
+=============+=================+============+=================================================+
| din_0...    | std_logic_vector| any        | The input vectors                               |
+-------------+-----------------+------------+-------------------------------------------------+
| dout        | std_logic_vector| any        | The output vector                               |  
+-------------+-----------------+------------+-------------------------------------------------+

----------
Parameters
----------
+---------------------+------------------+----------+------------------------------------------------------------+
| Generic             | Type             | Value    | Description                                                |
+=====================+==================+==========+============================================================+
| Input Bit Widths    | Comma-delimited  | 4,1,2,1  | The bit-width of each input vector                         |
|                     | Integers         |          |                                                            |
+---------------------+------------------+----------+------------------------------------------------------------+

===========
Bus Expand
===========
Breaks the input bus out into many smaller, constituent output buses.

-----
Ports
-----
+-------------+-----------------+------------+-------------------------------------------------+
| Signal      | Type            | Size       | Description                                     |
+=============+=================+============+=================================================+
| din         | std_logic_vector| any        | The input vector                                |
+-------------+-----------------+------------+-------------------------------------------------+
| dout_0...   | std_logic_vector| any        | The output vectors                              |  
+-------------+-----------------+------------+-------------------------------------------------+

----------
Parameters
----------
+---------------------+------------------+----------+------------------------------------------------------------+
| Generic             | Type             | Value    | Description                                                |
+=====================+==================+==========+============================================================+
| Division Bit Widths | Comma-delimited  | 1,2,3,2  | The bit-width of output vectors                            |
|                     | Integers         |          |                                                            |
+---------------------+------------------+----------+------------------------------------------------------------+
| Radix Positions     | Comma-delimited  | 0,0,1,0  | The fixed-point radix bit-position of the output vectors   |
|                     | Integers         |          |                                                            |
+---------------------+------------------+----------+------------------------------------------------------------+
| Output Division     | Comma-delimited  | 2,1,0,0  | The cast-type of each output vector:                       |
| Types               | Integers {0,1,2} |          | (ufix=0, fix=1, bool=2)                                    |
+---------------------+------------------+----------+------------------------------------------------------------+

===========
Munge
===========
Reorders equal-slices of the input bus.

-----
Ports
-----
+-------------+-----------------+------------+-------------------------------------------------+
| Signal      | Type            | Size       | Description                                     |
+=============+=================+============+=================================================+
| din         | std_logic_vector| any        | The input vector                                |
+-------------+-----------------+------------+-------------------------------------------------+
| dout        | std_logic_vector| any        | The output vector                               |  
+-------------+-----------------+------------+-------------------------------------------------+

----------
Parameters
----------
+---------------------+------------------+----------+------------------------------------------------------------+
| Generic             | Type             | Value    | Description                                                |
+=====================+==================+==========+============================================================+
| Number of Divisions | Integer          | 4        | The number of equally-sized divisions of the input vector  |
+---------------------+------------------+----------+------------------------------------------------------------+
| Division Size Bits  | Integer          | 2        | The bit-width of the divisions                             |
+---------------------+------------------+----------+------------------------------------------------------------+
| Packing Order       | Comma-delimited  | 3,0,2,1  | The order of division-indices that                         |
|                     | Integers         |          | determines the output vector                               |
+---------------------+------------------+----------+------------------------------------------------------------+

------------------
Standalone HDL Use
------------------

The Munge block has unconstrained std_logic_vectors in its interface so that it can be used on both little ('to')
and big ('downto') endian vectors. The packing order indices are always ascending: 0 is the first division, 1 the
next etcetera. The input and output std_logic_vectors must have lengths equal to the accumulated divisions:
e.g. `din'length = g_number_of_divisions*g_division_size_bits`.

~~~~~~~~~~~~~~~~~~~~~~~
Exemplary Instantiation
~~~~~~~~~~~~~~~~~~~~~~~
.. code-block:: vhdl
    LIBRARY IEEE, common_pkg_lib, casper_flow_control_lib;
    USE IEEE.std_logic_1164.all;
    USE common_pkg_lib.common_pkg.all;
    ENTITY munge_static is
    port (
        clk   : in std_logic := '1';
        ce    : in std_logic := '1';
        din   : in std_logic_vector(9-1 downto 0);
        dout  : out std_logic_vector(9-1 downto 0)
    );
    end ENTITY;
    ARCHITECTURE rtl of munge_static is
        CONSTANT c_number_of_divisions : NATURAL := 3;
        CONSTANT c_division_size_bits : NATURAL := 3;
        CONSTANT c_packing_order : t_natural_arr(0 to c_number_of_divisions-1) := (
            2,0,1
        );
    begin
    u_munge : entity casper_flow_control_lib.munge
    generic map (
        g_number_of_divisions => c_number_of_divisions,
        g_division_size_bits => c_division_size_bits,
        g_packing_order => c_packing_order
    )
    port map (
        clk => clk,
        ce => ce,
        din => din,
        dout => dout
    );
    end ARCHITECTURE;