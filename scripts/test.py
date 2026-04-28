#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parent.parent
SIM_EXE = REPO / "build" / "verilator" / "tb_integration" / "Vtb_integration"
TEST_DIR = REPO / "test"

GREEN = "\033[32m"
RED = "\033[31m"
BOLD = "\033[1m"
RESET = "\033[0m"


def main() -> None:
    if not SIM_EXE.exists():
        print(f"error: Verilator executable not found: {SIM_EXE}")
        print("run: make verilate")
        sys.exit(1)

    bin_files = sorted(TEST_DIR.glob("*.bin"))
    if not bin_files:
        print("error: no test/*.bin files found")
        print("run: make -C test")
        sys.exit(1)

    passed = 0
    failed = 0

    for bin_file in bin_files:
        completed = subprocess.run(
            [str(SIM_EXE), f"+PROG_FILE={bin_file.resolve().as_posix()}"],
            cwd=REPO,
            text=True,
            capture_output=True,
            timeout=120,
        )

        output = (completed.stdout or "") + (completed.stderr or "")
        result_line = next((line for line in output.splitlines() if "[RESULT]" in line), "")

        if completed.returncode == 0 and "PASS" in result_line:
            print(f"{GREEN}{BOLD}PASS{RESET} {bin_file.stem}")
            passed += 1
        else:
            reason = result_line or f"return code {completed.returncode}"
            print(f"{RED}{BOLD}FAIL{RESET} {bin_file.stem} ({reason})")
            failed += 1

    print()
    if failed:
        print(f"{GREEN}{BOLD}{passed} passed{RESET}  {RED}{BOLD}{failed} failed{RESET}")
        sys.exit(1)

    print(f"{GREEN}{BOLD}All {passed} tests passed.{RESET}")


if __name__ == "__main__":
    main()
