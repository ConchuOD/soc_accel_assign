`timescale 1ns/1ps
// 
// (c) Copyright 2008 - 2013 Xilinx, Inc. All rights reserved.
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
// 
//----------------------------------------------------------------------------
// User entered comments:  Clock generator created by Xilinx clock wizard
//                         Modified to add a second output @ 6.25 MHz
//----------------------------------------------------------------------------
//  Output     Output      Phase    Duty Cycle   Pk-to-Pk     Phase
//   Clock     Freq (MHz)  (degrees)    (%)     Jitter (ps)  Error (ps)
//----------------------------------------------------------------------------
// CLK_OUT1____50.000______0.000______50.0______167.017____114.212
// CLK_OUT2____06.250______0.000______50.0______???.???____???.???
//
//----------------------------------------------------------------------------
// Input Clock   Freq (MHz)    Input Jitter (UI)
//----------------------------------------------------------------------------
// __primary_________100.000____________0.010

module clock_gen_50_5 (
    input         clk_in1,      // 100 MHz input clock
    output        clk_out1,     // 50 MHz output clock
    output        clk_5_out,    // 6.25 Mhz output clock
    output        locked        // PLL lock indicator
    );

  // Input buffering
  IBUF clkin1_ibufg (
    .O (clk_in1_clk_wiz_0), 
    .I (clk_in1)
    );

  // Clocking PRIMITIVE
  //------------------------------------
  // Instantiation of the MMCM PRIMITIVE
  //    * Unused inputs are tied off
  //    * Unused outputs are labeled unused
    wire [15:0] do_unused;
    wire        drdy_unused;
    wire        psdone_unused;
    wire        locked_int;
    wire        clkfbout_clk_wiz_0;
    wire        clk_out1_clk_wiz_0;
    wire        clk_out1_clk_wiz_1;
    wire        clkfbout_buf_clk_wiz_0;
    wire        clkfboutb_unused;
    wire        clkout2_unused;
    wire        clkout3_unused;
    wire        clkout4_unused;
    wire        clkout5_unused;
    wire        clkout6_unused;
    wire        clkfbstopped_unused;
    wire        clkinstopped_unused;

    PLLE2_ADV #(
        .BANDWIDTH            ("OPTIMIZED"),
        .COMPENSATION         ("ZHOLD"),
        .DIVCLK_DIVIDE        (1),
        .CLKFBOUT_MULT        (8),
        .CLKFBOUT_PHASE       (0.000),
        
        .CLKOUT0_DIVIDE       (16),
        .CLKOUT0_PHASE        (0.000),
        .CLKOUT0_DUTY_CYCLE   (0.500),
        
        .CLKOUT1_DIVIDE       (128),
        .CLKOUT1_PHASE        (0.000),
        .CLKOUT1_DUTY_CYCLE   (0.500),
        
        .CLKIN1_PERIOD        (10.0),
        .REF_JITTER1          (0.010)
    )
    plle2_adv_inst 
    (
        // Output clocks
        .CLKFBOUT            (clkfbout_clk_wiz_0),
        .CLKOUT0             (clk_out1_clk_wiz_0),
        .CLKOUT1             (clk_out1_clk_wiz_1),
        .CLKOUT2             (clkout2_unused),
        .CLKOUT3             (clkout3_unused),
        .CLKOUT4             (clkout4_unused),
        .CLKOUT5             (clkout5_unused),
        // Input clock control
        .CLKFBIN             (clkfbout_buf_clk_wiz_0),
        .CLKIN1              (clk_in1_clk_wiz_0),
        .CLKIN2              (1'b0),
        // Tied to always select the primary input clock
        .CLKINSEL            (1'b1),
        // Ports for dynamic reconfiguration
        .DADDR               (7'h0),
        .DCLK                (1'b0),
        .DEN                 (1'b0),
        .DI                  (16'h0),
        .DO                  (do_unused),
        .DRDY                (drdy_unused),
        .DWE                 (1'b0),
        // Other control and status signals
        .LOCKED              (locked_int),
        .PWRDWN              (1'b0),
        .RST                 (1'b0));


  assign locked = locked_int;

  // Output buffering
  BUFG clkf_buf (
    .O (clkfbout_buf_clk_wiz_0),
    .I (clkfbout_clk_wiz_0)
    );

  BUFG clkout0_buf (
    .O   (clk_out1),
    .I   (clk_out1_clk_wiz_0)
    );

  BUFG clkout1_buf (
    .O   (clk_5_out),
    .I   (clk_out1_clk_wiz_1)
    );

endmodule