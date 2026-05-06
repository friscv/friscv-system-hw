# FRISC-V Quick-Start Guide

This guide walks through the full workflow from a fresh clone to running a program on the PYNQ-Z2.

## 1. Prerequisites

- **Vivado 2025.2** with `bin/` on `PATH`
- **Python 3.12+**
- **`riscv64-unknown-elf` toolchain** + `make` (Linux or WSL2 on Windows)
- PYNQ-Z2 board connected via USB (JTAG + serial on the same micro-USB port)

Verify Vivado is on PATH:

```bash
vivado -version
```

## 2. Clone and Create the Vivado Project

```bash
git clone git@github.com:friscv/friscv-system-hw.git
cd friscv-system-hw
python3 build.py
```

This runs `scripts/create_project.tcl` in Vivado batch mode and creates the project at `friscv-system-hw/friscv-system-hw.xpr`. You only need to do this once (or after `python build.py clean`).

To open the project in the GUI afterwards:

```bash
python3 build.py open
```

Or find the `.xpr` in the Vivado GUI and open the project that way.

## 3. Build the Bitstream

A pre-built bitstream (`overlay/friscv.bit`) is already in the repository. Only rebuild if you have changed the RTL, block design, constraints, or the ZSBL:

```bash
python3 build.py bitstream
```

This will:

1. Delete all cached synthesis and implementation runs
2. Run Vivado synthesis + implementation + bitstream generation
3. Copy `friscv.bit`, `friscv.hwh`, and `ps7_init.tcl` to their destinations

> [!NOTE]
> All CPU cores are used during synthesis. On a high core-count machine, ensure you have enough RAM (16 GB minimum recommended).

## 4. Build a Test Program

Test programs are assembled from `test/*.S`. This step requires the RISC-V toolchain - on Windows, run this inside WSL2:

```bash
cd test
make prog TEST=blink_led
cd ..
```

Output files: `test/prog.bin` (raw binary), `test/prog.elf`, `test/prog.dis`.

## 5. Program, Load, and Run

Make sure the board is powered on and the USB cable is connected. The JTAG and serial port share the single micro-USB connector on the PYNQ-Z2.

```bash
python3 build.py go
```

This is equivalent to running these three steps individually:

```bash
python3 build.py program   # load friscv.bit into the FPGA
python3 build.py load      # write test/prog.bin to DDR via XSDB
python3 build.py run       # release FRISC-V from reset → program starts
```

To load a different binary:

```bash
python3 build.py go --bin path/to/my.bin
```

## 6. Observe Output (Serial)

The ZSBL prints a boot message over UART at **115200 8N1** before handing off to the loaded program. Connect with any serial terminal:

```bash
# Linux
screen /dev/ttyUSB0 115200  # Or ttyUSB1/2/...

# Windows (PowerShell)
# Use PuTTY, TeraTerm, or: python -m serial.tools.miniterm COM3 115200
```

Expected output on boot:

```text
[ZSBL] Ready
[ZSBL] Mode: DRAM
```

## 7. UART Boot Mode (No JTAG Needed)

Set **SW0 = 1, SW1 = 0** before powering on to enter UART boot mode. The bootloader will wait for a binary over XMODEM-CRC:

```bash
pip install pyserial
python3 scripts/xmodem_load.py --port /dev/ttyUSB0 --baud 115200
# Windows: --port COM3
```

The ZSBL prints `[ZSBL] Mode: UART` and starts the transfer automatically. The program executes immediately after the transfer completes.

## 8. Regenerate the Boot ROM

If you modify `software/zsbl.S`, regenerate the ROM before rebuilding the bitstream:

```bash
python3 build.py zsbl-rom
python3 build.py bitstream
```

## Command Reference

```text
python build.py project           # create Vivado project
python build.py open              # open project in Vivado GUI
python build.py bitstream         # clean build → overlay/friscv.bit
python build.py program           # program FPGA via JTAG
python build.py load [--bin FILE] # load binary to DDR via XSDB
python build.py run               # release FRISC-V from reset
python build.py go [--bin FILE]   # program + load + run
python build.py status            # check FPGA status
python build.py zsbl-rom [TEST]   # regenerate boot ROM
python build.py clean             # remove Vivado project
python build.py help              # full usage
```
