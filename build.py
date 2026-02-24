#!/usr/bin/env python3
"""
build.py - Cross-platform build script for FRISCV-system-HW
Replaces build.ps1 (Windows) and Makefile (Linux/macOS)

Usage:
  python build.py <target> [options]

Targets:
  project            Create Vivado project
  export-bd          Export block designs to TCL
  bitstream          Build bitstream and deploy artifacts to overlay/
  program            Program FPGA via JTAG
  status             Check FPGA status
  load [--bin FILE]  Load binary to memory (default: test/prog.bin)
  run                Release FRISC-V core from reset
  go [--bin FILE]    Program FPGA, load binary, and run
  open               Open project in Vivado GUI
  clean              Remove project and generated files
  zsbl-rom [TEST]    Generate ZSBL ROM from software/zsbl.S, or
                       from test/<TEST>.S when TEST is given
  help               Show this help
"""

import argparse
import fnmatch
import hashlib
import os
import platform
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PROJECT_NAME = "friscv-system-hw"
ROOT = Path(__file__).parent.resolve()
PROJECT_DIR = ROOT / PROJECT_NAME
SCRIPTS_DIR = ROOT / "scripts"
OVERLAY_DIR = ROOT / "overlay"


# ---------------------------------------------------------------------------
# Terminal colors (ANSI, enabled on Windows 10+ via VT100)
# ---------------------------------------------------------------------------
def _supports_color() -> bool:
    if not hasattr(sys.stdout, "isatty") or not sys.stdout.isatty():
        return False
    if os.name == "nt":
        try:
            import ctypes
            kernel = ctypes.windll.kernel32
            # Enable ENABLE_VIRTUAL_TERMINAL_PROCESSING
            kernel.SetConsoleMode(kernel.GetStdHandle(-11), 7)
            return True
        except Exception:
            return False
    return True


_COLOR = _supports_color()


def _c(text: str, code: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _COLOR else text


def info(msg: str):     print(_c(msg, "36"))          # cyan
def success(msg: str):  print(_c(msg, "32"))          # green
def warn(msg: str):     print(_c("WARNING: " + msg, "33"), file=sys.stderr)
def section(msg: str):  print(_c(f"\n=== {msg} ===", "32"))


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------
def die(msg: str, code: int = 1) -> None:
    print(_c(f"ERROR: {msg}", "31"), file=sys.stderr)
    sys.exit(code)


def run(cmd: list, **kwargs) -> None:
    """Run a command, exiting on non-zero return code."""
    print(_c("  $ " + " ".join(str(c) for c in cmd), "90"))
    # On Windows, Vivado/XSDB are .bat files which require shell=True to launch.
    if os.name == "nt":
        kwargs.setdefault("shell", True)
    result = subprocess.run(cmd, **kwargs)
    if result.returncode != 0:
        sys.exit(result.returncode)


def vivado_batch(script: Path, *args: str) -> None:
    info(f"Running Vivado script: {script}")
    cmd = [
        "vivado", "-mode", "batch", "-nolog", "-nojournal",
        "-source", script.as_posix(),
    ]
    if args:
        cmd += ["-tclargs", *args]
    run(cmd)


def xsdb_run(script: Path, *args: str) -> None:
    if not shutil.which("xsdb"):
        die("xsdb not found in PATH.")
    info(f"Running XSDB script: {script}")
    run(["xsdb", script.as_posix(), *args])


def fmt_size(path: Path) -> str:
    size = float(path.stat().st_size)
    for unit in ("B", "KB", "MB", "GB"):
        if size < 1024:
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} TB"


