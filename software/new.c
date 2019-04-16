#include <stdio.h>
#include <stdbool.h>
#include "DES_M0_SoC.h"

#define BUF_SIZE                100
#define ASCII_CR                '\r'
#define CASE_BIT                ('A' ^ 'a')
#define nLOOPS_per_DELAY        1000000

#define INVERT_LEDS             (pt2GPIO->LED ^= 0xff)

#define ARRAY_SIZE(__x__)       (sizeof(__x__)/sizeof(__x__[0]))

#define ADXL_WRITE_COMMAND      0x0A
#define ADXL_READ_COMMAND       0x0B
#define ADXL_READ_FIFO_COMMAND  0x0D
#define ADXL_STATUS_REGISTER    0x0B
#define DISPLAY_WRITE_COMMAND   0x01
#define DISPLAY_ENABLE_REG      0x00
#define DISPLAY_ENABLE_ALL      0xFF
#define DISPLAY_MINUS           0xA
#define DISPLAY_BLANK           0xF

#define DISPLAY_SS_POS          0
#define ADXL_SS_POS             1

#define DISPLAY_DIGITS_PER_VAR  4

#define adxl_send_junk_byte()   adxl_send_byte(0xFF)



volatile uint8_t  counter  = 0; // current number of char received on UART currently in RxBuf[]
volatile uint8_t  BufReady = 0; // Flag to indicate if there is a sentence worth of data in RxBuf
volatile uint8_t  RxBuf[BUF_SIZE];
volatile bool   g_data_ready_flag;


//////////////////////////////////////////////////////////////////
// Interrupt service routine, runs when UART interrupt occurs - see cm0dsasm.s
//////////////////////////////////////////////////////////////////
void UART_ISR()     
{
    char c;
    c = pt2UART->RxData;   // read a character from UART - interrupt only occurs when character waiting
    RxBuf[counter]  = c;   // Store in buffer
    counter++;             // Increment counter to indicate that there is now 1 more character in buffer
    pt2UART->TxData = c;   // write (echo) the character to UART (assuming transmit queue not full!)
    // counter is now the position that the next character should go into
    // If this is the end of the buffer, i.e. if counter==BUF_SIZE-1, then null terminate
    // and indicate the a complete sentence has been received.
    // If the character just put in was a carriage return, do likewise.
    if (counter == BUF_SIZE-1 || c == ASCII_CR)  {
        counter--;                          // decrement counter (CR will be over-written)
        RxBuf[counter] = NULL;  // Null terminate
        BufReady       = 1;     // Indicate to rest of code that a full "sentence" has being received (and is in RxBuf)
    }
}


void ADXL_ISR()
{
    g_data_ready_flag = true;
	counter++;
    printf("\r\ninterrupt %d\r\n",counter); 
}

//ADXL362
void adxl_send_read_command(uint8_t address_to_read);
void adxl_send_write_command(uint8_t address_to_write);
void adxl_send_byte(uint8_t data_to_send);
void adxl_send_half_word(uint16_t data_to_send);
uint8_t adxl_read_status(void);
void adxl_init(void);
uint16_t * adxl_convert_bcd(uint32_t data_to_convert);

//Display
void display_send_write_data(uint8_t address_to_write, uint8_t value_to_write);
void display_enable_all_digits(void);
void display_value_to_digits(uint32_t value_to_display, uint8_t * digits, const uint8_t num_digits);
void display_send_value(uint8_t digit_offset, uint32_t value_to_display);

//SPI
void spi_init(void);
void spi_send_byte(uint8_t);
uint32_t spi_read_word(void);
void spi_send_half_word(uint16_t half_word_to_send);
void spi_set_ss(uint8_t ss_pos);
void spi_clear_ss(void);

//////////////////////////////////////////////////////////////////
// Software delay function
//////////////////////////////////////////////////////////////////
void wait_n_loops(uint32_t n) {
    volatile uint32_t i;
    for(i=0;i<n;i++)
    {
        ;
    }
}

