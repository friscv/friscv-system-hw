.section .text
.global _start

_start:
    li t6, 1
    lui a2, 0x40000
    sw t6, 0(a2)

    # Hazard 1: Read immediately after write
    addi t0, x0, 0xFF    # Write t0
    xor t1, t0, x0       # Read t0 immediately (hazard)
    
    # Hazard 2: Chain of dependencies
    addi t2, t1, 1       # Read t1, write t2
    addi t3, t2, 2       # Read t2, write t3 (hazard)
    xor t4, t3, t1       # Read t3 and t1 (hazard)
    
    # Hazard 3: Write to same register twice in a row
    addi t5, x0, 0x10
    addi t5, t5, 0x20    # Read t5, write t5 (RAW hazard)
    
    # Combine all results
    xor t6, t4, t5       # Read t4 and t5

    lui a2, 0x40000
    sw t6, 0(a2)
    
    # Write result to 0x80000500 (DRAM result location)
    lui t2, 0x80000
    addi t3, x0, 0x500
    add t4, t2, t3
    sw t6, 0(t4)
    
    # Halt (reuse register for address)
    lui t1, 0x50000
    sw x0, 0(t1)
