.section .text
.global _start

_start:
    nop
    nop
    # Hazard 1: Read immediately after write (with NOPs)
    addi t0, x0, 0xFF    # Write t0
    nop
    nop
    xor t1, t0, x0       # Read t0 (no longer a hazard)
    
    # Hazard 2: Chain of dependencies (with NOPs)
    addi t2, t1, 1       # Read t1, write t2
    nop
    nop
    addi t3, t2, 2       # Read t2, write t3
    nop
    nop
    xor t4, t3, t1       # Read t3 and t1
    
    # Hazard 3: Write to same register twice (with NOPs)
    addi t5, x0, 0x10
    nop
    nop
    addi t5, t5, 0x20    # Read t5, write t5
    
    # Combine all results (with NOPs)
    nop
    nop
    xor t6, t4, t5       # Read t4 and t5
    
    # Write result to GPIO (with NOPs before address calculation)
    nop
    nop
    lui t0, 0x40000
    nop
    nop
    sw t6, 0(t0)
    
    # Write result to 0x80000500 (with NOPs between each instruction)
    nop
    nop
    lui t2, 0x80000
    nop
    nop
    addi t3, x0, 0x500
    nop
    nop
    add t4, t2, t3
    nop
    nop
    sw t6, 0(t4)
    
    # Halt (with NOPs)
    nop
    nop
    lui t1, 0x50000
    nop
    nop
    sw x0, 0(t1)
