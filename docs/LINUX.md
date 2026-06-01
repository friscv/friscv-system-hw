# Linux Firmware Build

The `software/` directory builds a complete Linux firmware image for FRISC-V. The output is a single binary that can be loaded and run like any other test program.

## Dependencies

| Tool | Version / suffix | How to check |
| ---- | ---------------- | ------------ |
| `clang` | `-21` (configurable with `LLVM_SUFFIX`) | `clang-21 --version` |
| `lld` | same suffix | `lld-21 --version` |
| `llvm-ar`, `llvm-nm`, `llvm-ranlib`, `llvm-strip` | same suffix | `llvm-ar-21 --version` |
| CMake | | `cmake --version` |
| Make | | `make --version` |
| `fakeroot` | | `fakeroot --version` |
| `cpio` | | `cpio --version` |
| `gzip` | | `gzip --version` |
| `git` | | `git --version` |

The LLVM toolchain suffix defaults to `-21`. Override it with `make LLVM_SUFFIX=-18` (or whichever version you have installed).

## Build

```bash
cd software
make
```

On the first run this clones the upstream sources (Linux, OpenSBI, toybox, musl, LLVM compiler-rt). Subsequent builds are incremental.

The build chain is: compiler-rt + musl, toybox, initramfs, Linux kernel, OpenSBI (`fw_payload.bin`), `test/prog.bin`.

To clean build artifacts without removing cloned sources:

```bash
make clean
```

To remove everything including cloned sources:

```bash
make distclean
```

## Load and Run

The firmware is copied to `test/prog.bin`, so the standard load flow works:

```bash
python3 build.py go -t
```

Expected output: OpenSBI banner, Linux boot log, then:

```text
FRISCV Linux booted successfully!
```

followed by a shell prompt.

## Device Tree

`software/friscv.dts` describes the SoC hardware for Linux. It is compiled to `software/friscv.dtb` by the kernel's built-in DTC during the build.

Key nodes:

| Node | Address | Description |
| ---- | ------- | ----------- |
| `memory` | `0x80000000` | 256 MB DDR |
| `clint` | `0x02000000` | Timer and software interrupts |
| `serial` | `0x10000000` | NS16550A UART |

After modifying `friscv.dts`, rebuild with `make dtb` (or just `make`, which picks up the change).
