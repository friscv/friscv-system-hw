#!/usr/bin/env python3
import subprocess, sys
from pathlib import Path

GREEN = "\033[32m"
RED   = "\033[31m"
RESET = "\033[0m"

REPO = Path(__file__).resolve().parent.parent
RTL = REPO / "rtl"
SIM = REPO / "sim"
WORKDIR = REPO / "friscv-system-hw/friscv-system-hw.sim/sim_integration/behav/xsim"

def run(cmd):
    r = subprocess.run(cmd, cwd=WORKDIR, shell=True, capture_output=True)
    if r.returncode != 0:
        print(r.stdout.decode(errors="replace"))
        print(r.stderr.decode(errors="replace"))
        sys.exit(r.returncode)

WORKDIR.mkdir(parents=True, exist_ok=True)

print("Compiling...")
pkg = RTL / "friscv_pkg.sv"
sv_files = sorted(f for f in RTL.glob("*.sv") if f != pkg)
v_files = sorted(RTL.glob("*.v"))

run(["xvlog", "--sv", "--work", "xil_defaultlib", str(pkg)])
run(["xvlog", "--sv", "--work", "xil_defaultlib"] + [str(f) for f in sv_files])
run(["xvlog",         "--work", "xil_defaultlib"] + [str(f) for f in v_files])
run(["xvlog", "--sv", "--work", "xil_defaultlib", str(SIM / "tb_integration.sv")])

print("Elaborating...")
run(["xelab", "--debug", "typical", "--relax", "--mt", "auto",
     "-L", "xil_defaultlib", "xil_defaultlib.tb_integration",
     "--snapshot", "tb_integration_snapshot"])

bin_files = sorted((REPO / "test").glob("*.bin"))
if not bin_files:
    print("No .bin files found in test/")
    sys.exit(1)

test_count = len(bin_files)
passed_count = 0
failed_count = 0

print("Simulating...\n")

for bin_file in bin_files:
    bin_path = bin_file.as_posix()
    print(f"{bin_file.name[:-4]}")
    r = subprocess.run(
        ["xsim", "tb_integration_snapshot", "--testplusarg", f'"PROG_FILE={bin_path}"', "--runall"],
        cwd=WORKDIR, shell=True, capture_output=True,
    )
    output = r.stdout.decode(errors="replace")
    for line in output.splitlines():
        if "[RESULT]" in line:
            if "PASS" in line:
                print(f"{GREEN}PASS{RESET}")
                passed_count += 1
            else:
                print(f"{RED}FAIL{RESET} {line[15:-1]}")
                failed_count += 1

    if r.returncode != 0:
        print(r.stderr.decode(errors="replace"))
    
    print()

print(f"{GREEN}{passed_count}/{test_count} passed{RESET}  {RED}{failed_count}/{test_count} failed{RESET}")
