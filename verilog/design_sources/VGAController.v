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
    localparam VERT_COUNT_WIDTH = 18;
    
    localparam HORZ_COUNT_3US84 = 10'd96;
    localparam VERT_COUNT_64US  = 18'd1600;
    
    
    reg  [HORZ_COUNT_WIDTH-1:0] horz_count_r;
    reg  [HORZ_COUNT_WIDTH-1:0] horz_count_next_r;
    wire                        horz_enable_c;
    wire                        horz_zero_detect_c;
    wire                        horz_3us84_detect_c;
    
    
    reg  [VERT_COUNT_WIDTH-1:0] vert_count_r;
    reg  [VERT_COUNT_WIDTH-1:0] vert_count_next_r;
    wire                        vert_enable_c;
    wire                        vert_zero_detect_c;
    wire                        vert_64us_detect_c;
    
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
        if (horz_enable_c) horz_count_next_r = horz_count_r + 1'b1;
        else               horz_count_next_r = horz_count_r;
    end
    
    //vertical counter
    always @ (posedge block_clk_i or negedge rst_low_i)
    begin
        if (~rst_low_i) vert_count_r <= {(VERT_COUNT_WIDTH){1'b0}};
        else            vert_count_r <= vert_count_next_r;
    end
    
    always @ (vert_enable_c, vert_count_r)
    begin
        if (vert_enable_c) vert_count_next_r = vert_count_r + 1'b1;
        else               vert_count_next_r = vert_count_r;
    end
    
    /*************************************************************************/
    /* Waveform Shaping Logic                                                */
    /*************************************************************************/    
    
    assign horz_enable_c       = 1'd1;
    
    assign horz_zero_detect_c  = (horz_count_r == {(HORZ_COUNT_WIDTH){1'b0}}) ? 1'b1 : 1'b0;
    assign horz_3us84_detect_c = (horz_count_r == HORZ_COUNT_3US84)           ? 1'b1 : 1'b0;
    
    assign vert_zero_detect_c  = (vert_count_r == {(VERT_COUNT_WIDTH){1'b0}}) ? 1'b1 : 1'b0;
    assign vert_64us_detect_c  = (vert_count_r == VERT_COUNT_64US )           ? 1'b1 : 1'b0;
    
    SRLatchGate hSync(
        .R(horz_3us84_detect_c),
        .S(horz_zero_detect_c),
        .Q(h_sync_o)
    );

    assign vert_enable_c       = ~h_sync_o;
    
    SRLatchGate vSync(
        .R(vert_64us_detect_c),
        .S(vert_zero_detect_c),
        .Q(v_sync_o)
    );
    
endmodule //end VGAController
    