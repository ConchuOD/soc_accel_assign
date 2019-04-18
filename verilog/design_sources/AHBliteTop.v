`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCD School of Electrical and Electronic Engineering
// Engineer: Brian Mulkeen
// 
// Create Date:   18:24:44 15Oct2014 
// Design Name:    Cortex-M0 DesignStart system for Digilent Nexys4 board
// Module Name:    AHBliteTop 
// Description:    Top-level module.  Defines AHB Lite bus structure,
//                 instantiates and connects all other modules in system.
//
// Revision: 1 - Initial distribution for assignment
// Revision 0.01 - File Created
//
//////////////////////////////////////////////////////////////////////////////////
module AHBliteTop (
        input         clk,         // input clock from 100 MHz oscillator on Nexys4 board
        input         btnCpuReset, // reset pushbutton, active low (CPU RESET)
        input         btnU,        // up button - if pressed after reset, ROM loader activated
        input         btnD,        // down button
        input         btnL,        // left button
        input         btnC,        // centre button
        input         btnR,        // right button
        input         aclMISO,     //
        output        aclSCK,      //
        output        aclSS,       //
        input         aclInt1,     //
        input         aclInt2,     //
        input         RsRx,        // serial port receive line
        input  [15:0] sw,          // 16 slide switches on Nexys 4 board
        output [15:0] led,         // 16 individual LEDs above slide switches   
        output [5:0]  rgbLED,      // multi-colour LEDs - {blu2, grn2, red2, blu1, grn1, red1} 
        output [7:0]  JA,          // monitoring connector on FPGA board - use with oscilloscope
        output        RsTx,         // serial port transmit line
        output        aclMOSI,     //
        output [7:0]  segment_o,
        output [7:0]  digit_o
    );
 
    localparam  BAD_DATA = 32'hdeadbeef;
    localparam SPI_SS_DISPLAY_INDEX = 1'b0, SPI_SS_ACCEL_INDEX = 1'b1;

// ========================= Signals for monitoring on oscilloscope == 
    assign JA = {6'b0, RsRx, RsTx};   // monitor serial communication
    
// ========================= Bus =====================================
// Define AHB Lite bus signals
// Note that signals HMASTLOCK and HBURST are omitted - not used by processor
    wire        HCLK;       // 50 MHz clock 
    wire        HRESETn;    // active low reset
// Signals from processor
    wire [31:0]	HWDATA;     // write data
    wire [31:0]	HADDR;      // address
    wire 		HWRITE;     // write signal
    wire [1:0] 	HTRANS;     // transaction type
    wire [3:0] 	HPROT;      // protection
    wire [2:0] 	HSIZE;      // transaction width
// Signals to processor    
    wire [31:0] HRDATA;     // read data
    wire		HREADY;     // ready signal from active slave
    wire 		HRESP;      // error response
    
// ========================= Signals to-from individual slaves ==================
// Slave select signals (one per slave)
    wire        HSEL_rom, HSEL_ram, HSEL_gpio, HSEL_uart, HSEL_spi;
// Slave output signals (one per slave)
    wire [31:0] HRDATA_rom, HRDATA_ram, HRDATA_gpio, HRDATA_uart, HRDATA_spi;
    wire        HREADYOUT_rom, HREADYOUT_ram, HREADYOUT_gpio, HREADYOUT_uart, HREADYOUT_spi;
 
// =================================== SPI ======================================
    wire        display_clock_x;
    wire [31:0] spi_ss_x;
    wire        spi_ss_display_x = spi_ss_x[SPI_SS_DISPLAY_INDEX];
    wire        spi_clk_x;
    wire        spi_mosi_x;
    reg         spi_miso_r;
    wire        spi_miso_display_x;
    
    assign      aclSCK  = spi_clk_x;
    assign      aclSS   = spi_ss_x[SPI_SS_ACCEL_INDEX];
    assign      aclMOSI = spi_mosi_x;
    
    always @(*) begin        
        if(~spi_ss_display_x) begin
            spi_miso_r = spi_miso_display_x;
        end
        else if(~aclSS) begin
            spi_miso_r = aclMISO;
        end
        else begin
            spi_miso_r = 1'b1;
        end
    end    

// ======================== Other Interconnecting Signals =======================
    wire        PLL_locked;     // from clock generator, indicates clock is running
    wire        resetHW;        // reset signal for hardware, not on bus
    wire        CPUreset, CPUlockup, CPUsleep;       // status signals 
    wire        ROMload;        // rom loader active
    wire [3:0]  muxSel;         // from address decoder to control multiplexer
    wire [4:0]  buttons = {btnU, btnD, btnL, btnC, btnR};   // concatenate 5 pushbuttons

// Wires and multiplexer to drive LEDs from two different sources - needed for ROM loader
    wire [11:0] led_rom;        // status output from ROM loader
    wire [15:0] led_gpio;       // led output from GPIO block
    assign led = ROMload ? {4'b0,led_rom} : led_gpio;    // choose which to display

// Define Cortex-M0 DesignStart processor signals (not part of AHB Lite)
    wire 		RXEV, TXEV;  // event signals
    wire        NMI;        // non-maskable interrupt
    wire [15:0]	IRQ;        // interrupt signals
    wire        SYSRESETREQ;    // processor reset request output
    
    wire [15:0] gpio_in0, gpio_in1;		// input ports
    wire [15:0] gpio_out0, gpio_out1;    // output ports
    
    wire uart_IRQ;
    
    assign gpio_in0 = sw; 
    assign gpio_in1 = {10'd0, buttons};   
    
    assign led_gpio = gpio_out0;
 
// ======================== Clock Generator ======================================
// Generates 50 MHz bus clock from 100 MHz input clock
// Instantiate clock management module
    clock_gen_50M_6M25 clockGen (
        .clk_in1(clk),        // 100 MHz input clock
        .clk_out1(HCLK),      // 50 MHz output clock for AHB and other hardware
        .clk_6M25_out(display_clock_x),
        .locked(PLL_locked)   // locked indicator
        );

// ======================== Reset Generator ======================================
// Asserts hardware reset until PLL locked, also if reset button pressed.
// Asserts CPU and bus reset to meet Cortex-M0 requirements, also if ROM loader active
// Instantiate reset generator module    
    reset_gen resetGen (
        .clk            (HCLK),         // works on system bus clock
        .resetPBn       (btnCpuReset),  // signal from CPU reset pushbutton
        .pll_lock       (PLL_locked),   // from clock management PLL
        .loader_active  (ROMload),      // from ROM loader hardware
        .cpu_request    (SYSRESETREQ),  // from CPU, requesting reset
        .resetHW        (resetHW),      // hardware reset output, active high
        .resetCPUn      (HRESETn),      // CPU and bus reset, active low
        .resetLED       (CPUreset)      // status signal for indicator LED
        );

// ======================== Status Indicator ======================================
// Drives multi-colour LEDs to indicate status of processor and ROM loader.
// Instantiate status indicator module    
    status_ind statusInd (
        .clk            (HCLK),         // works on system bus clock
        .reset          (resetHW),       // hardware reset signal
        .statusIn       ({CPUreset, CPUlockup, CPUsleep, ROMload}),      // status inputs
        .rgbLED         (rgbLED)      // output signals for colour LEDs
        );

// ======================== Processor ========================================
    
// Set processor inputs to safe values
    assign RXEV = 1'b0;
    assign NMI = 1'b0;
    assign HRESP = 1'b0;    // no slaves use this signal yet

// Connect appropriate bits of IRQ to any interrupt signals used, others 0
    assign IRQ = {13'b0, aclInt1, uart_IRQ, 1'b0};     // only gpio & ADXL interrupts in use yet, so all 0

// Instantiate Cortex-M0 DesignStart processor and connect signals 
    CORTEXM0DS cpu (
        .HCLK       (HCLK),
        .HRESETn    (HRESETn), 
        // Outputs to bus
        .HWDATA      (HWDATA), 
        .HADDR       (HADDR), 
        .HWRITE      (HWRITE), 
        .HTRANS      (HTRANS), 
        .HPROT       (HPROT),
        .HSIZE       (HSIZE),
        .HMASTLOCK   (),        // not used, not connected
        .HBURST      (),        // not used, not connected
        // Inputs from bus	
        .HRDATA      (HRDATA),			
        .HREADY      (HREADY),					
        .HRESP       (HRESP),					
        // Other signals
        .NMI         (NMI),
        .IRQ         (IRQ),
        .TXEV        (TXEV),
        .RXEV        (RXEV),
        .SYSRESETREQ (SYSRESETREQ),
        .LOCKUP      (CPUlockup),   // CPU is in lockup state
        .SLEEPING    (CPUsleep)     // CPU sleeping, waiting for interrupt
        );

// ======================== Address Decoder ======================================
// Implements address map, generates slave select signals and controls mux      
    AHBDCD decode (
        .HADDR      (HADDR),        // address in
        .HSEL_S0    (HSEL_rom),     // ten slave select lines out
        .HSEL_S1    (HSEL_ram),
        .HSEL_S2    (HSEL_gpio),
        .HSEL_S3    (HSEL_uart),
        .HSEL_S4    (HSEL_spi),
        .HSEL_S5    (),
        .HSEL_S6    (),
        .HSEL_S7    (),
        .HSEL_S8    (),
        .HSEL_S9    (),
        .HSEL_NOMAP (),             // indicates invalid address selected
        .MUX_SEL    (muxSel)        // multiplexer control signal out
        );

// ======================== Multiplexer ======================================
// Selects appropriate slave output signals to pass to master      
    AHBMUX mux (
        .HCLK           (HCLK),             // bus clock and reset
        .HRESETn        (HRESETn),
        .MUX_SEL        (muxSel[3:0]),     // control from address decoder

        .HRDATA_S0      (HRDATA_rom),       // ten read data inputs from slaves
        .HRDATA_S1      (HRDATA_ram),
        .HRDATA_S2      (HRDATA_gpio),
        .HRDATA_S3      (HRDATA_uart),
        .HRDATA_S4      (HRDATA_spi),
        .HRDATA_S5      (BAD_DATA),
        .HRDATA_S6      (BAD_DATA),
        .HRDATA_S7      (BAD_DATA),
        .HRDATA_S8      (BAD_DATA),
        .HRDATA_S9      (BAD_DATA),
        .HRDATA_NOMAP   (BAD_DATA),
        .HRDATA         (HRDATA),           // read data output to master
         
        .HREADYOUT_S0   (HREADYOUT_rom),       // ten ready signals from slaves
        .HREADYOUT_S1   (HREADYOUT_ram),
        .HREADYOUT_S2   (HREADYOUT_gpio),
        .HREADYOUT_S3   (HREADYOUT_uart),             
        .HREADYOUT_S4   (HREADYOUT_spi),                 // unused inputs tied to 1
        .HREADYOUT_S5   (1'b1),
        .HREADYOUT_S6   (1'b1),
        .HREADYOUT_S7   (1'b1),
        .HREADYOUT_S8   (1'b1),
        .HREADYOUT_S9   (1'b1),
        .HREADYOUT_NOMAP(1'b1),
        .HREADY         (HREADY)            // ready output to master and all slaves
        );


// ======================== Slaves on AHB Lite Bus ======================================

// ======================== Program store - block RAM with loader interface ==============
    AHBprom ROM (
        // bus interface
        .HCLK           (HCLK),             // bus clock
        .HRESETn        (HRESETn),          // bus reset, active low
        .HSEL           (HSEL_rom),         // selects this slave
        .HREADY         (HREADY),           // indicates previous transaction completing
        .HADDR          (HADDR),            // address
        .HTRANS         (HTRANS),           // transaction type (only bit 1 used)
        .HRDATA         (HRDATA_rom),       // read data 
        .HREADYOUT      (HREADYOUT_rom),    // ready output
        // Loader connections
        .resetHW        (resetHW),			// hardware reset
        .loadButton     (btnU),		   // pushbutton to activate loader
        .serialRx	    (RsRx),         // serial input
        .status         (led_rom),      // 12-bit word count for display on LEDs
        .ROMload        (ROMload)			// loader active
        );

// ======================== Block RAM ======================================
// instantiate the AHBbram module here...
    AHBbram RAM (
        .HCLK       (HCLK),				// bus clock
        .HRESETn    (HRESETn),            // bus reset, active low
        .HSEL       (HSEL_ram),                // selects this slave
        .HREADY     (HREADY),            // indicates previous transaction completing
        .HADDR      (HADDR),    // address
        .HTRANS     (HTRANS),    // transaction type (only bit 1 used)
        .HWRITE     (HWRITE),            // write transaction
        .HSIZE      (HSIZE),        // transaction width (max 32-bit supported)
        .HWDATA     (HWDATA),    // write data
        .HRDATA     (HRDATA_ram),    // read data from slave
        .HREADYOUT  (HREADYOUT_ram)      // ready output from slave
    );

// ======================== GPIO ======================================
// instantiate the GPIO module here...   
 AHBgpio GPIO(
        .HCLK(HCLK),				
        .HRESETn(HRESETn),
        .HSEL(HSEL_gpio),
        .HREADY(HREADY),
        .HADDR(HADDR),
        .HTRANS(HTRANS),
        .HWRITE(HWRITE),  
        .HSIZE(HSIZE), 
        .HWDATA(HWDATA),  
        .HRDATA(HRDATA_gpio),  
        .HREADYOUT(HREADYOUT_gpio),
		.gpio_out0(gpio_out0),
		.gpio_out1(gpio_out1),
		.gpio_in0(gpio_in0),
		.gpio_in1(gpio_in1)
  );
  
  // ======================== UART ======================================
  // instantiate the UART module here...   
  AHBuart2 UART2(
          .HCLK(HCLK),                
          .HRESETn(HRESETn),
          .HSEL(HSEL_uart),
          .HREADY(HREADY),
          .HADDR(HADDR),
          .HTRANS(HTRANS),
          .HWRITE(HWRITE),  
          .HWDATA(HWDATA),  
          .HRDATA(HRDATA_uart),  
          .HREADYOUT(HREADYOUT_uart),
          .serialRx(RsRx),
          .serialTx(RsTx),
          .uart_IRQ(uart_IRQ)
  );
  
  // ======================== SPI ======================================
  AHBspi SPI(
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .HSEL(HSEL_spi),
        .HREADY(HREADY),    
        .HADDR(HADDR),
        .HWRITE(HWRITE),
        .HSIZE(HSIZE),        
        .HTRANS(HTRANS),
        .HWDATA(HWDATA),
        .HRDATA(HRDATA_spi),
        .HREADYOUT(HREADYOUT_spi),    
        .SPI_MISO_i(spi_miso_r),
        .SPI_MOSI_o(spi_mosi_x),
        .SPI_SS_o(spi_ss_x),
        .SPI_CLK_o(spi_clk_x)
    );
  
  // ======================== DISP ======================================
  Nexys4Display nexys4Display (
        .rst_low_i(HRESETn),
        .block_clk_i(display_clock_x),
        .spi_sclk_i(spi_clk_x),          //idle high, posedge active, < block_clk_i
        .spi_ss_i(spi_ss_display_x),     //idle high
        .spi_mosi_i(spi_mosi_x),         //idle high
        .spi_miso_o(spi_miso_display_x), //idle high
        .segment_o(segment_o), 
        .digit_o(digit_o)
    );

endmodule
