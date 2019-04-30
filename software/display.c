#if SERIAL
#include <stdio.h>
#endif
#include "display.h"
#include "spi.h"
#include "util.h"

#define DISPLAY_WRITE_COMMAND     0x01
#define DISPLAY_ENABLE_REG        0x00
#define DISPLAY_ENABLE_ALL        0xFF
#define DISPLAY_MINUS             0x0A
#define DISPLAY_BLANK             0x0F
#define DISPLAY_RADIX_REG         0x09
#define DISPLAY_RADIX_LOCS        0x44
#define DISPLAY_DIGITS_PER_VAR    4
#define DISPLAY_CLIPPING_THRESH   1000
#define DISPLAY_NUM_LEDS          16


//////////////////////////////////////////////////////////////////
// Display functions
//////////////////////////////////////////////////////////////////
void display_init(void)
{
    display_enable_all_digits();
    display_send_write_data(DISPLAY_RADIX_REG, DISPLAY_RADIX_LOCS); //enable radices at desired location   
}
void display_send_write_data(uint8_t address_to_write, uint8_t value_to_write)
{
    uint16_t half_word_to_send;
    
    //prepend write command & address
    half_word_to_send = ( ((uint16_t) DISPLAY_WRITE_COMMAND) << 12 ) | ( (uint16_t) (address_to_write & 0x0F) << 8 ) | (uint16_t) value_to_write;
    spi_set_ss(DISPLAY_SS_POS); //set slave select
    spi_send_half_word(half_word_to_send); //write 16 bits
    while(!SPI_WRITE_COMPLETE){} //wait for write to finish
    spi_clear_ss(); //clear slave select	
}

void display_enable_all_digits(void)
{
    uint16_t half_word_to_send;
    
    //prepend write command & address
    half_word_to_send = ( ((uint16_t) DISPLAY_WRITE_COMMAND) << 12 ) | ( (uint16_t) (DISPLAY_ENABLE_REG) << 8 ) | (uint16_t) DISPLAY_ENABLE_ALL;
    spi_set_ss(DISPLAY_SS_POS); //set slave select
    spi_send_half_word(half_word_to_send); //write 16 bits
    while(!SPI_WRITE_COMPLETE){} //wait for write to finish
    spi_clear_ss();  //clear slave select
}

void display_value_to_digits(int16_t value_to_display, uint8_t * digits, const uint8_t num_digits)
{
    uint8_t inc;
    int16_t magnitude;

    if (value_to_display < 0) 
    {
        *(digits+num_digits-1) = DISPLAY_MINUS;
        magnitude = -value_to_display; //reverse 2s complement for negative number
    }
    else
    {
        *(digits+num_digits-1) = DISPLAY_BLANK; //top digit is blank for positive values
        magnitude = value_to_display;
    }

    for(inc=0;inc<num_digits-1;inc++){ //convert magnitude to specified # of digits
        magnitude     = magnitude/10;
        *(digits+inc) = (uint8_t)(magnitude%10);
    }
}

void display_send_value(uint8_t digit_offset, int16_t value_to_display)
{
    uint8_t inc;
    uint8_t digits[DISPLAY_DIGITS_PER_VAR];
    uint8_t address;
    uint8_t character;

    display_value_to_digits(value_to_display, digits, DISPLAY_DIGITS_PER_VAR); //convert magnitude to specified # of digits

    for(inc = 0; inc < DISPLAY_DIGITS_PER_VAR; inc++)  //send digits to display
    {       
        address = digit_offset + inc + 1; //add increment to offset, +1 due to enable reg @ 0
        character = *(digits+inc);
        display_send_write_data(address, character); //send character to appropriate digit register
    }
}

void display_send_led_value(int16_t value_to_display)
{
    uint16_t led_pos;
    uint16_t us_value_to_display;
    
    const uint16_t scale_to_led_count = (2*DISPLAY_CLIPPING_THRESH)/DISPLAY_NUM_LEDS;
    
    //clip values outside the range
    if(value_to_display > (DISPLAY_CLIPPING_THRESH - 1))
    {
        value_to_display = (DISPLAY_CLIPPING_THRESH - 1);
    }
    else if (value_to_display < -DISPLAY_CLIPPING_THRESH)
    {
        value_to_display = -DISPLAY_CLIPPING_THRESH;
    }
    
    //convert to unsigned value by adding the midpoint on again
    us_value_to_display = (uint16_t) (value_to_display + DISPLAY_CLIPPING_THRESH);
    //light up the lED corresponding to value
    led_pos = us_value_to_display/scale_to_led_count;
    //light up the lED corresponding to value
    pt2GPIO->LED = (1UL << led_pos);
}
