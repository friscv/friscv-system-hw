#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed


REPO = Path(__file__).resolve().parent.parent
SIM_EXE = REPO / "build" / "verilator" / "tb_integration" / "Vtb_integration"
TEST_DIR = REPO / "test"
MAX_WORKERS = int(os.environ.get("JOBS", str(os.cpu_count() or 1)))

GREEN = "\033[32m"
RED = "\033[31m"
BOLD = "\033[1m"
RESET = "\033[0m"


def run_test(bin_file: Path) -> dict[str, str | int]:
    completed = subprocess.run(
            [str(SIM_EXE), f"+PROG_FILE={bin_file.resolve().as_posix()}"],
            cwd=REPO,
            text=True,
            capture_output=True,
            timeout=120,
        )

    output = (completed.stdout or "") + (completed.stderr or "")
    result_line = next((line for line in output.splitlines() if "[RESULT]" in line), "")

    return {
        "name": bin_file.stem,
        "returncode": completed.returncode,
        "result_line": result_line,
    }


def main() -> None:
    if not SIM_EXE.exists():
        print(f"error: Verilator executable not found: {SIM_EXE}")
        print("run: make verilate")
        sys.exit(1)

    bin_files = sorted(TEST_DIR.glob("*.bin"))
    if not bin_files:
        print("error: no test/*.bin files found")
        sys.exit(1)

    passed = 0
    failed = 0

    results = []

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        futures = [pool.submit(run_test, bin_file) for bin_file in bin_files]
        for future in as_completed(futures):
            result = future.result()
            name = str(result["name"])
            returncode = int(result["returncode"])
            result_line = str(result["result_line"])

            if returncode == 0 and "PASS" in result_line:
                results.append((name, f"{GREEN}{BOLD}PASS{RESET} {name}"))
                passed += 1
            else:
                reason = result_line or f"return code {returncode}"
                results.append((name, f"{RED}{BOLD}FAIL{RESET} {name} ({reason})"))
                failed += 1

    for _, line in sorted(results):
        print(line)

    print()
    if failed:
        print(f"{GREEN}{BOLD}{passed} passed{RESET}  {RED}{BOLD}{failed} failed{RESET}")
        sys.exit(1)

    print(f"{GREEN}{BOLD}All {passed} tests passed.{RESET}")


if __name__ == "__main__":
    main()
