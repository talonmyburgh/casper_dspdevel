"""
The radio astronomy delay_wideband_prog module is parameterized by the number of streams - hereafter referred to as nof_streams. 
"""

import numpy as np

def delay_wideband_prog_model(simultaneous_input_bits, delay_cycles):
    """
    Generate input and output files for the delay module where the output is delayed by delay_cycles.
    Args:
        simultaneous_input_bits (int): Number of inputs = 2^simultaneous_input_bits
        delay_cycles (int): Number of clock cycles to delay the inputs
    Returns:
        input_filename (str): Filename of the input file
        output_filename (str): Filename of the output
    """
    nof_values = 500
    nof_streams = int(2**simultaneous_input_bits)
    # Only needs to be a nof_values long.
    aranged_data = np.arange(1, nof_values+1, dtype=int)
    input_len = aranged_data.size
    input_data = np.vstack([aranged_data for _ in range(nof_streams)])
    input_data = np.atleast_2d(input_data.copy()).T  # Ensure input_data is at least 2D and transpose to get the correct shape
    # Generate expected output data. This is just going to be a file with the input data delayed by delay_cycles (padded with zeros)
    zero_pad = np.zeros(delay_cycles, dtype=int)
    out_stream_data = np.concatenate((zero_pad, aranged_data))
    output_len = out_stream_data.size
    output_data = np.vstack([out_stream_data for _ in range(nof_streams)])
    output_data = np.atleast_2d(output_data.copy()).T  # Ensure input_data is at least 2D and transpose to get the correct shape

    # Write only nof_values/wideband_factor lines to file. Columns are nof_values/wideband_factor long and there are nof_streams*wideband_factor columns
    input_filename = f"delay_input_{nof_streams}_{delay_cycles}.dat"
    with open(input_filename, 'w') as f:
        for i in range(input_len):
            i_dat = input_data[i,:]
            f.write(','.join(map(str, i_dat)) + '\n')

    # Write output data to file. Rows are 500 + delay_cycles long, columns are nof_streams long and values are comma separated
    output_filename = f"delay_output_{nof_streams}_{delay_cycles}.dat"
    with open(output_filename, 'w') as f:
        for i in range(output_len):
            o_dat = output_data[i,:]
            f.write(','.join(map(str, o_dat)) + '\n')

    return input_filename, output_filename

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description='Generate input/output files for the delay_wideband_prog model')
    parser.add_argument('--siml-in-bits', type=int, help='Number of inputs = 2^siml-in-bits')
    parser.add_argument('--delay-cycles', type=int, help='Number of clock cycles to delay the inputs')
    args = parser.parse_args()
    input_filename, output_filename = delay_wideband_prog_model(args.siml_in_bits, args.delay_cycles)
    print(f"Input file: {input_filename}")
    print(f"Output file: {output_filename}")
