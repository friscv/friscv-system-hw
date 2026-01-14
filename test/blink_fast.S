.section .text
.global _start

_start:
    # GPIO and end addresses
    li t0, 0x40000000    # gpio base
    li t2, 100


1:
    # Turn LED on (bit0 = 1)
    li t3, 1
    sw t3, 0(t0)

    li t4, 1000000
2:
    addi t4, t4, -1
    bne t4, x0, 2b

    # Turn LED off (bit0 = 0)
    li t3, 0
    sw t3, 0(t0)

    li t4, 1000000
3:
    addi t4, t4, -1
    bne t4, x0, 3b

    # decrement blink counter
    addi t2, t2, -1
    bne t2, x0, 1b

    # Finished: write to end address to signal completion
    li t1, 0x50000000    # end address (signal finish)
    sw x0, 0(t1)
