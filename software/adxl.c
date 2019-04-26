#include "adxl.h"
#include "util.h"

volatile uint8_t  g_data_ready_flag  = 0;
volatile uint32_t g_first_adxl_word  = 0;
volatile uint32_t g_second_adxl_word = 0;

//////////////////////////////////////////////////////////////////
// ADXL functions
//////////////////////////////////////////////////////////////////
void ADXL_ISR(void)
{
    //pt2NVIC->Disable	 = (1 << NVIC_ADXL_BIT_POS);
    g_data_ready_flag    = 1;
    adxl_send_read_command(ADXL_DATA_START);
    spi_send_half_word(0xffff);
    while(!SPI_DATA_READY){}
    g_first_adxl_word = spi_read_word();
    spi_send_word(0xffffffff);
    while(!SPI_DATA_READY){}
    spi_clear_ss();    
    g_second_adxl_word = spi_read_word();        
}

//ADXL362
void adxl_send_read_command(uint8_t address_to_read)
{
    uint16_t half_word_to_send;
    half_word_to_send = (((uint32_t) ADXL_READ_COMMAND) << 8) | address_to_read;
    spi_set_ss(ADXL_SS_POS);
    spi_send_half_word(half_word_to_send);
    //dont clear SS
}
void adxl_send_write_command(uint8_t address_to_write, uint8_t data_to_send)
{
    uint32_t word_to_send;
    spi_change_valid_write_bytes(0x03);
    word_to_send = (((uint32_t) ADXL_WRITE_COMMAND) << 16) | (((uint32_t) address_to_write) << 8) | data_to_send;
    spi_set_ss(ADXL_SS_POS);
    spi_send_word(word_to_send);
    while(!SPI_WRITE_COMPLETE){}
    spi_clear_ss();
	spi_change_valid_write_bytes(0x02);
}
void adxl_send_byte(uint8_t data_to_send) // %TODO this function should maybe allow for cont. writes
{
    //dont need to set SS low as it already will be done
    spi_send_byte(data_to_send);
    while(!SPI_WRITE_COMPLETE){}
    spi_clear_ss();
}
void adxl_send_half_word(uint16_t data_to_send) // %TODO this function should maybe allow for cont. writes
{
    //dont need to set SS low as it already will be done
    spi_send_byte(data_to_send);
    while(!SPI_WRITE_COMPLETE){}
    spi_clear_ss();
}
uint8_t adxl_read_status(void)
{
    uint8_t rx_word;

    adxl_send_read_command(ADXL_STATUS_REGISTER);
    while(!SPI_WRITE_COMPLETE){}
    adxl_send_junk_byte(); //can we have extra status bits that say how many bits are clocked in?
    while(!SPI_WRITE_COMPLETE){}
    spi_clear_ss();
    while(!SPI_DATA_READY){}
    rx_word = spi_read_word();
    return rx_word;
}
uint32_t adxl_read_register(uint8_t address) //TODO reads an extra reg
{
    uint32_t rx_word;
    adxl_send_read_command(address);
    while(!SPI_DATA_READY){}
    spi_clear_ss();
    rx_word = spi_read_word();
    
    return rx_word;
}
void adxl_init(void)
{
    //write to 2A - need to set interrupts active high & map DATA_READY
    adxl_send_write_command(0x2A,0x01);
    wait_n_loops(2);                             // wait a little

    //write to 2C - measurement range, half bw and ODR
    adxl_send_write_command(0x2C,0x10);
    wait_n_loops(2);                             // wait a little

    //write to 2D - 
    adxl_send_write_command(0x2D,0x02);
    wait_n_loops(2);                             // wait a little

}
int16_t adxl_scale_value(int16_t value_to_scale)
{
    int32_t interim_value;
    int16_t result;
    
    interim_value = ((int32_t)value_to_scale)*1000;
    result        = (int16_t)(interim_value/1024);
    return result;
}
