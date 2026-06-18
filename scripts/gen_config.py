#!/usr/bin/env python3
"""
Sources of values, applied in order (later overrides earlier):
  1. Schema defaults (defined below; the current committed configuration).
  2. A named preset  (--preset minimal | full).
  3. A TOML file     (--config PATH) whose keys are the SystemVerilog
                     parameter names, e.g. `ENABLE_MMU = 1`.

Usage:
  python gen_config.py --preset full              # splice 'full' into the pkg
  python gen_config.py --config config/x.toml     # splice from a TOML
  python gen_config.py --preset minimal --print   # preview, don't write
  python gen_config.py --preset full --check      # fail if pkg is stale
  python gen_config.py --preset full --emit-config config/friscv_config.toml
  python gen_config.py --list                     # list presets
"""

import argparse
import sys
import tomllib
from collections.abc import Callable, Sequence
from pathlib import Path
from typing import Any, NoReturn

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PKG = ROOT / "rtl" / "core" / "friscv_pkg.sv"

START_MARKER = "--- Configurable parameter definitions start ---"
END_MARKER = "--- Configurable parameter definitions end ---"

INDENT = "    "
# Width of the type column so `int` and `logic` line up (matches hand style).
TYPE_W = 5


# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------
def pow2_gt1(v: object) -> bool:
    return isinstance(v, int) and v > 1 and (v & (v - 1)) == 0


class Param:
    def __init__(
        self,
        name: str,
        sv_type: str,
        default: int | None = None,
        comment: Sequence[str] = (),
        validate: Callable[[int], bool] | None = None,
        validate_msg: str = "",
        derived: str | None = None,
    ) -> None:
        self.name = name
        self.sv_type = sv_type            # "int" or "logic"
        self.default = default            # schema fallback value
        self.comment = list(comment)      # comment lines emitted before the param
        self.validate = validate          # predicate(value) -> bool
        self.validate_msg = validate_msg
        self.derived = derived            # SV expression; if set, not user-settable


class Note:
    def __init__(self, *lines: str) -> None:
        self.lines = lines


class Blank:
    pass


LAYOUT: list[Blank | Note | Param] = [
    Blank(),
    Param(
        "ZSBL_ROM_SIZE_BYTES",
        "int",
        default=1024,
        comment=["Set this to 0 for debugging"]
    ),
    Blank(),
    Note("Performance optimizations"),
    Param(
        "ENABLE_EARLY_JAL_JALR",
        "logic",
        default=1,
        comment=["If enabled, execute JAL(R) in IF instead of EX"]
    ),
    Param(
        "ENABLE_L2_BUFFER",
        "logic",
        default=1,
        comment=["If enabled, buffer outbound requests to improve timing"]
    ),
    Blank(),
    Note("Memory protection and address translation"),
    Param(
        "ENABLE_MMU",
        "logic",
        default=1
    ),
    Param(
        "ENFORCE_PMP",
        "logic",
        default=1
    ),
    Param(
        "PMP_ENTRIES",
        "int",
        default=16
    ),
    Param(
        "ITLB_ENTRIES",
        "int",
        default=4,
        comment=["Must be a power of 2 greater than 1"],
        validate=pow2_gt1,
        validate_msg="must be a power of 2 greater than 1"
    ),
    Param(
        "DTLB_ENTRIES",
        "int",
        default=16,
        validate=pow2_gt1,
        validate_msg="must be a power of 2 greater than 1"
    ),
    Param(
        "ENABLE_FINE_TLB_FLUSH",
        "logic",
        default=1,
        comment=["If not enabled, any sfence.vma will flush all TLB entries"]
    ),
    Blank(),
    Note("Extension selection"),
    Param(
        "ENABLE_MUL",
        "logic",
        default=1
    ),
    Param(
        "ENABLE_DIV",
        "logic",
        default=1
    ),
    Param(
        "ENABLE_EXTENSION_M",
        "logic",
        derived="1'(ENABLE_MUL && ENABLE_DIV)",
        comment=["M extension configured by choosing MUL and DIV above"]
    ),
    Param(
        "ENABLE_EXTENSION_A",
        "logic",
        default=1
    ),
    Note("ALWAYS ENABLED localparam logic ENABLE_EXTENSION_ZICSR = 1;"),
    Param(
        "ENABLE_EXTENSION_ZIFENCEI",
        "logic",
        default=1
    ),
    Note("ALWAYS ENABLED localparam logic ENABLE_EXTENSION_SSTC = 1;"),
    Blank(),
    Param(
        "ENABLE_HALT_ON_END_ADDRESS",
        "logic",
        default=1,
        comment=["If enabled, a write to END_ADDRESS will stall the core until reset"]),
    Param(
        "ENABLE_HALT_ON_ENTER_EBREAK",
        "logic",
        default=0,
        comment=["If enabled, entering an EBREAK instruction will halt the core until reset"]),
    Param(
        "ENABLE_HALT_ON_RET_FROM_EBREAK",
        "logic",
        default=0,
        comment=["If enabled, the first MRET or SRET after entering an EBREAK handler will halt the core until reset"]
    ),
    Blank(),
]

