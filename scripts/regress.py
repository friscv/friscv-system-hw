#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


REPO = Path(__file__).resolve().parent.parent
ACT_ELFS = REPO / "verif" / "arch-test" / "riscv-arch-test" / "work" / "friscv-full" / "elfs"
SIM_EXE = REPO / "build" / "verilator" / "tb_integration" / "Vtb_integration"
OUT = REPO / "build" / "regress" / "arch-test"
OBJCOPY = "riscv64-unknown-elf-objcopy"
MAX_WORKERS = int(os.environ.get("JOBS", str(os.cpu_count() or 1)))

GREEN = "\033[32m"
RED = "\033[31m"
BOLD = "\033[1m"
RESET = "\033[0m"


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def safe_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", name)


def require_inputs() -> list[Path]:
    if shutil.which(OBJCOPY) is None:
        fail(f"{OBJCOPY} not found in PATH")
    if not SIM_EXE.exists():
        fail(f"Verilator executable not found: {SIM_EXE}. Run `make verilate` first.")
    if not ACT_ELFS.exists():
        fail(f"ACT ELF directory not found: {ACT_ELFS}. Run `make act-build` first.")

    tests = sorted(path for path in ACT_ELFS.rglob("*.elf") if not path.name.endswith(".sig.elf"))
    if not tests:
        fail(f"no ACT tests found under {ACT_ELFS}")
    return tests


def run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, text=True, capture_output=True)


def run_test(elf: Path) -> dict[str, str]:
    name = elf.relative_to(ACT_ELFS).as_posix().removesuffix(".elf")
    run_dir = OUT / "runs" / safe_name(name)
    run_dir.mkdir(parents=True, exist_ok=True)

    bin_file = run_dir / "test.bin"
    log_file = run_dir / "sim.log"

    try:
        completed = run([OBJCOPY, "-O", "binary", str(elf), str(bin_file)], elf.parent)
        if completed.returncode != 0:
            raise RuntimeError(completed.stderr.strip())

        completed = run(
            [
                str(SIM_EXE),
                f"+PROG_FILE={bin_file.resolve().as_posix()}",
            ],
            REPO,
        )
        output = (completed.stdout or "") + (completed.stderr or "")
        log_file.write_text(output, encoding="utf-8")

        print(f"COMPLETED {name}")

        if completed.returncode != 0:
            return {"name": name, "status": "SIM_ERROR", "log": log_file.as_posix()}
        if "[RESULT] PASS" in output or "RVCP-SUMMARY: TEST PASSED" in output:
            return {"name": name, "status": "PASS", "log": log_file.as_posix()}
        return {"name": name, "status": "FAIL", "log": log_file.as_posix()}
    except Exception as exc:
        print(f"ERROR {name}")
        return {"name": name, "status": "ERROR", "message": str(exc)}


def print_result(result: dict[str, str]) -> None:
    status = result["status"]
    name = result["name"]

    if status == "PASS":
        print(f"{GREEN}{BOLD}PASS{RESET} {name}")
        return

    reason = status
    if "message" in result:
        reason = f"{reason}: {result['message']}"
    elif "diff" in result:
        reason = f"{reason}: {result['diff']}"
    elif "log" in result:
        reason = f"{reason}: {result['log']}"

    print(f"{RED}{BOLD}FAIL{RESET} {name} ({reason})")


def main() -> None:
    tests = require_inputs()
    OUT.mkdir(parents=True, exist_ok=True)

    results = []
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        futures = [pool.submit(run_test, elf) for elf in tests]
        for future in as_completed(futures):
            results.append(future.result())

    results.sort(key=lambda result: result["name"])
    print("\n=== RESULTS ===\n")
    for result in results:
        print_result(result)

    report = OUT / "results.json"
    report.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")

    passed = sum(result["status"] == "PASS" for result in results)
    failed = len(results) - passed
    print()
    if failed:
        print(f"{GREEN}{BOLD}{passed} passed{RESET}  {RED}{BOLD}{failed} failed{RESET}")
        print(f"report: {report}")
        sys.exit(1)

    print(f"{GREEN}{BOLD}All {passed} tests passed.{RESET}")
    print(f"report: {report}")


if __name__ == "__main__":
    main()
