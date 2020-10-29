Wideband FFT
=============

Purpose:
--------
This FFT was originally sourced from ASTRON via OpenCores. It performs an N-Point Wideband FFT on data that is partly applied in serial and partly applied in
parallel. This FFT specifically suits applications where the sample clock is higher than the DSP processing clock. For each output stream a subband statistic
unit is included which can be read via the memory mapped interface.

Module Overview:
----------------
An overview of the fft_wide unit is shown in Figure 1. The fft_wide unit calculates a N-point FFT and has P
number of input streams. Data of each input is offered to a M-point pipelined FFT, where M=N/P. The output
of all pipelined FFTs is then connected to a P-point parallel FFT that performs the final stage of the wideband
FFT. Each output of the parallel FFT is connected to a subband statistics unit that calculates the power in
each subband. The MM interface is used to read out the subband statistics.
The rTwoSDF pipelined FFT (see :ref:`r2sdf_fft`) design is used as building block for the development of the wideband extension.

.. figure:: ./_images/widebandunit_overview.png
  :width: 650px
  :align: center
  :figclass: align-center

Figure 1: FFT Wideband Unit Overview
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



Firmware Interface:
-------------------

Clock Domains
~~~~~~~~~~~~~
There are two clock domains used in the fft_wide unit: the mm_clk and the dp_clk domain. Figure 2 shows
an overview of the clock domains in the fft_wide unit. The only unit that is connected to both clock domains is
the memory of the subband statistics module. This memory is a dual ported ram that holds the results of the
subband statistics. Table 1 lists both clocks and their characteristics.

+--------+----------------+------------------------+
| Name   | Frequency (MHz)| Description            |
+========+================+========================+
| DP_CLK | 200 MHz        | Clock for datapath     |
+--------+----------------+------------------------+
| MM_CLK | 125 MHz        | Clock for mm interface |
+--------+----------------+------------------------+

Parameters
~~~~~~~~~~
+----------------+---------+-------+----------------------------------------------------------------+
| Generic        | Type    | Value | Description                                                    |
+================+=========+=======+================================================================+
| use_reorder    | Boolean | true  | When set to ‘true’, the output bins of the FFT are reordered   |
|                |         |       | in such a way that the first bin represents the lowest         |
|                |         |       | frequency and the highest bin represents the highest frequency.|
+----------------+---------+-------+----------------------------------------------------------------+
| use_fft_shift  | Boolean | true  | False for [0, pos, neg] bin frequencies order, true for        |
|                |         |       | [neg, 0, pos] bin frequencies order in case of complex input   |  
+----------------+---------+-------+----------------------------------------------------------------+
| use_separate   | Boolean | true  | When set to ‘true’ a separate algorithm will be enabled in     |
|                |         |       | order to retrieve two separate spectra from the output of the  |
|                |         |       | complex FFT in case both the real and imaginary input of the   |
|                |         |       | complex FFT are fed with two independent real signals.         |
+----------------+---------+-------+----------------------------------------------------------------+
| nof_chan       | Natural | 0     | Defines the number of channels (=time-multiplexed input        |
|                |         |       | signals). The number of channels is :math:`2^{nof\_channels}`. |
|                |         |       | Multiple channels is only supported by the pipelined FFT.      |
+----------------+---------+-------+----------------------------------------------------------------+
| wb_factor=P    | Natural | 4     | The number that defines the wideband factor. It defines the    |
|                |         |       | number of parallel pipelined FFTs.                             |
+----------------+---------+-------+----------------------------------------------------------------+
| twiddle_offset | Natural | 0     | The twiddle offset is used for the pipelined sections in the   |
|                |         |       | wideband configuration.                                        |
+----------------+---------+-------+----------------------------------------------------------------+
| nof_points = N | Natural | 1024  | The number of points of the FFT.                               |
+----------------+---------+-------+----------------------------------------------------------------+
| in_dat_w       | Natural | 8     | Width in bits of the input data. This value specifies the      |
|                |         |       | width of both the real and the imaginary part.                 |
+----------------+---------+-------+----------------------------------------------------------------+
| out_dat_w      | Natural | 14    | The bitwidth of the real and imaginary part of the output of   |
|                |         |       | the FFT. The relation with the in_dat_w is as follows:         |
|                |         |       | :math:`out\_dat\_w=in\_dat\_w+(\log2(nof\_N))/{2+1}`.          |
+----------------+---------+-------+----------------------------------------------------------------+
| stage_dat_w    | Natural | 18    | The bitwidth of the data that is used between the stages       |
|                |         |       | (=DSP multiplier-width).                                       |
+----------------+---------+-------+----------------------------------------------------------------+
| guard_w        | Natural | 2     | Number of bits that function as guard bits. The guard bits are |
|                |         |       | required to avoid overflow in the first two stages of the FFT. |
+----------------+---------+-------+----------------------------------------------------------------+
| guard_enable   | Boolean | true  | When set to ‘true’ the input is guarded during the input resize|
|                |         |       | function, when set to ‘false’ the input is not guarded, but the|
|                |         |       | scaling is not skipped on the last stages of the FFT (based on |
|                |         |       | the value of guard_w).                                         |
+----------------+---------+-------+----------------------------------------------------------------+
