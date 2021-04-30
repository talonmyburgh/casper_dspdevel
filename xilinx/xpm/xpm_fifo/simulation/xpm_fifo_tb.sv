//------------------------------------------------------------------------------
//
// XPM FIFO Generator Core Demo Testbench 
//
//------------------------------------------------------------------------------
//
// Copyright (c) 2016, Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//------------------------------------------------------------------------------
//
// Filename: xpm_fifo_tb.sv
//
// Description:
//   This is the demo testbench top file for xpm_fifo.
//
`timescale 1ns/1ps
module xpm_fifo_tb;

  //testbench parameters
  parameter integer                 FREEZEON_ERROR = 0;
  parameter integer                 TB_STOP_CNT    = 2;
  parameter integer                 TB_SEED        = 20;

  // Common module parameters
  parameter                         CLOCK_DOMAIN       = "INDEPENDENT"; // CLOCK_DOMAIN must be "COMMON" for synchronous fifo, "INDEPENDENT" for asynchronous fifo
  parameter                         RELATED_CLOCKS     = 0;
  parameter                         FIFO_MEMORY_TYPE   = "BRAM";
  parameter                         ECC_MODE           = "NO_ECC";
  parameter integer                 FIFO_WRITE_DEPTH   = 512;
  parameter integer                 WRITE_DATA_WIDTH   = 288;
  parameter integer                 WR_DATA_COUNT_WIDTH = 10;
  parameter integer                 PROG_FULL_THRESH   = 450;
  parameter integer                 FULL_RESET_VALUE   = 0;
  parameter                         READ_MODE          = "FWFT";
  parameter integer                 FIFO_READ_LATENCY  = 0;
  parameter integer                 READ_DATA_WIDTH    = 288;
  parameter                         RD_DATA_COUNT_WIDTH = 10;
  parameter integer                 PROG_EMPTY_THRESH  = 5; 
  parameter                         DOUT_RESET_VALUE   = "0";
  parameter integer                 CDC_SYNC_STAGES    = 2;
  parameter                         WAKEUP_TIME        = 0;
  parameter integer                 VERSION            = 0;


// Wire and Reg Declarations
//TB
 wire  [7:0]                      status    ; 
 reg                              wr_clk    ; 
 reg                              rd_clk    ; 
 reg                              reset      ; 
 wire                             sim_done  ; 
  
 // Generation of clock
 always #20 wr_clk = ~wr_clk;
 always #10 rd_clk = ~rd_clk;
  
 initial
 begin
       wr_clk = 1'b0;
       rd_clk = 1'b0;
       reset  = 1'b1;
 #4000 reset  = 1'b0;
 end 

 always @(status)
 begin
   if(status[7])
       $error("Data mismatch found");
   if(status[5])
       $error("Empty flag Mismatch/timeout");
   if(status[6])
       $error("Full Flag Mismatch/timeout");
 end

 initial
 begin
   wait(sim_done);
   if((status != 'h0) && (status != 'h1))
         $error("Simulation failed");
   else 
         $info("Test Completed Successfully");
   $finish;
 end

 initial
 begin
   #900ms;
         $display("Test bench timed out");
         $finish;
 end  
  
  xpm_fifo_ex # (
    .FREEZEON_ERROR       (FREEZEON_ERROR      ),
    .TB_STOP_CNT          (TB_STOP_CNT         ),
    .TB_SEED              (TB_SEED             ),
    .CLOCK_DOMAIN         (CLOCK_DOMAIN        ),
    .RELATED_CLOCKS       (RELATED_CLOCKS      ),
    .FIFO_MEMORY_TYPE     (FIFO_MEMORY_TYPE    ),
    .ECC_MODE             (ECC_MODE            ),
    .FIFO_WRITE_DEPTH     (FIFO_WRITE_DEPTH    ),
    .WRITE_DATA_WIDTH     (WRITE_DATA_WIDTH    ),
    .WR_DATA_COUNT_WIDTH  (WR_DATA_COUNT_WIDTH ),
    .PROG_FULL_THRESH     (PROG_FULL_THRESH    ),
    .FULL_RESET_VALUE     (FULL_RESET_VALUE    ),
    .READ_MODE            (READ_MODE           ),
    .FIFO_READ_LATENCY    (FIFO_READ_LATENCY   ),
    .READ_DATA_WIDTH      (READ_DATA_WIDTH     ),
    .RD_DATA_COUNT_WIDTH  (RD_DATA_COUNT_WIDTH ),
    .PROG_EMPTY_THRESH    (PROG_EMPTY_THRESH   ),
    .DOUT_RESET_VALUE     (DOUT_RESET_VALUE    ),
    .CDC_SYNC_STAGES      (CDC_SYNC_STAGES     ),
    .WAKEUP_TIME          (WAKEUP_TIME         ),
    .VERSION              (VERSION             )
  ) xpm_fifo_ex_inst (
    .rst                  (reset),
    .wr_clk               (wr_clk),
    .rd_clk               (rd_clk),
    .sim_done             (sim_done),
    .status               (status)
  );

endmodule// : xpm_fifo_tb
  
module xpm_fifo_ex # (
  //testbench parameters
  parameter integer                 FREEZEON_ERROR       = 0,
  parameter integer                 TB_STOP_CNT          = 2,
  parameter integer                 TB_SEED              = 20,
  // Common module parameters
  parameter                         CLOCK_DOMAIN         = "COMMON",
  parameter                         RELATED_CLOCKS       = 0,
  parameter                         FIFO_MEMORY_TYPE     = "BRAM",
  parameter                         ECC_MODE             = "NO_ECC",
  parameter integer                 FIFO_WRITE_DEPTH     = 2048,
  parameter integer                 WRITE_DATA_WIDTH     = 32,
  parameter integer                 WR_DATA_COUNT_WIDTH  = 10,
  parameter integer                 PROG_FULL_THRESH     = 256,
  parameter integer                 FULL_RESET_VALUE     = 0,
  parameter                         READ_MODE            = "STD",
  parameter integer                 FIFO_READ_LATENCY    = 1,
  parameter integer                 READ_DATA_WIDTH      = WRITE_DATA_WIDTH,
  parameter                         RD_DATA_COUNT_WIDTH  = 10,
  parameter integer                 PROG_EMPTY_THRESH    = 256,
  parameter                         DOUT_RESET_VALUE     = "",
  parameter integer                 CDC_SYNC_STAGES      = 2,
  parameter                         WAKEUP_TIME          = 0,
  parameter integer                 VERSION              = 0
) (
  input  wire                           rst,
  input  wire                           wr_clk,
  input  wire                           rd_clk,
  output wire                           sim_done,
  output wire [7:0]                     status
);

  localparam integer FIFO_READ_DEPTH  = (FIFO_WRITE_DEPTH * WRITE_DATA_WIDTH)/(READ_DATA_WIDTH);
  localparam integer WR_PNTR_WIDTH    = $clog2(FIFO_WRITE_DEPTH);
  localparam integer RD_PNTR_WIDTH    = $clog2(FIFO_READ_DEPTH);
  localparam         FWFT_ENABLED     = (READ_MODE == "FWFT") ? 1 : 0;

//reg-wire Decalrations
 reg                              sleep     ;
 wire                             prog_full ;
 wire [WR_DATA_COUNT_WIDTH-1:0]   wr_data_count;
 wire                             overflow;
 wire                             wr_rst_busy;
 wire                             prog_empty;
 wire [RD_DATA_COUNT_WIDTH-1:0]   rd_data_count;
 wire                             underflow;
 wire                             rd_rst_busy;
 reg                              injectsbiterr;
 reg                              injectdbiterr;
 wire                             sbiterr;
 wire                             dbiterr;
// FIFO interface signal declarations
 wire                             wr_en  ; 
 wire                             rd_en  ; 
 wire  [WRITE_DATA_WIDTH-1:0]     din    ; 
 wire  [READ_DATA_WIDTH-1:0]      dout   ; 
 wire  [READ_DATA_WIDTH-1:0]      dout_i ; 
 wire                             full   ; 
 wire                             empty  ; 

 wire  [WRITE_DATA_WIDTH-1:0]     wr_data        ;
 wire                             wr_en_i        ;
 wire                             rd_en_i        ;
 wire                             full_i         ;
 wire                             empty_i        ;
 wire                             almost_full_i  ;
 wire                             almost_empty_i ;
 wire                             prc_we_i       ;
 wire                             prc_re_i       ;
 wire                             dout_chk_i     ;
 wire                             rst_int_rd     ;
 wire                             rst_int_wr     ;
 wire                             reset_en       ;

 reg                              rst_async_wr1  ;
 reg                              rst_async_wr2  ;
 reg                              rst_async_wr3  ;
 reg                              rst_async_rd1  ;
 reg                              rst_async_rd2  ;
 reg                              rst_async_rd3  ;
 wire                             rd_clk_i    ; 


// XPM FIFO Module Instantiation
  generate begin : gen_xpm_fifo
    if (CLOCK_DOMAIN == "COMMON") begin : gen_xpm_fifo_sync
      xpm_fifo_sync # (
        .FIFO_MEMORY_TYPE    (FIFO_MEMORY_TYPE  ),
        .ECC_MODE            (ECC_MODE          ),
        .FIFO_WRITE_DEPTH    (FIFO_WRITE_DEPTH  ),
        .WRITE_DATA_WIDTH    (WRITE_DATA_WIDTH  ),
        .WR_DATA_COUNT_WIDTH (WR_DATA_COUNT_WIDTH),
        .FULL_RESET_VALUE    (FULL_RESET_VALUE  ),
        .PROG_FULL_THRESH    (PROG_FULL_THRESH  ),
        .READ_MODE           (READ_MODE         ),
        .FIFO_READ_LATENCY   (FIFO_READ_LATENCY ),
        .READ_DATA_WIDTH     (READ_DATA_WIDTH   ),
        .RD_DATA_COUNT_WIDTH (RD_DATA_COUNT_WIDTH),
        .PROG_EMPTY_THRESH   (PROG_EMPTY_THRESH ),
        .DOUT_RESET_VALUE    (DOUT_RESET_VALUE  ),
        .WAKEUP_TIME         (WAKEUP_TIME       ),
        .VERSION             (VERSION           )
      ) xpm_fifo_sync_inst (
        .sleep            (sleep),
        .rst              (rst),
        .wr_clk           (wr_clk),
        .wr_en            (wr_en),
        .din              (din),
        .full             (full),
        .prog_full        (prog_full),
        .wr_data_count    (wr_data_count),
        .overflow         (overflow),
        .wr_rst_busy      (wr_rst_busy),
        .rd_en            (rd_en),
        .dout             (dout),
        .empty            (empty),
        .prog_empty       (prog_empty),
        .rd_data_count    (rd_data_count),
        .underflow        (underflow),
        .rd_rst_busy      (rd_rst_busy),
        .injectsbiterr    (injectsbiterr),
        .injectdbiterr    (injectdbiterr),
        .sbiterr          (sbiterr),
        .dbiterr          (dbiterr)
      );
    end// : gen_xpm_fifo_sync

    if (CLOCK_DOMAIN == "INDEPENDENT") begin : gen_xpm_fifo_async
      xpm_fifo_async # (
        .FIFO_MEMORY_TYPE    (FIFO_MEMORY_TYPE  ),
        .ECC_MODE            (ECC_MODE          ),
        .RELATED_CLOCKS      (RELATED_CLOCKS    ),
        .FIFO_WRITE_DEPTH    (FIFO_WRITE_DEPTH  ),
        .WRITE_DATA_WIDTH    (WRITE_DATA_WIDTH  ),
        .WR_DATA_COUNT_WIDTH (WR_DATA_COUNT_WIDTH),
        .PROG_FULL_THRESH    (PROG_FULL_THRESH  ),
        .FULL_RESET_VALUE    (FULL_RESET_VALUE  ),
        .READ_MODE           (READ_MODE         ),
        .FIFO_READ_LATENCY   (FIFO_READ_LATENCY ),
        .READ_DATA_WIDTH     (READ_DATA_WIDTH   ),
        .RD_DATA_COUNT_WIDTH (RD_DATA_COUNT_WIDTH),
        .PROG_EMPTY_THRESH   (PROG_EMPTY_THRESH ),
        .DOUT_RESET_VALUE    (DOUT_RESET_VALUE  ),
        .CDC_SYNC_STAGES     (CDC_SYNC_STAGES   ),
        .WAKEUP_TIME         (WAKEUP_TIME       ),
        .VERSION             (VERSION           )
      ) xpm_fifo_async_inst (
        .sleep            (sleep),
        .rst              (rst),
        .wr_clk           (wr_clk),
        .wr_en            (wr_en),
        .din              (din),
        .full             (full),
        .prog_full        (prog_full),
        .wr_data_count    (wr_data_count),
        .overflow         (overflow),
        .wr_rst_busy      (wr_rst_busy),
        .rd_clk           (rd_clk),
        .rd_en            (rd_en),
        .dout             (dout),
        .empty            (empty),
        .prog_empty       (prog_empty),
        .rd_data_count    (rd_data_count),
        .underflow        (underflow),
        .rd_rst_busy      (rd_rst_busy),
        .injectsbiterr    (injectsbiterr),
        .injectdbiterr    (injectdbiterr),
        .sbiterr          (sbiterr),
        .dbiterr          (dbiterr)
      );
    end// : gen_xpm_fifo_async
  end// : gen_xpm_fifo
  endgenerate

  //Reset generation logic 
  assign rst_int_wr  = rst_async_wr3;
  assign rst_int_rd  = rst_async_rd3;

  //Testbench reset synchronization
  always @(posedge rd_clk)
  begin
    if(rst)
    begin
      rst_async_rd1     <= 1'b1;
      rst_async_rd2     <= 1'b1;
      rst_async_rd3     <= 1'b1;
    end
    else
    begin
      rst_async_rd1     <= rst;
      rst_async_rd2     <= rst_async_rd1;
      rst_async_rd3     <= rst_async_rd2;
      end
  end

  always @(posedge wr_clk)
  begin
    if(rst)
    begin
      rst_async_wr1     <= 1'b1;
      rst_async_wr2     <= 1'b1;
      rst_async_wr3     <= 1'b1;
    end
    else
    begin
      rst_async_wr1     <= rst;
      rst_async_wr2     <= rst_async_wr1;
      rst_async_wr3     <= rst_async_wr2;
      end
  end

  assign  din      = wr_data;
  assign  dout_i   = dout;
  assign  wr_en    = wr_en_i;
  assign  rd_en    = rd_en_i;
  assign  full_i   = full;
  assign  empty_i  = empty;
  assign  rd_clk_i = (CLOCK_DOMAIN == "COMMON") ? wr_clk : rd_clk ;

  xpm_fifo_gen_dgen #(
      .C_DIN_WIDTH    (WRITE_DATA_WIDTH),
      .C_DOUT_WIDTH   (READ_DATA_WIDTH),
      .TB_SEED        (TB_SEED) 
    ) xpm_dgen_inst (  
      .rst        (rst_int_wr),
      .wr_clk     (wr_clk),
      .prc_wr_en  (prc_we_i),
      .full       (full_i),
      .wr_en      (wr_en_i),
      .wr_data    (wr_data)
    );

  xpm_fifo_gen_dverif #(
      .C_DOUT_WIDTH       (READ_DATA_WIDTH),
      .C_DIN_WIDTH        (WRITE_DATA_WIDTH),
      .C_USE_EMBEDDED_REG (1),
      .TB_SEED            (TB_SEED),
      .FWFT_ENABLED       (FWFT_ENABLED), 
      .FIFO_READ_LATENCY  (FIFO_READ_LATENCY), 
      .C_CH_TYPE          (0)
    ) xpm_fifo_dverif_inst(
      .rst        (rst_int_rd),
      .rd_clk     (rd_clk_i),
      .prc_rd_en  (prc_re_i),
      .rd_en      (rd_en_i),
      .empty      (empty_i),
      .data_out   (dout),
      .dout_chk   (dout_chk_i)
    );

  xpm_fifo_gen_pctrl #(
      .C_APPLICATION_TYPE  (0),
      .C_DOUT_WIDTH        (READ_DATA_WIDTH),
      .C_DIN_WIDTH         (WRITE_DATA_WIDTH),
      .C_WR_PNTR_WIDTH     (WR_PNTR_WIDTH),
      .C_RD_PNTR_WIDTH     (RD_PNTR_WIDTH),
      .C_CH_TYPE           (0),
      .FREEZEON_ERROR      (FREEZEON_ERROR),
      .TB_SEED             (TB_SEED), 
      .TB_STOP_CNT         (TB_STOP_CNT)
    ) xpm_fifo_pctrl_inst(
      .RESET_WR       (rst_int_wr),
      .RESET_RD       (rst_int_rd),
      .RESET_EN       (reset_en),
      .WR_CLK         (wr_clk),
      .RD_CLK         (rd_clk_i),
      .PRC_WR_EN      (prc_we_i),
      .PRC_RD_EN      (prc_re_i),
      .FULL           (full_i),
      .ALMOST_FULL    (almost_full_i),
      .ALMOST_EMPTY   (almost_empty_i),
      .DOUT_CHK       (dout_chk_i),
      .EMPTY          (empty_i),
      .DATA_IN        (wr_data),
      .DATA_OUT       (dout),
      .SIM_DONE       (sim_done),
      .STATUS         (status)
    );
  
endmodule// : xpm_fifo_ex 


// Module Name: xpm_fifo_gen_dverif
// Description:
//   Used for XPM FIFO read interface stimulus generation and data checking
module xpm_fifo_gen_dverif #(
   parameter integer  C_DIN_WIDTH        = 18,
   parameter integer  C_DOUT_WIDTH       = 18,
   parameter integer  C_USE_EMBEDDED_REG = 0,
   parameter integer  C_CH_TYPE          = 0,
   parameter          FWFT_ENABLED       = 0,
   parameter          FIFO_READ_LATENCY  = 0,
   parameter integer  TB_SEED            = 2
) (
   input                          rst        ,
   input                          rd_clk     ,
   input                          prc_rd_en  ,
   input                          empty      ,
   input  [C_DOUT_WIDTH-1 : 0]    data_out   ,
   output                         rd_en      ,
   output                         dout_chk   
);

 localparam          C_DATA_WIDTH = (C_DIN_WIDTH > C_DOUT_WIDTH) ? C_DIN_WIDTH : C_DOUT_WIDTH ;
 localparam          C_EXPECTED_WIDTH = (C_DIN_WIDTH < C_DOUT_WIDTH) ? C_DOUT_WIDTH : C_DIN_WIDTH;
 localparam          EXTRA_WIDTH  = (C_CH_TYPE == 2) ? 1 : 0; 
 localparam  integer DATA_BYTES   = (C_DATA_WIDTH+EXTRA_WIDTH)/8;
 localparam          LOOP_COUNT   = (((C_DATA_WIDTH+EXTRA_WIDTH)% 8) == 0)? DATA_BYTES : DATA_BYTES+1;
 localparam  integer WIDTH_RATIO  = C_DIN_WIDTH/C_DOUT_WIDTH;
 localparam  integer D_WIDTH_DIFF = $clog2(WIDTH_RATIO);


 reg  [C_EXPECTED_WIDTH-1:0]  expected_dout     ; 
 wire [8*LOOP_COUNT-1:0]      rand_num          ; 
 wire                         rd_en_i           ; 
 wire                         pr_r_en           ;
 reg                          data_chk          = 1'b0; 
 reg                          rd_en_d1          = 1'b1; 
 reg                          rd_en_d2          = 1'b0; 
 reg                          rst_d1            = 1'b0; 
 reg                          rst_d2            = 1'b0; 
 reg                          rst_d3            = 1'b0; 
 reg                          rst_d4            = 1'b0; 

 
 assign dout_chk = data_chk;
 assign rd_en    = rd_en_i;
 assign rd_en_i  = prc_rd_en;

  //-----------------------------------------------------
  // Expected data generation and checking for data_fifo
  //-----------------------------------------------------
 generate 
 begin
  if(FWFT_ENABLED == 1)
  begin
    always @(*)
    begin
        rd_en_d1 = 1'b1;
    end
  end
  else
  begin
    always @(posedge rd_clk)
    begin
      if (rst)
      begin
        rd_en_d1 <= 1'b0;
        rd_en_d2 <= 1'b0;
      end
      else
      begin
        if ((!empty) & rd_en_i & (!rd_en_d1))
        begin
          rd_en_d1 <= 1'b1;
        end
        rd_en_d2 <= rd_en_d1;
      end
    end
  end
 end
 endgenerate

 generate begin
  if (C_DIN_WIDTH <= C_DOUT_WIDTH)   begin
    assign pr_r_en       = rd_en_i & (!empty) & rd_en_d1;
    always @(*) begin
         expected_dout = rand_num;
    end
  end else begin
    reg  [D_WIDTH_DIFF-1:0]      rd_cntr       ;
    always @(posedge rd_clk) begin
      if (rst)
        rd_cntr <= 0;
      else begin
        if(rd_en_i & (!empty) & rd_en_d1) begin
          rd_cntr <= rd_cntr+1'b1;
        end
      end
    end
    assign pr_r_en       = rd_en_i & (!empty) & (&rd_cntr);
    always @(rd_cntr) begin
      if(rd_cntr == 0)
        expected_dout = rand_num;
      else
        expected_dout = {expected_dout[C_DOUT_WIDTH-1:0], expected_dout[C_DIN_WIDTH-1:C_DOUT_WIDTH]};
    end
  end
 end endgenerate

 generate begin
   for(genvar rn = LOOP_COUNT-1; rn >= 0; rn=rn-1 ) begin
     xpm_fifo_gen_rng #(
         .WIDTH (8),
         .SEED  (TB_SEED+rn)
     ) rd_gen_inst1 (
         .clk        (rd_clk),
         .rst        (rst),
         .enable     (pr_r_en),
         .random_num (rand_num[8*(rn+1)-1 : 8*rn])
     );
   end
 end endgenerate
  

 generate 
 begin
  if (FIFO_READ_LATENCY == 1)   
  begin
    always @(posedge rd_clk)
    begin
      if(rst)
        data_chk <= 1'b0;
      else
      begin
        if((!empty) & (rd_en_i & rd_en_d1))
        begin
          if(data_out == expected_dout[C_DOUT_WIDTH-1:0])
            data_chk <= 1'b0;
          else
            data_chk <= 1'b1;
        end
      end
    end
  end
 end
 endgenerate

 reg  [C_EXPECTED_WIDTH-1:0]      expected_dout_reg [FIFO_READ_LATENCY-1:0]     ; 
 reg  rd_en_i_reg [FIFO_READ_LATENCY-1:0]; 
 reg  rd_en_d1_reg [FIFO_READ_LATENCY-1:0]; 
 always @(*) begin
   expected_dout_reg[0] = expected_dout;
   rd_en_i_reg[0]       = rd_en_i;
   rd_en_d1_reg[0]      = rd_en_d1;
 end

 generate begin
   for (genvar rln = 1; rln < FIFO_READ_LATENCY; rln=rln+1 ) begin
     always @(posedge rd_clk) begin
       if(rst) begin
           expected_dout_reg[rln] <= 1'b0;
           rd_en_i_reg[rln] <= 1'b0;
           rd_en_d1_reg[rln] <= 1'b0;
       end else begin
           expected_dout_reg[rln] <= expected_dout_reg[rln-1]; 
           rd_en_i_reg[rln] <= rd_en_i_reg[rln-1];
           rd_en_d1_reg[rln] <= rd_en_d1_reg[rln-1];
       end
     end
   end
 end endgenerate

 generate 
 begin
 if (FIFO_READ_LATENCY > 1)   
 begin
   always @(posedge rd_clk)
   begin
       if(rst)
           data_chk <= 1'b0;
       else
       begin
           if((!empty) & (rd_en_i_reg[FIFO_READ_LATENCY-1] & rd_en_d1_reg[FIFO_READ_LATENCY-1]))
           begin
             if(data_out == expected_dout_reg[FIFO_READ_LATENCY-1][C_DOUT_WIDTH-1:0])
               data_chk <= 1'b0;
             else
               data_chk <= 1'b1;
           end
       end
   end
 end
 end
 endgenerate

endmodule// : xpm_fifo_gen_dverif

// Module Name: xpm_fifo_gen_rng
// Description:
//   Used for generation of pseudo random numbers
module xpm_fifo_gen_rng #(
  parameter  integer       WIDTH    = 8,
  parameter  integer       SEED     = 3
  )(
      input                     clk,
      input                     rst,
      input                     enable,
      output [WIDTH-1:0]        random_num
                                 );
  
  reg [WIDTH-1:0]        rand_temp;
  reg                    temp;

  always @(posedge clk)
  begin
    if (rst)
    begin
      temp      <= 0;
      rand_temp <= SEED[WIDTH-1:0];
    end
    else if(enable)
    begin
      temp      <= rand_temp[WIDTH-1] ~^ rand_temp[WIDTH-3] ~^ rand_temp[WIDTH-4] ~^ rand_temp[WIDTH-5];
      rand_temp <= {rand_temp[WIDTH-2:0], temp};
    end
  end
  assign random_num = rand_temp;

endmodule// : xpm_fifo_gen_rng

// Module Name: xpm_fifo_gen_dgen
// Description:
//   Used for XPM FIFO write interface stimulus generation
module xpm_fifo_gen_dgen #(
  parameter  integer       C_DIN_WIDTH = 32,
  parameter  integer       C_DOUT_WIDTH = 32,
  parameter  integer       TB_SEED = 2
)(
      input                     rst,
      input                     wr_clk,
      input                     prc_wr_en,
      input                     full,
      output                    wr_en,
      output  [C_DIN_WIDTH-1:0] wr_data
                                             );

  localparam          C_DATA_WIDTH = (C_DIN_WIDTH > C_DOUT_WIDTH) ? C_DIN_WIDTH : C_DOUT_WIDTH ;
  localparam  integer DATA_BYTES   = C_DATA_WIDTH/8;
  localparam          LOOP_COUNT   = ((C_DATA_WIDTH % 8) == 0)? DATA_BYTES : DATA_BYTES+1;
  localparam  integer WIDTH_RATIO  = C_DOUT_WIDTH/C_DIN_WIDTH;
  localparam  integer D_WIDTH_DIFF = $clog2(WIDTH_RATIO);

  reg  [D_WIDTH_DIFF-1:0]        wr_cntr       ;
  wire                           pr_w_en;
  wire [8*LOOP_COUNT-1 : 0]      rand_num;
  reg  [C_DATA_WIDTH-1 : 0]      wr_data_i;

 assign wr_en    = prc_wr_en; 
 assign #10 wr_data  = wr_data_i[C_DIN_WIDTH-1:0]; 

//Generation of DATA
generate begin : gen_stim
  for (genvar wn= LOOP_COUNT-1; wn >= 0; wn=wn-1) begin
    xpm_fifo_gen_rng #(
               .WIDTH (8),
               .SEED  (TB_SEED+wn)
    ) rd_gen_inst1 (
        .clk        (wr_clk),
        .rst        (rst),
        .enable     (pr_w_en),
        .random_num (rand_num[8*(wn+1)-1 : 8*wn])
    );
  end
end endgenerate

generate 
begin
if (C_DIN_WIDTH >= C_DOUT_WIDTH)   
begin
  assign pr_w_en   = prc_wr_en & (!full);
  always @(*)
  begin
       wr_data_i = rand_num;
  end
end
else
begin
      always @(posedge wr_clk)
      begin
         if (rst)
           wr_cntr <= 0;
         else
         begin
           if((!full) & prc_wr_en)
           begin
             wr_cntr <= wr_cntr+1'b1;
           end
         end
      end

  assign pr_w_en   = prc_wr_en & (!full) & (&wr_cntr);
  always @(wr_cntr)
  begin
      if(wr_cntr == 0)
          wr_data_i = rand_num;
      else
          wr_data_i = {wr_data_i[C_DIN_WIDTH-1:0], wr_data_i[C_DOUT_WIDTH-1:C_DIN_WIDTH]};
  end
end
end
endgenerate

endmodule// : xpm_fifo_gen_dgen

// Module Name: xpm_fifo_gen_pctrl
// Description:
//   Used for protocol control on write and read interface stimulus and status generation
module xpm_fifo_gen_pctrl #(
   parameter integer    C_APPLICATION_TYPE  = 0,
   parameter integer    C_DIN_WIDTH         = 18,
   parameter integer    C_DOUT_WIDTH        = 18,
   parameter integer    C_WR_PNTR_WIDTH     = 0,
   parameter integer    C_RD_PNTR_WIDTH     = 0,
   parameter integer    C_CH_TYPE           = 0,
   parameter integer    FREEZEON_ERROR      = 0,
   parameter integer    TB_STOP_CNT         = 2,
   parameter integer    TB_SEED             = 2
)(
       input                     RESET_WR       ,
       input                     RESET_RD       ,
       input                     WR_CLK         ,
       input                     RD_CLK         ,
       input                     FULL           ,
       input                     EMPTY          ,
       input                     ALMOST_FULL    ,
       input                     ALMOST_EMPTY   ,
       input  [C_DIN_WIDTH-1:0]  DATA_IN        ,
       input  [C_DOUT_WIDTH-1:0] DATA_OUT       ,
       input                     DOUT_CHK       ,
       output                    PRC_WR_EN      ,
       output                    PRC_RD_EN      ,
       output                    RESET_EN       ,
       output                    SIM_DONE       ,
       output [7:0]              STATUS          
);

 localparam  integer C_DATA_WIDTH    = (C_DIN_WIDTH > C_DOUT_WIDTH)? C_DIN_WIDTH : C_DOUT_WIDTH;
 localparam  integer DATA_BYTES      = C_DATA_WIDTH/8;
 localparam  integer LOOP_COUNT      = ((C_DATA_WIDTH % 8) == 0)? DATA_BYTES : DATA_BYTES+1;
 localparam  integer D_WIDTH_DIFF    = (C_DIN_WIDTH > C_DOUT_WIDTH) ? $clog2(C_DIN_WIDTH/C_DOUT_WIDTH) : (C_DIN_WIDTH < C_DOUT_WIDTH) ? $clog2(C_DOUT_WIDTH/C_DIN_WIDTH) : 1;
 localparam  integer SIM_STOP_CNTR1  = (C_CH_TYPE == 2) ? 64 : TB_STOP_CNT;

 wire                          data_chk_i          ; 
 reg                           full_chk_i   = 1'b0 ; 
 reg                           empty_chk_i  = 1'b0 ; 
 wire  [4:0]                   status_i            ; 
 reg   [4:0]                   status_d1_i  = 5'h0 ; 
 wire  [7:0]                   wr_en_gen           ; 
 wire  [7:0]                   rd_en_gen           ; 
 reg   [C_WR_PNTR_WIDTH-2:0]   wr_cntr           = 0  ; 
 reg   [C_WR_PNTR_WIDTH:0]     full_as_timeout   = 0  ; 
 reg   [C_WR_PNTR_WIDTH:0]     full_ds_timeout   = 0  ; 
 reg   [C_RD_PNTR_WIDTH-2:0]   rd_cntr           = 0  ; 
 reg   [C_RD_PNTR_WIDTH:0]     empty_as_timeout  = 0  ; 
 reg   [C_RD_PNTR_WIDTH:0]     empty_ds_timeout  = 0  ; 
 reg                           wr_en_i           = 1'b0  ; 
 reg                           rd_en_i           = 1'b0  ; 
 reg                           state             = 1'b0  ; 
 reg                           wr_control        = 1'b0  ; 
 reg                           rd_control        = 1'b0  ; 
 reg                           stop_on_err       = 1'b0  ; 
 reg   [7:0]                   sim_stop_cntr   = SIM_STOP_CNTR1[7:0];
 reg                           sim_done_i        = 1'b0  ;
 reg   [D_WIDTH_DIFF-1:0]      rdw_gt_wrw      = {D_WIDTH_DIFF{1'b1}}    ; 
 reg   [D_WIDTH_DIFF-1:0]      wrw_gt_rdw      = {D_WIDTH_DIFF{1'b1}}    ; 
 reg   [25:0]                  rd_activ_cont   = 25'd0  ;
 wire                          prc_we_i            ;
 wire                          prc_re_i            ;
 reg                           reset_en_i        = 1'b0  ;
 reg                           sim_done_d1       = 1'b0  ;
 reg                           sim_done_wr_dom1  = 1'b0  ;
 reg                           sim_done_wr_dom2  = 1'b0  ;
 reg                           empty_d1          = 1'b0  ;
 reg                           empty_wr_dom1     = 1'b0  ;
 reg                           state_d1          = 1'b0  ;
 reg                           state_rd_dom1     = 1'b0  ;
 reg                           rd_en_d1          = 1'b0  ;
 reg                           rd_en_wr_dom1     = 1'b0  ;
 reg                           wr_en_d1          = 1'b0  ;
 reg                           wr_en_rd_dom1     = 1'b0  ;
 reg                           full_chk_d1       = 1'b0  ;
 reg                           full_chk_rd_dom1  = 1'b0  ;
 reg                           empty_wr_dom2     = 1'b0  ;
 reg                           state_rd_dom2     = 1'b0  ;
 reg                           state_rd_dom3     = 1'b0  ;
 reg                           rd_en_wr_dom2     = 1'b0  ;
 reg                           wr_en_rd_dom2     = 1'b0  ;
 reg                           full_chk_rd_dom2  = 1'b0  ;
 reg                           reset_en_d1       = 1'b0  ;
 reg                           reset_en_rd_dom1  = 1'b0  ;
 reg                           reset_en_rd_dom2  = 1'b0  ;
 reg   [4:0]                   post_rst_dly_wr   = 5'b11111  ; 
 reg   [4:0]                   post_rst_dly_rd   = 5'b11111  ; 

 
 assign status_i  = {data_chk_i, full_chk_rd_dom2, empty_chk_i, 2'b00};
 assign STATUS    = {status_d1_i, 2'b00, rd_activ_cont[25]};
 assign prc_we_i = (sim_done_wr_dom2 == 1'b0) ? wr_en_i  : 1'b0;
 assign prc_re_i = (sim_done_i == 1'b0) ? rd_en_i : 1'b0;
 assign SIM_DONE   = sim_done_i;

 always @(posedge RD_CLK)
 begin
     if(prc_re_i == 1'b1)
       rd_activ_cont <= rd_activ_cont + 1'b1;
 end

//SIM_DONE SIGNAL GENERATION
always @(posedge RD_CLK)
begin
    if(RESET_RD == 1'b1)
      sim_done_i <= 1'b0;
    else
    begin
      if(((!(|sim_stop_cntr)) & (TB_STOP_CNT != 0)) | stop_on_err == 1'b1)
         sim_done_i <= 1'b1;
    end
end
// TB Timeout/Stop
 generate if (TB_STOP_CNT != 0)
 begin : fifo_tb_stop_run
     always @(posedge RD_CLK)
     begin
         if(!state_rd_dom2 & state_rd_dom3)
           sim_stop_cntr <= sim_stop_cntr - 1'b1;
     end
 end
 endgenerate

// Stop when error found
  always @(posedge RD_CLK)
  begin
      if(sim_done_i == 1'b0) 
        status_d1_i <= status_i | status_d1_i;
  end
  always @(posedge RD_CLK)
  begin
      if((FREEZEON_ERROR == 1) && (status_i != 1'b0))
        stop_on_err <= 1'b1;
  end

// CHECKS FOR FIFO
  always @(posedge RD_CLK)
  begin
      if(RESET_RD)
        post_rst_dly_rd <= 5'b11111;
      else
        post_rst_dly_rd <= post_rst_dly_rd-post_rst_dly_rd[4];
  end

  always @(posedge WR_CLK)
  begin
      if(RESET_WR)
        post_rst_dly_wr <= 5'b11111;
      else
        post_rst_dly_wr <= post_rst_dly_wr-post_rst_dly_wr[4];
  end

 generate if (C_DIN_WIDTH > C_DOUT_WIDTH)
 begin 
     always @(posedge WR_CLK)
     begin
         if(RESET_WR)
           wrw_gt_rdw <= 1;
         else
         begin
           if(rd_en_wr_dom2 & (!wr_en_i) & FULL)
             wrw_gt_rdw <= wrw_gt_rdw + 1'b1;
         end
     end
 end
 endgenerate

// FULL de-assert Counter
  always @(posedge WR_CLK)
  begin
      if(RESET_WR)
        full_ds_timeout <= 1'b0;
      else
      begin
        if(state)
        begin
          if(rd_en_wr_dom2 & (!wr_en_i) & FULL & (&wrw_gt_rdw))
            full_ds_timeout <= full_ds_timeout + 1'b1;
          else
            full_ds_timeout <= 1'b0;
        end
      end
  end
 
 generate if (C_DIN_WIDTH < C_DOUT_WIDTH)
 begin 
     always @(posedge RD_CLK)
     begin
         if(RESET_RD)
           rdw_gt_wrw <= 1;
         else
         begin
           if(wr_en_rd_dom2 & (!rd_en_i) & EMPTY)
             rdw_gt_wrw <= rdw_gt_wrw + 1'b1;
         end
     end
 end
 endgenerate
// EMPTY deassert counter
  always @(posedge RD_CLK)
  begin
    if(RESET_RD)
      empty_ds_timeout <= 1'b0;
    else
    begin
        if(!state_rd_dom2)
        begin
          if(wr_en_rd_dom2 & (!rd_en_i) & EMPTY && (&rdw_gt_wrw))
            empty_ds_timeout <= empty_ds_timeout + 1'b1;
          else
             empty_ds_timeout <= 1'b0;
        end
    end
  end

// Full check signal generation
  always @(posedge WR_CLK)
  begin
    if(RESET_WR)
      full_chk_i <= 1'b0;
    else
    begin
      if(C_APPLICATION_TYPE == 1)
        full_chk_i <= 1'b0;
      else
        full_chk_i <= (&full_as_timeout) | (&full_ds_timeout);
    end
  end

// Empty checks
  always @(posedge RD_CLK)
  begin
    if(RESET_RD)
      empty_chk_i <= 1'b0;
    else
    begin
      if(C_APPLICATION_TYPE == 1)
        empty_chk_i <= 1'b0;
      else
        empty_chk_i <= (&empty_as_timeout) | (&empty_ds_timeout);
    end
  end

  generate if(C_CH_TYPE != 2)
  begin: fifo_d_chk
    assign  PRC_WR_EN  = prc_we_i ;
    assign  PRC_RD_EN  = prc_re_i ;
    assign data_chk_i = DOUT_CHK;
  end
  endgenerate

// SYNCHRONIZERS B/W WRITE AND READ DOMAINS
  always @(posedge WR_CLK)
  begin
     if(RESET_WR)
     begin
       empty_wr_dom1     <= 1'b1;
       empty_wr_dom2     <= 1'b1;
       state_d1          <= 1'b0;
       wr_en_d1          <= 1'b0;
       rd_en_wr_dom1     <= 1'b0;
       rd_en_wr_dom2     <= 1'b0;
       full_chk_d1       <= 1'b0;
       reset_en_d1       <= 1'b0;
       sim_done_wr_dom1  <= 1'b0;
       sim_done_wr_dom2  <= 1'b0;
     end
     else
     begin
       sim_done_wr_dom1  <= sim_done_d1;
       sim_done_wr_dom2  <= sim_done_wr_dom1;
       reset_en_d1       <= reset_en_i;
       state_d1          <= state;
       empty_wr_dom1     <= empty_d1;
       empty_wr_dom2     <= empty_wr_dom1;
       wr_en_d1          <= wr_en_i;
       rd_en_wr_dom1     <= rd_en_d1;
       rd_en_wr_dom2     <= rd_en_wr_dom1;
       full_chk_d1       <= full_chk_i;
     end
   end

  always @(posedge RD_CLK)
  begin
     if(RESET_RD)
     begin
         empty_d1           <= 1'b1;
         state_rd_dom1      <= 1'b0;
         state_rd_dom2      <= 1'b0;
         state_rd_dom3      <= 1'b0;
         wr_en_rd_dom1      <= 1'b0;
         wr_en_rd_dom2      <= 1'b0;
         rd_en_d1           <= 1'b0;
         full_chk_rd_dom1   <= 1'b0;
         full_chk_rd_dom2   <= 1'b0;
         reset_en_rd_dom1   <= 1'b0;
         reset_en_rd_dom2   <= 1'b0;
         sim_done_d1        <= 1'b0;
     end
     else
     begin
         sim_done_d1        <= sim_done_i;
         reset_en_rd_dom1   <= reset_en_d1;
         reset_en_rd_dom2   <= reset_en_rd_dom1;
         empty_d1           <= EMPTY;
         rd_en_d1           <= rd_en_i;
         state_rd_dom1      <= state_d1;
         state_rd_dom2      <= state_rd_dom1;
         state_rd_dom3      <= state_rd_dom2;
         wr_en_rd_dom1      <= wr_en_d1;
         wr_en_rd_dom2      <= wr_en_rd_dom1;
         full_chk_rd_dom1   <= full_chk_d1;
         full_chk_rd_dom2   <= full_chk_rd_dom1;
     end
  end
   
   assign RESET_EN = reset_en_rd_dom2;
 

   generate if(C_CH_TYPE != 2)
   begin: data_fifo_en
   // WR_EN GENERATION
   xpm_fifo_gen_rng #(
                 .WIDTH (8),
                 .SEED  (TB_SEED+1)
                 )
         gen_rand_wr_en(
              .clk        (WR_CLK),
              .rst        (RESET_WR),
              .random_num (wr_en_gen),
              .enable     (1'b1)
            );

  always @(posedge WR_CLK)
  begin
      if(RESET_WR)
        wr_en_i   <=  1'b0;
      else
      begin
        if(state)
          wr_en_i <= wr_en_gen[0] & wr_en_gen[7] & wr_en_gen[2] & wr_control;
        else
          wr_en_i <= (wr_en_gen[3] | wr_en_gen[4] | wr_en_gen[2]) && (!post_rst_dly_wr[4]); 
      end
  end
    
  // WR_EN CONTROL
  always @(posedge WR_CLK)
  begin
      if(RESET_WR)
      begin
        wr_cntr         <= 0;
       wr_control      <= 1'b1;
       full_as_timeout <= 0;
      end
      else
      begin
       if(state)
        begin
        if(wr_en_i)
          wr_cntr <= wr_cntr + 1'b1;
        full_as_timeout <= 0;
        end
       else
        begin
        wr_cntr <= 0;
        if(!rd_en_wr_dom2)
         begin
          if(wr_en_i)
               full_as_timeout <= full_as_timeout + 1'b1;
         end
        else 
          full_as_timeout <= 0;
       end
       wr_control <= ~wr_cntr[C_WR_PNTR_WIDTH-2];
      end
  end

  // RD_EN GENERATION
    xpm_fifo_gen_rng #(
               .WIDTH (8),
               .SEED  (TB_SEED)
               )
    gen_rand_rd_en(
              .clk        (RD_CLK),
              .rst        (RESET_RD),
              .random_num (rd_en_gen),
              .enable     (1'b1)
            );

  always @(posedge RD_CLK)
  begin
      if(RESET_RD)
        rd_en_i    <= 1'b0;
      else
      begin
        if(!state_rd_dom2)
           rd_en_i <= rd_en_gen[1] & rd_en_gen[5] & rd_en_gen[3] & rd_control & (!post_rst_dly_rd[4]);
        else
          rd_en_i <= rd_en_gen[0] | rd_en_gen[6];
      end
  end

 // RD_EN CONTROL
  always @(posedge RD_CLK)
  begin
      if(RESET_RD)
      begin
        rd_cntr    <= 0;
       rd_control <= 1'b1;
       empty_as_timeout <= 0;
      end
      else
      begin
       if(!state_rd_dom2)
        begin
         if(rd_en_i)
           rd_cntr <= rd_cntr + 1'b1;
         empty_as_timeout <= 0;
        end
       else
        begin
         rd_cntr <= 0;
         if(!wr_en_rd_dom2)
          begin
           if(rd_en_i)
               empty_as_timeout <= empty_as_timeout + 1'b1;
          end
         else 
           empty_as_timeout <= 0;
        end
     rd_control <= ~rd_cntr[C_RD_PNTR_WIDTH-2];
      end
  end

  // STIMULUS CONTROL
  always @(posedge RD_CLK)
  begin
      if(RESET_WR)
      begin
        state      <= 1'b0;
       reset_en_i <= 1'b0;
      end
      else
      begin
        if(!state)
        begin
          if(FULL & !empty_wr_dom2)
              state   <= 1'b1;
        reset_en_i <= 1'b0;
        end
        else if(state)
        begin
          if(empty_wr_dom2 & (!FULL))
              state       <= 1'b0;
        reset_en_i <= 1'b1;
        end
        else
          state <= state;
      end
   end
end
endgenerate

endmodule// : xpm_fifo_gen_pctrl
