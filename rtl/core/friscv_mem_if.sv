// (c) FER, HPC Architecture and Application Research Center, All rights reserved
// License and version info is listed in friscv_pkg.sv

/*
 * This interface defines the signals for the external memory interface of the FRISC-V CPU subsystem.
 * It should be used on the core-side of any adapter implementation.
 *
 * See docs/MEM_IF.md for details on the protocol.
 */

`timescale 1ns / 1ps

import friscv_pkg::*;

interface friscv_mem_if;

    mem_width_e size;
    addr_t      addr;
    data_t      wdata;
    data_t      rdata;
    rw_cmd_e    rw;
    logic       wait_req;
    logic       burst_en;
    logic       rstn;
    logic       beat_valid;
    logic       err;

    modport master (
        output size, addr, wdata, rw, burst_en, rstn,
        input  rdata, wait_req, beat_valid, err
    );

    modport slave (
        input  size, addr, wdata, rw, burst_en, rstn,
        output rdata, wait_req, beat_valid, err
    );

endinterface
