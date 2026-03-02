.section .text
.global _start

# =============================================================================
# REGISTER ALLOCATION (Stack-free design - do not use these for other purposes)
# =============================================================================
# s0 - Reserved for boot mode
# s1 - Reserved for GPIO0_BASE
# s2 - Reserved for GPIO1_BASE
# s3 - Reserved for uart_puts return address
# s4 - Reserved for uart_boot return address
# s5 - DRAM write pointer (uart_boot)
# s6 - Packet counter (uart_boot)
# s7 - Retry counter (uart_boot)
# s8 - Byte counter (uart_boot inner loop)
# s9-s11 - Free to use
# =============================================================================

.equ DRAM_BASE, 0x80000000
.equ GPIO0_BASE, 0x40000000
.equ GPIO1_BASE, 0x40010000
.equ UART_BASE, 0x40600000
.equ HALT_ADDR, 0x50000000

.equ GPIO_LED_OFFSET, 0x0
.equ GPIO_SW_OFFSET, 0x8
.equ GPIO_BTN_BIT, 0x1
.equ GPIO_BTN_OFFSET, 0x0

.equ UART_STATUS, 0x8
.equ UART_TX, 0x4
.equ UART_RX, 0x0
.equ UART_CTRL, 0xC

.equ UART_RST, 0x3
.equ UART_SR_RX_VALID, 0x01
.equ UART_SR_TX_EMPTY, 0x04
.equ UART_SR_TX_FULL, 0x08

.equ XMODEM_START, 'C'
.equ XMODEM_EOT, 0x04
.equ XMODEM_SOH, 0x01
.equ XMODEM_ACK, 0x06

.equ UART_TIMEOUT_COUNT, 10000000
.equ XMODEM_RETRIES, 16

.equ MODE_UART, 0x1
.equ MODE_SD, 0x2
.equ MODE_WAIT, 0x3

_start:
    li t2, UART_BASE
    li t0, UART_RST            # Reset TX and RX FIFOs
    sw t0, UART_CTRL(t2)
    sw zero, UART_CTRL(t2)     # Release reset

    la a0, ready_msg
    call uart_puts

    li s1, GPIO0_BASE
    li s2, GPIO1_BASE
    lw s0, GPIO_SW_OFFSET(s1)  # Read boot mode from switches (GPIO2_DATA)

    bnez s0, .skip_direct_jump # mode 0 = boot from DRAM
    la a0, dram_msg
    call uart_puts
    j execute_loaded
    .skip_direct_jump:

    li t1, MODE_UART           # mode 1 = UART (xmodem) boot
    bne s0, t1, .skip_uart
    la a0, uart_msg
    call uart_puts
    call uart_boot
    j .try_sd
    .skip_uart:

    li t1, MODE_SD             # mode 2 = SD card boot
    bne s0, t1, .skip_sd
    .try_sd:
    la a0, sd_msg
    call uart_puts
    call sd_boot
    j .try_wait
    .skip_sd:

    li t1, MODE_WAIT           # mode 3 = wait for button press
    bne s0, t1, .invalid_mode
    .try_wait:
    la a0, wait_msg
    call uart_puts
    1:  lw t1, GPIO_BTN_OFFSET(s2)
        andi t1, t1, GPIO_BTN_BIT
        beqz t1, 1b            # Wait while button is not pressed
    j execute_loaded

    .invalid_mode:
        li t0, HALT_ADDR
        sw zero, (t0)
        j .invalid_mode

# ----- Jump to DRAM to execute loaded code -----
execute_loaded:
    li t0, DRAM_BASE
    jalr zero, t0

# -----------------------------------------------------------------------------
# UART routines
# -----------------------------------------------------------------------------

# ----- Put character in a0 to UART, wait until ready -----
uart_putc:
    li t1, UART_BASE
    1:  lw t0, UART_STATUS(t1)
        andi t0, t0, UART_SR_TX_FULL
        bnez t0, 1b            # Wait while TX FIFO is full
    sw a0, UART_TX(t1)
    ret

# ----- Wait for character from UART and return it in a0 -----
uart_getc:
    li t1, UART_BASE
    1:  lw t0, UART_STATUS(t1)
        andi t0, t0, UART_SR_RX_VALID
        beqz t0, 1b            # Wait while RX FIFO is empty
    lbu a0, UART_RX(t1)
    ret

