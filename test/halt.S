.section .text
.global _start

_start:
    # Write pattern to GPIO to confirm execution
    li t0, 0x1
    li t1, 0x40000000
    sw t0, 0(t1)
    
    # Halt
    li t2, 0x50000000
    sw x0, 0(t2)
