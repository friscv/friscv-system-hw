/*
(c) FER, HPC Architecture and Application Research Center, All rights reserved

Use under License Agreement ONLY.

IF, PRIOR TO DOWNLOADING, STORING, INSTALLING, ACTIVATING OR USING THE WORK,
(A) YOU DECIDE YOU ARE UNWILLING TO AGREE TO THE TERMS OF THE PROVIDED LICENSE AGREEMENT, or
(B) YOU DID NOT RECEIVE OR OBTAIN THE LICENSE AGREEMENT, YOU HAVE NO RIGHT TO USE THE WORK AND YOU SHOULD PROMPTLY RETURN THE WORK TO FER, DELETE IT, OR DISABLE IT.

https://hpc.fer.hr/en/hpc
licensing.hpc@fer.hr

*/

/*
Version history:

v 0.1.0     Mario Kovac, 2022, Initial design 
v 0.2.0     Matej Grzunov, Duje Strunje, 2022_06, pipeline debug, ALU debug, initial instruction set 
v 0.5.0		Mario Kovac, 2024_05, memory debug & update, system update
v 0.9.0     Petra Kelkovic, Luka Kokic, 2024_06, cpu & system verification, external debug interface, PC & ARM SW, External IO board connections
v 1.0.0     Mario Kovac, 2025_02, some signals renaming, if update, v1.0.0 official
v 2.0.0     Emil Popovic, Franko Ciric, 2026_03, AXI interface, combinatorial control unit, automation scripts, A extension, external timer interrupt

*/

`ifndef FRISCV_PKG_DEF
`define FRISCV_PKG_DEF

