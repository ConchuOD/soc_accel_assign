// DES_M0_SoC.h
#ifndef DES_M0_SoC_ALREADY_INCLUDED
#define DES_M0_SoC_ALREADY_INCLUDED

typedef unsigned       char uint8_t;
typedef   signed       char  int8_t;
typedef unsigned short int  uint16_t;
typedef   signed short int   int16_t;
typedef unsigned       int  uint32_t;
typedef   signed       int   int32_t;

#define bit_read(value, bit) (((value) >> (bit)) & 0x01)
#define bit_set(value, bit) ((value) |= (1UL << (bit)))
#define bit_clear(value, bit) ((value) &= ~(1UL << (bit)))
#define bit_write(value, bit, bitvalue) ((bitvalue) ? bitSet((value), (bit)) : bitClear((value), (bit)))

#pragma anon_unions
typedef struct {
	union {
		volatile uint8_t   RxData;
		volatile uint32_t  reserved0;
	};
	union {
		volatile uint8_t   TxData;
		volatile uint32_t  reserved1;
	};
	union {
		volatile uint8_t   Status;
		volatile uint32_t  reserved2;
	};
	union {
		volatile uint8_t   Control;
		volatile uint32_t  reserved3;
	};
} UART_t;
// bit position defs for the UART status register
#define UART_TX_FIFO_FULL_BIT_POS		0			// Tx FIFO full
#define UART_TX_FIFO_EMPTY_BIT_POS	    1			// Rx FIFO empty
#define UART_RX_FIFO_FULL_BIT_POS		2			// Rx FIFO full
#define UART_RX_FIFO_EMPTY_BIT_POS	    3			// Rx FIFO not empty (data available)
// corresponding bit position defs for the UART interrupts enables in the control register`
#define UART_TX_FIFO_FULL_INT_BIT_POS	(UART_TX_FIFO_FULL_BIT_POS )	// Tx FIFO full
#define UART_TX_FIFO_EMPTY_INT_BIT_POS	(UART_TX_FIFO_EMPTY_BIT_POS)	// Rx FIFO empty
#define UART_RX_FIFO_FULL_BIT_INT_POS	(UART_RX_FIFO_FULL_BIT_POS )	// Rx FIFO full
#define UART_RX_FIFO_EMPTY_BIT_INT_POS	(UART_RX_FIFO_EMPTY_BIT_POS)	// Rx FIFO data available


typedef struct {
	union {
		volatile uint32_t	Enable;
		volatile uint32_t	reserved0;
	};
	volatile uint32_t		reserved1[0x20-1];  // force next guy to to 0x80 bytes = 0x20 words away from start of this one
	union {
		volatile uint32_t	Disable;
		volatile uint32_t	reserved2;
	};
} NVIC_t;
#define NVIC_UART_BIT_POS		1      // bit position of UART in ARM's interrupt control register
#define NVIC_ADXL_BIT_POS		2      // bit position of ADXL in ARM's interrupt control register


typedef struct {
	union {
		volatile uint16_t  LED;
		volatile uint32_t  reserved0;
	};
	union {
		volatile uint16_t  NotConnected;
		volatile uint32_t  reserved1;
	};
	union {
		volatile uint16_t  Switches;
		volatile uint32_t  reserved2;
	};
	union {
		volatile uint16_t  Buttons;
		volatile uint32_t  reserved3;
	};
} GPIO_t;

typedef struct
{
	volatile uint32_t control;
	volatile uint32_t slave_select;
    union
    {
		volatile uint16_t  write_half_word;
		volatile uint32_t  write_word;
	};
	volatile uint32_t read;
} SPI_t;

#define SPI_DATA_READY_BIT 		  0
#define SPI_TRANSMIT_COMPLETE_BIT 4
#define SPI_WRITE_COMPLETE        bit_read(pt2SPI->control, SPI_TRANSMIT_COMPLETE_BIT)
#define SPI_DATA_READY            bit_read(pt2SPI->control, SPI_DATA_READY_BIT)

// use above typedefs to define the memory map.
#define pt2NVIC ((NVIC_t *)0xE000E100)
#define pt2UART ((UART_t *)0x51000000)
#define pt2GPIO ((GPIO_t *)0x50000000)
#define pt2SPI  ((SPI_t  *)0x52000000)


#endif
