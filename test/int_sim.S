.option arch, +zicsr
.text
.globl _start

_start:
    j _start2

my_handler:
    addi x10, x10, 1    
    mret                

_start2:
    li x10, 0           
    la x5, my_handler
    nop; nop; nop
    csrw 0x305, x5      
    
    li x6, 8
    nop; nop; nop
    csrw 0x300, x6     
    
loop:
    addi x11, x11, 1    
    j loop
