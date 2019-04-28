#ifndef ADXL_H_
#define ADXL_H_

#include "DES_M0_SoC.h"
#include "spi.h"

extern volatile uint8_t  g_data_ready_flag;

//ADXL362
void ADXL_ISR(void);

void adxl_init(void);

void adxl_send_read_command(uint8_t address_to_read);
void adxl_send_write_command(uint8_t address_to_write, uint8_t data_to_send);

void adxl_send_half_word(uint16_t data_to_send);

int16_t adxl_scale_value(int16_t value_to_scale);
uint8_t adxl_read_register(uint8_t address);

void adxl_burst_data_read(uint16_t * adxl_x_data, uint16_t * adxl_y_data, uint16_t * adxl_z_data);

#endif
