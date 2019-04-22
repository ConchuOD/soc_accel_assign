#include "spi.h"

//SPI
void spi_init(void)
{
    // Set number of valid bytes in WDATA to 2, set slave select signals to active low
    pt2SPI->control = 0x00002040;
}
void spi_send_byte(uint8_t byte_to_send)
{
    pt2SPI->write_half_word = (uint16_t) byte_to_send;
}
void spi_change_valid_write_bytes(uint8_t num_valid_bytes)
{
    uint32_t desired_wdata_valid_bytes;
    uint32_t previous_with_wiped_wdata_valid;
    
    if(num_valid_bytes > 0 && num_valid_bytes <= 4)
    {
        num_valid_bytes <<= CS_WDATA_VALID_BYTES_POS;
        desired_wdata_valid_bytes = num_valid_bytes & WDATA_VALID_BYTES_BITMASK;
        previous_with_wiped_wdata_valid = pt2SPI->control & ~WDATA_VALID_BYTES_BITMASK;
        pt2SPI->control = previous_with_wiped_wdata_valid | desired_wdata_valid_bytes;
    }
}
uint32_t spi_read_word(void)
{
    return pt2SPI->read;
}
void spi_send_half_word(uint16_t half_word_to_send)
{
    pt2SPI->write_half_word = half_word_to_send;
}
void spi_send_word(uint32_t word_to_send)
{
    pt2SPI->write_word = word_to_send;
}
void spi_set_ss(uint8_t ss_pos)
{
    uint32_t one_hot_ss = 0x00000000;
    one_hot_ss = (0x00000000) | (1UL << (ss_pos));
    pt2SPI->slave_select = one_hot_ss;

}
void spi_clear_ss(void)
{
    pt2SPI->slave_select = 0x00000000;    
}
