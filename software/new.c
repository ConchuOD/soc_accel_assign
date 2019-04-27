#define SERIAL 0

#include <stdio.h>

#include "DES_M0_SoC.h"
#include "display.h"
#include "spi.h"
#include "adxl.h"
#include "util.h"

#define BUF_SIZE         100
#define ASCII_CR         '\r'
#define CASE_BIT         ('A' ^ 'a')
#define nLOOPS_per_DELAY 1000000
#define VALUE_1_OFFSET   0x00
#define VALUE_2_OFFSET   0x04

volatile uint8_t  g_counter          = 0; // current number of char received on UART currently in g_rx_buf[]
volatile uint8_t  g_buf_ready        = 0; // Flag to indicate if there is a sentence worth of data in g_rx_buf
volatile uint8_t  g_rx_buf[BUF_SIZE];


//////////////////////////////////////////////////////////////////
// Interrupt service routine, runs when UART interrupt occurs - see cm0dsasm.s
//////////////////////////////////////////////////////////////////
void UART_ISR()     
{
    char c;
    c = pt2UART->RxData;   // read a character from UART - interrupt only occurs when character waiting
    g_rx_buf[g_counter]  = c;   // Store in buffer
    g_counter++;             // Increment g_counter to indicate that there is now 1 more character in buffer
    pt2UART->TxData = c;   // write (echo) the character to UART (assuming transmit queue not full!)
    // g_counter is now the position that the next character should go into
    // If this is the end of the buffer, i.e. if g_counter==BUF_SIZE-1, then null terminate
    // and indicate the a complete sentence has been received.
    // If the character just put in was a carriage return, do likewise.
    if (g_counter == BUF_SIZE-1 || c == ASCII_CR)  {
        g_counter--;                          // decrement g_counter (CR will be over-written)
        g_rx_buf[g_counter] = NULL;  // Null terminate
        g_buf_ready       = 1;     // Indicate to rest of code that a full "sentence" has being received (and is in g_rx_buf)
    }
}

//////////////////////////////////////////////////////////////////
// Main Function
//////////////////////////////////////////////////////////////////
int main(void) {
    uint16_t   adxl_x_data;
    uint16_t   adxl_y_data;
    uint16_t   adxl_z_data;
    uint16_t   scaled_adxl_x_data;
    uint16_t   scaled_adxl_y_data;
    uint16_t   scaled_adxl_z_data; 
    uint32_t   first_adxl_word;
    uint32_t   second_adxl_word;
    uint32_t   third_adxl_word;

    //enable interrupts
    pt2NVIC->Enable = (1UL << NVIC_UART_BIT_POS);    // Enable interrupts for UART & ADXL in the NVIC

    pt2UART->Control = (1UL << UART_RX_FIFO_EMPTY_BIT_INT_POS);   // 
    wait_n_loops(nLOOPS_per_DELAY);                             // wait a little
    
    #if SERIAL
    printf("\r\nConor/Andrew Assignment 3\r\n");                // output welcome message
    #endif
    //spi setup
    spi_init();
    #if SERIAL
    printf("\r\nspi init complete\r\n");
    wait_n_loops(nLOOPS_per_DELAY);     // wait a little 
    #endif
    //adxl setup
    adxl_init();
    #if SERIAL
    printf("\r\nadxl init complete\r\n");
    #endif
    //display setup TODO
    display_init();
    #if SERIAL
    printf("\r\ndisplay init complete\r\n");
    #endif

    pt2NVIC->Enable =  pt2NVIC->Enable | (1UL << NVIC_ADXL_BIT_POS);
    #if SERIAL
    printf("\r\nenabled adxl\r\n");
    #endif
    
    for(;/*ever*/;)
    {
        //__wfi(); // use sleep somehow TODO
        if(g_data_ready_flag) 
        { 
            g_data_ready_flag = 0;
                        
            spi_set_ss(ADXL_SS_POS);
            adxl_send_read_command(ADXL_DATA_START);
            while(!SPI_WRITE_COMPLETE){}
                
            spi_send_half_word(0xffff);
            while(!SPI_DATA_READY){}        
            first_adxl_word = spi_read_word(); 
                
            spi_send_half_word(0xffff);
            while(!SPI_DATA_READY){}
            second_adxl_word = spi_read_word();
            
            spi_send_half_word(0xffff);
            while(!SPI_DATA_READY){}
            third_adxl_word = spi_read_word(); 
                
            spi_clear_ss();     
            
            adxl_x_data = (int16_t)( (((first_adxl_word >> 16) & 0xFF) << 8)  | ((first_adxl_word >> 24) & 0xFF) );			
            adxl_y_data = (int16_t)( (((second_adxl_word >> 16) & 0xFF) << 8) | ((second_adxl_word >> 24) & 0xFF) );
            adxl_z_data = (int16_t)( (((third_adxl_word >> 16) & 0xFF) << 8)  | ((third_adxl_word >> 24) & 0xFF) );
            
            scaled_adxl_x_data = adxl_scale_value(adxl_x_data);     
            scaled_adxl_z_data = adxl_scale_value(adxl_z_data); 
            
            #if SERIAL
            printf("raw xdata = %05hd\t", adxl_x_data);	  
            printf("raw ydata = %05hd\t", adxl_y_data);  
            printf("raw zdata = %05hd\t", adxl_z_data);	
            printf("\r\n");
            #endif
            
            display_send_value(VALUE_1_OFFSET,scaled_adxl_x_data);
            display_send_led_value(adxl_y_data);
            display_send_value(VALUE_2_OFFSET,scaled_adxl_z_data);
            
            wait_n_loops(nLOOPS_per_DELAY);  // wait a little
        } //if data ready
        pt2NVIC->Enable =  pt2NVIC->Enable | (1UL << NVIC_ADXL_BIT_POS);
    } //for ever loop
}  //main




