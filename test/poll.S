.section .text
.global _start

_start:
    li t0, 0x40000000
poll_loop:
    lw t3, 4(t0)
    andi t3, t3, 1
    beq t3, zero, write_zero
    li t6, 1
    sw t6, 0(t0)
    j poll_delay
write_zero:
    li t6, 0
    sw t6, 4(t0)
poll_delay:
    li t2, 10
delay_loop:
    addi t2, t2, -1
    bnez t2, delay_loop
    j poll_loop
