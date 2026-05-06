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

interface friscv_l2_if;
    logic       valid;
    logic       stall;
    logic       err;
    addr_t      addr;
    mem_width_e size;
    data_t      wdata;
    data_t      rdata;
    rw_cmd_e    rw;
    amo_op_e    amo_op;

    modport requester (
        output valid, addr, size, wdata, rw, amo_op,
        input  stall, err, rdata
    );

    modport responder (
        input  valid, addr, size, wdata, rw, amo_op,
        output stall, err, rdata
    );
endinterface
