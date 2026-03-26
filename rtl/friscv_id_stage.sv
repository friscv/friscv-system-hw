/*
(c) FER, HPC Architecture and Application Research Center, All rights reserved

Use under License Agreement ONLY.

IF, PRIOR TO DOWNLOADING, STORING, INSTALLING, ACTIVATING OR USING THE WORK, 
(A) YOU DECIDE YOU ARE UNWILLING TO AGREE TO THE TERMS OF THE PROVIDED LICENSE AGREEMENT, or 
(B) YOU DID NOT RECEIVE OR OBTAIN THE LICENSE AGREEMENT, YOU HAVE NO RIGHT TO USE THE WORK AND YOU SHOULD PROMPTLY RETURN THE WORK TO FER, DELETE IT, OR DISABLE IT.

https://hpc.fer.hr/en/hpc
licensing.hpc@fer.hr

Version info is listed in friscv_pkg.sv
*/

`include "friscv_pkg.sv"

module friscv_id_stage #(
    parameter int HART_ID = 0
) (
    input  logic      clk_in,
    input  logic      rst_n_in,
    
    input  logic      branch_ok_in,

    // Interrupt pending inputs
    input  logic      msip_in,
    input  logic      mtip_in,
    input  logic      meip_in,

    // Page fault signals
    input  logic      inst_fault_in,
    input  logic      load_fault_in,
    input  logic      store_fault_in,
    input  addr_t     fault_addr_in,

    // Stage control signals
    input  logic      flush_in,
    input  logic      stage_stall_in,

    // Outputs to control logic
    output reg_addr_t rs1_sel_out,
    output reg_addr_t rs2_sel_out,
    output reg_addr_t rd_sel_out,

    output logic      jal_ok_out,
    output addr_t     jal_target_out,

    output logic      illegal_inst,

    // Inputs from IF stage
    input  addr_t     pc_in,
    input  addr_t     pc_plus_4_in,
    input  inst_t     ir_in,

    // Outputs to EX stage
    output addr_t     pc_out,
    output addr_t     pc_plus_4_out,
    output data_t     rs1_out,
    output data_t     rs2_out,
    output data_t     imm32_out,
    output data_t     csr_out,
    output instr_ex_t instr_ex_out,

    // Inputs from WB stage    
    input  reg_addr_t rd_sel_in,
    input  data_t     rd_data_in,
    input  csr_addr_e csr_sel_in,
    input  data_t     csr_data_in,
    input  logic      csr_en_in,
    input  logic      instr_ret_in,

    // CSR write-in-flight visibility
    input  logic      ex_csr_en_in,
    input  logic      mem_csr_en_in,
    input  logic      wb_csr_en_in,

    // Outputs and inputs for handling interrupts
    output addr_t     tvec_out,          // Resolved mtvec or stvec
    output addr_t     epc_out,           // Resolved mepc or sepc
    output logic      trap_out,
    output logic      trap_pending_out,
    output logic      ret_out,           // Active for both mret and sret

    // Outputs to MMU
    output satp_t     satp_out,
    output logic      sum_out,
    output logic      mxr_out,
    output mode_e     mode_out
);

data_t regfile [REGISTER_NUM];

// Initialize regfile to prevent X in simulation
genvar g;
generate
    for (g = 0; g < REGISTER_NUM; g++) begin : init_regfile
        initial regfile[g] = '0;
    end
endgenerate

instr_op_t ir_buff;
addr_t     pc_in_buff;
addr_t     pc_plus_4_buff;
imm_e      imm_sel;

assign rs1_out = regfile[rs1_sel_out];
assign rs2_out = regfile[rs2_sel_out];

assign pc_out = pc_in_buff;
assign pc_plus_4_out = pc_plus_4_buff;

// ============================================================
// Input capture
// ============================================================

always_ff @(posedge clk_in) begin
    if (!rst_n_in) begin
        // Do not reset regfile to synthesize as distributed RAM
        ir_buff        <= NOP;
        pc_in_buff     <= 32'h0;
        pc_plus_4_buff <= 32'h0;
    end else begin
        if (rd_sel_in != 0)
            regfile[rd_sel_in] <= rd_data_in;

        if (flush_in) begin
            ir_buff        <= NOP;
            pc_in_buff     <= 32'h0;
            pc_plus_4_buff <= 32'h0;
        end else if (!stage_stall_in) begin
            ir_buff <= ir_in;
            pc_in_buff <= pc_in;
            pc_plus_4_buff <= pc_plus_4_in;
        end
    end
end

// ============================================================
// Control and Status Registers
// ============================================================

mode_e r_current_mode = M_MODE;

// CSR file definition
typedef struct packed {

    // Supervisor Interrupt Pending
    logic ssip;
    logic stip;
    logic seip;

    // Supervisor Trap Setup
    addr_t stvec;

    // Supervisor Trap Handling
    data_t sscratch;
    addr_t sepc;
    data_t scause;
    inst_t stval;

    // Supervisor Protection and Translation
    satp_t satp;

    // Machine Information Registers
    // Hardwired in read block

    // Machine Trap Setup
    mstatus_t mstatus;
    data_t medeleg;
    data_t mideleg;
    data_t mie;
    addr_t mtvec;
    data_t mcounteren;

    // Machine Trap Handling
    data_t mscratch;
    addr_t mepc;
    data_t mcause;
    inst_t mtval;

    // Machine Memory Protection
    data_t pmpcfg0;
    addr_t pmpaddr0;
    addr_t pmpaddr1;
    addr_t pmpaddr2;
    addr_t pmpaddr3;

    // Machine Counter/Timers
    logic [63:0] mcycle;
    logic [63:0] minstret;

    // Machine Counter Setup
    data_t mcountinhibit;
} csr_file_t;

// Initialize CSRs to 0
csr_file_t csr = '0;

csr_addr_e selected_csr;  // Extract selected CSR from ir_buff
assign selected_csr = csr_addr_e'(ir_buff.b[31:20]);

// Read-only status of CSR being WRITTEN BACK
logic wb_csr_ro;
assign wb_csr_ro = csr_sel_in[11:10] == 2'b11;

// Read-only status and minimum mode of CSR being DECODED
logic decode_csr_ro;
assign decode_csr_ro = selected_csr[11:10] == 2'b11;

mode_e decode_csr_mode;
assign decode_csr_mode = mode_e'(selected_csr[9:8]);

// Determine if the instruction being decoded will write to a CSR
// CSR write will have no effect if either the destination is x0 or uimm is 5'b0
logic is_csr_write;

always_comb begin
    case (ir_buff.r.funct3)
        3'b001, 3'b101: is_csr_write = (ir_buff.r.opcode == SYSTEM);  // CSRRW/I always write
        default:        is_csr_write = (ir_buff.r.opcode == SYSTEM) && (ir_buff.r.rs1 != 5'b0);
    endcase
end

// ============================================================
// Trap logic
// ============================================================

logic [1:0] r_mret_inhibit;

// Check if interrupt is safe to execute - safe if
//  1) Not returning from a previous interrupt,
//  2) Not executing a branch and
//  3) Not in the middle of a fetch
logic interrupt_safe, exception_safe;
assign interrupt_safe = (r_mret_inhibit == 2'b00) && !branch_ok_in && (|pc_in_buff);
assign exception_safe = !branch_ok_in && (|pc_in_buff);

logic m_interrupt_active, s_interrupt_active;

assign m_interrupt_active = interrupt_safe &&
                            (csr.mstatus.mie || r_current_mode != M_MODE) &&
                            (msip_in && csr.mie[3] ||
                             mtip_in && csr.mie[7] ||
                             meip_in && csr.mie[11]);

assign s_interrupt_active = interrupt_safe &&
                            (csr.mstatus.sie || r_current_mode == U_MODE) &&
                            ((csr.ssip && csr.mie[1] && csr.mideleg[1]) ||
                             (csr.stip && csr.mie[5] && csr.mideleg[5]) ||
                             (csr.seip && csr.mie[9] && csr.mideleg[9]));

logic interrupt_active, exception_active;
assign interrupt_active = m_interrupt_active || s_interrupt_active;

logic ecall_active, ebreak_active;
assign exception_active = exception_safe && (ecall_active || ebreak_active || illegal_inst);

// Trap RAW hazard - a CSR write in EX or MEM might update mtvec/mstatus/mepc before the
// trap fires. Suppress the effective trap (flush + CSR state write) until the pipeline
// is clear. trap_pending_out lets pipeline_control stall so the instruction is not lost
// from ir_buff while waiting.
logic trap_raw, trap_csr_hazard;
assign trap_raw         = interrupt_active || exception_active;
assign trap_csr_hazard  = trap_raw && (ex_csr_en_in || mem_csr_en_in || wb_csr_en_in);
assign trap_out         = trap_raw && !trap_csr_hazard;
assign trap_pending_out = trap_raw;

logic mret_active, sret_active;
assign mret_active = (ir_buff.r.opcode == SYSTEM) && (ir_buff.r.funct3 == 3'b000) && (ir_buff.b[31:20] == 12'b001100000010);
assign sret_active = (ir_buff.r.opcode == SYSTEM) && (ir_buff.r.funct3 == 3'b000) && (ir_buff.b[31:20] == 12'b000100000010);

assign ret_out = mret_active || sret_active;

// Compute exception cause code based on current mode (for ecall)
logic [4:0] exception_cause_code;
always_comb begin
    if (ecall_active)
        case (r_current_mode)
            U_MODE:  exception_cause_code = 5'd8;
            S_MODE:  exception_cause_code = 5'd9;
            default: exception_cause_code = 5'd11;  // M_MODE
        endcase
    else if (ebreak_active) exception_cause_code = 5'd3;
    else if (illegal_inst)  exception_cause_code = 5'd2;
    else                    exception_cause_code = 5'd0;
end

// A trap is delegated to S-mode when:
//   - Not already in M-mode (traps never transition to less-privileged mode)
//   - No M-mode interrupt is active (M-mode interrupts take priority over S-mode)
//   - s_interrupt_active (already checks mideleg bits), or
//   - exception cause bit is set in medeleg
logic is_delegated;
assign is_delegated = (r_current_mode != M_MODE) &&
                      !m_interrupt_active &&
                      (s_interrupt_active || (exception_active && csr.medeleg[exception_cause_code]));

logic trap_to_s_mode;
assign trap_to_s_mode = trap_out && is_delegated;

// Interrupt cause code for vectored tvec offset
logic [31:0] current_cause;
always_comb begin
    if (meip_in && csr.mie[11])
        current_cause = 32'd11;
    else if (mtip_in && csr.mie[7])
        current_cause = 32'd7;
    else if (msip_in && csr.mie[3])
        current_cause = 32'd3;
    else if (csr.seip && csr.mie[9] && csr.mideleg[9])
        current_cause = 32'd9;
    else if (csr.stip && csr.mie[5] && csr.mideleg[5])
        current_cause = 32'd5;
    else if (csr.ssip && csr.mie[1] && csr.mideleg[1])
        current_cause = 32'd1;
    else
        current_cause = 32'd0;
end

// Return address used by mret/sret
assign epc_out = sret_active ? csr.sepc : csr.mepc;

// Trap vector, resolved to correct mode mode with vectored mode
assign tvec_out = trap_to_s_mode
                  ? ((csr.stvec[1:0] == 2'b01 && interrupt_active)
                     ? {csr.stvec[31:2], 2'b0} + {current_cause[29:0], 2'b0}
                     : {csr.stvec[31:2], 2'b0})
                  : ((csr.mtvec[1:0] == 2'b01 && interrupt_active)
                     ? {csr.mtvec[31:2], 2'b0} + {current_cause[29:0], 2'b0}
                     : {csr.mtvec[31:2], 2'b0});

// ============================================================
// CSR write
// ============================================================

always_ff @(posedge clk_in) begin
    if(!rst_n_in) begin
        csr <= '0;
        r_mret_inhibit <= 2'b00;
        r_current_mode <= M_MODE;
    end else begin
        // Only advance countdown when pipeline is not stalled
        if ((mret_active || sret_active) && !ex_csr_en_in && !mem_csr_en_in && !wb_csr_en_in)
            r_mret_inhibit <= 2'd2;
        else if (r_mret_inhibit != 2'b00 && !stage_stall_in)
            r_mret_inhibit <= r_mret_inhibit - 1;

        if (trap_out) begin
            if (trap_to_s_mode) begin
                // Delegated trap: enter S-mode
                r_current_mode <= S_MODE;
                csr.sepc            <= pc_in_buff;
                csr.mstatus.spie    <= csr.mstatus.sie;
                csr.mstatus.sie     <= 1'b0;
                csr.mstatus.spp     <= (r_current_mode == S_MODE) ? 1'b1 : 1'b0;
                csr.stval           <= illegal_inst ? ir_buff.b : 32'h0;

                if      (csr.seip && csr.mie[9] && csr.mideleg[9]) csr.scause <= {1'b1, 31'd9};
                else if (csr.stip && csr.mie[5] && csr.mideleg[5]) csr.scause <= {1'b1, 31'd5};
                else if (csr.ssip && csr.mie[1] && csr.mideleg[1]) csr.scause <= {1'b1, 31'd1};
                else if (ecall_active) begin
                    case (r_current_mode)
                        U_MODE:  csr.scause <= 32'd8;
                        S_MODE:  csr.scause <= 32'd9;
                        default: csr.scause <= 32'd11;
                    endcase
                end
                else if (ebreak_active) csr.scause <= 32'd3;
                else if (illegal_inst)  csr.scause <= 32'd2;

            end else begin
                // Non-delegated trap: enter M-mode
                r_current_mode <= M_MODE;
                csr.mepc            <= pc_in_buff;
                csr.mstatus.mpie    <= csr.mstatus.mie;
                csr.mstatus.mie     <= 1'b0;
                csr.mstatus.mpp     <= r_current_mode;
                csr.mtval           <= illegal_inst ? ir_buff.b : 32'h0;

                if      (meip_in && csr.mie[11]) csr.mcause <= {1'b1, 31'd11};
                else if (mtip_in && csr.mie[7])  csr.mcause <= {1'b1, 31'd7};
                else if (msip_in && csr.mie[3])  csr.mcause <= {1'b1, 31'd3};
                else if (ecall_active) begin
                    case (r_current_mode)
                        U_MODE:  csr.mcause <= 32'd8;
                        S_MODE:  csr.mcause <= 32'd9;
                        default: csr.mcause <= 32'd11;
                    endcase
                end
                else if (ebreak_active) csr.mcause <= 32'd3;
                else if (illegal_inst)  csr.mcause <= 32'd2;
            end

        end else if (sret_active && !ex_csr_en_in && !mem_csr_en_in && !wb_csr_en_in) begin
            csr.mstatus.sie     <= csr.mstatus.spie;
            csr.mstatus.spie    <= 1'b1;
            r_current_mode <= csr.mstatus.spp ? S_MODE : U_MODE;
            csr.mstatus.spp     <= 1'b0;

        end else if (mret_active && !ex_csr_en_in && !mem_csr_en_in && !wb_csr_en_in) begin
            csr.mstatus.mie     <= csr.mstatus.mpie;
            csr.mstatus.mpie    <= 1'b1;
            r_current_mode <= csr.mstatus.mpp;
            csr.mstatus.mpp     <= U_MODE;

        end else if (csr_en_in && instr_ret_in && !wb_csr_ro) begin
            case (csr_sel_in)
                // Supervisor Trap Setup (aliased into mstatus/mie)
                CSR_SSTATUS: begin
                    csr.mstatus.sie  <= csr_data_in[1];
                    csr.mstatus.spie <= csr_data_in[5];
                    csr.mstatus.spp  <= csr_data_in[8];
                    csr.mstatus.sum  <= csr_data_in[18];
                    csr.mstatus.mxr  <= csr_data_in[19];
                end
                CSR_SIE: begin  // S-mode visible bits of mie only
                    csr.mie[1] <= csr_data_in[1];
                    csr.mie[5] <= csr_data_in[5];
                    csr.mie[9] <= csr_data_in[9];
                end
                CSR_STVEC:    csr.stvec    <= csr_data_in;
                CSR_SSCRATCH: csr.sscratch <= csr_data_in;
                CSR_SEPC:     csr.sepc     <= csr_data_in;
                CSR_SCAUSE:   csr.scause   <= csr_data_in;
                CSR_STVAL:    csr.stval    <= csr_data_in;
                CSR_SIP: begin  // SSIP writable by S-mode; STIP/SEIP only by M-mode
                    csr.ssip <= csr_data_in[1];
                    if (r_current_mode == M_MODE) begin
                        csr.stip <= csr_data_in[5];
                        csr.seip <= csr_data_in[9];
                    end
                end

                // Supervisor Protection and Translation
                CSR_SATP: csr.satp <= csr_data_in;

                // Machine Trap Setup
                CSR_MSTATUS: begin
                    csr.mstatus.sie  <= csr_data_in[1];
                    csr.mstatus.mie  <= csr_data_in[3];
                    csr.mstatus.spie <= csr_data_in[5];
                    csr.mstatus.mpie <= csr_data_in[7];
                    csr.mstatus.spp  <= csr_data_in[8];
                    csr.mstatus.mpp  <= mode_e'(csr_data_in[12:11]);
                    csr.mstatus.sum  <= csr_data_in[18];
                    csr.mstatus.mxr  <= csr_data_in[19];
                    csr.mstatus.tvm  <= csr_data_in[20];
                end
                CSR_MEDELEG:    csr.medeleg    <= csr_data_in;
                CSR_MIDELEG:    csr.mideleg    <= csr_data_in & 32'h0000_0222;  // Bits 1,5,9 only
                CSR_MIE:        csr.mie        <= csr_data_in;
                CSR_MTVEC:      csr.mtvec      <= csr_data_in;
                CSR_MCOUNTEREN: csr.mcounteren <= csr_data_in;
                CSR_MIP: begin  // S-mode soft interrupt bits writable through mip
                    csr.ssip <= csr_data_in[1];
                    csr.stip <= csr_data_in[5];
                    csr.seip <= csr_data_in[9];
                end

                // Machine Trap Handling
                CSR_MSCRATCH: csr.mscratch <= csr_data_in;
                CSR_MEPC:     csr.mepc     <= csr_data_in;
                CSR_MCAUSE:   csr.mcause   <= csr_data_in;

                // Machine Memory Protection
                CSR_PMPCFG0:  csr.pmpcfg0  <= csr_data_in;
                CSR_PMPADDR0: csr.pmpaddr0 <= csr_data_in;
                CSR_PMPADDR1: csr.pmpaddr1 <= csr_data_in;
                CSR_PMPADDR2: csr.pmpaddr2 <= csr_data_in;
                CSR_PMPADDR3: csr.pmpaddr3 <= csr_data_in;

                // Machine Counter Setup
                CSR_MCOUNTINHIBIT: csr.mcountinhibit <= csr_data_in;
                default: ;
            endcase
        end

        // Cycle counter
        if (!csr.mcountinhibit[0])
            csr.mcycle <= csr.mcycle + 1;

        // Instruction retire counter
        if (instr_ret_in && !csr.mcountinhibit[2])
            csr.minstret <= csr.minstret + 1;
    end
end

// ============================================================
// CSR read
// ============================================================

// Decode selected CSR address
// Determine whether the selected CSR is implemented
logic csr_not_implemented;

always_comb begin
    csr_not_implemented = 1'b0;
    case (selected_csr)
        // Machine Information Registers
        CSR_MVENDORID:     csr_out = 32'h0;
        CSR_MARCHID:       csr_out = 32'h0;
        CSR_MIMPID:        csr_out = 32'h0;
        CSR_MHARTID:       csr_out = 32'(HART_ID);
        CSR_MCONFIGPTR:    csr_out = 32'h0;

        // Machine Trap Setup
        CSR_MSTATUS:       csr_out = csr.mstatus;
        //                                mx----zyxwvutsrqponmlkjihgfedcb a
        CSR_MISA:          csr_out = {31'b0100000000000100000000010000000,{ENABLE_EXTENSION_A}};
        CSR_MEDELEG:       csr_out = csr.medeleg;
        CSR_MIDELEG:       csr_out = csr.mideleg;
        CSR_MIE:           csr_out = csr.mie;
        CSR_MTVEC:         csr_out = csr.mtvec;
        CSR_MCOUNTEREN:    csr_out = csr.mcounteren;
        CSR_MSTATUSH:      csr_out = 32'h0;

        // Machine Trap Handling
        CSR_MSCRATCH:      csr_out = csr.mscratch;
        CSR_MEPC:          csr_out = csr.mepc;
        CSR_MCAUSE:        csr_out = csr.mcause;
        CSR_MTVAL:         csr_out = csr.mtval;
        CSR_MIP:           csr_out = {20'b0, meip_in, 1'b0, csr.seip, 1'b0, mtip_in, 1'b0, csr.stip, 1'b0, msip_in, 1'b0, csr.ssip, 1'b0};

        // Machine Memory Protection
        CSR_PMPCFG0:       csr_out = csr.pmpcfg0;
        CSR_PMPADDR0:      csr_out = csr.pmpaddr0;
        CSR_PMPADDR1:      csr_out = csr.pmpaddr1;
        CSR_PMPADDR2:      csr_out = csr.pmpaddr2;
        CSR_PMPADDR3:      csr_out = csr.pmpaddr3;

        // Machine Counter/Timers
        CSR_MCYCLE:        csr_out = csr.mcycle[31:0];
        CSR_MINSTRET:      csr_out = csr.minstret[31:0];
        CSR_MCYCLEH:       csr_out = csr.mcycle[63:32];
        CSR_MINSTRETH:     csr_out = csr.minstret[63:32];

        // Machine Counter Setup
        CSR_MCOUNTINHIBIT: csr_out = csr.mcountinhibit;

        // Supervisor Trap Setup
        // sstatus is mstatus with M-mode-only bits (MIE[3], MPIE[7], MPP[12:11], MPRV[17]) zeroed
        CSR_SSTATUS:       csr_out = data_t'(csr.mstatus) & ~32'h0002_1888;
        CSR_SIE:           csr_out = csr.mie & 32'h0000_0222;  // S-mode bits: SEIE[9], STIE[5], SSIE[1]
        CSR_STVEC:         csr_out = csr.stvec;
        CSR_SSCRATCH:      csr_out = csr.sscratch;
        CSR_SEPC:          csr_out = csr.sepc;
        CSR_SCAUSE:        csr_out = csr.scause;
        CSR_STVAL:         csr_out = csr.stval;
        // S-mode visible interrupt pending bits only
        CSR_SIP:           csr_out = {22'b0, csr.seip, 3'b0, csr.stip, 3'b0, csr.ssip, 1'b0};

        // Supervisor Protection and Translation
        CSR_SATP:          csr_out = csr.satp;

        default: begin
            csr_out             = 32'h0;
            csr_not_implemented = 1'b1;
        end
    endcase
end

// ============================================================
// Immediate generation
// ============================================================

always_comb begin
    case (imm_sel)
        I_TYPE:  imm32_out = {{21{ir_buff.b[31]}}, ir_buff.b[30:20]};
        I2_TYPE: imm32_out = {27'h0, ir_buff.b[24:20]};
        S_TYPE:  imm32_out = {{21{ir_buff.b[31]}}, ir_buff.b[30:25], ir_buff.b[11:7]};
        B_TYPE:  imm32_out = {{20{ir_buff.b[31]}}, ir_buff.b[7], ir_buff.b[30:25], ir_buff.b[11:8], 1'b0};
        U_TYPE:  imm32_out = {ir_buff.b[31], ir_buff.b[30:12], 12'b0};
        J_TYPE:  imm32_out = {{12{ir_buff.b[31]}}, ir_buff.b[19:12], ir_buff.b[20], ir_buff.b[30:21], 1'b0};
        ZERO:    imm32_out = 32'h0;
        NEXT_PC: imm32_out = pc_plus_4_buff;
    endcase
end

// ============================================================
// Early JAL/JALR
// ============================================================

always_comb begin
    if (ENABLE_EARLY_JAL_JALR && !trap_out) begin
        addr_t jal_target_base;
        data_t jal_imm;
        jal_target_base = 32'h0;
        jal_imm = 32'h0;

        case (ir_buff.r.opcode)
            JALR: begin
                jal_ok_out = 1'b1;
                jal_target_base = (rd_sel_in != 0 && ir_buff.r.rs1 == rd_sel_in) ? rd_data_in : regfile[ir_buff.r.rs1];
                jal_imm = {{21{ir_buff.b[31]}}, ir_buff.b[30:20]};  // I-type immediate
                jal_target_out = (jal_target_base + jal_imm) & ~32'h1;
            end
            JAL: begin
                jal_ok_out = 1'b1;
                jal_imm = {{12{ir_buff.b[31]}}, ir_buff.b[19:12], ir_buff.b[20], ir_buff.b[30:21], 1'b0};  // J-type immediate
                jal_target_out = pc_in_buff + jal_imm;
            end
            default: begin
                jal_ok_out = 1'b0;
                jal_target_out = 32'h0;
            end
        endcase
    end else begin
        jal_ok_out = 1'b0;
        jal_target_out = 32'h0;
    end
end

// ============================================================
// Instruction decoding
// ============================================================

always_comb begin
    // Set signals to have no side effect by default
    instr_ex_out = NOP_CTRL;
    instr_ex_out.instr_valid = 1'b1;
    instr_ex_out.csr_addr = selected_csr;

    rs1_sel_out = 5'b0;
    rs2_sel_out = 5'b0;
    rd_sel_out  = 5'b0;

    imm_sel = I_TYPE;

    illegal_inst = 1'b0;
    ecall_active = 1'b0;
    ebreak_active = 1'b0;

    case (ir_buff.r.opcode)
        LOAD: begin
            instr_ex_out.a_bus_sel = RS1;
            instr_ex_out.b_bus_sel = IMM;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_LOAD;
            instr_ex_out.load_store_width = ir_buff.r.funct3;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_MEM;

            if (ir_buff.r.funct3 == 3'b011 || ir_buff.r.funct3 == 3'b110 || ir_buff.r.funct3 == 3'b111)
                illegal_inst = 1'b1;

            imm_sel = I_TYPE;
            rs1_sel_out = ir_buff.r.rs1;
            rd_sel_out  = ir_buff.r.rd;
        end

        MISC_MEM: begin
            case (ir_buff.r.funct3)
                3'b000: begin  // FENCE
                end
                3'b001: begin  // FENCE.I
                    // BEQ x0, x0, <PC+4> to flush potentially modified fetched instruction
                    if (ENABLE_EXTENSION_ZIFENCEI) begin
                        instr_ex_out.branch_jal_sel = BRANCH_INSTR;
                        instr_ex_out.branch_cond = COND_EQ;
                        instr_ex_out.a_bus_sel = RS1;    // Branch address = x0 + next_pc
                        instr_ex_out.b_bus_sel = IMM;
                        imm_sel = NEXT_PC;
                        instr_ex_out.alu_op = ADD_OP;
                        instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
                    end else begin
                        illegal_inst = 1'b1;
                    end
                end
                default: illegal_inst = 1'b1;
            endcase
        end

        STORE: begin
            instr_ex_out.a_bus_sel = RS1;
            instr_ex_out.b_bus_sel = IMM;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_STORE;
            instr_ex_out.load_store_width = ir_buff.r.funct3;

            if (ir_buff.r.funct3 == 3'b011 || ir_buff.r.funct3 >= 3'b100) illegal_inst = 1'b1;

            imm_sel = S_TYPE;
            rs1_sel_out = ir_buff.r.rs1;
            rs2_sel_out = ir_buff.r.rs2;
        end

        AMO: begin
            if (ENABLE_EXTENSION_A) begin
                case (ir_buff.r.funct3)
                    3'b010: begin  // RV32A Standard Extension instructions
                        instr_ex_out.wb_data_sel = WB_DATA_SEL_MEM;
                        instr_ex_out.mem_instr_sel = MEM_INSTR_LOAD;
                        instr_ex_out.load_store_width = WIDTH_I32;
                        instr_ex_out.alu_op = ADD_OP;
                        instr_ex_out.a_bus_sel = RS1;
                        instr_ex_out.b_bus_sel = IMM;
                        imm_sel = ZERO;  // AMO has no offset, address = rs1 + 0
                        rd_sel_out  = ir_buff.r.rd;
                        rs2_sel_out = ir_buff.r.rs2;
                        rs1_sel_out = ir_buff.r.rs1;

                        case (ir_buff.r.funct7[6:2])
                            5'b00011: begin  // SC.W
                                instr_ex_out.mem_instr_sel = MEM_INSTR_STORE;
                                instr_ex_out.conditional = 1'b1;
                                instr_ex_out.wb_data_sel = WB_DATA_SEL_SC_RES;
                            end
                            5'b00010: begin  // LR.W
                                instr_ex_out.reserve = 1'b1;
                                if (ir_buff.r.rs2 != 5'b0) illegal_inst = 1'b1;
                            end
                            5'b00001: instr_ex_out.amo_op = AMO_SWAP;  // AMOSWAP.W
                            5'b00000: instr_ex_out.amo_op = AMO_ADD;   // AMOADD.W
                            5'b00100: instr_ex_out.amo_op = AMO_XOR;   // AMOXOR.W
                            5'b01100: instr_ex_out.amo_op = AMO_AND;   // AMOAND.W
                            5'b01000: instr_ex_out.amo_op = AMO_OR;    // AMOOR.W
                            5'b10000: instr_ex_out.amo_op = AMO_MIN;   // AMOMIN.W
                            5'b10100: instr_ex_out.amo_op = AMO_MAX;   // AMOMAX.W
                            5'b11000: instr_ex_out.amo_op = AMO_MINU;  // AMOMINU.W
                            5'b11100: instr_ex_out.amo_op = AMO_MAXU;  // AMOMAXU.W
                            default:  illegal_inst = 1'b1;
                        endcase
                    end
                    default: illegal_inst = 1'b1;
                endcase
            end else begin
                illegal_inst = 1'b1;
            end
        end

        OP: begin
            instr_ex_out.a_bus_sel = RS1;
            instr_ex_out.b_bus_sel = RS2;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_ALU;

            imm_sel = I_TYPE;
            rs1_sel_out = ir_buff.r.rs1;
            rs2_sel_out = ir_buff.r.rs2;
            rd_sel_out  = ir_buff.r.rd;

            case (ir_buff.r.funct3)
                3'b000: begin
                    case (ir_buff.r.funct7)
                        7'b0000000: instr_ex_out.alu_op = ADD_OP;
                        7'b0100000: instr_ex_out.alu_op = SUB_OP;
                        default:    illegal_inst = 1'b1;
                    endcase
                end
                3'b001: instr_ex_out.alu_op = SLL_OP;
                3'b010: instr_ex_out.alu_op = SLT_OP;
                3'b011: instr_ex_out.alu_op = SLTU_OP;
                3'b100: instr_ex_out.alu_op = XOR_OP;
                3'b101: begin
                    case (ir_buff.r.funct7)
                        7'b0000000: instr_ex_out.alu_op = SRL_OP;
                        7'b0100000: instr_ex_out.alu_op = SRA_OP;
                        default:    illegal_inst = 1'b1;
                    endcase
                end
                3'b110: instr_ex_out.alu_op = OR_OP;
                3'b111: instr_ex_out.alu_op = AND_OP;
            endcase

            // Check if funct7 of SLL/SLT/SLTU/XOR/OR/AND is legal
            if ((ir_buff.r.funct3 == 3'b001 ||
                 ir_buff.r.funct3 == 3'b010 ||
                 ir_buff.r.funct3 == 3'b011 ||
                 ir_buff.r.funct3 == 3'b100 ||
                 ir_buff.r.funct3 == 3'b110 ||
                 ir_buff.r.funct3 == 3'b111) && ir_buff.r.funct7 != 7'b0)
                illegal_inst = 1'b1;
        end

        OP_IMM: begin
            instr_ex_out.a_bus_sel = RS1;
            instr_ex_out.b_bus_sel = IMM;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_ALU;

            imm_sel = I_TYPE;
            rs1_sel_out = ir_buff.r.rs1;
            rd_sel_out  = ir_buff.r.rd;
        
            case (ir_buff.r.funct3)
                3'b000: instr_ex_out.alu_op = ADD_OP;
                3'b010: instr_ex_out.alu_op = SLT_OP;
                3'b011: instr_ex_out.alu_op = SLTU_OP;
                3'b100: instr_ex_out.alu_op = XOR_OP;
                3'b110: instr_ex_out.alu_op = OR_OP;
                3'b111: instr_ex_out.alu_op = AND_OP;
                3'b001: begin
                    imm_sel = I2_TYPE;
                    instr_ex_out.alu_op = SLL_OP;
                    if (ir_buff.r.funct7 != 7'b0) illegal_inst = 1'b1;
                end
                3'b101: begin
                    imm_sel = I2_TYPE;
                    case (ir_buff.r.funct7)
                        7'b0000000: instr_ex_out.alu_op = SRL_OP;
                        7'b0100000: instr_ex_out.alu_op = SRA_OP;
                        default:    illegal_inst = 1'b1;
                    endcase
                end
            endcase
        end
        
        AUIPC: begin
            instr_ex_out.a_bus_sel = PC;
            instr_ex_out.b_bus_sel = IMM;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_ALU;

            imm_sel = U_TYPE;
            rd_sel_out  = ir_buff.r.rd;
        end
        
        LUI: begin
            instr_ex_out.a_bus_sel = RS1;
            instr_ex_out.b_bus_sel = IMM;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_ALU;

            imm_sel = U_TYPE;
            rd_sel_out  = ir_buff.r.rd;
        end
        
        BRANCH: begin
            instr_ex_out.branch_jal_sel = BRANCH_INSTR;
            instr_ex_out.a_bus_sel = PC;
            instr_ex_out.b_bus_sel = IMM;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;

            imm_sel = B_TYPE;
            rs1_sel_out = ir_buff.r.rs1;
            rs2_sel_out = ir_buff.r.rs2;

            case (ir_buff.r.funct3)
                3'b000:  instr_ex_out.branch_cond = COND_EQ;
                3'b001:  instr_ex_out.branch_cond = COND_NE;
                3'b100:  instr_ex_out.branch_cond = COND_LT;
                3'b101:  instr_ex_out.branch_cond = COND_GE;
                3'b110:  instr_ex_out.branch_cond = COND_LTU;
                3'b111:  instr_ex_out.branch_cond = COND_GEU;
                default: illegal_inst = 1'b1;
            endcase
        end
        
        JALR: begin
            instr_ex_out.branch_jal_sel = JAL_INSTR;
            instr_ex_out.a_bus_sel = RS1;
            instr_ex_out.b_bus_sel = IMM;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_PC_PLUS_4;

            if (ir_buff.r.funct3 != 3'b000) illegal_inst = 1'b1;

            imm_sel = I_TYPE;
            rs1_sel_out = ir_buff.r.rs1;
            rd_sel_out  = ir_buff.r.rd;
        end
        
        JAL: begin
            instr_ex_out.branch_jal_sel = JAL_INSTR;
            instr_ex_out.a_bus_sel = PC;
            instr_ex_out.b_bus_sel = IMM;
            instr_ex_out.alu_op = ADD_OP;
            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
            instr_ex_out.wb_data_sel = WB_DATA_SEL_PC_PLUS_4;

            imm_sel = J_TYPE;
            rd_sel_out  = ir_buff.r.rd;
        end
        
        SYSTEM: begin
            if (ir_buff.r.funct3 == 3'b0) begin  // Non-CSR SYSTEM instructions
                case (ir_buff.r.funct7)
                    7'b0001001: begin  // SFENCE.VMA
                        if (ir_buff.r.rd != 5'b0) illegal_inst = 1'b1;
                        else if (r_current_mode == U_MODE) illegal_inst = 1'b1;
                        else if (r_current_mode == S_MODE && csr.mstatus.tvm) illegal_inst = 1'b1;
                        else begin
                            instr_ex_out.sfence_vma = 1'b1;
                            // Refetch from here, same as FENCE.I
                            instr_ex_out.branch_jal_sel = BRANCH_INSTR;
                            instr_ex_out.branch_cond = COND_EQ;
                            instr_ex_out.a_bus_sel = RS1;
                            instr_ex_out.b_bus_sel = IMM;
                            imm_sel = NEXT_PC;
                            instr_ex_out.alu_op = ADD_OP;
                            instr_ex_out.mem_instr_sel = MEM_INSTR_NONE;
                        end
                    end
                    default: begin
                        if (ir_buff.r.rs1 != 5'b0 || ir_buff.r.rd != 5'b0) illegal_inst = 1'b1;

                        case (ir_buff.b[31:20])
                            12'b000000000000: ecall_active  = 1'b1;  // ECALL
                            12'b000000000001: ebreak_active = 1'b1;  // EBREAK
                            12'b001100000010: begin  // MRET
                                if (r_current_mode != M_MODE) illegal_inst = 1'b1;
                                else instr_ex_out.mret_en = 1'b1;
                            end
                            12'b000100000010: begin  // SRET
                                if (r_current_mode < S_MODE) illegal_inst = 1'b1;
                                else instr_ex_out.sret_en = 1'b1;
                            end
                            12'b000100000101: begin  // WFI
                                instr_ex_out.branch_jal_sel = JAL_INSTR;
                                instr_ex_out.a_bus_sel = PC;
                                instr_ex_out.b_bus_sel = IMM;
                                instr_ex_out.alu_op = ADD_OP;
                                imm_sel = ZERO;
                            end
                            default: illegal_inst = 1'b1;
                        endcase
                    end
                endcase
            end else begin  // CSR read-modify-write instructions
                instr_ex_out.csr_op      = 1'b1;
                instr_ex_out.wb_data_sel = WB_DATA_SEL_CSR;
                rs1_sel_out = ir_buff.r.rs1;
                rd_sel_out  = ir_buff.r.rd;

                illegal_inst = (decode_csr_ro && is_csr_write) ||
                               (r_current_mode < decode_csr_mode) ||
                               csr_not_implemented;

                case (ir_buff.r.funct3)
                    3'b001: begin  //  CSRRW
                        instr_ex_out.a_bus_sel = RS1;
                        instr_ex_out.b_bus_sel = IMM;
                        instr_ex_out.alu_op    = OR_OP;
                        imm_sel = ZERO;
                    end
                    3'b010: begin  // CSRRS
                        instr_ex_out.a_bus_sel = RS1;
                        instr_ex_out.b_bus_sel = CSR;
                        instr_ex_out.alu_op    = OR_OP;
                    end
                    3'b011: begin  // CSRRC
                        instr_ex_out.a_bus_sel   = RS1;
                        instr_ex_out.invert_op_a = 1'b1;
                        instr_ex_out.b_bus_sel   = CSR;
                        instr_ex_out.alu_op      = AND_OP;
                    end
                    3'b101: begin  // CSRRWI
                        instr_ex_out.a_bus_sel = RS1_SEL;
                        instr_ex_out.b_bus_sel = IMM;
                        instr_ex_out.alu_op    = OR_OP;
                        imm_sel = ZERO;
                    end
                    3'b110: begin  // CSRRSI
                        instr_ex_out.a_bus_sel = RS1_SEL;
                        instr_ex_out.b_bus_sel = CSR;
                        instr_ex_out.alu_op    = OR_OP;
                    end
                    3'b111: begin  // CSRRCI
                        instr_ex_out.a_bus_sel   = RS1_SEL;
                        instr_ex_out.invert_op_a = 1'b1;
                        instr_ex_out.b_bus_sel   = CSR;
                        instr_ex_out.alu_op      = AND_OP;
                    end
                    default: illegal_inst = 1'b1;
                endcase
            end
        end

        default: illegal_inst = 1'b1;
    endcase

    // Propagate illegal instruction as bubble
    // MUST KEEP THIS LAST
    if (illegal_inst) instr_ex_out = NOP_CTRL;
end

// ============================================================
// MMU outputs
// ============================================================

assign satp_out = csr.satp;
assign sum_out  = csr.mstatus.sum;
assign mxr_out  = csr.mstatus.mxr;
assign mode_out = r_current_mode;

endmodule