//////////////////////////////////////////////////////////////////
// Main Function
//////////////////////////////////////////////////////////////////
int main(void) {
    uint8_t    adxl_x_ls8;
    uint16_t   adxl_x_data;
    uint16_t   adxl_y_data;
    uint16_t   adxl_z_data;
    uint32_t   first_adxl_word;
    uint32_t   second_adxl_word;
    uint8_t *  bcd_x_data;
    uint8_t *  bcd_y_data;
    uint8_t *  bcd_z_data;
	
	uint32_t test = 4294967295UL;
	
		uint32_t current_interrupts;
    
    
    uint8_t i;
    uint8_t TxBuf[ARRAY_SIZE(RxBuf)];

    //enable interrupts
    pt2NVIC->Enable = (1 << NVIC_UART_BIT_POS);    // Enable interrupts for UART & ADXL in the NVIC
    
	
		pt2UART->Control = (1 << UART_RX_FIFO_EMPTY_BIT_INT_POS);   // 
    wait_n_loops(nLOOPS_per_DELAY);                             // wait a little
    
    printf("\r\nConor/Andrew Assignment 3\r\n");                // output welcome message
    //spi setup
		spi_init();
		printf("\r\nspi init complete\r\n");
    wait_n_loops(nLOOPS_per_DELAY);                             // wait a little                           // wait a little
    //adxl setup
    adxl_init();
		printf("\r\nadxl init complete\r\n");
    //display setup
    //display_enable_all_digits();
		printf("\r\ndisplay init complete\r\n");
    display_send_write_data(0x01,0x07);
		printf("\r\nwrote 7 on display\r\n");

    //pt2NVIC->Enable =  pt2NVIC->Enable | (1UL << NVIC_ADXL_BIT_POS);
		printf("\r\nenabled adxl\r\n");
    
    for(;/*ever*/;)
    {
			test =  pt2NVIC->Enable;
		//printf("\r\n%010u\r\n",test);
        //__wfi(); // use sleep somehow
        if(g_data_ready_flag) 
        {
					printf("\r\ndata ready !\r\n");
            //disable interruts TODO
            g_data_ready_flag = false;
            adxl_send_read_command(0x00); //TODO do I need to send junk to wait?
            while(!SPI_DATA_READY){}
            first_adxl_word = spi_read_word();
            adxl_x_data = (uint16_t)( ((first_adxl_word & 0xFF) << 8) | ((first_adxl_word >> 8) & 0xFF) ); //%TODO may change - see spec
            while(!SPI_DATA_READY){}
            spi_clear_ss();
            second_adxl_word = spi_read_word();
           
            adxl_y_data = (uint32_t)( (((second_adxl_word >> 16) & 0xFF) << 8) | ((second_adxl_word >> 24) & 0xFF) );
            adxl_z_data = (uint32_t)( ((second_adxl_word & 0xFF) << 8)         | ((second_adxl_word >> 8) & 0xFF) );    
            adxl_x_ls8  = (uint8_t)( adxl_x_data & 0xFF );
            display_send_write_data(0x01,adxl_x_ls8);
            //bcd_x_data = display_value_to_digits(adxl_x_data);
            //bcd_y_data = display_value_to_digits(adxl_y_data);
            //bcd_z_data = display_value_to_digits(adxl_z_data);
            display_send_value(0x01,adxl_x_data);
        }
    }
}  // end of main

