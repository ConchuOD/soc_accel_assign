#ifndef SPI_H_
#define SPI_H_

#include "DES_M0_SoC.h"

#define DISPLAY_SS_POS            0
#define ADXL_SS_POS               1

#define CS_WDATA_VALID_BYTES_POS  5
#define WDATA_VALID_BYTES_BITMASK 0x000000E0;

//SPI
void spi_init(void);
void spi_send_byte(uint8_t);
uint32_t spi_read_word(void);
void spi_send_half_word(uint16_t half_word_to_send);
void spi_send_word(uint32_t word_to_send);
void spi_set_ss(uint8_t ss_pos);
void spi_clear_ss(void);
void spi_change_valid_write_bytes(uint8_t);

#endif

