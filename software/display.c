#include <stdio.h>
#include "display.h"
#include "spi.h"
#include "util.h"

//display
//display
void display_init(void)
{
    display_enable_all_digits();
    display_send_write_data(RADIX_REG,RADIX_LOCS);    
}
void display_send_write_data(uint8_t address_to_write, uint8_t value_to_write)
{
    uint16_t half_word_to_send;
    spi_change_valid_write_bytes(0x02);
    half_word_to_send = ( ((uint16_t) DISPLAY_WRITE_COMMAND) << 12 ) | ( (uint16_t) (address_to_write & 0x0F) << 8 ) | (uint16_t) value_to_write;
    spi_set_ss(DISPLAY_SS_POS);
    spi_send_half_word(half_word_to_send);
    while(!SPI_WRITE_COMPLETE){}
    spi_clear_ss();    
}
void display_enable_all_digits(void)
{
    uint16_t half_word_to_send;
    half_word_to_send = ( ((uint16_t) DISPLAY_WRITE_COMMAND) << 12 ) | ( (uint16_t) (DISPLAY_ENABLE_REG) << 8 ) | (uint16_t) DISPLAY_ENABLE_ALL;
    spi_set_ss(DISPLAY_SS_POS);
    spi_send_half_word(half_word_to_send);
    while(!SPI_WRITE_COMPLETE){}
    spi_clear_ss(); 
}
void display_value_to_digits(int16_t value_to_display, uint8_t * digits, const uint8_t num_digits)
{
    uint8_t inc;
    uint8_t sign;
    int16_t magnitude;

    sign = value_to_display < 0 ? 1 : 0; //sign is 1 if less than zero, 1 otherwise
    if (sign) //todo delete this
    {
        *(digits+num_digits-1) = DISPLAY_MINUS;
        magnitude = -value_to_display;
    }
    else
    {
        *(digits+num_digits-1) = DISPLAY_BLANK;
        magnitude = value_to_display;
    }

    for(inc=0;inc<num_digits-1;inc++)
    {
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

    display_value_to_digits(value_to_display, digits, DISPLAY_DIGITS_PER_VAR);

    for(inc = 0; inc < DISPLAY_DIGITS_PER_VAR; inc++)
    {
        address = digit_offset + inc + 1;
        character = *(digits+inc);
        display_send_write_data(address, character);
        wait_n_loops(1);
    }
}
void display_send_led_value(int16_t value_to_display)
{
    uint16_t led_pos;
    uint16_t led_lit;
    uint16_t us_value_to_display;
    
    if(value_to_display > 1023)
    {
        value_to_display = 1023;
    }
    else if (value_to_display < -1024)
    {
        value_to_display = -1024;
    }
    
    us_value_to_display = (uint16_t) (value_to_display + 1024);
    led_pos = us_value_to_display/128;
    led_lit = (1UL << led_pos);
    pt2GPIO->LED = led_lit;
}
