#include <stdio.h>
#include "DES_M0_SoC.h"

#define BUF_SIZE                100
#define ASCII_CR                '\r'
#define CASE_BIT                ('A' ^ 'a')
#define nLOOPS_per_DELAY        1000000

#define INVERT_LEDS             (pt2GPIO->LED ^= 0xff)

#define ARRAY_SIZE(__x__)       (sizeof(__x__)/sizeof(__x__[0]))

volatile uint8  counter  = 0; // current number of char received on UART currently in RxBuf[]
volatile uint8  BufReady = 0; // Flag to indicate if there is a sentence worth of data in RxBuf
volatile uint8  RxBuf[BUF_SIZE];
volatile _Bool  g_data_ready_flag;


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
    g_data_ready_flag = True;
}

void send_adxl_read_command(uint8 address_to_read);

//////////////////////////////////////////////////////////////////
// Software delay function
//////////////////////////////////////////////////////////////////
void wait_n_loops(uint32 n) {
    volatile uint32 i;
    for(i=0;i<n;i++)
    {
        ;
    }
}


//////////////////////////////////////////////////////////////////
// Main Function
//////////////////////////////////////////////////////////////////
int main(void) {
    uint16 adxl_x_data, adxl_y_data, adxl_z_data;
    uint32 first_adxl_word, second_adxl_word;
    
    
    uint8 i;
    uint8 TxBuf[ARRAY_SIZE(RxBuf)];

    
    pt2UART->Control = (1 << UART_RX_FIFO_EMPTY_BIT_INT_POS);       // Enable rx data available interrupt, and no others.
    pt2NVIC->Enable  = (1 << NVIC_UART_BIT_POS);                                // Enable interrupts for UART in the NVIC
    pt2NVIC->Enable  = (1 << NVIC_ADXL_BIT_POS);                                // Enable interrupts for ADXL in the NVIC
    wait_n_loops(nLOOPS_per_DELAY);                                     // wait a little
    
    printf("\r\nConor/Andrew Assignment 3\r\n");            // output welcome message
    
    for(;;)
    {
        if(g_data_ready_flag) // use sleep somehow
        {
            g_data_ready_flag = False;
            send_adxl_read_command(0x00);
            while(!SPI_DATA_READY_BIT){}
            first_adxl_word = SPI_READ_BUFFER;
            while(!SPI_DATA_READY_BIT){}
            set_adxl_ss(False);
            second_adxl_word = SPI_READ_BUFFER;
            adxl_x_data = uint16( ((first_adxl_word & 0xFF) << 8) | ((first_adxl_word >> 8) & 0xFF) ); //move to before rx2?
            adxl_y_data = uint16( (((second_adxl_word >> 16) & 0xFF) << 8) | ((second_adxl_word >> 24) & 0xFF) );
            adxl_z_data = uint16( ((second_adxl_word & 0xFF) << 8) | ((second_adxl_word >> 8) & 0xFF) );           
        }
    }

    
    while(1){           // loop forever
            
            // Do some processing before entering Sleep Mode
            
            pt2GPIO->LED = pt2GPIO->Switches; // Echo the switches onto the LEDs
            wait_n_loops(nLOOPS_per_DELAY);     // delay a little
            INVERT_LEDS;                                            // invert the 8 rightmost LEDs
            wait_n_loops(nLOOPS_per_DELAY);
            INVERT_LEDS;
            wait_n_loops(nLOOPS_per_DELAY);
            
            printf("\r\nType some characters: ");
            while (BufReady == 0)
            {           
                __wfi();  // Wait For Interrupt: enter Sleep Mode - wake on character received
                pt2GPIO->LED = RxBuf[counter-1];  // display code for character received
            }

            // get here when CR entered or buffer full - do some processing with interrupts disabled
            pt2NVIC->Disable     = (1 << NVIC_UART_BIT_POS);    // Disable interrupts for UART in the NVIC

            // ---- start of critical section ----
            for (i=0; i<=counter; i++)
            {
                if (RxBuf[i] >= 'A') {                          // if this character is a letter (roughly)
                    TxBuf[i] = RxBuf[i] ^ CASE_BIT;  // copy to transmit buffer, changing case
                }
                else {
                    TxBuf[i] = RxBuf[i];             // non-letter so don't change case
                }
            }
            
            BufReady = 0;   // clear the flag
                
            // ---- end of critical section ----        
            
            pt2NVIC->Enable  = (1 << NVIC_UART_BIT_POS);        // Enable interrupts for UART in the NVIC


            printf("\r\n:--> |%s|\r\n", TxBuf);  // print the results between bars
            printf("\r\nNumber Of Characters:%d\r\n", counter);  // print the number of characters
            printf("\r\nSwitch State:%d\r\n",pt2GPIO->Switches);
            
            counter  = 0; // clear the counter for next sentence    
            
        } // end of infinite loop

}  // end of main


