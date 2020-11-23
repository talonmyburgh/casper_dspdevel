############
Wideband FFT
############

********
Purpose:
********
This FFT was originally sourced from ASTRON via OpenCores. It performs an N-Point Wideband FFT on data that is partly applied in serial and partly applied in
parallel. This FFT specifically suits applications where the sample clock is higher than the DSP processing clock. For each output stream a subband statistic
unit is included which can be read via the memory mapped interface.

This unit connects an incoming array of streaming interfaces to the wideband fft. The output of the wideband fft is 
connected to a set of subband statistics units. The statistics can be read via the memory mapped interface (TODO). 
A control unit takes care of the correct composition of the output streams(sop,eop,sync,bsn,err). These signals are 
optional and can be removed to only use the sync signal.

This unit only handles one sync at a time. Therefore the sync interval should be larger than the total
pipeline stages of the wideband FFT.

****************
Module Overview:
****************
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

*******************
Firmware Interface:
*******************

Clock Domains
=============
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

=================
Interface signals
=================

--------------
Complex input:
--------------
For complex input use_separate = false.
When use_reorder=true then the output bins of the FFT are re-ordered to 
undo the bit-reversed (or bit-flipped) default radix 2 FFT output order.
The fft_r2_wide then outputs first 0 Hz and the positive frequencies
and then the negative frequencies. The use_reorder is performed at both
the pipelined stage and the parallel stage.

When use_fft_shift=true then the fft_r2_wide then outputs the frequency
bins in incrementing order, so first the negative frequencies, then 0 Hz
and then the positive frequencies.
When use_fft_shift = true then also use_reorder must be true.

----------------
Two Real inputs:
----------------
When use_separate=true then the fft_r2_wide can be used to process two
real streams. The first real stream (A) presented on the real input, the
second real stream (B) presented on the imaginary input. The separation
unit outputs the spectrum of A and B in an alternating way.
When use_separate = true then also use_reorder must be true.
When use_separate = true then the use_fft_shift must be false, because
fft_shift() only applies to spectra for complex input.

--------
Remarks:
--------
This FFT supports a wb_factor = 1 (= only a fft_r2_pipe
instance) or wb_factor = g_fft.nof_points (= only a fft_r2_par instance).
Care must be taken to properly account for guard_w and out_gain_w,
therefore it is best to simply use a structural approach that generates
seperate instances for each case:

* wb_factor = 1                                  --> pipelined FFT
* wb_factor > 1 AND wb_factor < g_fft.nof_points --> wideband FFT
* wb_factor = g_fft.nof_points                   --> parallel FFT

This FFT uses the use_reorder in the pipeline FFT, in the parallel
FFT and also has reorder memory in the fft_sepa_wide instance. The reorder
memories in the FFTs can maybe be saved by using only the reorder memory
in the fft_sepa_wide instance. This would require changing the indexing in
fft_sepa_wide instance (TODO).

The reorder memory in the pipeline FFT, parallel FFT and in the
fft_sepa_wide could make reuse of a reorder component from the reorder
library instead of using a dedicated local solution (TODO).

**********
Parameters
**********

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
