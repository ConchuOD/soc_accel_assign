`timescale 1ns / 1ps    
/*************************************************************************/
/* Author: Conor Dooley 12/04/2019                                       */
/* Digital & Embedded Systems Assignment 3                               */
/*************************************************************************/
module VGAController (
    input   rst_low_i,
    input   block_clk_i,
    output  h_sync_o, 
    output  v_sync_o
    );
    
    /*************************************************************************/
    /* Declarations                                                          */
    /*************************************************************************/
    
    localparam HORZ_COUNT_WIDTH = 10;
    localparam VERT_COUNT_WIDTH = 10;

    localparam HORZ_FRONT_PORCH = 10'd16;
    localparam HORZ_BACK_PORCH  = 10'd48;
    
    localparam HORZ_COUNT_3US84 = 10'd96;
    localparam HORZ_COUNT_32US  = 10'd799;
    localparam VERT_COUNT_64US  = 10'd2;
    localparam VERT_COUNT_16MS7 = 10'd520;

    localparam HORZ_COUNT_START = HORZ_COUNT_3US84 + HORZ_BACK_PORCH;
    localparam HORZ_COUNT_END   = HORZ_COUNT_32US - HORZ_FRONT_PORCH;
    
    
    reg  [HORZ_COUNT_WIDTH-1:0] horz_count_r;
    reg  [HORZ_COUNT_WIDTH-1:0] horz_count_next_r;
    wire                        horz_enable_c;
    wire                        horz_zero_detect_c;
    wire                        horz_3us84_detect_c;
    wire                        horz_32us_detect_c;
    
    
    reg  [VERT_COUNT_WIDTH-1:0] vert_count_r;
    reg  [VERT_COUNT_WIDTH-1:0] vert_count_next_r;
    wire                        vert_enable_c;
    wire                        vert_zero_detect_c;
    wire                        vert_64us_detect_c;
    wire                        vert_16ms7_detect_c;
    
    /*************************************************************************/
    /* Counters                                                              */
    /*************************************************************************/

    //horizontal counter
    always @ (posedge block_clk_i or negedge rst_low_i)
    begin
        if (~rst_low_i) horz_count_r <= {(HORZ_COUNT_WIDTH){1'b0}};
        else            horz_count_r <= horz_count_next_r;
    end
    
    always @ (horz_enable_c, horz_count_r)
    begin
        if (horz_enable_c & horz_32us_detect_c) horz_count_next_r = {(HORZ_COUNT_WIDTH){1'b0}};
        else if (horz_enable_c)                 horz_count_next_r = horz_count_r + 1'b1;
        else                                    horz_count_next_r = horz_count_r;
    end
    
    //vertical counter
    always @ (posedge block_clk_i or negedge rst_low_i)
    begin
        if (~rst_low_i) vert_count_r <= {(VERT_COUNT_WIDTH){1'b0}};
        else            vert_count_r <= vert_count_next_r;
    end
    
    always @ (vert_enable_c, vert_count_r)
    begin
        if (vert_enable_c & vert_16ms7_detect_c) vert_count_next_r = {(VERT_COUNT_WIDTH){1'b0}};
        else if (vert_enable_c)                  vert_count_next_r = vert_count_r + 1'b1;
        else                                     vert_count_next_r = vert_count_r;
    end
    
    /*************************************************************************/
    /* Waveform Shaping Logic                                                */
    /*************************************************************************/    
    
    assign horz_enable_c       = 1'd1;
    
    assign horz_zero_detect_c  = (horz_count_r == {(HORZ_COUNT_WIDTH){1'b0}}) ? 1'b1 : 1'b0;
    assign horz_3us84_detect_c = (horz_count_r == HORZ_COUNT_3US84)           ? 1'b1 : 1'b0;
    assign horz_32us_detect_c  = (horz_count_r == HORZ_COUNT_32US)            ? 1'b1 : 1'b0;
    
    assign vert_zero_detect_c  = (vert_count_r == {(VERT_COUNT_WIDTH){1'b0}}) ? 1'b1 : 1'b0;
    assign vert_64us_detect_c  = (vert_count_r == VERT_COUNT_64US)            ? 1'b1 : 1'b0;
    assign vert_16ms7_detect_c = (vert_count_r == VERT_COUNT_16MS7)           ? 1'b1 : 1'b0;
    
    SRLatchGate hSync(
        .R(horz_3us84_detect_c),
        .S(horz_zero_detect_c),
        .Q(h_sync_o)
    );

    assign vert_enable_c       = horz_zero_detect_c;
    
    SRLatchGate vSync(
        .R(vert_64us_detect_c),
        .S(vert_zero_detect_c),
        .Q(v_sync_o)
    );
    
endmodule //end VGAController
    