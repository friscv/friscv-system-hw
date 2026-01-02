.section .text
.global _start

_start:
    # Test arithmetic/logic with result bit 0 = 1
    li t0, 0xFF
    li t1, 0xF1
    xor t2, t0, t1
    
    # Write result to GPIO (t2 = 1, should turn on LED)
    li t3, 0x40000000
    sw t2, 0(t3)
    
    # Halt
    li t4, 0x50000000
    sw x0, 0(t4)
