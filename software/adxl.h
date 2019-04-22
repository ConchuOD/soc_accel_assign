#ifndef ADXL_H_
#define ADXL_H_

#include "DES_M0_SoC.h"
#include "spi.h"

#define ADXL_WRITE_COMMAND        0x0A
#define ADXL_READ_COMMAND         0x0B
#define ADXL_READ_FIFO_COMMAND    0x0D
#define ADXL_STATUS_REGISTER      0x0B
#define ADXL_DATA_START           0x0E
#define adxl_send_junk_byte()     adxl_send_byte(0xFF)

//ADXL362
void adxl_send_read_command(uint8_t address_to_read);
void adxl_send_write_command(uint8_t address_to_write, uint8_t data_to_send);
void adxl_send_byte(uint8_t data_to_send);
void adxl_send_half_word(uint16_t data_to_send);
uint8_t adxl_read_status(void);
void adxl_init(void);
uint16_t * adxl_convert_bcd(uint32_t data_to_convert);
int16_t adxl_scale_value(int16_t value_to_scale);

extern volatile uint8_t  g_data_ready_flag;
extern volatile uint32_t g_first_adxl_word;
extern volatile uint32_t g_second_adxl_word;

void ADXL_ISR(void);

#endif
