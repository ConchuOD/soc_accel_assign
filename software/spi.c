#include "spi.h"

// Set number of valid bytes in WDATA to 2, set slave select signals to active low
#define SPI_INITIAL_CFG           0x00002040
#define SPI_WDATA_VALID_BYTE_MASK 0x000000E0;

//////////////////////////////////////////////////////////////////
// SPI functions
//////////////////////////////////////////////////////////////////
void spi_init(void)
{
    pt2SPI->control = SPI_INITIAL_CFG;
}

//single line function should be inlined to avoid un-needed function call overhead
__attribute__((always_inline)) void spi_send_byte(uint8_t byte_to_send)
{
    pt2SPI->write_byte = byte_to_send; //read from spi read register
}

void spi_change_valid_write_bytes(uint8_t num_valid_bytes)
{
    uint32_t desired_wdata_valid_bytes;
    uint32_t previous_with_wiped_wdata_valid;
    
    if(num_valid_bytes > 0 && num_valid_bytes <= 4) //if the number is in the valid range
    {
        //read, modify, write
        num_valid_bytes <<= CS_WDATA_VALID_BYTES_POS; //shift up to valid position
        desired_wdata_valid_bytes = num_valid_bytes & SPI_WDATA_VALID_BYTE_MASK; //apply mask
        previous_with_wiped_wdata_valid = pt2SPI->control & ~SPI_WDATA_VALID_BYTE_MASK; //read out current values
        pt2SPI->control = previous_with_wiped_wdata_valid | desired_wdata_valid_bytes; //modify and write
    }
}

//single line function should be inlined to avoid un-needed function call overhead
__attribute__((always_inline)) uint32_t spi_read_word(void)
{
    return pt2SPI->read; //read from spi read register
}

//single line function should be inlined to avoid un-needed function call overhead
__attribute__((always_inline)) void spi_send_half_word(uint16_t half_word_to_send)
{
    pt2SPI->write_half_word = half_word_to_send; //write to spi write register
}

//single line function should be inlined to avoid un-needed function call overhead
__attribute__((always_inline)) void spi_send_word(uint32_t word_to_send)
{
    pt2SPI->write_word = word_to_send; //write to spi write register
}

__attribute__((always_inline)) void spi_set_ss(uint8_t ss_pos)
{   
    //shift into correct bit position & write to spi ss control register
    pt2SPI->slave_select = (1UL << (ss_pos));
}

//single line function should be inlined to avoid un-needed function call overhead
__attribute__((always_inline)) void spi_clear_ss(void)
{
    pt2SPI->slave_select = 0x00000000; //clear any active SS
}
