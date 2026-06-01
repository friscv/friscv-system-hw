# Repository Workflow Guide

This document describes the conventions and required steps for working with this repository.

## Cloning

```bash
git clone https://github.com/friscv/FRISCV-system-HW.git
cd friscv-system-hw
```

## Working with git

You probably don't want to be making changes directly on the `main` branch, it is the stable release branch and should only contain known-good code. The `dev` branch is used for making changes.

```bash
# switch to the dev branch
git checkout dev
```

When starting to work on a new feature, create a branch where you can freely commit work-in-progress or untested changes, and make sure your feature works before merging into `dev`.

```bash
# create and switch to a new branch
git checkout -b my-new-feature
```

Merging changes to hardware is more complex than in software, and is mostly a manual process. A way to possibly make this easier is to merge dev into your branch, integrate changes, and merge that back into `dev`. I am honestly not sure what the best way to merge complex changes is. If you have git-related problems, Google or an AI agent may be able to help you. Make sure all tests pass on the merged version too.

> [!CAUTION]
> **Always recreate the Vivado project after switching to another branch.** Using the block design of a different branch can corrupt the Vivado project and make you have to clone the repo again, and have a bad day in general.

## Creating the Vivado Project

The Vivado project is not committed. It must be generated from the TCL scripts in `scripts/`:

```bash
python3 build.py project
```

This sources `scripts/create_project.tcl`, which recreates the project, adds all source files, and rebuilds the block designs from `scripts/export_bd.tcl`. The resulting project directory `friscv-system-hw/` is git-ignored.

To open the project in the GUI afterward:

```bash
python3 build.py open
```

## Adding New RTL or Simulation Files

**Never create new source files from within Vivado.** Vivado writes files into the project directory, which is not tracked by git.

Instead:

1. Create the file manually in the appropriate directory:
   - `rtl/core/` for generic core RTL (pipeline, MMU, arbiter, interfaces, etc.)
   - `rtl/soc/` for reference SoC RTL (AXI adapter, CLINT, remapper, wrappers, etc.)
   - `sim/` for simulation-only files
2. Open the project in Vivado.
3. In the Sources panel, right-click → **Add Sources** and add the file from its location.
4. Verify the file appears under the correct source set (Design Sources or Simulation Sources).

All synthesizable RTL must live under `rtl/core/` or `rtl/soc/`. All simulation files must live under `sim/`. Files outside these directories will not be picked up when the project is recreated from TCL.

## Modifying Block Designs

After making any change to a block design in the Vivado GUI, you **must** export it back to TCL before committing. The `.bd` files are not tracked; only the TCL export is.

```bash
python3 build.py export-bd
```

This runs `scripts/export_bd.tcl` and overwrites the TCL files under `bd/`. Stage and commit those updated TCL files.

> [!CAUTION]
> **Never commit without running export-bd after a block design change.** If the TCL is out of date, other contributors will get a different design when they recreate the project.

## Pre-Commit Checklist

Before committing any RTL or simulation change:

### 1. Run all integration tests

All `integration_test_*.S` files in `test/` must pass. Run them with Verilator:

```bash
make test
```

This verilates `tb_integration`, builds all test binaries, and runs each one. `[RESULT] PASS` must appear for every test.

Architecture compliance tests (`make act`) should also pass before considering a feature complete. See [TESTING.md](TESTING.md) for details.

### 2. Verify the project can be cleanly recreated

Clean the project and recreate it from scratch to confirm that all source files are correctly registered in the TCL scripts and that nothing depends on stale cached state:

```bash
python3 build.py clean
python3 build.py project
```

If the project fails to recreate, find what is missing from `scripts/create_project.tcl` or `scripts/export_bd.tcl` and fix it before committing.

## Delivering a New Feature on FPGA

When a new feature has been verified working on hardware, provide the bitstream artifacts alongside the RTL commit by running:

```bash
python3 build.py bitstream
```

This performs a clean synthesis and implementation run and copies the outputs to `overlay/`:

| File | Description |
| ---- | ----------- |
| `overlay/friscv.bit` | FPGA bitstream |
| `overlay/friscv.hwh` | Hardware handoff file |
| `overlay/ps7_init.tcl` | Zynq PS7 initialisation |
| `overlay/BOOT.bin` | QSPI boot image |
| `overlay/fsbl.elf` | First Stage Boot Loader ELF |

Commit these files together with the RTL change so that the bitstream in `overlay/` always corresponds to the committed source.

## Summary of Rules

| Rule | Command |
| ---- | ------- |
| Create new source files in `rtl/core/`, `rtl/soc/`, or `sim/`, then add them from the Vivado GUI | — |
| Export block designs after any BD change | `python3 build.py export-bd` |
| Make sure all tests pass before committing | `make test && make regress` |
| Verify clean project recreation before committing | `python3 build.py clean && python3 build.py project` |
| Provide updated bitstream when a feature is verified on hardware | `python3 build.py bitstream` |