def md5(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def check_vivado() -> None:
    if not shutil.which("vivado"):
        die("vivado not found in PATH. Please add the Vivado bin directory to PATH.")


def check_project() -> None:
    xpr = PROJECT_DIR / f"{PROJECT_NAME}.xpr"
    if not xpr.exists():
        die(f"Project not found ({xpr}).\nRun 'python build.py project' first.")


def remove_if_exists(path: Path) -> None:
    if path.is_dir():
        shutil.rmtree(path)
    elif path.exists():
        path.unlink()


def extract_from_xsa(xsa: Path, pattern: str, dest: Path) -> bool:
    """Read first entry matching *pattern* from an XSA (ZIP) file and write it to *dest*."""
    with zipfile.ZipFile(xsa, "r") as z:
        matches = [n for n in z.namelist() if fnmatch.fnmatch(os.path.basename(n), pattern)]
        if not matches:
            return False
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(z.read(matches[0]))
        return True


# ---------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------
def target_project() -> None:
    check_vivado()
    section("CREATING VIVADO PROJECT")
    vivado_batch(SCRIPTS_DIR / "create_project.tcl")
    success(f"Done! Project created at: {PROJECT_DIR / (PROJECT_NAME + '.xpr')}")


def target_export_bd() -> None:
    check_vivado()
    check_project()
    section("EXPORTING BLOCK DESIGNS TO TCL")
    vivado_batch(SCRIPTS_DIR / "export_bd.tcl")


def target_bitstream() -> None:
    check_vivado()
    check_project()

    # --- clean old artifacts ---
    section("CLEANING OLD BITSTREAM FILES")
    runs_dir = PROJECT_DIR / f"{PROJECT_NAME}.runs"
    for sub in [
        "impl_1",
        "synth_1",
        "design_1_friscv_soc_wrapper_0_synth_1",
        "design_1_ps_0_synth_1",
    ]:
        remove_if_exists(runs_dir / sub)

    remove_if_exists(PROJECT_DIR / f"{PROJECT_NAME}.cache")
    remove_if_exists(PROJECT_DIR / f"{PROJECT_NAME}.gen")

    bd_ip_dir = ROOT / "bd/design_1/ip/design_1_friscv_soc_wrapper_0"
    if bd_ip_dir.exists():
        for f in bd_ip_dir.glob("*.dcp"):
            f.unlink()
        synth_dir = bd_ip_dir / "synth"
        if synth_dir.exists():
            for f in synth_dir.glob("*.v"):
                f.unlink()

    xsa_file = ROOT / f"{PROJECT_NAME}.xsa"
    remove_if_exists(xsa_file)
    print("Old files cleaned.")

    # --- build ---
    section("BUILDING NEW BITSTREAM")
    vivado_batch(SCRIPTS_DIR / "build_bitstream.tcl")

    # --- deploy ---
    section(f"DEPLOYING ARTIFACTS TO {OVERLAY_DIR}")
    OVERLAY_DIR.mkdir(parents=True, exist_ok=True)

    # .bit file
    impl_dir = PROJECT_DIR / f"{PROJECT_NAME}.runs/impl_1"
    bit_files = list(impl_dir.rglob("*.bit")) if impl_dir.exists() else []
    if not bit_files:
        die("Bitstream generation failed — no .bit file found.")
    bit_dest = OVERLAY_DIR / "friscv.bit"
    shutil.copy2(bit_files[0], bit_dest)
    info(f"Copied bitstream to {bit_dest}")

    # .hwh file (try project tree first, then XSA)
    hwh_dest = OVERLAY_DIR / "friscv.hwh"
    hwh_files = list(PROJECT_DIR.rglob("*.hwh"))
    if hwh_files:
        shutil.copy2(hwh_files[0], hwh_dest)
    else:
        warn(".hwh not found directly. Attempting to extract from XSA...")
        xsa_file = ROOT / f"{PROJECT_NAME}.xsa"
        if not xsa_file.exists():
            die("Could not find .hwh or .xsa file!")
        if not extract_from_xsa(xsa_file, "*.hwh", hwh_dest):
            die("Could not find .hwh inside XSA file.")
        info("Extracted HWH from XSA.")

    # ps7_init.tcl from XSA
    xsa_file = ROOT / f"{PROJECT_NAME}.xsa"
    if xsa_file.exists():
        info("Extracting ps7_init.tcl from XSA...")
        if extract_from_xsa(xsa_file, "ps7_init.tcl", SCRIPTS_DIR / "ps7_init.tcl"):
            info(f"Extracted ps7_init.tcl to {SCRIPTS_DIR}/")
        remove_if_exists(xsa_file)

    # summary
    section("BUILD COMPLETE")
    print(f"Bitstream:        {bit_dest}  ({fmt_size(bit_dest)})  md5={md5(bit_dest)}")
    if hwh_dest.exists():
        print(f"Hardware handoff: {hwh_dest}  ({fmt_size(hwh_dest)})")


def target_program() -> None:
    check_vivado()
    bit_path = OVERLAY_DIR / "friscv.bit"
    if not bit_path.exists():
        die("Bitstream not found. Run 'python build.py bitstream' first.")
    section("PROGRAMMING FPGA VIA JTAG")
    info(f"Bitstream: {bit_path}  md5={md5(bit_path)}")
    vivado_batch(SCRIPTS_DIR / "program_fpga.tcl", bit_path.as_posix())
    success("FPGA programmed successfully!")


def target_status() -> None:
    section("CHECKING FPGA STATUS")
    xsdb_run(SCRIPTS_DIR / "check_status.tcl")


def target_load(prog_bin: Path) -> None:
    if not prog_bin.exists():
        die(f"Binary file '{prog_bin}' not found.")
    section("LOADING PROGRAM TO MEMORY")
    info(f"Binary:  {prog_bin}")
    info("Address: 0x00100000")
    xsdb_run(SCRIPTS_DIR / "load_program.tcl", prog_bin.as_posix(), "0x00100000")


def target_run() -> None:
    section("RELEASING FRISC-V CORE FROM RESET")
    xsdb_run(SCRIPTS_DIR / "release_reset.tcl")


def target_go(prog_bin: Path) -> None:
    target_program()
    target_load(prog_bin)
    target_run()


def target_open() -> None:
    check_vivado()
    xpr = PROJECT_DIR / f"{PROJECT_NAME}.xpr"
    if not xpr.exists():
        info("Project not found. Creating first...")
        target_project()
    info(f"Opening Vivado GUI: {xpr}")
    cmd = ["vivado", "-mode", "gui", "-nolog", "-nojournal", str(xpr)]
    if platform.system() == "Windows":
        subprocess.Popen(
            cmd,
            shell=True,
            creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP,
        )
    else:
        subprocess.Popen(cmd, start_new_session=True)


def target_clean() -> None:
    section("CLEANING PROJECT")
    xil_dir = ROOT / ".Xil"
    if xil_dir.exists():
        info("Removing .Xil directory...")
        shutil.rmtree(xil_dir)
    if PROJECT_DIR.exists():
        info("Removing project directory...")
        shutil.rmtree(PROJECT_DIR)
    info("Cleaning generated block design files...")
    bd_dir = ROOT / "bd"
    if bd_dir.exists():
        for f in bd_dir.rglob("*"):
            if f.is_file() and f.suffix != ".tcl":
                f.unlink()
        # Remove empty directories bottom-up
        for d in sorted(bd_dir.rglob("*"), key=lambda p: len(p.parts), reverse=True):
            if d.is_dir():
                try:
                    d.rmdir()
                except OSError:
                    pass
    success("CLEAN COMPLETE")


def target_zsbl_rom(test_name=None) -> None:
    cmd = [
        sys.executable,
        str(SCRIPTS_DIR / "gen_zsbl_rom.py"),
        "",  # source placeholder
        "rtl/friscv_zsbl_rom.sv",
        "--start-addr", "0x1000",
    ]
    if test_name:
        src = ROOT / f"test/{test_name}.S"
        if not src.exists():
            die(f"Test file not found: {src}")
        cmd[2] = str(src)
        info(f"Generating ZSBL ROM from {src}...")
    else:
        src = ROOT / "software/zsbl.S"
        if not src.exists():
            die("software/zsbl.S not found.")
        cmd[2] = str(src)
        cmd += ["--linker-script", "software/zsbl_linker.ld"]
        info(f"Generating ZSBL ROM from {src}...")
    run(cmd)


def print_help() -> None:
    print("""
FRISCV Hardware Project - PYNQ-Z2
Cross-platform build script

Usage: python build.py <target> [options]

Targets:
  project            Create Vivado project
  export-bd          Export block designs to TCL
  bitstream          Build bitstream and deploy to overlay/
  program            Program FPGA via JTAG
  status             Check FPGA status
  load               Load binary to DRAM (default: test/prog.bin)
  run                Release FRISC-V core from reset
  go                 Program FPGA, load binary, and run
  open               Open project in Vivado GUI
  clean              Remove project and generated files
  zsbl-rom [TEST]    Generate ZSBL ROM:
                       (no TEST)  from software/zsbl.S
                       TEST       from test/<TEST>.S  (e.g. zsbl-rom halt)
  help               Show this help

Options:
  --bin FILE         Binary file path for load/go (default: test/prog.bin)

Typical workflow:
  python build.py project    # Create Vivado project
  python build.py bitstream  # Build bitstream (clean + compile + deploy)
  python build.py program    # Program FPGA via JTAG
  python build.py load       # Load software to DRAM
  python build.py run        # Release FRISC-V from reset
  -- or --
  python build.py go         # program + load + run in one step
""")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(
        prog="build.py",
        description="FRISCV build system",
        add_help=False,
    )
    parser.add_argument("target", nargs="?", default="project",
                        help="Build target (default: project)")
    parser.add_argument("target_arg", nargs="?", default=None,
                        help="Optional positional argument (e.g. test name for zsbl-rom)")
    parser.add_argument("--bin", dest="prog_bin", default="test/prog.bin",
                        metavar="FILE",
                        help="Binary file for load/go targets (default: test/prog.bin)")
    parser.add_argument("-h", "--help", action="store_true")

    args = parser.parse_args()

    if args.help or args.target in ("help", "-h", "--help"):
        print_help()
        return

    prog_bin = Path(args.prog_bin)

    targets = {
        "project":   target_project,
        "export-bd": target_export_bd,
        "bitstream": target_bitstream,
        "program":   target_program,
        "status":    target_status,
        "load":      lambda: target_load(prog_bin),
        "run":       target_run,
        "go":        lambda: target_go(prog_bin),
        "open":      target_open,
        "clean":     target_clean,
        "zsbl-rom":  lambda: target_zsbl_rom(args.target_arg),
    }

    t = args.target.lower()
    if t not in targets:
        die(f"Unknown target '{t}'.\nAvailable targets: {', '.join(targets)}")

    targets[t]()


if __name__ == "__main__":
    main()
