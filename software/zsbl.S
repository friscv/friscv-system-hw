.section .text
.global _start

_start:
    lui t0, 0x80000
    jalr x0, 0(t0)
