# FRISC-V

FRISC-V is a 32-bit RISC-V core developed at [FER](https://www.fer.unizg.hr/en), University of Zagreb. This repo also contains a reference SoC targeting the TUL PYNQ-Z2.

**ISA:** RV32I + M (multiply/divide) + A (atomics) + Zicsr + Zifencei + Zicntr + Sstc + Sv32

## Prerequisites

| Tool | Purpose | Notes |
| ---- | ------- | ----- |
| [Vivado 2025.2](https://www.xilinx.com/support/download.html) | Synthesis and programming | Add `bin/` to `PATH` |
| Python 3.11+ | `build.py` and helper scripts | Standard library only (`tomllib`) |
| `riscv64-unknown-elf` toolchain | Building test programs | [riscv-gnu-toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain) |
| [Verilator](https://verilator.org) | RTL simulation and testing | `make test` runs all integration tests |
| `make` | Building test programs | Linux/macOS native; Windows: WSL2 |

> [!IMPORTANT]
> On Windows, Vivado's `bin/` must be on `PATH`. Test programs in `test/` must be assembled inside WSL2 or another environment that has the RISC-V toolchain.
> The [Linux firmware build](docs/LINUX.md) and [architecture compliance tests](docs/TESTING.md#architecture-compliance-tests) have additional dependencies listed in their respective docs.

## Quick Start

```bash
git clone https://github.com/friscv/FRISCV-system-HW.git
cd friscv-system-hw

python3 build.py  # create Vivado project
```

See [docs/QUICKSTART.md](docs/QUICKSTART.md) for a full walkthrough from clone to running a program on hardware.

## Documentation

| Document | Description |
| -------- | ----------- |
| [docs/QUICKSTART.md](docs/QUICKSTART.md) | Step-by-step setup: clone → bitstream → program → run |
| [docs/TESTING.md](docs/TESTING.md) | Verilator integration tests, architecture compliance |
| [docs/LINUX.md](docs/LINUX.md) | Building and running the Linux firmware |
| [docs/GIT.md](docs/GIT.md) | Repository workflow: project setup, file conventions, pre-commit checklist |
| [docs/BOOT.md](docs/BOOT.md) | Boot modes, ZSBL boot process, switch encoding, QSPI flash |
| [docs/UART.md](docs/UART.md) | UART pinout, register map, host connection, C examples |

## Build Script

`build.py` is the cross-platform build entry point (Windows, Linux).

```bash
python3 build.py <target> [--bin FILE]
```

| Target | Description |
| ------ | ----------- |
| `project` | Create the Vivado project *(default)* |
| `export-bd` | Export block designs to TCL |
| `bitstream` | Clean, rebuild bitstream, deploy `.bit`/`.hwh` to `overlay/` |
| `program` | Program FPGA via JTAG |
| `status` | Check FPGA status via XSDB |
| `load` | Load `test/prog.bin` (or `--bin FILE`) into DDR via XSDB |
| `run` | Release FRISC-V from reset |
| `go [-t]` | `program` + `load` + `run` in one step (`-t` opens serial terminal) |
| `flash` | Write `BOOT.bin` to QSPI flash (board self-programs on power-on) |
| `open` | Open project in Vivado GUI |
| `clean` | Remove Vivado project and generated files |
| `zsbl-rom [TEST]` | Regenerate boot ROM from `software/zsbl.S`, or from `test/TEST.S` |
| `config [PRESET]` | Regenerate configurable parameters in `friscv_pkg.sv` (`minimal` / `full` / TOML) |
| `help` | Show usage |

> [!NOTE]
> `bitstream` deletes all cached synthesis and implementation runs before building to ensure a clean result. All CPU cores will be used during synthesis by default - ensure sufficient RAM.

## Building Test Programs

Test programs are RISC-V assembly files in `test/`. They require the `riscv64-unknown-elf` toolchain and `make`:

```bash
cd test
make                              # build all integration_test_*.S -> .bin files
make prog TEST=integration_test_I # build a single test into prog.bin
```

`test/prog.bin` is what `build.py load` and `xmodem_load.py` use. To run all tests automatically with Verilator, see [docs/TESTING.md](docs/TESTING.md).

## Running Programs

### Via JTAG (XSDB)

The PYNQ-Z2 exposes a USB JTAG interface. With the board powered on and connected:

```bash
python3 build.py program   # load bitstream
python3 build.py load      # write test/prog.bin to DDR
python3 build.py run       # release FRISC-V from reset
# or in one step:
python3 build.py go
```

### Via UART (XMODEM boot)

Set switch `SW0` = 1, `SW1` = 0 before powering on, then transfer the binary over the serial port:

```bash
pip install pyserial
python3 scripts/xmodem_load.py --port /dev/ttyUSB0 --baud 115200
# Windows: --port COM3 (check Device Manager)
```

The bootloader prints `[ZSBL] Mode: UART` over the same serial port when ready to receive.

## Boot Modes

The ZSBL (Zero-Stage Boot Loader, embedded in the bitstream ROM) reads the slide switches at reset to select a boot mode:

| Switches (SW1:SW0) | Mode | Action |
| ------------------ | ---- | ------ |
| `00` | DRAM | Jump directly to DDR base (`0x8000_0000`) |
| `01` | UART | Receive binary over UART via XMODEM-CRC, then execute |
| `10` | - | - |
| `11` | Wait | Wait for BTN0 press, then jump to DDR |

The ZSBL source is in `software/zsbl.S`. After modifying it, regenerate the ROM and rebuild the bitstream:

```bash
python3 build.py zsbl-rom
python3 build.py bitstream
```

## Bitstream Artifacts

Pre-built artifacts are committed under `overlay/`:

| File | Description |
| ---- | ----------- |
| `overlay/friscv.bit` | FPGA bitstream |
| `overlay/friscv.hwh` | Hardware handoff (PYNQ overlay system) |
| `overlay/ps7_init.tcl` | Zynq PS7 initialisation (extracted from XSA) |
| `overlay/BOOT.bin` | QSPI boot image (FSBL + bitstream) |
| `overlay/fsbl.elf` | First Stage Boot Loader ELF |

These are regenerated by `python3 build.py bitstream` and must not be edited manually.