PARAMS: dict[str, Param] = {it.name: it for it in LAYOUT if isinstance(it, Param)}
SETTABLE: list[Param] = [p for p in PARAMS.values() if p.derived is None]


# ---------------------------------------------------------------------------
# Presets
# ---------------------------------------------------------------------------
PRESETS: dict[str, dict[str, int]] = {
    # Full-featured core
    "full": {
        "ZSBL_ROM_SIZE_BYTES": 1024,
        "ENABLE_EARLY_JAL_JALR": 1,
        "ENABLE_L2_BUFFER": 1,
        "ENABLE_MMU": 1,
        "ENFORCE_PMP": 1,
        "PMP_ENTRIES": 16,
        "ITLB_ENTRIES": 16,
        "DTLB_ENTRIES": 16,
        "ENABLE_FINE_TLB_FLUSH": 1,
        "ENABLE_MUL": 1,
        "ENABLE_DIV": 1,
        "ENABLE_EXTENSION_A": 1,
        "ENABLE_EXTENSION_ZIFENCEI": 1,
        "ENABLE_HALT_ON_END_ADDRESS": 1,
        "ENABLE_HALT_ON_ENTER_EBREAK": 0,
        "ENABLE_HALT_ON_RET_FROM_EBREAK": 0,
    },
    # Smallest functional RV32I_Zicsr core
    "minimal": {
        "ZSBL_ROM_SIZE_BYTES": 0,
        "ENABLE_EARLY_JAL_JALR": 1,
        "ENABLE_L2_BUFFER": 0,
        "ENABLE_MMU": 0,
        "ENFORCE_PMP": 0,
        "PMP_ENTRIES": 0,
        "ITLB_ENTRIES": 2,
        "DTLB_ENTRIES": 2,
        "ENABLE_FINE_TLB_FLUSH": 0,
        "ENABLE_MUL": 0,
        "ENABLE_DIV": 0,
        "ENABLE_EXTENSION_A": 0,
        "ENABLE_EXTENSION_ZIFENCEI": 0,
        "ENABLE_HALT_ON_END_ADDRESS": 1,
        "ENABLE_HALT_ON_ENTER_EBREAK": 0,
        "ENABLE_HALT_ON_RET_FROM_EBREAK": 0,
    },
}


# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
def die(msg: str) -> NoReturn:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def warn(msg: str) -> None:
    print(f"WARNING: {msg}", file=sys.stderr)


def coerce(param: Param, raw: object) -> int:
    """Coerce a raw config/preset value to the param's SV type."""
    if param.sv_type == "logic":
        if isinstance(raw, bool):
            return 1 if raw else 0
        if isinstance(raw, int) and raw in (0, 1):
            return raw
        die(f"{param.name}: logic value must be 0/1 or true/false, got {raw!r}")
    if param.sv_type == "int":
        if isinstance(raw, bool) or not isinstance(raw, int):
            die(f"{param.name}: expected an integer, got {raw!r}")
        return raw
    die(f"{param.name}: unknown SV type {param.sv_type!r}")


def fmt_value(param: Param, value: int) -> str:
    return str(value)  # logic renders as 0/1, int as decimal


# ---------------------------------------------------------------------------
# Value resolution + validation
# ---------------------------------------------------------------------------
def resolve(preset_name: str | None = None, config_path: str | None = None) -> dict[str, int]:
    """Build the {name: value} map for all settable params."""
    values: dict[str, int | None] = {p.name: p.default for p in SETTABLE}

    if preset_name:
        if preset_name not in PRESETS:
            die(f"unknown preset {preset_name!r}. Available: {', '.join(PRESETS)}")
        for k, v in PRESETS[preset_name].items():
            values[k] = v

    if config_path:
        cfg = load_config(config_path)
        for k, v in cfg.items():
            values[k] = v

    return {p.name: coerce(p, values[p.name]) for p in SETTABLE}


