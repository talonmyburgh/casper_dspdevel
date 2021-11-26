from os.path import join, dirname, abspath
script_dir = dirname(__file__)

c_dsp_mult_w = 18
# c_nof_blk_per_sync = None
# c_fft_pipeline = None
# c_fft_pipeline = None
# c_fil_ppf_pipeline = None

c_stage_dat_extra_w = 28

c_wb1_two_real_1024 = {
    "g_wb_factor": 1,
    "g_nof_points": 1024,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": True,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 1,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb1_two_real = {
    "g_wb_factor": 1,
    "g_nof_points": 32,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": True,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 1,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb1_two_real_4streams = {
    "g_wb_factor": 1,
    "g_nof_points": 32,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 4,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": True,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 1,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb1_two_real_4channels = {
    "g_wb_factor": 1,
    "g_nof_points": 32,
    "g_nof_chan": 2,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": True,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 1,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb4_two_real_1024 = {
    "g_wb_factor": 4,
    "g_nof_points": 1024,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": True,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 1,
    # "g_stage_dat_w": c_stage_dat_extra_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb4_two_real = {
    "g_wb_factor": 4,
    "g_nof_points": 32,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": True,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 1,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb4_two_real_4streams = {
    "g_wb_factor": 4,
    "g_nof_points": 32,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 4,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": True,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 1,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb4_two_real_4channels = {
    "g_wb_factor": 4,
    "g_nof_points": 32,
    "g_nof_chan": 2,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": True,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 1,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb1_complex_1024 = {
    "g_wb_factor": 1,
    "g_nof_points": 1024,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb1_complex_64 = {
    "g_wb_factor": 1,
    "g_nof_points": 64,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb1_complex = {
    "g_wb_factor": 1,
    "g_nof_points": 32,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb1_complex_4streams = {
    "g_wb_factor": 1,
    "g_nof_points": 32,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 4,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb1_complex_4channels = {
    "g_wb_factor": 1,
    "g_nof_points": 32,
    "g_nof_chan": 2,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb1_complex_fft_shift = {
    "g_wb_factor": 1,
    "g_nof_points": 32,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": True,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb1_complex_flipped_1024 = {
    "g_wb_factor": 1,
    "g_nof_points": 1024,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": False,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb1_complex_flipped_64 = {
    "g_wb_factor": 1,
    "g_nof_points": 64,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": False,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb1_complex_flipped = {
    "g_wb_factor": 1,
    "g_nof_points": 32,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": False,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb4_complex_1024 = {
    "g_wb_factor": 4,
    "g_nof_points": 1024,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb4_complex_64 = {
    "g_wb_factor": 4,
    "g_nof_points": 64,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb4_complex = {
    "g_wb_factor": 4,
    "g_nof_points": 32,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb4_complex_4streams = {
    "g_wb_factor": 4,
    "g_nof_points": 32,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 4,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb4_complex_4channels = {
    "g_wb_factor": 4,
    "g_nof_points": 32,
    "g_nof_chan": 2,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb4_complex_fft_shift = {
    "g_wb_factor": 4,
    "g_nof_points": 32,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": True,
    "g_use_fft_shift": True,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb4_complex_flipped_1024 = {
    "g_wb_factor": 4,
    "g_nof_points": 1024,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": False,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb4_complex_flipped_64 = {
    "g_wb_factor": 4,
    "g_nof_points": 64,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": False,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb4_complex_flipped = {
    "g_wb_factor": 4,
    "g_nof_points": 32,
    "g_nof_chan": 0,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": False,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }
c_wb4_complex_flipped_channels = {
    "g_wb_factor": 4,
    "g_nof_points": 32,
    "g_nof_chan": 2,
    "g_nof_wb_streams": 1,
    "g_nof_taps": 16,
    "g_fil_backoff_w": 1,
    # "g_fil_in_dat_w": 8,
    # "g_fil_out_dat_w": 16,
    # "g_coef_dat_w": 16,
    "g_use_reorder": False,
    "g_use_fft_shift": False,
    "g_use_separate": False,
    # "g_fft_in_dat_w": 16,
    # "g_fft_out_dat_w": 16,
    "g_fft_out_gain_w": 0,
    # "g_stage_dat_w": c_dsp_mult_w,
    "g_guard_w": 2,
    "g_guard_enable": True,
    # "stat_data_w": 56,
    # "stat_data_sz": 2,
    # "nof_blk_per_sync": c_nof_blk_per_sync,
    # "pft_pipeline": c_fft_pipeline,
    # "fft_pipeline": c_fft_pipeline,
    # "fil_pipeline": c_fil_ppf_pipeline
    }

c_pre_ab              = abspath(join(script_dir, "./data/mem/hex/run_pfb_m_pfir_coeff_fircls1_16taps_32points_16b"))
c_pre_ab_1024         = abspath(join(script_dir, "./data/mem/hex/run_pfb_m_pfir_coeff_fircls1_16taps_1024points_16b"))
c_pre_ab_v2           = abspath(join(script_dir, "./data/mem/hex/run_pfb_m_v2_pfir_coeff_fircls1_16taps_1024points_16b"))
c_pre_c               = abspath(join(script_dir, "./data/mem/hex/run_pfb_complex_m_pfir_coeff_fircls1_16taps_32points_16b"))
c_pre_c_64            = abspath(join(script_dir, "./data/mem/hex/run_pfb_complex_m_pfir_coeff_fircls1_16taps_64points_16b"))
c_pre_c_1024          = abspath(join(script_dir, "./data/mem/hex/run_pfb_complex_m_pfir_coeff_fircls1_16taps_1024points_16b"))
c_sinusoid_chirp_1024 = abspath(join(script_dir, "./data/run_pfb_m_sinusoid_chirp_8b_16taps_1024points_16b.dat"))
c_sinusoid_chirp      = abspath(join(script_dir, "./data/run_pfb_m_sinusoid_chirp_8b_16taps_32points_16b.dat"))
c_sinusoid_1024       = abspath(join(script_dir, "./data/run_pfb_m_sinusoid_8b_16taps_1024points_16b.dat"))
c_sinusoid_1024_v2    = abspath(join(script_dir, "./data/run_pfb_m_v2_sinusoid_8b_16taps_1024points_16b.dat"))
c_sinusoid            = abspath(join(script_dir, "./data/run_pfb_m_sinusoid_8b_16taps_32points_16b.dat"))
c_impulse_chirp       = abspath(join(script_dir, "./data/run_pfb_m_impulse_chirp_8b_16taps_32points_16b.dat"))
c_noise_1024          = abspath(join(script_dir, "./data/run_pfb_m_noise_8b_16taps_1024points_16b.dat"))
c_noise               = abspath(join(script_dir, "./data/run_pfb_m_noise_8b_16taps_32points_16b.dat"))
c_dc_agwn             = abspath(join(script_dir, "./data/run_pfb_m_dc_agwn_8b_16taps_32points_16b.dat"))
c_phasor_chirp_1024   = abspath(join(script_dir, "./data/run_pfb_complex_m_phasor_chirp_8b_16taps_1024points_16b.dat"))
c_phasor_chirp_128    = abspath(join(script_dir, "./data/run_pfb_complex_m_phasor_chirp_8b_16taps_128points_16b.dat"))
c_phasor_chirp_64     = abspath(join(script_dir, "./data/run_pfb_complex_m_phasor_chirp_8b_16taps_64points_16b.dat"))
c_phasor_chirp        = abspath(join(script_dir, "./data/run_pfb_complex_m_phasor_chirp_8b_16taps_32points_16b.dat"))
c_phasor              = abspath(join(script_dir, "./data/run_pfb_complex_m_phasor_8b_16taps_32points_16b.dat"))
c_noise_complex_1024  = abspath(join(script_dir, "./data/run_pfb_complex_m_noise_complex_8b_16taps_1024points_16b.dat"))
c_noise_complex_128   = abspath(join(script_dir, "./data/run_pfb_complex_m_noise_complex_8b_16taps_128points_16b.dat"))
c_noise_complex_64    = abspath(join(script_dir, "./data/run_pfb_complex_m_noise_complex_8b_16taps_64points_16b.dat"))
c_noise_complex       = abspath(join(script_dir, "./data/run_pfb_complex_m_noise_complex_8b_16taps_32points_16b.dat"))

u_act_wb4_two_real_a0_1024 = {
  "g_diff_margin": 1,
  "g_coefs_file_prefix_ab": c_pre_ab_v2,
  "g_coefs_file_prefix_c": c_pre_c_1024,
  "g_data_file_a": c_sinusoid_1024_v2,
  "g_data_file_a_nof_lines": 51200,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 51200,
  "g_data_file_c": "UNUSED",
  "g_data_file_c_nof_lines": 0,
  "g_data_file_nof_lines": 51200,
  "g_enable_in_val_gaps": False
  }
u_act_wb4_two_real_a0_1024.update(c_wb4_two_real_1024)

u_act_wb4_two_real_ab_1024 = {
  "g_diff_margin": 1,
  "g_coefs_file_prefix_ab": c_pre_ab_1024,
  "g_coefs_file_prefix_c": c_pre_c_1024,
  "g_data_file_a": c_sinusoid_chirp_1024,
  "g_data_file_a_nof_lines": 204800,
  "g_data_file_b": c_noise_1024,
  "g_data_file_b_nof_lines": 51200,
  "g_data_file_c": "UNUSED",
  "g_data_file_c_nof_lines": 0,
  "g_data_file_nof_lines": 51200,
  "g_enable_in_val_gaps": False
  }
u_act_wb4_two_real_ab_1024.update(c_wb4_two_real_1024)

u_act_wb1_two_real_ab_1024 = {
  "g_diff_margin": 6,
  "g_coefs_file_prefix_ab": c_pre_ab_1024,
  "g_coefs_file_prefix_c": c_pre_c_1024,
  "g_data_file_a": c_sinusoid_chirp_1024,
  "g_data_file_a_nof_lines": 204800,
  "g_data_file_b": c_noise_1024,
  "g_data_file_b_nof_lines": 51200,
  "g_data_file_c": "UNUSED",
  "g_data_file_c_nof_lines": 0,
  "g_data_file_nof_lines": 51200,
  "g_enable_in_val_gaps": False
  }
u_act_wb1_two_real_ab_1024.update(c_wb1_two_real_1024)

u_act_wb1_two_real_chirp_1024 = {
  "g_diff_margin": 5,
  "g_coefs_file_prefix_ab": c_pre_ab_1024,
  "g_coefs_file_prefix_c": c_pre_c_1024,
  "g_data_file_a": c_sinusoid_chirp_1024,
  "g_data_file_a_nof_lines": 204800,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 51200,
  "g_data_file_c": "UNUSED",
  "g_data_file_c_nof_lines": 0,
  "g_data_file_nof_lines": 51200,
  "g_enable_in_val_gaps": False
  }
u_act_wb1_two_real_chirp_1024.update(c_wb1_two_real_1024)

u_act_wb1_two_real_chirp = {
  "g_diff_margin": 5,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": c_sinusoid_chirp,
  "g_data_file_a_nof_lines": 6400,
  "g_data_file_b": c_impulse_chirp,
  "g_data_file_b_nof_lines": 6400,
  "g_data_file_c": "UNUSED",
  "g_data_file_c_nof_lines": 0,
  "g_data_file_nof_lines": 6400,
  "g_enable_in_val_gaps": False
  }
u_act_wb1_two_real_chirp.update(c_wb1_two_real)

u_act_wb1_two_real_a0 = {
  "g_diff_margin": 5,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 6400,
  "g_data_file_b": c_impulse_chirp,
  "g_data_file_b_nof_lines": 6400,
  "g_data_file_c": "UNUSED",
  "g_data_file_c_nof_lines": 0,
  "g_data_file_nof_lines": 6400,
  "g_enable_in_val_gaps": False
  }
u_act_wb1_two_real_a0.update(c_wb1_two_real)

u_act_wb1_two_real_b0 = {
  "g_diff_margin": 5,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": c_sinusoid_chirp,
  "g_data_file_a_nof_lines": 6400,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 6400,
  "g_data_file_c": "UNUSED",
  "g_data_file_c_nof_lines": 0,
  "g_data_file_nof_lines": 6400,
  "g_enable_in_val_gaps": False
  }
u_act_wb1_two_real_b0.update(c_wb1_two_real)

u_rnd_wb4_two_real_noise = {
  "g_diff_margin": 5,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": c_noise,
  "g_data_file_a_nof_lines": 1600,
  "g_data_file_b": c_dc_agwn,
  "g_data_file_b_nof_lines": 1600,
  "g_data_file_c": "UNUSED",
  "g_data_file_c_nof_lines": 0,
  "g_data_file_nof_lines": 1600,
  "g_enable_in_val_gaps": True
  }
u_rnd_wb4_two_real_noise.update(c_wb4_two_real)

u_rnd_wb4_two_real_noise_channels = {
  "g_diff_margin": 5,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": c_noise,
  "g_data_file_a_nof_lines": 1600,
  "g_data_file_b": c_dc_agwn,
  "g_data_file_b_nof_lines": 1600,
  "g_data_file_c": "UNUSED",
  "g_data_file_c_nof_lines": 0,
  "g_data_file_nof_lines": 1600,
  "g_enable_in_val_gaps": True
  }
u_rnd_wb4_two_real_noise_channels.update(c_wb4_two_real_4channels)

u_rnd_wb4_two_real_noise_streams = {
  "g_diff_margin": 5,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": c_noise,
  "g_data_file_a_nof_lines": 1600,
  "g_data_file_b": c_dc_agwn,
  "g_data_file_b_nof_lines": 1600,
  "g_data_file_c": "UNUSED",
  "g_data_file_c_nof_lines": 0,
  "g_data_file_nof_lines": 1600,
  "g_enable_in_val_gaps": True
  }
u_rnd_wb4_two_real_noise_streams.update(c_wb4_two_real_4streams)

u_rnd_wb1_two_real_noise = {
  "g_diff_margin": 5,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": c_noise,
  "g_data_file_a_nof_lines": 1600,
  "g_data_file_b": c_dc_agwn,
  "g_data_file_b_nof_lines": 1600,
  "g_data_file_c": "UNUSED",
  "g_data_file_c_nof_lines": 0,
  "g_data_file_nof_lines": 1600,
  "g_enable_in_val_gaps": True
  }
u_rnd_wb1_two_real_noise.update(c_wb1_two_real)

u_rnd_wb1_two_real_noise_channels = {
  "g_diff_margin": 5,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": c_noise,
  "g_data_file_a_nof_lines": 1600,
  "g_data_file_b": c_dc_agwn,
  "g_data_file_b_nof_lines": 1600,
  "g_data_file_c": "UNUSED",
  "g_data_file_c_nof_lines": 0,
  "g_data_file_nof_lines": 1600,
  "g_enable_in_val_gaps": True
  }
u_rnd_wb1_two_real_noise_channels.update(c_wb1_two_real_4channels)

u_rnd_wb1_two_real_noise_streams = {
  "g_diff_margin": 5,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": c_noise,
  "g_data_file_a_nof_lines": 1600,
  "g_data_file_b": c_dc_agwn,
  "g_data_file_b_nof_lines": 1600,
  "g_data_file_c": "UNUSED",
  "g_data_file_c_nof_lines": 0,
  "g_data_file_nof_lines": 1600,
  "g_enable_in_val_gaps": True
  }
u_rnd_wb1_two_real_noise_streams.update(c_wb1_two_real_4streams)

u_act_wb1_complex_chirp_1024 = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab_1024,
  "g_coefs_file_prefix_c": c_pre_c_1024,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_phasor_chirp_1024,
  "g_data_file_c_nof_lines": 204800,
  "g_data_file_nof_lines": 51200,
  "g_enable_in_val_gaps": False
  }
u_act_wb1_complex_chirp_1024.update(c_wb1_complex_1024)

u_act_wb4_complex_chirp_1024 = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab_1024,
  "g_coefs_file_prefix_c": c_pre_c_1024,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_phasor_chirp_1024,
  "g_data_file_c_nof_lines": 204800,
  "g_data_file_nof_lines": 51200,
  "g_enable_in_val_gaps": False
  }
u_act_wb4_complex_chirp_1024.update(c_wb4_complex_1024)

u_act_wb1_complex_chirp_64 = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c_64,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_phasor_chirp_64,
  "g_data_file_c_nof_lines": 12800,
  "g_data_file_nof_lines": 12800,
  "g_enable_in_val_gaps": False
  }
u_act_wb1_complex_chirp_64.update(c_wb1_complex_64)

u_act_wb4_complex_chirp_64 = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c_64,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_phasor_chirp_64,
  "g_data_file_c_nof_lines": 12800,
  "g_data_file_nof_lines": 12800,
  "g_enable_in_val_gaps": False
  }
u_act_wb4_complex_chirp_64.update(c_wb4_complex_64)

u_act_wb1_complex_flipped_noise_64 = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c_64,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_noise_complex_64,
  "g_data_file_c_nof_lines": 3200,
  "g_data_file_nof_lines": 3200,
  "g_enable_in_val_gaps": False
  }
u_act_wb1_complex_flipped_noise_64.update(c_wb1_complex_flipped_64)

u_act_wb4_complex_flipped_noise_64 = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c_64,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_noise_complex_64,
  "g_data_file_c_nof_lines": 3200,
  "g_data_file_nof_lines": 3200,
  "g_enable_in_val_gaps": False
  }
u_act_wb4_complex_flipped_noise_64.update(c_wb4_complex_flipped_64)

u_act_wb4_complex_chirp = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_phasor_chirp,
  "g_data_file_c_nof_lines": 6400,
  "g_data_file_nof_lines": 6400,
  "g_enable_in_val_gaps": False
  }
u_act_wb4_complex_chirp.update(c_wb4_complex)

u_act_wb4_complex_flipped = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_phasor_chirp,
  "g_data_file_c_nof_lines": 6400,
  "g_data_file_nof_lines": 6400,
  "g_enable_in_val_gaps": False
  }
u_act_wb4_complex_flipped.update(c_wb4_complex_flipped)

u_rnd_wb4_complex_flipped_channels = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_phasor_chirp,
  "g_data_file_c_nof_lines": 6400,
  "g_data_file_nof_lines": 6400,
  "g_enable_in_val_gaps": False
  }
u_rnd_wb4_complex_flipped_channels.update(c_wb4_complex_flipped_channels)

u_rnd_wb1_complex_phasor = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_phasor,
  "g_data_file_c_nof_lines": 1600,
  "g_data_file_nof_lines": 1600,
  "g_enable_in_val_gaps": True
  }
u_rnd_wb1_complex_phasor.update(c_wb1_complex)

u_rnd_wb4_complex_phasor = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_phasor,
  "g_data_file_c_nof_lines": 1600,
  "g_data_file_nof_lines": 1600,
  "g_enable_in_val_gaps": True
  }
u_rnd_wb4_complex_phasor.update(c_wb4_complex)

u_rnd_wb1_complex_fft_shift_phasor = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_phasor,
  "g_data_file_c_nof_lines": 1600,
  "g_data_file_nof_lines": 1600,
  "g_enable_in_val_gaps": True
  }