# ----- Put null-terminated string at a0 to UART -----
uart_puts:
    mv s3, ra                  # Save ra in s3 (ZSBL doesn't use it)
    mv t2, a0                  # t2 = string pointer
    1:  lbu a0, (t2)
        beqz a0, 2f            # Return if null terminator
        call uart_putc
        addi t2, t2, 1
        j 1b
    2:
    li t2, UART_BASE           # Wait until TX FIFO is fully drained
    3:  lw t0, UART_STATUS(t2)
        andi t0, t0, UART_SR_TX_EMPTY
        beqz t0, 3b
    mv ra, s3                  # Restore ra from s3
    ret

# -----------------------------------------------------------------------------
# Xmodem
# -----------------------------------------------------------------------------

# ----- Wait for character with timeout -----
# char in a0, or -1 on timeout
# a1 = timeout loop count
uart_getc_timeout:
    li t1, UART_BASE
    1:  lw t0, UART_STATUS(t1)
        andi t0, t0, UART_SR_RX_VALID
        bnez t0, 2f            # Character available
        addi a1, a1, -1
        bnez a1, 1b            # Keep polling while count > 0
    li a0, -1                  # Timeout - no character received
    ret
    2:  lbu a0, UART_RX(t1)
    ret

uart_boot:
    mv s4, ra                  # Save ra in s4

    li s5, DRAM_BASE           # s5 = DRAM write pointer
    li s6, 1                   # s6 = Packet counter
    li s7, XMODEM_RETRIES      # s7 = Retry counter for initial handshake

    li t0, 1
    sw t0, GPIO_LED_OFFSET(s1) # LED on: ready to receive

    .xmodem_start_retry:
        li a0, XMODEM_START
        call uart_putc         # Send 'C' to initiate XMODEM-CRC

        li a1, UART_TIMEOUT_COUNT
        call uart_getc_timeout

        li t0, -1
        beq a0, t0, .xmodem_check_retry    # Timed out

        j .check_char                  # Got a character, process it

        .xmodem_check_retry:
        addi s7, s7, -1
        bnez s7, .xmodem_start_retry   # Retry if attempts remain
        # All retries exhausted - return
        sw zero, GPIO_LED_OFFSET(s1)   # LED off: receive failed
        mv ra, s4                      # Restore ra from s4
        ret

    # Blocking packet receive loop
    .next_packet:
        call uart_getc
    .check_char:
        li t0, XMODEM_EOT
        beq a0, t0, .transfer_done

        li t0, XMODEM_SOH
        bne a0, t0, .next_packet   # Unexpected byte, wait for SOH

        sw zero, GPIO_LED_OFFSET(s1)   # LED off: load started

        call uart_getc             # Packet number (ignored)
        call uart_getc             # Packet number complement (ignored)

        li s8, 128
        1:  call uart_getc
            sb a0, (s5)            # Store byte in DRAM
            addi s5, s5, 1
            addi s8, s8, -1
            bnez s8, 1b

        call uart_getc             # CRC high byte (ignored)
        call uart_getc             # CRC low byte (ignored)

        li a0, XMODEM_ACK
        call uart_putc

        addi s6, s6, 1
        j .next_packet

    .transfer_done:
    li a0, XMODEM_ACK
    call uart_putc
    li t1, UART_BASE           # Wait for TX FIFO to drain before handing off
    1:  lw t0, UART_STATUS(t1)
        andi t0, t0, UART_SR_TX_EMPTY
        beqz t0, 1b
    # Jump directly to loaded code
    j execute_loaded

# -----------------------------------------------------------------------------
# SD card routines
# -----------------------------------------------------------------------------

sd_boot:
    # Placeholder for SD card loading code
    ret

# -----------------------------------------------------------------------------
# Data
# -----------------------------------------------------------------------------

ready_msg:
    .string "[ZSBL] Ready\r\n"
dram_msg:
    .string "[ZSBL] Mode: DRAM\r\n"
uart_msg:
    .string "[ZSBL] Mode: UART\r\n"
sd_msg:
    .string "[ZSBL] Mode: SD\r\n"
wait_msg:
    .string "[ZSBL] Waiting for BTN0 press\r\n"
