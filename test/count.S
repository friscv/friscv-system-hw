.section .text
.global _start

_start:
    # Seed counter
    li t0, 0

    # Base address for GPIO (0x40000000)
    lui t1, 0x40000

    # Delay count for human-readable speed
    li t2, 10000000

loop:
    # Create hazards by moving through a zeroed chain
    # These dependent adds force read-after-write hazards
    addi t3, x0, 0
    add  t3, t3, t0
    addi t4, x0, 0
    add  t4, t4, t3
    addi t5, x0, 0
    add  t5, t5, t4

    # Write count (t5) to GPIO
    sw t5, 0(t1)

    # Increment counter
    addi t0, t0, 1

    # Delay loop (dependent chain to keep hazards)
    addi t6, x0, 0
    add  t6, t6, t2

delay_loop:
    addi t6, t6, -1
    bne  t6, x0, delay_loop

    # Repeat
    jal x0, loop
