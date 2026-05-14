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
        output size,
        output addr,
        output wdata,
        input  rdata,
        output rw,
        input  wait_req,
        output burst_en,
        output rstn,
        input  beat_valid,
        input  err
    );

    modport slave (
        input  size,
        input  addr,
        input  wdata,
        output rdata,
        input  rw,
        output wait_req,
        input  burst_en,
        input  rstn,
        output beat_valid,
        output err
    );

endinterface
