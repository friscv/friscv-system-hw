VERILATOR := verilator
VERILATOR_FLAGS := -j 0 --binary --timing --sv -Irtl -Wno-fatal -Wno-TIMESCALEMOD -Wno-PINMISSING
VERILATOR_OUT := build/verilator/tb_integration
ACT_ROOT := verif/arch-test/riscv-arch-test
ACT_CONFIG_SRC := verif/arch-test/friscv-rv32ia
ACT_CONFIG_DST := $(ACT_ROOT)/config/cores/friscv/friscv-rv32ia
ACT_CONFIG := config/cores/friscv/friscv-rv32ia/test_config.yaml
ACT_WORK := $(ACT_ROOT)/work/friscv-rv32ia
ACT_EXCLUDE_EXTENSIONS ?= Sm,S,Sv,InterruptsSm,InterruptsS,InterruptsU,ExceptionsZalrsc,ExceptionsZaamo,PMPF,PMPS,PMPSm,PMPU,PMPZaamo,PMPZalrsc,PMPZca,PMPZicbo,Svade,Svadu,SvaduPMP,SvPMP,SvZicbo,SvPMPZicbo
JOBS ?= $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
UV_LINK_MODE ?= copy

.PHONY: verilate
verilate:
	mkdir -p $(VERILATOR_OUT)
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module tb_integration rtl/*.sv rtl/friscv_clint.v sim/tb_integration.sv -Mdir $(VERILATOR_OUT)

.PHONY: test-bin
test-bin:
	$(MAKE) -C test

.PHONY: verilator-test
verilator-test:
	python3 scripts/test.py

.PHONY: test
test: verilate test-bin verilator-test

.PHONY: act-config
act-config:
	test -d $(ACT_ROOT) || (echo "error: missing $(ACT_ROOT). Add/init the riscv-arch-test submodule." && exit 1)
	mkdir -p $(ACT_CONFIG_DST)
	cp $(ACT_CONFIG_SRC)/* $(ACT_CONFIG_DST)/

.PHONY: act-build
act-build: act-config
	rm -rf $(ACT_WORK)/build $(ACT_WORK)/elfs
	UV_LINK_MODE=$(UV_LINK_MODE) CONFIG_FILES=$(ACT_CONFIG) EXCLUDE_EXTENSIONS=$(ACT_EXCLUDE_EXTENSIONS) $(MAKE) -C $(ACT_ROOT) --jobs $(JOBS)

.PYTHON: regress
regress:
	python3 scripts/regress.py

.PHONY: act
act: verilate act-build regress

.PHONY: clean
clean:
	rm -rf build/