u_rnd_wb1_complex_fft_shift_phasor.update(c_wb1_complex_fft_shift)

u_rnd_wb4_complex_fft_shift_phasor = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_phasor,
  "g_data_file_c_nof_lines": 1600,
  "g_data_file_nof_lines": 1600,
  "g_enable_in_val_gaps": True
  }
u_rnd_wb4_complex_fft_shift_phasor.update(c_wb4_complex_fft_shift)

u_rnd_wb1_complex_noise = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_noise_complex,
  "g_data_file_c_nof_lines": 1600,
  "g_data_file_nof_lines": 1600,
  "g_enable_in_val_gaps": True
  }
u_rnd_wb1_complex_noise.update(c_wb1_complex)

u_rnd_wb1_complex_noise_channels = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_noise_complex,
  "g_data_file_c_nof_lines": 1600,
  "g_data_file_nof_lines": 1600,
  "g_enable_in_val_gaps": True
  }
u_rnd_wb1_complex_noise_channels.update(c_wb1_complex_4channels)

u_rnd_wb1_complex_noise_streams = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_noise_complex,
  "g_data_file_c_nof_lines": 1600,
  "g_data_file_nof_lines": 1600,
  "g_enable_in_val_gaps": True
  }
u_rnd_wb1_complex_noise_streams.update(c_wb1_complex_4streams)

u_rnd_wb4_complex_noise = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_noise_complex,
  "g_data_file_c_nof_lines": 1600,
  "g_data_file_nof_lines": 1600,
  "g_enable_in_val_gaps": True
  }
u_rnd_wb4_complex_noise.update(c_wb4_complex)

u_rnd_wb4_complex_noise_channels = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_noise_complex,
  "g_data_file_c_nof_lines": 1600,
  "g_data_file_nof_lines": 1600,
  "g_enable_in_val_gaps": True
  }
u_rnd_wb4_complex_noise_channels.update(c_wb4_complex_4channels)

u_rnd_wb4_complex_noise_streams = {
  "g_diff_margin": 3,
  "g_coefs_file_prefix_ab": c_pre_ab,
  "g_coefs_file_prefix_c": c_pre_c,
  "g_data_file_a": "UNUSED",
  "g_data_file_a_nof_lines": 0,
  "g_data_file_b": "UNUSED",
  "g_data_file_b_nof_lines": 0,
  "g_data_file_c": c_noise_complex,
  "g_data_file_c_nof_lines": 1600,
  "g_data_file_nof_lines": 1600,
  "g_enable_in_val_gaps": True
  }
u_rnd_wb4_complex_noise_streams.update(c_wb4_complex_4streams)
