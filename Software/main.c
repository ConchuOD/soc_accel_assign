//------------------------------------------------------------------------------------------------------
// Demonstration program for Cortex-M0 SoC design
// 1)Enable the interrupt for UART - interrupt when character received
// 2)Go to sleep mode
// 3)On interruption, echo character back to the UART and collect into buffer
// 4)When a whole sentence has been received, invert the case and send it back
// 5)Loop forever doing the above.
//
// Version 4 - October 2015
//------------------------------------------------------------------------------------------------------
#include <stdio.h>
#include "DES_M0_SoC.h"

#define BUF_SIZE						100
#define ASCII_CR						'\r'
#define CASE_BIT						('A' ^ 'a')
#define nLOOPS_per_DELAY		1000000

#define INVERT_LEDS					(pt2GPIO->LED ^= 0xff)

#define ARRAY_SIZE(__x__)       (sizeof(__x__)/sizeof(__x__[0]))

volatile uint8  counter  = 0; // current number of char received on UART currently in RxBuf[]
volatile uint8  BufReady = 0; // Flag to indicate if there is a sentence worth of data in RxBuf
volatile uint8  RxBuf[BUF_SIZE];


//////////////////////////////////////////////////////////////////
// Interrupt service routine, runs when UART interrupt occurs - see cm0dsasm.s
//////////////////////////////////////////////////////////////////
void UART_ISR()		
{
	char c;
	c = pt2UART->RxData;	 // read a character from UART - interrupt only occurs when character waiting
	RxBuf[counter]  = c;   // Store in buffer
	counter++;             // Increment counter to indicate that there is now 1 more character in buffer
	pt2UART->TxData = c;   // write (echo) the character to UART (assuming transmit queue not full!)
	// counter is now the position that the next character should go into
	// If this is the end of the buffer, i.e. if counter==BUF_SIZE-1, then null terminate
	// and indicate the a complete sentence has been received.
	// If the character just put in was a carriage return, do likewise.
	if (counter == BUF_SIZE-1 || c == ASCII_CR)  {
		counter--;							// decrement counter (CR will be over-written)
		RxBuf[counter] = NULL;  // Null terminate
		BufReady       = 1;	    // Indicate to rest of code that a full "sentence" has being received (and is in RxBuf)
	}
}


//////////////////////////////////////////////////////////////////
// Software delay function
//////////////////////////////////////////////////////////////////
void wait_n_loops(uint32 n) {
	volatile uint32 i;
		for(i=0;i<n;i++){
			;
		}
}


//////////////////////////////////////////////////////////////////
// Main Function
//////////////////////////////////////////////////////////////////
int main(void) {
	uint8 i;
	uint8 TxBuf[ARRAY_SIZE(RxBuf)];

	
	pt2UART->Control = (1 << UART_RX_FIFO_EMPTY_BIT_INT_POS);		// Enable rx data available interrupt, and no others.
  pt2NVIC->Enable	 = (1 << NVIC_UART_BIT_POS);								// Enable interrupts for UART in the NVIC
	wait_n_loops(nLOOPS_per_DELAY);										// wait a little
	
	printf("\r\nConor/Andrew Assignment 3\r\n");			// output welcome message

	
	while(1){			// loop forever
			
			// Do some processing before entering Sleep Mode
			
			pt2GPIO->LED = pt2GPIO->Switches; // Echo the switches onto the LEDs
			wait_n_loops(nLOOPS_per_DELAY);		// delay a little
			INVERT_LEDS;											// invert the 8 rightmost LEDs
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
			pt2NVIC->Disable	 = (1 << NVIC_UART_BIT_POS);	// Disable interrupts for UART in the NVIC

			// ---- start of critical section ----
			for (i=0; i<=counter; i++)
			{
				if (RxBuf[i] >= 'A') {							// if this character is a letter (roughly)
					TxBuf[i] = RxBuf[i] ^ CASE_BIT;  // copy to transmit buffer, changing case
				}
				else {
					TxBuf[i] = RxBuf[i];             // non-letter so don't change case
				}
			}
			
			BufReady = 0;	// clear the flag
				
			// ---- end of critical section ----		
			
			pt2NVIC->Enable	 = (1 << NVIC_UART_BIT_POS);		// Enable interrupts for UART in the NVIC


			printf("\r\n:--> |%s|\r\n", TxBuf);  // print the results between bars
			printf("\r\nNumber Of Characters:%d\r\n", counter);  // print the number of characters
			printf("\r\nSwitch State:%d\r\n",pt2GPIO->Switches);
			
			counter  = 0; // clear the counter for next sentence	
			
		} // end of infinite loop

}  // end of main