package friscv_pkg;

    // --- Configurable parameter definitions start ---

    // Set this to 0 for debugging
    localparam int unsigned ZSBL_ROM_SIZE_BYTES = 1024;

    // Parametrized feature generation
    localparam logic ENABLE_EARLY_JAL_JALR = 1;

    // Memory protection and address translation
    localparam logic ENABLE_MMU = 1;
    // Must be a power of 2 greater than 1
    localparam int   TLB_ENTRIES = 4;

    // Extension selection
    localparam logic ENABLE_EXTENSION_A = 1;
    localparam logic ENABLE_EXTENSION_ZIFENCEI = 1;

    localparam logic ENABLE_REMAP = 1;

    // CLINT address workaround
    // Remaps standard address to free address in AXI - 0x0200_0000 -> 0x4010_0000
    localparam logic ENABLE_REMAP_CLINT = 1;
    // Remaps 0x1000_0000 -> 0x4060_0000
    localparam logic ENABLE_REMAP_UART = 1;

    // --- Configurable parameter definitions end ---

    localparam int unsigned XLEN = 32;

    localparam int unsigned ADDR_WIDTH = XLEN;
    localparam int unsigned DATA_WIDTH = XLEN;

    localparam int unsigned REG_SEL_WIDTH = 5;
    localparam int unsigned REGISTER_NUM  = 32;

    localparam int unsigned NOP = 32'h00000013;  // addi x0,x0,0

    typedef logic [ADDR_WIDTH-1:0]    addr_t;
    typedef logic [DATA_WIDTH-1:0]    data_t;
    typedef logic [31:0]              inst_t;
    typedef logic [REG_SEL_WIDTH-1:0] reg_addr_t;

    localparam addr_t ZSBL_BASE       = 32'h1000;      // RISC-V convention
    localparam addr_t END_ADDRESS     = 32'h50000000;  // FRISC convention
    localparam addr_t DRAM_BASE       = 32'h80000000;  // RISC-V convention
    localparam addr_t DRAM_START_AT   = 32'h00100000;  // Must not be less than 0x00100000, range reserved on Zynq for OCM
    localparam addr_t CLINT_REAL_BASE = 32'h40100000;  // Must match AXI address map
    localparam addr_t CLINT_PHY_BASE  = 32'h02000000;  // RISC-V convention
    localparam addr_t UART_REAL_BASE  = 32'h40600000;
    localparam addr_t UART_PHY_BASE   = 32'h10000000;
    localparam addr_t RESET_VEC       = (ZSBL_ROM_SIZE_BYTES > 0) ? ZSBL_BASE : DRAM_BASE;  // Reset to ZSBL if enabled, else jump to RAM

    typedef enum logic [11:0] {
        CSR_ZERO = 12'h000,

        // Supervisor Trap Setup
        CSR_SSTATUS    = 12'h100,
        CSR_SCOUNTEREN = 12'h106,
        CSR_SIE        = 12'h104,
        CSR_STVEC      = 12'h105,

        // Supervisor Trap Handling
        CSR_SSCRATCH   = 12'h140,
        CSR_SEPC       = 12'h141,
        CSR_SCAUSE     = 12'h142,
        CSR_STVAL      = 12'h143,
        CSR_SIP        = 12'h144,

        // Supervisor Protection and Translation
        CSR_SATP       = 12'h180,

        // Machine Information Registers
        CSR_MVENDORID  = 12'hF11,
        CSR_MARCHID    = 12'hF12,
        CSR_MIMPID     = 12'hF13,
        CSR_MHARTID    = 12'hF14,
        CSR_MCONFIGPTR = 12'hF15,

        // Machine Trap Setup
        CSR_MSTATUS    = 12'h300,
        CSR_MISA       = 12'h301,
        CSR_MEDELEG    = 12'h302,
        CSR_MIDELEG    = 12'h303,
        CSR_MIE        = 12'h304,
        CSR_MTVEC      = 12'h305,
        CSR_MCOUNTEREN = 12'h306,
        CSR_MSTATUSH   = 12'h310,
        CSR_MENVCFG    = 12'h30A,
        CSR_MENVCFGH   = 12'h31A,

        // Machine Trap Handling
        CSR_MSCRATCH = 12'h340,
        CSR_MEPC     = 12'h341,
        CSR_MCAUSE   = 12'h342,
        CSR_MTVAL    = 12'h343,
        CSR_MIP      = 12'h344,

        // Machine Memory Protection
        CSR_PMPCFG0   = 12'h3A0,
        CSR_PMPADDR0  = 12'h3B0,
        CSR_PMPADDR1  = 12'h3B1,
        CSR_PMPADDR2  = 12'h3B2,
        CSR_PMPADDR3  = 12'h3B3,

        // Machine Counter/Timers
        CSR_MCYCLE    = 12'hB00,
        CSR_MINSTRET  = 12'hB02,
        CSR_MCYCLEH   = 12'hB80,
        CSR_MINSTRETH = 12'hB82,

        // Machine Counter Setup
        CSR_MCOUNTINHIBIT = 12'h320,

        // User/Supervisor Counter/Timers
        CSR_CYCLE     = 12'hC00,
        CSR_TIME      = 12'hC01,
        CSR_INSTRET   = 12'hC02,
        CSR_CYCLEH    = 12'hC80,
        CSR_TIMEH     = 12'hC81,
        CSR_INSTRETH  = 12'hC82
    } csr_addr_e;

    typedef enum logic [1:0] {
        U_MODE = 2'b00,
        S_MODE = 2'b01,
        H_MODE = 2'b10,
        M_MODE = 2'b11
    } mode_e;

    typedef struct packed {
        logic        sd;          // [31]    State Dirty (RO, OR of FS/XS/VS)
        logic [7:0]  wpri_30_23;  // [30:23] Reserved (WPRI)
        logic        tsr;         // [22]    Trap SRET (WPRI)
        logic        tw;          // [21]    Timeout Wait (WPRI)
        logic        tvm;         // [20]    Trap Virtual Memory
        logic        mxr;         // [19]    Make eXecutable Readable
        logic        sum;         // [18]    Supervisor User Memory access
        logic        mprv;        // [17]    Modify PRiVilege (WPRI)
        logic [1:0]  xs;          // [16:15] eXtension Status (WPRI)
        logic [1:0]  fs;          // [14:13] Floating-point Status (WPRI)
        mode_e       mpp;         // [12:11] M Previous Privilege
        logic [1:0]  vs;          // [10:9]  Vector Status (WPRI)
        logic        spp;         // [8]     S Previous Privilege
        logic        mpie;        // [7]     M Previous Interrupt Enable
        logic        ube;         // [6]     U Big-Endian (WPRI)
        logic        spie;        // [5]     S Previous Interrupt Enable
        logic        wpri_4;      // [4]     Reserved (WPRI)
        logic        mie;         // [3]     M Interrupt Enable
        logic        wpri_2;      // [2]     Reserved (WPRI)
        logic        sie;         // [1]     S Interrupt Enable
        logic        wpri_0;      // [0]     Reserved (WPRI)
    } mstatus_t;

    localparam int SATP_MODE_W = (XLEN == 32) ? 1  : 4;
    localparam int SATP_ASID_W = (XLEN == 32) ? 9  : 16;
    localparam VPN_WIDTH = (XLEN == 32) ? 20 : 27;
    localparam PPN_WIDTH = (XLEN == 32) ? 20 : 44;

    typedef logic [VPN_WIDTH-1:0] vpn_t;
    typedef logic [PPN_WIDTH-1:0] ppn_t;

    typedef logic [SATP_MODE_W-1:0] satp_mode_t;
    typedef logic [SATP_ASID_W-1:0] asid_t;

    localparam int PTE_LEVEL_W = (XLEN == 32) ? 1 : 3;

    typedef logic [PTE_LEVEL_W-1:0] pte_level_t;

    typedef enum logic [3:0] { 
        SATP_BARE = 4'd0,
        SATP_SV32 = 4'd1,
        SATP_SV39 = 4'd8,
        SATP_SV48 = 4'd9,
        SATP_SV57 = 4'd10
    } satp_mode_e;

    typedef struct packed {
        satp_mode_t mode;
        logic [1:0] reserved;
        asid_t      asid;
        ppn_t       ppn;
    } satp_t;

    typedef struct packed {
        addr_t  addr;
        satp_t  satp;
        mode_e  mode;
        logic   sum;
        logic   mxr;
        logic   is_inst;
        logic   is_write;
    } mmu_req_ctx_t;

    typedef struct packed {
        logic d;  // Dirty
        logic a;  // Accessed
        logic g;  // Global
        logic u;  // User-accessible
        logic x;  // Execute
        logic w;  // Write
        logic r;  // Read
        logic v;  // Valid
    } perm_t;

    typedef enum logic [2:0] {
        I_TYPE  = 3'b000,
        I2_TYPE = 3'b001,
        S_TYPE  = 3'b010,
        B_TYPE  = 3'b011,
        U_TYPE  = 3'b100,
        J_TYPE  = 3'b101,
        ZERO    = 3'b110,  // Always produces 32'h0
        NEXT_PC = 3'b111   // Used to jump to incremented PC to refetch on FENCE.I
    } imm_e;

    // Load/Store instruction funct3
    typedef enum logic [2:0] {
        WIDTH_I8  = 3'b000,
        WIDTH_U8  = 3'b100,
        WIDTH_I16 = 3'b001,
        WIDTH_U16 = 3'b101,
        WIDTH_I32 = 3'b010
    } mem_width_e;

    // Instruction types
    typedef enum logic [6:0] {
        LOAD     = 7'b0000011,
        LOAD_FP  = 7'b0000111,
        CUSTOM_0 = 7'b0001011,
        MISC_MEM = 7'b0001111,
        OP_IMM   = 7'b0010011,
        AUIPC    = 7'b0010111,
        STORE    = 7'b0100011,
        STORE_FP = 7'b0100111,
        CUSTOM_1 = 7'b0101011,
        AMO      = 7'b0101111,
        OP       = 7'b0110011,
        LUI      = 7'b0110111,
        MADD     = 7'b1000011,
        MSUB     = 7'b1000111,
        NMSUB    = 7'b1001011,
        NMADD    = 7'b1001111,
        OP_FP    = 7'b1010011,
        OP_V     = 7'b1010111,
        BRANCH   = 7'b1100011,
        JALR     = 7'b1100111,
        JAL      = 7'b1101111,
        SYSTEM   = 7'b1110011,
        OP_VE    = 7'b1110111
    } opcode_e;

    typedef struct packed {
        logic [6:0] funct7;
        reg_addr_t  rs2;
        reg_addr_t  rs1;
        mem_width_e funct3;
        reg_addr_t  rd;
        opcode_e    opcode;
    } r_type_t;

    typedef union packed {
        inst_t   b;
        r_type_t r;
    } instr_op_t;

    typedef enum logic [1:0] {
        BRANCH_JAL_NONE = 2'b00,
        BRANCH_INSTR    = 2'b01,
        JAL_INSTR       = 2'b10
    } jump_sel_e;

    typedef enum logic [2:0] {
        COND_EQ     = 3'b000,
        COND_NE     = 3'b001,
        COND_ALWAYS = 3'b010,
        COND_LT     = 3'b100,
        COND_GE     = 3'b101,
        COND_LTU    = 3'b110,
        COND_GEU    = 3'b111
    } branch_cond_e;

    typedef enum logic [1:0] {
        RS1     = 2'b00,
        ZERO_A  = 2'b01,
        PC      = 2'b10,
        RS1_SEL = 2'b11
    } a_bus_sel_e;

    typedef enum logic [1:0] {
        RS2 = 2'b00,
        IMM = 2'b01,
        CSR = 2'b10
    } b_bus_sel_e;

    typedef enum logic [3:0] {
        ADD_OP  = 4'b0000,
        SUB_OP  = 4'b1000,
        AND_OP  = 4'b0111,
        OR_OP   = 4'b0110,
        XOR_OP  = 4'b0100,
        SLL_OP  = 4'b0001,
        SRL_OP  = 4'b0101,
        SRA_OP  = 4'b1101,
        SLT_OP  = 4'b0010,
        SLTU_OP = 4'b0011
    } alu_op_e;

    typedef enum logic [3:0] {
        AMO_NONE = 4'b0000,
        AMO_SWAP = 4'b0001,
        AMO_ADD  = 4'b0010,
        AMO_XOR  = 4'b0011,
        AMO_AND  = 4'b0100,
        AMO_OR   = 4'b0101,
        AMO_MIN  = 4'b0110,
        AMO_MAX  = 4'b0111,
        AMO_MINU = 4'b1000,
        AMO_MAXU = 4'b1001
    } amo_op_e;

    typedef enum logic [1:0] {
        MEM_INSTR_NONE  = 2'b00,
        MEM_INSTR_LOAD  = 2'b01,
        MEM_INSTR_STORE = 2'b10
    } mem_instr_sel_e;

    typedef enum logic [2:0] {
        WB_DATA_SEL_PC_PLUS_4 = 3'b000,
        WB_DATA_SEL_ALU       = 3'b001,
        WB_DATA_SEL_MEM       = 3'b010,
        WB_DATA_SEL_SC_RES    = 3'b011,
        WB_DATA_SEL_CSR       = 3'b100
    } wb_data_sel_e;

    typedef struct packed {
        logic           instr_valid;
        jump_sel_e      branch_jal_sel;
        branch_cond_e   branch_cond;
        a_bus_sel_e     a_bus_sel;
        b_bus_sel_e     b_bus_sel;
        alu_op_e        alu_op;
        logic           invert_op_a;
        mem_instr_sel_e mem_instr_sel;
        mem_width_e     load_store_width;
        wb_data_sel_e   wb_data_sel;
        logic           reserve;
        logic           conditional;
        amo_op_e        amo_op;
        logic           csr_op;
        logic           mret_en;
        logic           sret_en;
        csr_addr_e      csr_addr;
        logic           sfence_vma;
    } instr_ex_t;

    localparam instr_ex_t NOP_CTRL = '{
        instr_valid: 1'b0,
        branch_jal_sel: BRANCH_JAL_NONE,
        branch_cond: COND_NE,
        a_bus_sel: RS1,
        b_bus_sel: RS2,
        alu_op: ADD_OP,
        invert_op_a: 1'b0,
        mem_instr_sel: MEM_INSTR_NONE,
        load_store_width: WIDTH_I32,
        wb_data_sel: WB_DATA_SEL_ALU,
        reserve: 1'b0,
        conditional: 1'b0,
        amo_op: AMO_NONE,
        csr_op: 1'b0,
        mret_en: 1'b0,   
        sret_en: 1'b0,
        csr_addr: CSR_ZERO,
        sfence_vma: 1'b0
    };

    typedef enum logic [1:0] {
        RW_IDLE  = 2'b00,
        RW_WRITE = 2'b01,
        RW_READ  = 2'b10
    } rw_cmd_e;

endpackage

import friscv_pkg::*;
`endif