def load_config(path: str | Path) -> dict[str, Any]:
    path = Path(path)
    if not path.exists():
        die(f"config file not found: {path}")
    with path.open("rb") as f:
        try:
            data = tomllib.load(f)
        except tomllib.TOMLDecodeError as e:
            die(f"failed to parse {path}: {e}")
    settable = {p.name for p in SETTABLE}
    unknown = sorted(set(data) - settable)
    if unknown:
        derived_typo = [u for u in unknown if u in PARAMS]
        hint = ""
        if derived_typo:
            hint = (f" ({', '.join(derived_typo)} is a derived parameter and cannot be set directly)")
        die(f"unknown key(s) in {path}: {', '.join(unknown)}{hint}\nvalid keys: {', '.join(sorted(settable))}")
    return data


def validate(values: dict[str, int]) -> None:
    for p in SETTABLE:
        v = values[p.name]
        if p.validate and not p.validate(v):
            die(f"{p.name} = {v}: {p.validate_msg}")

    if not values["ENABLE_MMU"] and values["ENABLE_FINE_TLB_FLUSH"]:
        warn("ENABLE_FINE_TLB_FLUSH has no effect while ENABLE_MMU = 0.")
    if values["ENABLE_MUL"] != values["ENABLE_DIV"]:
        warn("ENABLE_MUL != ENABLE_DIV: the M extension needs both; ENABLE_EXTENSION_M will be 0.")


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------
def render_block(values: dict[str, int]) -> str:
    lines: list[str] = []
    for item in LAYOUT:
        if isinstance(item, Blank):
            lines.append("")
        elif isinstance(item, Note):
            lines += [f"{INDENT}// {ln}" for ln in item.lines]
        elif isinstance(item, Param):
            lines += [f"{INDENT}// {c}" for c in item.comment]
            val = item.derived if item.derived else fmt_value(item, values[item.name])
            lines.append(f"{INDENT}localparam {item.sv_type:<{TYPE_W}} {item.name} = {val};")
    return "\n".join(lines)


def splice(pkg_text: str, block: str) -> str:
    lines = pkg_text.split("\n")
    start: int | None = None
    end: int | None = None
    for i, ln in enumerate(lines):
        if START_MARKER in ln:
            start = i
        elif END_MARKER in ln:
            end = i
            break
    if start is None or end is None:
        die("could not find both configuration markers in the package file.")
    if end <= start:
        die("end marker appears before start marker.")
    new_lines = lines[:start + 1] + block.split("\n") + lines[end:]
    return "\n".join(new_lines)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--preset", choices=sorted(PRESETS), help="base preset to start from")
    ap.add_argument("--config", help="TOML file with parameter overrides")
    ap.add_argument("--pkg", default=str(DEFAULT_PKG), help=f"package file to edit (default: {DEFAULT_PKG})")
    ap.add_argument("--check", action="store_true", help="do not write; exit 1 if the package would change")
    ap.add_argument("--print", dest="to_stdout", action="store_true", help="print the generated block to stdout; do not write")
    ap.add_argument("--list", action="store_true", help="list available presets and exit")
    args = ap.parse_args()

    if args.list:
        print("Available presets:")
        for name in sorted(PRESETS):
            print(f"  {name}")
        return

    if not args.preset and not args.config:
        die("nothing to do: pass --preset NAME and/or --config FILE (or --list).")

    values = resolve(args.preset, args.config)
    validate(values)

    block = render_block(values)

    if args.to_stdout:
        print(block)
        return

    pkg = Path(args.pkg)
    if not pkg.exists():
        die(f"package file not found: {pkg}")
    original = pkg.read_text()
    updated = splice(original, block)

    if args.check:
        if original != updated:
            die(f"{pkg} is out of sync with the configuration. Run 'python build.py config ...' to regenerate.")
        print(f"{pkg} is up to date.")
        return

    if original == updated:
        print(f"{pkg} already up to date.")
    else:
        pkg.write_text(updated)
        print(f"Updated configurable block in {pkg}")


if __name__ == "__main__":
    main()
