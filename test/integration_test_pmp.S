.option arch, +a
.option arch, +zicsr
.option arch, +zifencei

.text
.globl _start

_start:
    li x31, 0x80000500
    li x30, 0x40000000
    li x29, 0
    li x28, 0

# Readback
test1:
    # pmpcfg initalizes to 0
    csrr x1, pmpcfg0
    bne x1, x0, test_fail

    # Correct normal readback
    li x1, 0b00000011
    csrw pmpcfg2, x1
    csrr x2, pmpcfg2
    bne x1, x2, test_fail

    # Reserved reads as 0
    li x3, 0b01100011
    csrw pmpcfg3, x3
    csrr x2, pmpcfg3
    bne x1, x2, test_fail

    addi x28, x28, 0x111
    sw x4, 0(x31)
    addi x29, x29, 1
    li x27, 0x111
    bne x28, x27, test_fail

# NAPOT R allow

# NAPOT R deny

# NAPOT W allow

# NAPOT W deny

# NAPOT X allow

# NAPOT X deny

# NAPOT RW allow

# NAPOT RW deny

# TODO Addressing modes...

# TOR region start

# TOR region last word (end-4)

# TOR one below start

# TOR exact upper

# NAPOT boundry

# Priority deny-over-allow

# Priority allow-over-deny

# Default policy

# Allowed before deny entry

# Denied before allow entry

# lr.w with R+W

# lr.w with R

# lr.w with W

# Lock enforces M-mode

# Locked CSR read-only

all_tests_pass:
    #li x1, 5  # TODO replace with real test count
    #bne x29, x2, test_fail

    #li x2, 0x25FB  # TODO replace with real magic value
    #bne x28, x2, test_fail

    li x1, 0xAABBCCDD
    sw x1, 0(x30)

    j end_program

test_fail:
    li x1, 0xBADC0DE
    sw x1, 0(x30)
    j end_program

end_program:
    lui x10, 0x50000
    sw s0, 0(x10)

.data
