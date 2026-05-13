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

`timescale 1ns / 1ps

import friscv_pkg::*;

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

    // CLINT time
    input  mtime_t    mtime_in,

    // Instruction fetch page fault
    input  logic      inst_fault_in,
    input  addr_t     fault_addr_in,
    input  logic      inst_err_in,

    // Data memory page fault
    input  mem_trap_e mem_trap_in,
    input  addr_t     mem_trap_pc_in,
    input  addr_t     mem_trap_va_in,
    input  mode_e     mem_trap_mode_in,
    output logic      mem_trap_commit_out,

    // EX stage trap
    input  ex_trap_e  ex_trap_in,
    input  addr_t     ex_trap_pc_in,
    input  addr_t     ex_trap_va_in,
    input  mode_e     ex_trap_mode_in,
    output logic      ex_trap_commit_out,

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

    // Inputs from older stages for state visibility
    input  reg_addr_t ex_rd_sel_in,
    input  reg_addr_t mem_rd_sel_in,

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
    input  logic      ex_mem_inflight_in,
    input  logic      mem_mem_inflight_in,

    // Outputs and inputs for handling interrupts
    output addr_t     tvec_out,          // Resolved mtvec or stvec
    output addr_t     epc_out,           // Resolved mepc or sepc
    output logic      trap_out,
    output logic      trap_pending_out,
    output logic      ret_out,           // Active for both mret and sret
    input  logic      ret_commit_in,

    // Outputs to MMU
    output satp_t     satp_out,
    output logic      sum_out,
    output logic      mxr_out,
    output mode_e     mode_out,
    output mode_e     data_mode_out
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
logic      instr_valid_buff;
imm_e      imm_sel;
logic      inst_fault_buff;
addr_t     fault_addr_buff;
logic      inst_err_buff;
mode_e     pc_mode_buff;
logic      if_trap_inhibit;

assign rs1_out = regfile[rs1_sel_out];
assign rs2_out = regfile[rs2_sel_out];

assign pc_out = pc_in_buff;
assign pc_plus_4_out = pc_plus_4_buff;

// ============================================================
// Input capture
// ============================================================

always_ff @(posedge clk_in) begin
    if (!rst_n_in) begin
        ir_buff          <= NOP;
        pc_in_buff       <= '0;
        pc_plus_4_buff   <= '0;
        instr_valid_buff <= 1'b0;
        inst_fault_buff  <= 1'b0;
        fault_addr_buff  <= '0;
        inst_err_buff    <= 1'b0;
        pc_mode_buff     <= M_MODE;

        for (int i = 0; i < REGISTER_NUM; i++) begin
            regfile[i] = '0;
        end

    end else begin
        if (rd_sel_in != 0)
            regfile[rd_sel_in] <= rd_data_in;

        if (flush_in) begin
            ir_buff          <= NOP;
            pc_in_buff       <= '0;
            pc_plus_4_buff   <= '0;
            instr_valid_buff <= 1'b0;
            inst_fault_buff  <= 1'b0;
            fault_addr_buff  <= '0;
            inst_err_buff    <= 1'b0;
            pc_mode_buff     <= M_MODE;

        end else if (!stage_stall_in) begin
            ir_buff          <= ir_in;
            pc_in_buff       <= pc_in;
            pc_plus_4_buff   <= pc_plus_4_in;
            instr_valid_buff <= 1'b1;
            inst_fault_buff  <= inst_fault_in;
            fault_addr_buff  <= fault_addr_in;
            inst_err_buff    <= inst_err_in;
            pc_mode_buff     <= r_current_mode;

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
    data_t scounteren;
    addr_t stvec;
    data_t senvcfg;

    // Supervisor Trap Handling
    data_t sscratch;
    addr_t sepc;
    data_t scause;
    inst_t stval;

    // Supervisor Timer (Sstc)
    data_t stimecmp;
    data_t stimecmph;

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

    // Machine Environment Configuration
    data_t menvcfg;
    data_t menvcfgh;

    // Machine Memory Protection
    data_t pmpcfg0;
    data_t pmpcfg1;
    addr_t pmpaddr0;
    addr_t pmpaddr1;
    addr_t pmpaddr2;
    addr_t pmpaddr3;
    addr_t pmpaddr4;
    addr_t pmpaddr5;
    addr_t pmpaddr6;
    addr_t pmpaddr7;

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

logic       selected_is_ctr;
logic [4:0] selected_ctr_bit;
logic       ctr_access_illegal;

// Determine which counter is selected
always_comb begin
    selected_is_ctr  = 1'b1;
    selected_ctr_bit = 5'd0;
    case (selected_csr)
        CSR_CYCLE, CSR_CYCLEH:     selected_ctr_bit = 5'd0;
        CSR_TIME, CSR_TIMEH:       selected_ctr_bit = 5'd1;
        CSR_INSTRET, CSR_INSTRETH: selected_ctr_bit = 5'd2;
        default:                   selected_is_ctr = 1'b0;
    endcase
end

// Determine if current mode can access selected counter
always_comb begin
    ctr_access_illegal = 1'b0;

    if (selected_is_ctr) begin
        case (r_current_mode)
            M_MODE:  ctr_access_illegal = 1'b0;
            S_MODE:  ctr_access_illegal = !csr.mcounteren[selected_ctr_bit];
            default: ctr_access_illegal = !csr.mcounteren[selected_ctr_bit] ||
                                          !csr.scounteren[selected_ctr_bit];
        endcase
    end
end

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

logic r_mret_inhibit;

// Check if interrupt is safe to execute - safe if
//  1) Not returning from a previous interrupt,
//  2) Not executing a branch and
//  3) Not in the middle of a fetch
logic interrupt_safe, exception_safe;
assign interrupt_safe = !r_mret_inhibit && !branch_ok_in && (|pc_in_buff);
assign exception_safe = !branch_ok_in && instr_valid_buff;

// Interrupt active detection

logic m_interrupt_active, s_interrupt_active;

logic stip_hw;
logic stip_eff;
assign stip_hw  = csr.menvcfgh[31] && (mtime_in >= {csr.stimecmph, csr.stimecmp});
assign stip_eff = csr.stip || stip_hw;

assign m_interrupt_active = interrupt_safe &&
                            (csr.mstatus.mie || r_current_mode != M_MODE) &&
                            (msip_in && csr.mie[3] ||
                             mtip_in && csr.mie[7] ||
                             meip_in && csr.mie[11]);

assign s_interrupt_active = interrupt_safe &&
                            (r_current_mode != M_MODE) &&
                            (csr.mstatus.sie || r_current_mode == U_MODE) &&
                            ((csr.ssip && csr.mie[1] && csr.mideleg[1]) ||
                             (stip_eff && csr.mie[5] && csr.mideleg[5]) ||
                             (csr.seip && csr.mie[9] && csr.mideleg[9]));

logic interrupt_active, exception_active;
assign interrupt_active = m_interrupt_active || s_interrupt_active;

// Exception active detection

logic inst_addr_virtual;
assign inst_addr_virtual = ENABLE_MMU &&
                           (r_current_mode != M_MODE) &&
                           (satp_mode_e'(csr.satp.mode) != SATP_BARE);

if_trap_e if_trap;
assign if_trap = inst_fault_buff ? IF_TRAP_FAULT  :
                 inst_err_buff   ? IF_TRAP_ACCESS :
                                   IF_TRAP_NONE;

logic is_if_trap;
assign is_if_trap = (if_trap != IF_TRAP_NONE) && !if_trap_inhibit && !branch_ok_in;

logic is_id_trap;
assign is_id_trap = exception_safe &&
                    (ecall_active  ||
                     ebreak_active ||
                     illegal_inst  ||
                     (ENABLE_EARLY_JAL_JALR && target_misaligned));

logic is_mem_trap;
assign is_mem_trap = mem_trap_in != MEM_TRAP_NONE;

logic is_ex_trap;
assign is_ex_trap = ex_trap_in != EX_TRAP_NONE;

trap_src_e trap_src;
assign trap_src =
    is_mem_trap ? TRAP_SRC_MEM :
    is_ex_trap  ? TRAP_SRC_EX  :
    is_if_trap  ? TRAP_SRC_IF  :
    is_id_trap  ? TRAP_SRC_ID  :
                  TRAP_SRC_NONE;

logic ecall_active, ebreak_active;
assign exception_active = is_if_trap || is_id_trap || is_ex_trap || is_mem_trap;

// Trap RAW hazard - a CSR write in EX or MEM might update mtvec/mstatus/mepc before the
// trap fires. Suppress the effective trap (flush + CSR state write) until the pipeline
// is clear. trap_pending_out lets pipeline_control stall so the instruction is not lost
// from ir_buff while waiting.
logic trap_raw, trap_csr_hazard;
logic trap_gpr_hazard;
assign trap_raw         = interrupt_active || exception_active;
assign trap_csr_hazard  = trap_raw && (ex_csr_en_in || mem_csr_en_in || wb_csr_en_in);
assign trap_gpr_hazard  = trap_raw &&
                          ((ex_rd_sel_in  != 5'd0) ||
                           (mem_rd_sel_in != 5'd0) ||
                           (rd_sel_in     != 5'd0));

// Flag to not re-take an already taken trap.
logic trap_seen;

// An incoming trap has a pipeline hazard if
//  1) there is a memory instruction in the pipeline or
//  2) a dispatched instruction will write back to a register.
// These must commit before taking a trap.
logic trap_pipe_hazard;
assign trap_pipe_hazard = trap_raw &&
                          (ex_mem_inflight_in || mem_mem_inflight_in || trap_gpr_hazard);
assign trap_out         = trap_raw && !trap_seen && !trap_csr_hazard && !trap_pipe_hazard;
assign trap_pending_out = trap_raw && !trap_seen && (trap_csr_hazard || trap_pipe_hazard);

assign ex_trap_commit_out  = trap_out && (trap_src == TRAP_SRC_EX || trap_src == TRAP_SRC_MEM);
assign mem_trap_commit_out = trap_out && (trap_src == TRAP_SRC_MEM);

logic mret_active, sret_active;
assign mret_active = (ir_buff.r.opcode == SYSTEM) && (ir_buff.r.funct3 == 3'b000) && (ir_buff.b[31:20] == 12'b001100000010);
assign sret_active = (ir_buff.r.opcode == SYSTEM) && (ir_buff.r.funct3 == 3'b000) && (ir_buff.b[31:20] == 12'b000100000010);

assign ret_out = (mret_active || sret_active) && !illegal_inst;

// Compute exception cause code
logic [4:0] exception_cause_code;
always_comb begin
    exception_cause_code = 5'd0;

    case (trap_src)
        TRAP_SRC_IF:
            case (if_trap)
                IF_TRAP_FAULT:  exception_cause_code = 5'd12;  // Instruction page fault
                IF_TRAP_ACCESS: exception_cause_code = 5'd1;   // Instruction access fault
                default:        exception_cause_code = 5'd0;
            endcase
        TRAP_SRC_ID:
            if (ecall_active)
                case (r_current_mode)
                    U_MODE:  exception_cause_code = 5'd8;   // Environment call from U-mode
                    S_MODE:  exception_cause_code = 5'd9;   // Environment call from S-mode
                    default: exception_cause_code = 5'd11;  // Environment call from M-mode
                endcase
            else if (ebreak_active)
                exception_cause_code = 5'd3;  // Breakpoint
            else if (illegal_inst)
                exception_cause_code = 5'd2;  // Illegal instruction
            else if (target_misaligned)
                exception_cause_code = 5'd0;  // Instruction address misaligned
        TRAP_SRC_EX:
            case (ex_trap_in)
                EX_TRAP_MISALIGNED: exception_cause_code = 5'd0;  // Instruction address misaligned
                default:            exception_cause_code = 5'd0;
            endcase
        TRAP_SRC_MEM:
            case (mem_trap_in)
                MEM_TRAP_LOAD_MISALIGNED:  exception_cause_code = 5'd4;   // Load address misaligned
                MEM_TRAP_LOAD_ACCESS:      exception_cause_code = 5'd5;   // Load access fault
                MEM_TRAP_STORE_MISALIGNED: exception_cause_code = 5'd6;   // Store/AMO address misaligned
                MEM_TRAP_STORE_ACCESS:     exception_cause_code = 5'd7;   // Store/AMO access fault
                MEM_TRAP_LOAD:             exception_cause_code = 5'd13;  // Load page fault
                MEM_TRAP_STORE:            exception_cause_code = 5'd15;  // Store/AMO page fault
                default:                   exception_cause_code = 5'd0;
            endcase
        default: exception_cause_code = 5'd0;
    endcase
end

// A trap is delegated to S-mode when:
//   - Not already in M-mode (traps never transition to less-privileged mode)
//   - No M-mode interrupt is active (M-mode interrupts take priority over S-mode)
//   - s_interrupt_active (already checks mideleg bits), or
//   - exception cause bit is set in medeleg
logic is_delegated;

mode_e trap_mode;
always_comb begin
    case (trap_src)
        TRAP_SRC_IF:  trap_mode = pc_mode_buff;
        TRAP_SRC_ID:  trap_mode = r_current_mode;
        TRAP_SRC_EX:  trap_mode = ex_trap_mode_in;
        TRAP_SRC_MEM: trap_mode = mem_trap_mode_in;
        default:      trap_mode = r_current_mode;
    endcase
end

assign is_delegated = (trap_mode != M_MODE) &&
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
    else if (stip_eff && csr.mie[5] && csr.mideleg[5])
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
// Trap EPC and TVAL resolution
// ============================================================

addr_t trap_epc;
always_comb begin
    case (trap_src)
        TRAP_SRC_IF:  trap_epc = pc_in_buff;
        TRAP_SRC_ID:  trap_epc = pc_in_buff;
        TRAP_SRC_EX:  trap_epc = ex_trap_pc_in;
        TRAP_SRC_MEM: trap_epc = mem_trap_pc_in;
        default:      trap_epc = pc_in_buff;
    endcase
end

addr_t trap_tval;
always_comb begin
    case (trap_src)
        TRAP_SRC_IF:  trap_tval = (if_trap == IF_TRAP_ACCESS) ? '0 : fault_addr_buff;
        TRAP_SRC_ID:  trap_tval = illegal_inst      ? ir_buff.b         :
                                  target_misaligned ? misaligned_target : '0;
        TRAP_SRC_EX:  trap_tval = ex_trap_va_in;
        TRAP_SRC_MEM:
            case (mem_trap_in)
                MEM_TRAP_LOAD_ACCESS,
                MEM_TRAP_STORE_ACCESS: trap_tval = '0;
                default:               trap_tval = mem_trap_va_in;
            endcase
        default: trap_tval = '0;
    endcase
end

// ============================================================
// CSR write
// ============================================================

always_ff @(posedge clk_in) begin
    if(!rst_n_in) begin
        csr <= '0;
        r_mret_inhibit <= 1'b0;
        r_current_mode <= M_MODE;
        trap_seen      <= 1'b0;
        if_trap_inhibit <= 1'b0;
    end else begin
        if (!trap_raw)
            trap_seen <= 1'b0;

        if (r_mret_inhibit && !stage_stall_in)
            r_mret_inhibit <= 1'b0;

        if (trap_out)
            if_trap_inhibit <= 1'b1;
        else if (!stage_stall_in && !(inst_fault_in || inst_err_in))
            if_trap_inhibit <= 1'b0;

        if (trap_out) begin
            trap_seen <= 1'b1;
            r_mret_inhibit <= 1'b0;
            if (trap_to_s_mode) begin
                r_current_mode   <= S_MODE;
                csr.sepc         <= trap_epc;
                csr.mstatus.spie <= csr.mstatus.sie;
                csr.mstatus.sie  <= 1'b0;
                csr.mstatus.spp  <= (trap_mode == S_MODE) ? 1'b1 : 1'b0;
                csr.stval        <= trap_tval;

                if      (csr.seip && csr.mie[9] && csr.mideleg[9]) csr.scause <= {1'b1, 31'd9};
                else if (stip_eff && csr.mie[5] && csr.mideleg[5]) csr.scause <= {1'b1, 31'd5};
                else if (csr.ssip && csr.mie[1] && csr.mideleg[1]) csr.scause <= {1'b1, 31'd1};
                else if (exception_active)                         csr.scause <= 32'(exception_cause_code);

            end else begin
                // Non-delegated trap: enter M-mode
                r_current_mode <= M_MODE;
                csr.mepc            <= trap_epc;
                csr.mstatus.mpie    <= csr.mstatus.mie;
                csr.mstatus.mie     <= 1'b0;
                csr.mstatus.mpp     <= trap_mode;
                csr.mtval           <= trap_tval;

                if      (meip_in && csr.mie[11])         csr.mcause <= {1'b1, 31'd11};
                else if (mtip_in && csr.mie[7])          csr.mcause <= {1'b1, 31'd7};
                else if (msip_in && csr.mie[3])          csr.mcause <= {1'b1, 31'd3};
                else if (exception_active)               csr.mcause <= 32'(exception_cause_code);
            end

        end else if (ret_commit_in && sret_active) begin
            r_mret_inhibit   <= 1'b1;
            csr.mstatus.sie  <= csr.mstatus.spie;
            csr.mstatus.spie <= 1'b1;
            r_current_mode   <= csr.mstatus.spp ? S_MODE : U_MODE;
            csr.mstatus.spp  <= 1'b0;

        end else if (ret_commit_in && mret_active) begin
            // Commit MRET
            r_mret_inhibit   <= 1'b1;
            csr.mstatus.mie  <= csr.mstatus.mpie;
            csr.mstatus.mpie <= 1'b1;
            r_current_mode   <= csr.mstatus.mpp;
            csr.mstatus.mpp  <= U_MODE;
            if (csr.mstatus.mpp != M_MODE)
                csr.mstatus.mprv <= 1'b0;

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
                CSR_SCOUNTEREN: csr.scounteren <= csr_data_in & 32'h0000_0007;
                CSR_SIE: begin  // S-mode visible bits of mie only
                    csr.mie[1] <= csr_data_in[1];
                    csr.mie[5] <= csr_data_in[5];
                    csr.mie[9] <= csr_data_in[9];
                end
                CSR_STVEC:    csr.stvec    <= csr_data_in;
                CSR_SENVCFG:  csr.senvcfg  <= csr_data_in;
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

                // Supervisor Timer (Sstc)
                CSR_STIMECMP:  csr.stimecmp  <= csr_data_in;
                CSR_STIMECMPH: csr.stimecmph <= csr_data_in;

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
                    csr.mstatus.mprv <= csr_data_in[17];
                    csr.mstatus.sum  <= csr_data_in[18];
                    csr.mstatus.mxr  <= csr_data_in[19];
                    csr.mstatus.tvm  <= csr_data_in[20];
                end
                CSR_MEDELEG:    csr.medeleg    <= csr_data_in;
                CSR_MIDELEG:    csr.mideleg    <= csr_data_in & 32'h0000_0222;  // Bits 1,5,9 only
                CSR_MIE:        csr.mie        <= csr_data_in;
                CSR_MTVEC:      csr.mtvec      <= csr_data_in;
                CSR_MCOUNTEREN: csr.mcounteren <= csr_data_in & 32'h0000_0007;
                CSR_MENVCFG:    csr.menvcfg    <= csr_data_in;
                CSR_MENVCFGH:   csr.menvcfgh   <= csr_data_in;
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
                CSR_PMPCFG1:  csr.pmpcfg1  <= csr_data_in;
                CSR_PMPADDR0: csr.pmpaddr0 <= csr_data_in;
                CSR_PMPADDR1: csr.pmpaddr1 <= csr_data_in;
                CSR_PMPADDR2: csr.pmpaddr2 <= csr_data_in;
                CSR_PMPADDR3: csr.pmpaddr3 <= csr_data_in;
                CSR_PMPADDR4: csr.pmpaddr4 <= csr_data_in;
                CSR_PMPADDR5: csr.pmpaddr5 <= csr_data_in;
                CSR_PMPADDR6: csr.pmpaddr6 <= csr_data_in;
                CSR_PMPADDR7: csr.pmpaddr7 <= csr_data_in;

                // Machine Counter Setup
                CSR_MCOUNTINHIBIT: csr.mcountinhibit <= csr_data_in & 32'h0000_0005;
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

always_comb begin : csr_read
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
        //                                mx----zyxwvutsrqpon m                        lkjihgfedcb a
        CSR_MISA:          csr_out = {19'b0100000000010100000,{ENABLE_EXTENSION_M},11'b00010000000,{ENABLE_EXTENSION_A}};
        CSR_MEDELEG:       csr_out = csr.medeleg;
        CSR_MIDELEG:       csr_out = csr.mideleg;
        CSR_MIE:           csr_out = csr.mie;
        CSR_MTVEC:         csr_out = csr.mtvec;
        CSR_MCOUNTEREN:    csr_out = csr.mcounteren;
        CSR_MENVCFG:       csr_out = csr.menvcfg;
        CSR_MENVCFGH:      csr_out = csr.menvcfgh;
        CSR_MSTATUSH:      csr_out = 32'h0;

        // Machine Trap Handling
        CSR_MSCRATCH:      csr_out = csr.mscratch;
        CSR_MEPC:          csr_out = csr.mepc;
        CSR_MCAUSE:        csr_out = csr.mcause;
        CSR_MTVAL:         csr_out = csr.mtval;
        CSR_MIP:           csr_out = {20'b0, meip_in, 1'b0, csr.seip, 1'b0, mtip_in, 1'b0, stip_eff, 1'b0, msip_in, 1'b0, csr.ssip, 1'b0};

        // Machine Memory Protection
        CSR_PMPCFG0:       csr_out = csr.pmpcfg0;
        CSR_PMPCFG1:       csr_out = csr.pmpcfg1;
        CSR_PMPADDR0:      csr_out = csr.pmpaddr0;
        CSR_PMPADDR1:      csr_out = csr.pmpaddr1;
        CSR_PMPADDR2:      csr_out = csr.pmpaddr2;
        CSR_PMPADDR3:      csr_out = csr.pmpaddr3;
        CSR_PMPADDR4:      csr_out = csr.pmpaddr4;
        CSR_PMPADDR5:      csr_out = csr.pmpaddr5;
        CSR_PMPADDR6:      csr_out = csr.pmpaddr6;
        CSR_PMPADDR7:      csr_out = csr.pmpaddr7;

        // Machine Counter/Timers
        CSR_MCYCLE:        csr_out = csr.mcycle[31:0];
        CSR_MINSTRET:      csr_out = csr.minstret[31:0];
        CSR_MCYCLEH:       csr_out = csr.mcycle[63:32];
        CSR_MINSTRETH:     csr_out = csr.minstret[63:32];

        // Machine Counter Setup
        CSR_MCOUNTINHIBIT: csr_out = csr.mcountinhibit;

        // User/Supervisor Counter/Timer shadows (read-only)
        CSR_CYCLE:         csr_out = csr.mcycle[31:0];
        CSR_INSTRET:       csr_out = csr.minstret[31:0];
        CSR_CYCLEH:        csr_out = csr.mcycle[63:32];
        CSR_INSTRETH:      csr_out = csr.minstret[63:32];
        CSR_TIME:          csr_out = mtime_in[31:0];
        CSR_TIMEH:         csr_out = mtime_in[63:32];

        // Supervisor Trap Setup
        // sstatus is mstatus with M-mode-only bits (MIE[3], MPIE[7], MPP[12:11], MPRV[17]) zeroed
        CSR_SSTATUS:       csr_out = data_t'(csr.mstatus) & ~32'h0002_1888;
        CSR_SCOUNTEREN:    csr_out = csr.scounteren;
        CSR_SIE:           csr_out = csr.mie & 32'h0000_0222;  // S-mode bits: SEIE[9], STIE[5], SSIE[1]
        CSR_STVEC:         csr_out = csr.stvec;
        CSR_SENVCFG:       csr_out = csr.senvcfg;
        CSR_SSCRATCH:      csr_out = csr.sscratch;
        CSR_SEPC:          csr_out = csr.sepc;
        CSR_SCAUSE:        csr_out = csr.scause;
        CSR_STVAL:         csr_out = csr.stval;
        // S-mode visible interrupt pending bits only
        CSR_SIP:           csr_out = {22'b0, csr.seip, 3'b0, stip_eff, 3'b0, csr.ssip, 1'b0};

        // Supervisor Timer (Sstc)
        CSR_STIMECMP:      csr_out = csr.stimecmp;
        CSR_STIMECMPH:     csr_out = csr.stimecmph;

        // Supervisor Protection and Translation
        CSR_SATP:          csr_out = csr.satp;

        default: begin
            csr_out             = 32'h0;
            csr_not_implemented = 1'b1;
        end
    endcase
end : csr_read

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

addr_t jal_target;
assign jal_target_out = jal_ok_out ? jal_target : '0;

// Compute target_misaligned independently of trap_out to avoid a combinatorial loop
logic target_misaligned;
addr_t misaligned_target;
always_comb begin
    unique case (ir_buff.r.opcode)
        JALR: begin
            addr_t jalr_base = (rd_sel_in != 0 && ir_buff.r.rs1 == rd_sel_in) ? rd_data_in : regfile[ir_buff.r.rs1];
            data_t jalr_imm = {{21{ir_buff.b[31]}}, ir_buff.b[30:20]};
            addr_t target = (jalr_base + jalr_imm) & ~ 32'd1;
            target_misaligned = target[1] && instr_valid_buff;
            misaligned_target = target;
        end
        JAL: begin
            data_t jal_imm = {{12{ir_buff.b[31]}}, ir_buff.b[19:12], ir_buff.b[20], ir_buff.b[30:21], 1'b0};
            addr_t target = pc_in_buff + jal_imm;
            target_misaligned = target[1] && instr_valid_buff;
            misaligned_target = target;
        end
        default: begin
            target_misaligned = 1'b0;
            misaligned_target = '0;
        end
    endcase
end

// Compute the final target
always_comb begin
    if (ENABLE_EARLY_JAL_JALR && !trap_out) begin
        addr_t jal_target_base;
        data_t jal_imm;
        jal_target_base = '0;
        jal_imm = '0;

        case (ir_buff.r.opcode)
            JALR: begin
                jal_ok_out = !target_misaligned;
                jal_target_base = (rd_sel_in != 0 && ir_buff.r.rs1 == rd_sel_in) ? rd_data_in : regfile[ir_buff.r.rs1];
                jal_imm = {{21{ir_buff.b[31]}}, ir_buff.b[30:20]};  // I-type immediate
                jal_target = (jal_target_base + jal_imm) & ~32'h1;
            end
            JAL: begin
                jal_ok_out = !target_misaligned;
                jal_imm = {{12{ir_buff.b[31]}}, ir_buff.b[19:12], ir_buff.b[20], ir_buff.b[30:21], 1'b0};  // J-type immediate
                jal_target = pc_in_buff + jal_imm;
            end
            default: begin
                jal_ok_out = 1'b0;
                jal_target = '0;
            end
        endcase
    end else begin
        jal_ok_out = 1'b0;
        jal_target = '0;
    end
end

// ============================================================
// Instruction decoding
// ============================================================

always_comb begin
    // Set signals to have no side effect by default
    instr_ex_out = NOP_CTRL;
    instr_ex_out.instr_valid = instr_valid_buff;
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
                3'b000:
                    if      (ir_buff.r.funct7 == 7'b0000000) instr_ex_out.alu_op = ADD_OP;
                    else if (ir_buff.r.funct7 == 7'b0100000) instr_ex_out.alu_op = SUB_OP;
                    else if (ir_buff.r.funct7 == 7'b0000001 && ENABLE_MUL) instr_ex_out.alu_op = MUL_OP;
                    else illegal_inst = 1'b1;
                3'b001:
                    if      (ir_buff.r.funct7 == 7'b0000000) instr_ex_out.alu_op = SLL_OP;
                    else if (ir_buff.r.funct7 == 7'b0000001 && ENABLE_MUL) instr_ex_out.alu_op = MULH_OP;
                    else illegal_inst = 1'b1;
                3'b010:
                    if      (ir_buff.r.funct7 == 7'b0000000) instr_ex_out.alu_op = SLT_OP;
                    else if (ir_buff.r.funct7 == 7'b0000001 && ENABLE_MUL) instr_ex_out.alu_op = MULHSU_OP;
                    else illegal_inst = 1'b1;
                3'b011:
                    if      (ir_buff.r.funct7 == 7'b0000000) instr_ex_out.alu_op = SLTU_OP;
                    else if (ir_buff.r.funct7 == 7'b0000001 && ENABLE_MUL) instr_ex_out.alu_op = MULHU_OP;
                    else illegal_inst = 1'b1;
                3'b100:
                    if      (ir_buff.r.funct7 == 7'b0000000) instr_ex_out.alu_op = XOR_OP;
                    else if (ir_buff.r.funct7 == 7'b0000001 && ENABLE_DIV) begin
                        instr_ex_out.alu_op = DIV_OP;
                        instr_ex_out.div_en = 1'b1;
                        instr_ex_out.div_signed = 1'b1;
                    end
                    else illegal_inst = 1'b1;
                3'b101:
                    if      (ir_buff.r.funct7 == 7'b0000000) instr_ex_out.alu_op = SRL_OP;
                    else if (ir_buff.r.funct7 == 7'b0100000) instr_ex_out.alu_op = SRA_OP;
                    else if (ir_buff.r.funct7 == 7'b0000001 && ENABLE_DIV) begin
                        instr_ex_out.alu_op = DIVU_OP;
                        instr_ex_out.div_en = 1'b1;
                        instr_ex_out.div_signed = 1'b0;
                    end
                    else illegal_inst = 1'b1;
                3'b110:
                    if      (ir_buff.r.funct7 == 7'b0000000) instr_ex_out.alu_op = OR_OP;
                    else if (ir_buff.r.funct7 == 7'b0000001 && ENABLE_DIV) begin
                        instr_ex_out.alu_op = REM_OP;
                        instr_ex_out.div_en = 1'b1;
                        instr_ex_out.div_signed = 1'b1;
                    end
                    else illegal_inst = 1'b1;
                3'b111:
                    if      (ir_buff.r.funct7 == 7'b0000000) instr_ex_out.alu_op = AND_OP;
                    else if (ir_buff.r.funct7 == 7'b0000001 && ENABLE_DIV) begin
                        instr_ex_out.alu_op = REMU_OP;
                        instr_ex_out.div_en = 1'b1;
                        instr_ex_out.div_signed = 1'b0;
                    end
                    else illegal_inst = 1'b1;
            endcase

            // Check if funct7 of SLL/SLT/SLTU/XOR/OR/AND is legal
            if ((ir_buff.r.funct3 == 3'b001 ||
                 ir_buff.r.funct3 == 3'b010 ||
                 ir_buff.r.funct3 == 3'b011 ||
                 ir_buff.r.funct3 == 3'b100 ||
                 ir_buff.r.funct3 == 3'b110 ||
                 ir_buff.r.funct3 == 3'b111) && (ir_buff.r.funct7 != 7'b0 && ir_buff.r.funct7 != 7'b0000001))
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
            instr_ex_out.jalr_target = 1'b1;
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
                        if      (ir_buff.r.rd != 5'b0) illegal_inst = 1'b1;
                        else if (r_current_mode == U_MODE) illegal_inst = 1'b1;
                        else if (r_current_mode == S_MODE && csr.mstatus.tvm) illegal_inst = 1'b1;
                        else begin
                            instr_ex_out.sfence_vma = 1'b1;
                            // Flush pipeline and jump to PC+4
                            instr_ex_out.branch_jal_sel = BRANCH_INSTR;
                            instr_ex_out.branch_cond = COND_ALWAYS;
                            instr_ex_out.a_bus_sel = ZERO_A;
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
                            12'b001100000010:        // MRET
                                if (r_current_mode != M_MODE) illegal_inst = 1'b1;
                                else instr_ex_out.mret_en = 1'b1;
                            12'b000100000010:        // SRET
                                if (r_current_mode < S_MODE) illegal_inst = 1'b1;
                                else instr_ex_out.sret_en = 1'b1;
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
                               ((r_current_mode == S_MODE) &&
                                csr.mstatus.tvm &&
                                (selected_csr == CSR_SATP)) ||
                               csr_not_implemented ||
                               ctr_access_illegal;

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
assign data_mode_out = (r_current_mode == M_MODE && csr.mstatus.mprv) ? csr.mstatus.mpp : r_current_mode;

endmodule
