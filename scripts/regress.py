#!/usr/bin/env python3
from __future__ import annotations

import difflib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parent.parent
ACT_BUILD = REPO / "verif" / "arch-test" / "riscv-arch-test" / "work" / "friscv-rv32ia" / "build"
SIM_EXE = REPO / "build" / "verilator" / "tb_integration" / "Vtb_integration"
OUT = REPO / "build" / "regress" / "arch-test"
OBJCOPY = "riscv64-unknown-elf-objcopy"
NM = "riscv64-unknown-elf-nm"

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
    if shutil.which(NM) is None:
        fail(f"{NM} not found in PATH")
    if not SIM_EXE.exists():
        fail(f"Verilator executable not found: {SIM_EXE}. Run `make verilate` first.")
    if not ACT_BUILD.exists():
        fail(f"ACT build directory not found: {ACT_BUILD}")

    tests = sorted(ACT_BUILD.rglob("*.sig.elf"))
    if not tests:
        fail(f"no ACT tests found under {ACT_BUILD}")
    return tests


def run(cmd: list[str], cwd: Path) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, text=True, capture_output=True)


def signature_bounds(elf: Path) -> tuple[int, int]:
    completed = run([NM, "-n", str(elf)], elf.parent)
    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip())

    symbols: dict[str, int] = {}
    for line in completed.stdout.splitlines():
        fields = line.split()
        if len(fields) >= 3 and fields[2] in ("begin_signature", "end_signature"):
            symbols[fields[2]] = int(fields[0], 16)

    if "begin_signature" not in symbols or "end_signature" not in symbols:
        raise RuntimeError("ELF does not define begin_signature/end_signature")
    return symbols["begin_signature"], symbols["end_signature"]


def read_sig(path: Path) -> list[str]:
    return [line.strip().lower() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def compare_signatures(golden: Path, dut: Path, diff_path: Path) -> bool:
    golden_lines = read_sig(golden)
    dut_lines = read_sig(dut)
    if golden_lines == dut_lines:
        return True

    diff = difflib.unified_diff(
        golden_lines,
        dut_lines,
        fromfile=golden.as_posix(),
        tofile=dut.as_posix(),
        lineterm="",
    )
    diff_path.write_text("\n".join(diff) + "\n", encoding="utf-8")
    return False


def run_test(elf: Path) -> dict[str, str]:
    name = elf.relative_to(ACT_BUILD).as_posix().removesuffix(".sig.elf")
    run_dir = OUT / "runs" / safe_name(name)
    run_dir.mkdir(parents=True, exist_ok=True)

    bin_file = run_dir / "test.bin"
    dut_sig = run_dir / "dut.sig"
    diff_file = run_dir / "diff.txt"
    log_file = run_dir / "sim.log"
    golden_sig = Path(str(elf).removesuffix(".elf"))

    try:
        completed = run([OBJCOPY, "-O", "binary", str(elf), str(bin_file)], elf.parent)
        if completed.returncode != 0:
            raise RuntimeError(completed.stderr.strip())

        sig_start, sig_end = signature_bounds(elf)
        completed = run(
            [
                str(SIM_EXE),
                f"+PROG_FILE={bin_file.resolve().as_posix()}",
                f"+SIG_START={sig_start:08x}",
                f"+SIG_END={sig_end:08x}",
                f"+SIG_OUT={dut_sig.resolve().as_posix()}",
            ],
            REPO,
        )
        log_file.write_text((completed.stdout or "") + (completed.stderr or ""), encoding="utf-8")

        if completed.returncode != 0:
            return {"name": name, "status": "SIM_ERROR", "log": log_file.as_posix()}
        if not dut_sig.exists():
            return {"name": name, "status": "NO_SIGNATURE", "log": log_file.as_posix()}
        if compare_signatures(golden_sig, dut_sig, diff_file):
            return {"name": name, "status": "PASS", "log": log_file.as_posix()}
        return {"name": name, "status": "FAIL", "diff": diff_file.as_posix(), "log": log_file.as_posix()}
    except Exception as exc:
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
    for elf in tests:
        result = run_test(elf)
        results.append(result)
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
