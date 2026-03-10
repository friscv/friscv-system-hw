#!/usr/bin/env python3
import subprocess, sys, os, shutil
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

SIM_TIMEOUT_SECONDS = 120

GREEN = "\033[32m"
RED   = "\033[31m"
RESET = "\033[0m"

REPO = Path(__file__).resolve().parent.parent
RTL = REPO / "rtl"
SIM = REPO / "sim"
WORKDIR = REPO / "friscv-system-hw/friscv-system-hw.sim/sim_integration/behav/xsim"
MARKER = WORKDIR / ".build_marker"

def run(cmd):
    r = subprocess.run(cmd, cwd=WORKDIR, shell=True, capture_output=True)
    if r.returncode != 0:
        print(r.stdout.decode(errors="replace"))
        print(r.stderr.decode(errors="replace"))
        sys.exit(r.returncode)

WORKDIR.mkdir(parents=True, exist_ok=True)

pkg = RTL / "friscv_pkg.sv"
sv_files = sorted(f for f in RTL.glob("*.sv") if f != pkg)
v_files = sorted(RTL.glob("*.v"))
src_files = [pkg] + sv_files + v_files + [SIM / "tb_integration.sv"]

def needs_rebuild():
    if not MARKER.exists():
        return True
    t = MARKER.stat().st_mtime
    return any(f.stat().st_mtime > t for f in src_files if f.exists())

if needs_rebuild():
    print("Compiling...")
    run(["xvlog", "--sv", "--work", "xil_defaultlib", str(pkg)])
    run(["xvlog", "--sv", "--work", "xil_defaultlib"] + [str(f) for f in sv_files])
    run(["xvlog",         "--work", "xil_defaultlib"] + [str(f) for f in v_files])
    run(["xvlog", "--sv", "--work", "xil_defaultlib", str(SIM / "tb_integration.sv")])

    print("Elaborating...")
    run(["xelab", "--debug", "typical", "--relax", "--mt", "auto",
         "-L", "xil_defaultlib", "xil_defaultlib.tb_integration",
         "--snapshot", "tb_integration_snapshot"])
    MARKER.touch()
else:
    print("Sources unchanged, skipping compile/elaborate.")

bin_files = sorted((REPO / "test").glob("*.bin"))
if not bin_files:
    print("No .bin files found in test/")
    sys.exit(1)

test_count = len(bin_files)
passed_count = 0
failed_count = 0

print("Simulating...\n")

SRC_XSIM_DIR = WORKDIR / "xsim.dir"

def make_test_dir(test_name: str) -> Path:
    test_dir = WORKDIR / f"run_{test_name}"
    dst = test_dir / "xsim.dir"
    if dst.exists() and dst.stat().st_mtime < MARKER.stat().st_mtime:
        shutil.rmtree(test_dir)
    if not dst.exists():
        shutil.copytree(SRC_XSIM_DIR, dst)
        test_dir.mkdir(exist_ok=True)
    return test_dir

def run_test(bin_file):
    test_name = bin_file.stem
    test_dir = make_test_dir(test_name)
    bin_path = bin_file.as_posix()
    try:
        r = subprocess.run(
            ["xsim", "tb_integration_snapshot", "--testplusarg", f'"PROG_FILE={bin_path}"',
             "--runall", "--log", f"xsim_{test_name}.log"],
            cwd=test_dir, shell=True, capture_output=True, timeout=SIM_TIMEOUT_SECONDS,
        )
        output = r.stdout.decode(errors="replace")
        passed = None
        fail_msg = ""
        for line in output.splitlines():
            if "[RESULT]" in line:
                if "PASS" in line:
                    passed = True
                else:
                    passed = False
                    fail_msg = line[15:-1]
        stderr = r.stderr.decode(errors="replace") if r.returncode != 0 else ""
        return test_name, passed, fail_msg, stderr
    except subprocess.TimeoutExpired:
        return test_name, None, f"timeout after {SIM_TIMEOUT_SECONDS}s", ""

workers = min(os.cpu_count() or 4, len(bin_files))

results = {}
with ThreadPoolExecutor(max_workers=workers) as executor:
    futures = {executor.submit(run_test, bf): bf for bf in bin_files}
    for future in as_completed(futures):
        name, passed, fail_msg, stderr = future.result()
        results[name] = (passed, fail_msg, stderr)

for bin_file in sorted(bin_files, key=lambda f: f.stem):
    name = bin_file.stem
    passed, fail_msg, stderr = results[name]
    print(name)
    if passed is True:
        print(f"{GREEN}PASS{RESET}")
        passed_count += 1
    else:
        print(f"{RED}FAIL{RESET} ({fail_msg or 'no [RESULT] line'})")
        failed_count += 1
    if stderr:
        print(stderr)
    print()

print(f"{GREEN}{passed_count}/{test_count} passed{RESET}  {RED}{failed_count}/{test_count} failed{RESET}")
