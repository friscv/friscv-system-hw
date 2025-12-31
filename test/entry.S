.section .text
.global _start

_start:
    li t0, -1

    # Write to GPIO
    li t1, 0x40000000
    sw t0, 0(t1)

    # Write to result address
    li t1, 0x80000400
    sw t0, 0(t1)

    # Write to end address to halt
    li t2, 0x50000000
    sw x0, 0(t2)