//ADXL362
void adxl_send_read_command(uint8_t address_to_read)
{
    uint16_t half_word_to_send;
    half_word_to_send = ((uint32_t) ADXL_READ_COMMAND << 16) | address_to_read;
    spi_set_ss(ADXL_SS_POS);
    spi_send_half_word(half_word_to_send);
    //dont clear SS
}
void adxl_send_write_command(uint8_t address_to_write)
{
    uint16_t half_word_to_send;
    half_word_to_send = ((uint32_t) ADXL_WRITE_COMMAND << 16) | address_to_write;
    spi_set_ss(ADXL_SS_POS);
    spi_send_half_word(half_word_to_send);
    //dont clear SS

}
void adxl_send_byte(uint8_t data_to_send) // %TODO this function should maybe allow for cont. writes
{
    //dont need to set SS low as it already will be done TODO
    //spi_set_ss(ADXL_SS_POS);
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
uint32_t adxl_read_register(uint8_t address)
{
    uint32_t rx_word;

    adxl_send_read_command(address);
    //while(!SPI_WRITE_COMPLETE){}
    //adxl_send_junk_byte(); //can we have extra status bits that say how many bits are clocked in?
    //while(!SPI_WRITE_COMPLETE){}
    //adxl_send_junk_byte(); //can we have extra status bits that say how many bits are clocked in?
    //while(!SPI_WRITE_COMPLETE){}
    while(!SPI_DATA_READY){}
		printf("%08X\r\n",pt2SPI->slave_select);	
    spi_clear_ss();
    rx_word = spi_read_word();
    
    return rx_word;
}
void adxl_init(void)
{
    //write to 2C - 
	printf("%08X\r\n",adxl_read_register(0x00));
	printf("%08X\r\n",adxl_read_register(0x2C));
    adxl_send_write_command(0x2C);
    adxl_send_byte(0x11);
	printf("%08X\r\n",adxl_read_register(0x2C));
    //write to 2D - 
    adxl_send_write_command(0x2D);
    adxl_send_byte(0x02);
    //write to 2A - need to set interrupts active high & map DATA_READY
    adxl_send_write_command(0x2A);
    adxl_send_byte(0x1);

}

void display_send_write_data(uint8_t address_to_write, uint8_t value_to_write)
{
    uint16_t half_word_to_send;
		printf("display_send_write_data\r\n");	
    half_word_to_send = ( ((uint16_t) DISPLAY_WRITE_COMMAND) << 12 ) | ( (uint16_t) (address_to_write & 0x0F) << 8 ) | (uint16_t) value_to_write; //TODO check these 
	printf("%04X\r\n",half_word_to_send);
    spi_set_ss(DISPLAY_SS_POS);
		printf("%08X\r\n",pt2SPI->slave_select);	
    spi_send_half_word(half_word_to_send);
		printf("%08X\r\n",pt2SPI->write);
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
void display_value_to_digits(uint32_t value_to_display, uint8_t * digits, const uint8_t num_digits)
{
    uint8_t inc;
    uint8_t sign;
    uint32_t magnitude;
    const uint8_t convert_to_accel = 0xFA;

    sign = (value_to_display >> 12) & 1UL;
    magnitude = value_to_display & 0x7FF;
    if (sign)
    {
        *(digits+num_digits-1) = DISPLAY_MINUS;
        magnitude = !magnitude;
    }
    else
    {
        *(digits+num_digits-1) = DISPLAY_BLANK;
    }
    magnitude = ((magnitude << 8) * convert_to_accel) >> 8;

    for(inc=0;inc<num_digits-1;inc++)
    {
        *(digits+inc)  = (uint8_t)(magnitude%10);
        magnitude   = magnitude/10;
    }
}
void display_send_value(uint8_t digit_offset, uint32_t value_to_display)
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
    }
}
//SPI
void spi_init(void)
{
    // Set number of valid bytes in WDATA to 2, set slave select
    // signals to active low
    pt2SPI->control = 0x00002040;
}

void spi_send_byte(uint8_t byte_to_send)
{
    ;//TODO
}
uint32_t spi_read_word(void)
{
    return pt2SPI->read;
}
void spi_send_half_word(uint16_t half_word_to_send)
{
    pt2SPI->write = half_word_to_send;
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
