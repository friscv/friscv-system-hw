.section .text
.global _start

_start:
    # Single jump to turn_on_led
    j turn_on_led
    
    # If we get here, jump didn't work - halt without LED
    li t0, 0x50000000
    sw x0, 0(t0)

turn_on_led:
    # Turn on LED
    li t0, 0x40000000
    li t1, 0xFF
    sw t1, 0(t0)
    
    # Halt
    li t2, 0x50000000
    sw x0, 0(t2)
