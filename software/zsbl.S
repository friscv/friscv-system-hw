.section .text
.global _start

.equ DRAM_BASE, 0x80000000
.equ GPIO_BASE, 0x40000000
.equ UART_BASE, 0x40600000
.equ HALT_ADDR, 0x50000000

.equ GPIO_SWITCHES, 0x8
.equ GPIO_BTN_OFFSET, 0x0
.equ GPIO_BTN_BIT, 0x10

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

.equ MODE_UART, 0x1
.equ MODE_SD, 0x2
.equ MODE_WAIT, 0x3

_start:
.ifdef SIMULATION
    li sp, 0x80000800          # Top of 2KiB sim DRAM (MEM_BASE + MEM_SIZE)
.else
    li sp, 0x81000000          # Top of stack in hardware (1MB above DRAM base)
.endif

    li t2, UART_BASE
    li t0, UART_RST            # Reset TX and RX FIFOs
    sw t0, UART_CTRL(t2)
    sw zero, UART_CTRL(t2)     # Release reset

    la a0, ready_msg
    call uart_puts

    li s1, GPIO_BASE
    lw s0, GPIO_SWITCHES(s1)   # Read boot mode from switches (GPIO2_DATA)

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
    1:  lw t1, GPIO_BTN_OFFSET(s1)
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
    addi sp, sp, -4            # Save ra
    sw ra, 0(sp)
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
    lw ra, 0(sp)               # Restore ra
    addi sp, sp, 4
    ret

# -----------------------------------------------------------------------------
# Xmodem
# -----------------------------------------------------------------------------

uart_boot:
    addi sp, sp, -12           # Save ra, s0 and s1 on stack
    sw ra, 0(sp)
    sw s0, 4(sp)
    sw s1, 8(sp)

    li a0, XMODEM_START
    call uart_putc

    li s0, DRAM_BASE
    li s1, 1

    .wait_packet:
        call uart_getc

        li t0, XMODEM_EOT
        beq a0, t0, .transfer_done

        li t0, XMODEM_SOH
        bne a0, t0, .wait_packet

        call uart_getc         # Packet number (ignored)
        call uart_getc         # Packet number complement (ignored)

        li t1, 128
        1:  call uart_getc
            sb a0, (s0)        # Store byte in DRAM
            addi s0, s0, 1
            addi t1, t1, -1
            bnez t1, 1b

        call uart_getc         # CRC high byte (ignored)
        call uart_getc         # CRC low byte (ignored)

        li a0, XMODEM_ACK
        call uart_putc

        addi s1, s1, 1
        j .wait_packet

    .transfer_done:
    li a0, XMODEM_ACK
    call uart_putc
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
