# Testing

## Integration Tests (Verilator)

### Prerequisites (Integration)

| Tool | How to check |
| ---- | ------------ |
| [Verilator](https://verilator.org) | `verilator --version` |
| `riscv64-unknown-elf` toolchain | `riscv64-unknown-elf-as --version` |
| Python 3.11+ | `python3 --version` |
| `make` | `make --version` |

### Running (Integration)

From the repo root:

```bash
make test
```

This runs three steps in sequence:

1. `make verilate` - builds the Verilator model from `tb_integration`
2. `make test-bin` - assembles all `test/integration_test_*.S` into `.bin` files
3. `make verilator-test` - runs each `.bin` in parallel

Each test must print `[RESULT] PASS`. The runner exits non-zero if any test fails.

To run the steps individually (e.g. after changing only a test program):

```bash
make test-bin        # rebuild test binaries only
make verilator-test  # re-run without re-verilating
```

## Architecture Compliance Tests

The [riscv-arch-test](https://github.com/riscv/riscv-arch-test) suite verifies ISA compliance against the Sail reference model.

### Prerequisites (ACT)

Everything from [Integration Tests](#integration-tests-verilator), plus:

| Tool | How to check |
| ---- | ------------ |
| `riscv64-unknown-elf-gcc` | `riscv64-unknown-elf-gcc --version` |
| `sail_riscv_sim` (Sail reference model) | `sail_riscv_sim --help` |

The test suite is cloned automatically on first run of `make act`.

### Running (ACT)

```bash
make act
```

This runs the full flow: verilate, build ACT tests, and run the regression. Individual steps:

```bash
make act-build   # build the ACT test ELFs (requires submodule + sail)
make regress     # run regression against the Verilator model (most common command)
```

Results are written to `build/regress/arch-test/results.json`.

All architecture compliance tests should pass before a feature is considered complete.
