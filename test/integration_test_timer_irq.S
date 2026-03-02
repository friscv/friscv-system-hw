# RV32I M-mode Interrupt Test
# Tests: IRQ handler entry, MRET return, register preservation, MIE gate
#
# Final result will be 0xAABBCCDD only if all tests pass correctly

.option arch, +zicsr
.text
.globl _start

_start:
    lui  x31, 0x80000          # Checkpoint base: 0x80000000
    addi x31, x31, 0x700       # → 0x80000700
    lui  x30, 0x40000          # Final result: 0x40000000
    li   x28, 0                # Accumulator
    li   x29, 0                # Test counter
    j    main_start

# ============================================================
# HANDLER 1 - test 1 (interrupt entry)
# Increments x10, disables timer, returns.
# ============================================================
handler1:
    addi x10, x10, 1
    lui  x5, 0x40100           # 0x40100000
    li   x6, -1
    sw   x6, 0(x5)             # target[31:0]  = 0xFFFFFFFF (suppress IRQ)
    sw   x6, 4(x5)             # target[63:32] = 0xFFFFFFFF
    mret

# ============================================================
# HANDLER 2 - tests 2 & 3 (MRET return, register integrity)
# Writes 0xBEEF into x12, disables timer, returns.
# ============================================================
handler2:
    li   x12, 0xBEEF
    lui  x5, 0x40100
    li   x6, -1
    sw   x6, 0(x5)             # target[31:0]  = 0xFFFFFFFF (suppress IRQ)
    sw   x6, 4(x5)             # target[63:32] = 0xFFFFFFFF
    mret

# ============================================================
# HANDLER 3 - test 4 (MIE gate)
# Must NEVER execute: IRQ cannot be taken with MIE = 0.
# Increments x14 to leave a detectable trace if called.
# ============================================================
handler3:
    addi x14, x14, 1
    lui  x5, 0x40100
    li   x6, -1
    sw   x6, 0(x5)             # target[31:0]  = 0xFFFFFFFF (suppress IRQ)
    sw   x6, 4(x5)             # target[63:32] = 0xFFFFFFFF
    mret

# ============================================================
main_start:

# ================================================================
# TEST 1 - interrupt handler is entered
#
# Pass: x10 == 1  (handler called exactly once)
# Fail: timeout (handler never entered) or x10 != 1
# ================================================================
test1:
    li   x10, 0                # x10 = handler_count

    la   x1, handler1
    csrw 0x305, x1             # mtvec = handler1

    lui  x5, 0x40100           # timer base = 0x40100000
    sw   x0, 8(x5)             # counter[31:0]  = 0
    sw   x0, 12(x5)            # counter[63:32] = 0
    li   x6, 64
    sw   x6, 0(x5)             # target[31:0]  = 64 (fire after 64 ticks)
    sw   x0, 4(x5)             # target[63:32] = 0

    li   x1, 8
    csrw 0x300, x1             # mstatus.MIE = 1

    li   x6, 4096              # spin limit
test1_spin:
    bnez x10, test1_done       # exit when handler has fired
    addi x6, x6, -1
    bnez x6, test1_spin
    j    test_fail             # timeout: handler never called

test1_done:
    csrw 0x300, x0             # disable MIE

    li   x1, 1
    bne  x10, x1, test_fail    # must be exactly 1 (single entry, timer disabled)

test1_pass:
    addi x28, x28, 0x111
    sw   x10, 0(x31)           # checkpoint 0: handler_count (expect 1)
    addi x29, x29, 1
    li   x27, 0x111
    bne  x28, x27, test_fail

# ================================================================
# TEST 2 - MRET returns execution to main code
#
# The spin loop can only be running (and exit) if MRET returned us
# to it.  Staying stuck inside the handler makes the loop invisible.
#
# Pass: x11 == 0xAA55  (register integrity)
#       x12 == 0xBEEF  (handler was entered)
#       x13 == 1       (main code continued after MRET)
# ================================================================
test2:
    li   x11, 0xAA55           # sentinel
    li   x12, 0                # handler marker
    li   x13, 0                # post-interrupt step counter

    la   x1, handler2
    csrw 0x305, x1             # mtvec = handler2

    lui  x5, 0x40100
    sw   x0, 8(x5)             # counter[31:0]  = 0
    sw   x0, 12(x5)            # counter[63:32] = 0
    li   x6, 64
    sw   x6, 0(x5)             # target[31:0]  = 64
    sw   x0, 4(x5)             # target[63:32] = 0

    li   x1, 8
    csrw 0x300, x1             # MIE = 1

    li   x6, 4096
    li   x7, 0xBEEF
test2_spin:
    beq  x12, x7, test2_done   # handler ran AND MRET brought us back
    addi x6, x6, -1
    bnez x6, test2_spin
    j    test_fail             # timeout: MRET never returned to main code

test2_done:
    csrw 0x300, x0             # disable MIE
    addi x13, x13, 1           # main code continues here after MRET

    li   x1, 0xAA55
    bne  x11, x1, test_fail    # x11 was modified by handler - fail
    li   x1, 0xBEEF
    bne  x12, x1, test_fail    # handler marker not set - fail
    li   x1, 1
    bne  x13, x1, test_fail    # main code did not resume - fail

test2_pass:
    addi x28, x28, 0x222
    sw   x11, 4(x31)           # checkpoint 1: sentinel (expect 0xAA55)
    addi x29, x29, 1
    li   x27, 0x333
    bne  x28, x27, test_fail

# ================================================================
# TEST 3 - MIE = 0 prevents handler from being called
#
# Pass: x14 == 0 throughout (IRQ never taken)
# Fail: x14 != 0 (interrupt taken despite MIE=0)
# ================================================================
test3:
    li   x14, 0                # spurious-entry counter

    la   x1, handler3
    csrw 0x305, x1             # mtvec = handler3

    lui  x5, 0x40100
    sw   x0, 8(x5)             # counter[31:0]  = 0
    sw   x0, 12(x5)            # counter[63:32] = 0
    li   x6, 64
    sw   x6, 0(x5)             # target[31:0]  = 64
    sw   x0, 4(x5)             # target[63:32] = 0
    # MIE intentionally NOT enabled

    li   x6, 1024
test3_spin:
    bnez x14, test_fail        # handler fired with MIE=0 - fail
    addi x6, x6, -1
    bnez x6, test3_spin

    # clean up timer before leaving: set target to max to suppress IRQ
    lui  x5, 0x40100
    li   x6, -1
    sw   x6, 0(x5)             # target[31:0]  = 0xFFFFFFFF
    sw   x6, 4(x5)             # target[63:32] = 0xFFFFFFFF

test3_pass:
    addi x28, x28, 0x333
    sw   x14, 8(x31)           # checkpoint 2: must be 0
    addi x29, x29, 1
    li   x27, 0x666
    bne  x28, x27, test_fail

# ================================================================
# All tests passed
# ================================================================
all_tests_pass:
    li   x1, 3
    bne  x29, x1, test_fail
    li   x2, 0x666
    bne  x28, x2, test_fail

    li   x1, 0xAABBCCDD
    sw   x1, 0(x30)            # write passing result to 0x40000000
    j    end_program

test_fail:
    li   x1, 0xBADC0DE
    sw   x1, 0(x30)
    j    end_program

end_program:
    lui  x10, 0x50000
    sw   x0, 0(x10)            # halt: write to END_ADDRESS (0x50000000)

.data
