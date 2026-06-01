# FRISC-V Quick-Start Guide

This guide walks through the full workflow from a fresh clone to running a program on the PYNQ-Z2.

## 1. Prerequisites

- **Vivado 2025.2** with `bin/` on `PATH`
- **Python 3.11+**
- **`riscv64-unknown-elf` toolchain** + `make` (Linux or WSL2 on Windows)
- **[Verilator](https://verilator.org)** (optional, for linting and simulation without Vivado)
- PYNQ-Z2 board connected via USB (JTAG + serial on the same micro-USB port)

Verify Vivado is on PATH:

```bash
vivado -version
```

## 2. Clone and Create the Vivado Project

```bash
git clone --recurse-submodules -j8 https://github.com/friscv/FRISCV-system-HW.gitcd friscv-system-hw
cd friscv-system-hw
python3 build.py
```

This runs `scripts/create_project.tcl` in Vivado batch mode and creates the project at `friscv-system-hw/friscv-system-hw.xpr`. You only need to do this once (or after `python3 build.py clean`).

To open the project in the GUI afterwards:

```bash
python3 build.py open
```

Or find the `.xpr` in the Vivado GUI and open the project that way.

## 3. Build a Test Program

Test programs are assembled from `test/*.S`. This step requires the RISC-V toolchain - on Windows, run this inside WSL2:

```bash
cd test
make prog TEST=blink_led
cd ..
```

Output files: `test/prog.bin` (raw binary), `test/prog.elf`, `test/prog.dis`.

## 4. Program, Load, and Run

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

To open a serial terminal immediately after run:

```bash
python3 build.py go -t
```

## 4a. Running Without Hardware (Verilator)

If you don't have a board connected, you can run all integration tests in simulation:

```bash
make test
```

This verilates `tb_integration`, builds all `test/integration_test_*.S` programs, and runs each one. See [TESTING.md](TESTING.md) for details.

## 5. Observe Output (Serial)

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

## 6. UART Boot Mode (No JTAG Needed)

Set **SW0 = 1, SW1 = 0** before powering on to enter UART boot mode. The bootloader will wait for a binary over XMODEM-CRC:

```bash
pip install pyserial
python3 scripts/xmodem_load.py --port /dev/ttyUSB0 --baud 115200
# Windows: --port COM3
```

The ZSBL prints `[ZSBL] Mode: UART` and starts the transfer automatically. The program executes immediately after the transfer completes.

## 7. Flash to QSPI (Optional)

To have the board program itself on power-on without JTAG, write the pre-built boot image to QSPI flash:

```bash
python3 build.py flash
```

See [BOOT.md](BOOT.md#qspi-flash-boot) for jumper settings and details, the Python script will also tell you what to do.

> [!NOTE]
> This has only been tested on Linux.

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
python build.py zsbl-rom          # regenerate boot ROM
python build.py clean             # remove Vivado project
python build.py help              # full usage
```
