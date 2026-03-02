.option arch, +zicsr
.text
.globl _start

_start:
    j     main

.balign 4
timer_handler:
    addi  sp, sp, -12
    sw    t0, 0(sp)
    sw    t1, 4(sp)
    sw    t2, 8(sp)

    # Reset counter to 0 so the next IRQ fires in exactly 0.5 s
    li    t0, 0x40100000
    sw    x0, 8(t0)
    sw    x0, 12(t0)

    # Toggle led_state
    la    t1, led_state
    lw    t2, 0(t1)
    xori  t2, t2, 1
    sw    t2, 0(t1)
    li    t0, 0x40000000
    sw    t2, 0(t0)

    lw    t0, 0(sp)
    lw    t1, 4(sp)
    lw    t2, 8(sp)
    addi  sp, sp, 12
    mret

# ----------------------------------------------------------------
# Main
# ----------------------------------------------------------------
main:
    li    sp, 0x80000800

    la    t0, timer_handler
    csrw  0x305, t0

    la    t0, led_state
    sw    x0, 0(t0)
    li    t0, 0x40000000
    sw    x0, 0(t0)

    # Configure timer: target = 45,454,544 cycles = 0.5 s @ 90.909088 MHz
    li    t0, 0x40100000
    sw    x0, 8(t0)
    sw    x0, 12(t0)
    li    t1, 0x02B594D0      # 45,454,544 cycles
    sw    t1, 0(t0)
    sw    x0, 4(t0)

    # Enable global machine interrupts
    li    t0, 8
    csrw  0x300, t0

idle:
    j     idle

.data
led_state:
    .word 0
