#include "adxl.h"
#include "util.h"
#include "spi.h"

#define ADXL_WRITE_COMMAND        0x0A
#define ADXL_READ_COMMAND         0x0B
#define ADXL_READ_FIFO_COMMAND    0x0D
#define ADXL_STATUS_REGISTER      0x0B
#define ADXL_DATA_START           0x0E

#define ADXL_JUNK_BYTE            0xFF
#define ADXL_JUNK_HALF_WORD       0xFFFF

volatile uint8_t  g_data_ready_flag  = 0;

//////////////////////////////////////////////////////////////////
// ADXL functions
//////////////////////////////////////////////////////////////////
void ADXL_ISR(void)
{
    pt2NVIC->Disable     = (1 << NVIC_ADXL_BIT_POS); //disable interrupt, data will now be ready
    g_data_ready_flag    = 1; //set data ready flag
}

void adxl_init(void)
{
    //write to 2A - need to set interrupts active high & map DATA_READY
    adxl_send_write_command(0x2A,0x01);
    wait_n_loops(2); //wait a little

    //write to 2C - measurement range, half bw and ODR
    adxl_send_write_command(0x2C,0x10);
    wait_n_loops(2); //wait a little

    //write to 2D - 02 puts the device in measurement mode
    adxl_send_write_command(0x2D,0x02);
    wait_n_loops(2); //wait a little

}

void adxl_send_read_command(uint8_t address_to_read)
{
    uint16_t half_word_to_send;
    
    half_word_to_send = (((uint16_t) ADXL_READ_COMMAND) << 8) | address_to_read; //prepend command
    spi_send_half_word(half_word_to_send); //send 16 bits
 }

void adxl_send_write_command(uint8_t address_to_write, uint8_t data_to_send)
{
    uint32_t word_to_send;
    
    //change from 16 bit mode to 24 bit mode
    spi_change_valid_write_bytes(0x03);
    //prepend write cmd and address to data
    word_to_send = (((uint32_t) ADXL_WRITE_COMMAND) << 16) | (((uint32_t) address_to_write) << 8) | data_to_send; 
    spi_set_ss(ADXL_SS_POS); //set slave select
    
    //send 24 bits (top 8 will be ignored by valid bytes setting)
    spi_send_word(word_to_send);
    while(!SPI_WRITE_COMPLETE){} //wait to complete
    spi_clear_ss(); //clear slave select
    spi_change_valid_write_bytes(0x02); //reset valid bytes to default
}

uint8_t adxl_read_register(uint8_t address)
{
    uint32_t rx_word;
    uint8_t rx_reg;
    
    spi_set_ss(ADXL_SS_POS); //set slave select
    adxl_send_read_command(address);
    while(!SPI_WRITE_COMPLETE){} //wait to complete
    spi_change_valid_write_bytes(0x01); //change from 16 bit mode to 8 bit mode
    spi_send_byte(0xFF); //send junk to 
    while(!SPI_DATA_READY){} //wait for read data
    spi_clear_ss(); //clear slave select
    rx_word = spi_read_word(); //read back word
    spi_change_valid_write_bytes(0x02); //reset valid bytes to default
    rx_reg = (uint8_t) (rx_word >> 24); //top 8 bits is the read value
    
    return rx_reg;
}

//scale rx value to range of +-2g
int16_t adxl_scale_value(int16_t value_to_scale)
{
    int32_t interim_value;
    int16_t result;
    
    interim_value = ((int32_t)value_to_scale)*1000; //multiply before divide for precision
    result        = (int16_t)(interim_value/1024);
    return result;
}

//perform a burst read of the 6 data registers
void adxl_burst_data_read(int16_t * adxl_x_data, int16_t * adxl_y_data, int16_t * adxl_z_data)
{
    uint32_t first_adxl_word;
    uint32_t second_adxl_word;
    uint32_t third_adxl_word;
    
    spi_set_ss(ADXL_SS_POS); //set slave select
    adxl_send_read_command(ADXL_DATA_START); //start read at the first data register
    while(!SPI_WRITE_COMPLETE){} //wait to complete
        
    spi_send_half_word(0xFFFF); //send bus idle value to generate SPI clock
    while(!SPI_DATA_READY){} //wait for read data
    first_adxl_word = spi_read_word(); //read back word
        
    spi_send_half_word(0xFFFF); //send bus idle value to generate SPI clock
    while(!SPI_DATA_READY){} //wait for read data
    second_adxl_word = spi_read_word(); //read back word
    
    spi_send_half_word(0xFFFF); //send bus idle value to generate SPI clock
    while(!SPI_DATA_READY){} //wait for read data
    third_adxl_word = spi_read_word(); //read back word
    
    spi_clear_ss(); //clear slave select    
    
    //retrieve data from the upper bits, which due to bursts is in inverse order
    *adxl_x_data = (int16_t)( ((first_adxl_word >> 8) & 0xFF00)  | ((first_adxl_word >> 24) & 0xFF) );            
    *adxl_y_data = (int16_t)( ((second_adxl_word >> 8) & 0xFF00) | ((second_adxl_word >> 24) & 0xFF) );
    *adxl_z_data = (int16_t)( ((third_adxl_word >> 8) & 0xFF00)  | ((third_adxl_word >> 24) & 0xFF) ); 
}
