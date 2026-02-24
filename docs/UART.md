# Connecting to FRISC-V via Serial

FRISC-V has a hardware UART interface connected to the Rasbperry Pi header in the standard pinout (pins 8 and 10). Hardware support is provided by a Xilinx UARTLite module with a fixed baudrate of `115200`.

![PYNQ-Z2 Raspberry Pi header pinout](assets/images/pynq-z2-raspi-header-pinout.png)

## Pinouts and Addresses

### FRISC-V Side

**Standard Pinout:**

Pin No. | Board Port Label | ZYNQ Port Label | Function
------- | ---------------- | --------------- | --------
6       | `GND`            | N/A             | Ground
8       | `RPIO14`         | `V6`            | UART Transmit
10      | `RPIO15`         | `Y6`            | UART Receive

**Address Map:**

The base address of hardware UART is `0x4060_0000`. Different registers are located at different offsets from the base address.

Offset | Register      | SDK Name        | Width
------ | ------------- | --------------- | -----
`0x0`  | Receive Data  | `UART_RX_FIFO`  | 8
`0x4`  | Transmit Data | `UART_TX_FIFO`  | 8
`0x8`  | Status        | `UART_STAT_REG` | 4
`0xC`  | Control       | `UART_CTRL_REG` | 5

**Register Pin Map:**

Read from `UART_RX_FIFO` to read a byte from UART, write to `UART_TX_FIFO` to send a byte.

`UART_RX_FIFO` and `UART_TX_FIFO` pin map:

Bit(s)  | Description
------- | -----------
`7`-`0` | Received or transmitted byte.

`UART_STAT_REG` pin map:

Bit | SDK Name           | Description
--- | ------------------ | -----------
`0` | `UART_SR_RX_VALID` | There is a byte which can be read.
`1` | `UART_SR_RX_FULL`  | The receive queue is full, bytes can't be received.
`2` | `UART_SR_TX_EMPTY` | All enqueued bytes have been transmitted.
`3` | `UART_SR_TX_FULL`  | The transmit queue is full, bytes can't be sent.

`UART_CTRL_REG` pin map:

Bit | SDK Name             | Description
--- | -------------------- | -----------
`0` | `UART_CR_RST_TX`     | Reset transmit and clear queue.
`1` | `UART_CR_RST_RX`     | Reset receive and clear queue.
`5` | `UART_CR_ENABLE_INT` | Enable or disable interrupts.

### I/O Board Side

FRISC-V has first party support for the Embedded Artists LPCXpresso Base Board (I/O board).

The I/O board features a USB-to-UART bridge connected to the primary power source interface on the right side of the board (`U22`, `X3`). Default jumper positions should be used. Consult the LPCXpresso Base Board 
Rev B User’s Guide if needed.

![I/O Board USB-to-UART Connector](assets/images/io-board-uart.png)

The UART TX and RX pins are directly connected to the 50-pin expansion headers on the top side of the board.

Connection to the PYNQ-Z2 board should be done as follows:

Pin  | PYNQ (Connection Board) Name | I/O Pin Name | I/O Board Marking
---- | ---------------------------- | ------------ | -----------------
`RX` | `GPIO15/RXD0`                | `GPIO_6-RXD` | `PIO1.6`
`TX` | `GPIO14/TXD0`                | `GPIO_5-TXD` | `PIO1.7`

> [!IMPORTANT]
> If connecting without the connection board, grounds of the I/O board and PYNQ-Z2 should also be connected.

![Expansion Port UART Pins](assets/images/io-board-expansion-uart.png)

## Host Machine Connection

The recommended way of connecting to the USB-to-UART bridge on the I/O board is through `screen` on Linux. With a USB connected to the port shown in [I/O Board Side](#io-board-side) and detected as `/dev/ttyUSB0`, a serial connection can be connected by running:

```bash
sudo screen /dev/ttyUSB0 115200
```

`/dev/ttyUSB0` is the most common port. If the board was detected as a different port, its device path should be used. `115200` is the default baudrate used by FRISC-V. If FRISC-V is configured with a different baudrate, use that instead.

Install screen by running `sudo apt install screen -y` in a Linux terminal.

Connecting from Windows should be done through WSL2. As WSL does not have direct access to the devices connected to the Windows machine, the port must first be attached to WSL.

**Windows First-time Setup:**

In PowerShell, run:

```powershell
usbipd list
```

Connected USB devices will be listed, as shown below.

```powershell
PS C:\WINDOWS\system32> usbipd list
Connected:
BUSID  VID:PID    DEVICE                             STATE
2-1    0403:6001  USB Serial Converter               Not Shared
2-3    8087:0032  Intel(R) Wireless Bluetooth(R)     Not shared

Persisted:
GUID                                  DEVICE
be100f34-5425-4bd9-801c-0f2b1ce19841  USB-SERIAL CH340 (COM3)
```

Look for `USB Serial Converter` and note its `BUSID` (`2-1` in this case).

Bind the device with that `BUSID` for future use by running:

```powershell
usbipd bind --busid 2-1
```

If your `BUSID` was not `2-1`, use that `BUSID` instead.

**Connecting from Windows:**

The steps above need to be run only once. These steps need to be followed every time the I/O board is connected. If UART starts misbehaving or becomes unresponsive, reconnect the USB cable and start from here.

Attach the USB device to WSL using PowerShell to make it detectable as `/dev/ttyUSB0`.

```powershell
usbipd attach --wsl --busid 2-1
```

Again, use the `BUSID` your `usbipd list` detected, not necessarily `2-1`.

After that, enter WSL and run the connection command:

```bash
sudo screen /dev/ttyUSB0 115200
```

## Software Examples

Before using UART, the RX and TX queues must be reset by writing to the appropriate pins of the control register.

```c
void uart_init() {
    // Reset TX and RX
    UART_CTRL_REG = UART_CR_RST_TX | UART_CR_RST_RX;
    // Release reset
    UART_CTRL_REG = 0;
}
```

When writing a byte, software must check that the transmit queue is not full.

```c
void uart_putc(char c) {
    // Wait if TX FIFO is full
    while (UART_STAT_REG & UART_SR_TX_FULL);
    // Put char when not full
    UART_TX_FIFO = c;
}
```

When reading a byte, software must check that there is valid data in the receive queue.

```c
char uart_getc() {
    // Wait if RX FIFO is empty
    while (!(UART_STAT_REG & UART_SR_RX_VALID));
    // Read when valid byte present
    return UART_RX_FIFO & 0xFF;
}
```

The constant values are defined as in [Pinouts and Addresses](#pinouts-and-addresses).

```c
#include <stdint.h>

// UARTLite register definitions
#define UART_BASE      0x40600000
#define UART_RX_FIFO   (*(volatile uint32_t *)(UART_BASE + 0x0))
#define UART_TX_FIFO   (*(volatile uint32_t *)(UART_BASE + 0x4))
#define UART_STAT_REG  (*(volatile uint32_t *)(UART_BASE + 0x8))
#define UART_CTRL_REG  (*(volatile uint32_t *)(UART_BASE + 0xC))

// Status register bits
#define UART_SR_RX_VALID    0x01  // Receive FIFO valid data
#define UART_SR_RX_FULL     0x02  // Receive FIFO full
#define UART_SR_TX_EMPTY    0x04  // Transmit FIFO empty
#define UART_SR_TX_FULL     0x08  // Transmit FIFO full

// Control register bits
#define UART_CR_RST_TX      0x01  // Reset transmit FIFO
#define UART_CR_RST_RX      0x02  // Reset receive FIFO
#define UART_CR_ENABLE_INT  0x10  // Enable interrupt
```
