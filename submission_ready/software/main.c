#define SERIAL 0

#include <stdio.h>

#include "DES_M0_SoC.h"
#include "display.h"
#include "spi.h"
#include "adxl.h"
#include "util.h"

#define nLOOPS_per_DELAY 1000000
#define VALUE_1_OFFSET   0x00
#define VALUE_2_OFFSET   0x04

//////////////////////////////////////////////////////////////////
// Main Function
//////////////////////////////////////////////////////////////////
int main(void) {
    int16_t   adxl_x_data;
    int16_t   adxl_y_data;
    int16_t   adxl_z_data;
    int16_t   scaled_adxl_x_data;
    int16_t   scaled_adxl_y_data;
    int16_t   scaled_adxl_z_data; 

    //enable interrupts
    pt2NVIC->Enable = (1UL << NVIC_UART_BIT_POS); //enable interrupts for UART & ADXL in the NVIC

    pt2UART->Control = (1UL << UART_RX_FIFO_EMPTY_BIT_INT_POS); //setup UART
    wait_n_loops(nLOOPS_per_DELAY); // wait a little
    
    #if SERIAL
    printf("\r\nConor/Andrew Assignment 3\r\n"); //output welcome message
    #endif
    
    //spi setup
    spi_init();
    #if SERIAL
    printf("\r\nspi init complete\r\n");
    wait_n_loops(nLOOPS_per_DELAY);     //wait a little 
    #endif
    
    //adxl setup
    adxl_init();
    #if SERIAL
    printf("\r\nadxl init complete\r\n");
    #endif
    
    //display setup
    display_init();
    #if SERIAL
    printf("\r\ndisplay init complete\r\n");
    #endif

    //enable adxl interrupt
    pt2NVIC->Enable =  pt2NVIC->Enable | (1UL << NVIC_ADXL_BIT_POS); //enable
    #if SERIAL
    printf("\r\nenabled adxl\r\n");
    #endif
    
    for(;/*ever*/;)
    {
        //__wfi(); // sleep
        if(g_data_ready_flag) // if the interrupt has triggered
        { 
            g_data_ready_flag = 0; //reset flag

            adxl_burst_data_read(&adxl_x_data, &adxl_y_data, &adxl_z_data); //burst read from all 6 data registers
            
            scaled_adxl_x_data = adxl_scale_value(adxl_x_data); //scale x, y & z value for display
            scaled_adxl_y_data = adxl_scale_value(adxl_y_data); 
            scaled_adxl_z_data = adxl_scale_value(adxl_z_data);
            
            #if SERIAL
            printf("raw xdata = %05hd\t", adxl_x_data);
            printf("raw ydata = %05hd\t", adxl_y_data);
            printf("raw zdata = %05hd\t", adxl_z_data);
            printf("\r\n");
            #endif
            
            //display on digits & LEDs
            display_send_value(VALUE_1_OFFSET,scaled_adxl_x_data); 
            display_send_led_value(scaled_adxl_y_data);
            display_send_value(VALUE_2_OFFSET,scaled_adxl_z_data);

            pt2NVIC->Enable =  pt2NVIC->Enable | (1UL << NVIC_ADXL_BIT_POS); //re-enable interrupts
        } //if data ready
    } //for ever loop
}  //main




