#!/usr/bin/env python3
import sys
import subprocess
import re
import argparse
from pathlib import Path


def assemble_and_link(input_file, output_elf, linker_script=None):
    """Assemble and link RISC-V assembly to ELF."""
    # First assemble
    temp_obj = input_file.with_suffix('.o')
    cmd_as = [
        "riscv32-unknown-elf-as",
        "-march=rv32i",
        "-mabi=ilp32",
        "-o", str(temp_obj),
        str(input_file)
    ]
    try:
        subprocess.run(cmd_as, check=True, capture_output=True)
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Assembly failed: {e.stderr.decode()}", file=sys.stderr)
        sys.exit(1)
    
    # Then link
    cmd_ld = [
        "riscv32-unknown-elf-ld",
        "-o", str(output_elf),
    ]
    if linker_script:
        cmd_ld.extend(["-T", str(linker_script)])
    cmd_ld.append(str(temp_obj))
    
    try:
        subprocess.run(cmd_ld, check=True, capture_output=True)
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Linking failed: {e.stderr.decode()}", file=sys.stderr)
        sys.exit(1)
    finally:
        # Clean up object file
        temp_obj.unlink(missing_ok=True)


def extract_instructions(elf_file):
    """Extract machine code instructions and mnemonics from ELF using objdump."""
    cmd = [
        "riscv32-unknown-elf-objdump",
        "-d",
        "-M", "no-aliases,numeric",
        str(elf_file)
    ]
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Objdump failed: {e.stderr}", file=sys.stderr)
        sys.exit(1)
    
    instructions = []
    # Pattern to match instruction lines: address<tab>hex<tab>mnemonic
    pattern = r"^\s*[0-9a-f]+:\s+([0-9a-f]+)\s+(.+)"
    
    for line in result.stdout.split('\n'):
        match = re.match(pattern, line)
        if match:
            hex_instr = match.group(1)
            mnemonic = match.group(2).strip()
            # Convert to 32-bit value
            instr_val = int(hex_instr, 16)
            instructions.append((instr_val, mnemonic))
    
    return instructions


def generate_verilog_rom(instructions, output_file, start_addr=0x1000):
    """Generate Verilog ROM module from instructions with mnemonics."""
    
    verilog_template = '''/*
(c) FER, HPC Architecture and Application Research Center, All rights reserved

Use under License Agreement ONLY.

IF, PRIOR TO DOWNLOADING, STORING, INSTALLING, ACTIVATING OR USING THE WORK, 
(A) YOU DECIDE YOU ARE UNWILLING TO AGREE TO THE TERMS OF THE PROVIDED LICENSE AGREEMENT, or 
(B) YOU DID NOT RECEIVE OR OBTAIN THE LICENSE AGREEMENT, YOU HAVE NO RIGHT TO USE THE WORK AND YOU SHOULD PROMPTLY RETURN THE WORK TO FER, DELETE IT, OR DISABLE IT.

https://hpc.fer.hr/en/hpc
licensing.hpc@fer.hr

Version info is listed in friscv_pkg.sv

AUTO-GENERATED FROM: {input_file}
*/

`include "friscv_pkg.sv"

module friscv_zsbl_rom (
    input  addr_t i_addr,
    output inst_t o_data
);

inst_t mem [0:(ZSBL_ROM_SIZE/4)-1];
localparam int unsigned ZSBL_PROG_WORDS = {num_words};

logic [31:0] w_word_offset;
assign w_word_offset = (i_addr - RESET_VEC) >> 2;

assign o_data = (i_addr >= RESET_VEC && w_word_offset < (ZSBL_ROM_SIZE/4)) ? mem[w_word_offset] : NOP;

initial begin
    // Auto-generated program at RESET_VEC ({start_addr})
{instructions}

    for (int i = ZSBL_PROG_WORDS; i < (ZSBL_ROM_SIZE/4); i++) begin
        mem[i] = 32'h0000_0000;
    end
end

endmodule
'''

    # Format instruction lines with mnemonics as comments
    instr_lines = []
    for i, (instr, mnemonic) in enumerate(instructions):
        hex_str = f"{instr:08x}"
        # Format as pairs: "hxxxx_xxxx"
        formatted = f"h{hex_str[0:4]}_{hex_str[4:8]}"
        instr_lines.append(f"    mem[{i}] = 32'{formatted};  // {mnemonic}")
    
    instr_block = "\n".join(instr_lines)
    
    verilog = verilog_template.format(
        input_file=Path(sys.argv[1]).name,
        num_words=len(instructions),
        start_addr=hex(start_addr),
        instructions=instr_block
    )
    
    with open(output_file, 'w') as f:
        f.write(verilog)

def main():
    parser = argparse.ArgumentParser(
        description="Generate ZSBL ROM Verilog from RISC-V assembly"
    )
    parser.add_argument("input_file", help="Input .S assembly file")
    parser.add_argument("output_file", help="Output .sv Verilog file")
    parser.add_argument(
        "--linker-script",
        help="Linker script to use (optional)"
    )
    parser.add_argument(
        "--start-addr",
        type=lambda x: int(x, 0),
        default=0x1000,
        help="Start address (default: 0x1000)"
    )
    
    args = parser.parse_args()
    
    input_file = Path(args.input_file)
    output_file = Path(args.output_file)
    
    if not input_file.exists():
        print(f"ERROR: Input file not found: {input_file}", file=sys.stderr)
        sys.exit(1)
    
    linker_script = None
    if args.linker_script:
        linker_script = Path(args.linker_script)
        if not linker_script.exists():
            print(f"ERROR: Linker script not found: {linker_script}", file=sys.stderr)
            sys.exit(1)
    
    # Create temporary ELF file
    temp_elf = input_file.with_suffix('.elf')
    
    print(f"Assembling and linking {input_file}...", file=sys.stderr)
    assemble_and_link(input_file, temp_elf, linker_script)
    
    print(f"Extracting instructions...", file=sys.stderr)
    instructions = extract_instructions(temp_elf)
    
    if not instructions:
        print(f"WARNING: No instructions found in {input_file}", file=sys.stderr)
    
    print(f"Found {len(instructions)} instructions", file=sys.stderr)
    print(f"Generating {output_file}...", file=sys.stderr)
    generate_verilog_rom(instructions, output_file, args.start_addr)
    
    # Clean up temporary file
    temp_elf.unlink()
    
    print(f"Success! Generated {output_file}", file=sys.stderr)


if __name__ == "__main__":
    main()
