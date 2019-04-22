#ifndef DISPLAY_H_
#define DISPLAY_H_

#include "DES_M0_SoC.h"

#define DISPLAY_WRITE_COMMAND     0x01
#define DISPLAY_ENABLE_REG        0x00
#define DISPLAY_ENABLE_ALL        0xFF
#define DISPLAY_MINUS             0x0A
#define DISPLAY_BLANK             0x0F
#define RADIX_REG                 0x09
#define RADIX_LOCS                0x44
#define DISPLAY_DIGITS_PER_VAR    4

//Display
void display_init(void);
void display_send_write_data(uint8_t address_to_write, uint8_t value_to_write);
void display_enable_all_digits(void);
void display_value_to_digits(int16_t value_to_display, uint8_t * digits, const uint8_t num_digits);
void display_send_value(uint8_t digit_offset, int16_t value_to_display);
void display_send_led_value(int16_t value_to_display);

#endif
