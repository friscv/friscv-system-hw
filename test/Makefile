SHELL := /bin/bash

# Toolchain
PREFIX = riscv32-unknown-elf-
AS = $(PREFIX)as
LD = $(PREFIX)ld
OBJCOPY = $(PREFIX)objcopy
OBJDUMP = $(PREFIX)objdump

ASFLAGS = -march=rv32i -mabi=ilp32
LDFLAGS = -T linker.ld

# Default target: build all integration tests into individual .bin files
INTEGRATION_SRCS = $(wildcard integration_test_*.S)
INTEGRATION_BINS = $(INTEGRATION_SRCS:.S=.bin)

.PHONY: all clean help

all: $(INTEGRATION_BINS)
	@echo ""
	@echo "Built $(words $(INTEGRATION_BINS)) integration test(s)"

# Pattern rule: integration_test_X.S -> integration_test_X.bin
integration_test_%.bin: integration_test_%.S
	@$(AS) $(ASFLAGS) -o $(basename $<).o $< && \
	$(LD) $(LDFLAGS) -o $(basename $<).elf $(basename $<).o && \
	$(OBJCOPY) -O binary $(basename $<).elf $@ && \
	$(OBJDUMP) -d -M no-aliases,numeric $(basename $<).elf > $(basename $<).dis && \
	rm -f $(basename $<).o && \
	echo "Built $< -> $@"

help:
	@echo "Usage:"
	@echo "  make                        - Build all integration tests into <name>.bin"
	@echo "  make prog TEST=<name>       - Build <name>.S into prog.bin (for GUI sim)"
	@echo "  make clean                  - Remove build artifacts"

.PHONY: prog
prog:
	@test -n "$(TEST)" || (echo "Error: specify TEST=<name>  e.g. make prog TEST=integration_test_Zaamo"; exit 1)
	@test -f "$(TEST).S" || (echo "Error: $(TEST).S not found"; exit 1)
	@$(AS) $(ASFLAGS) -o $(TEST).o $(TEST).S && \
	$(LD) $(LDFLAGS) -o prog.elf $(TEST).o && \
	$(OBJCOPY) -O binary prog.elf prog.bin && \
	$(OBJDUMP) -d -M no-aliases,numeric prog.elf > prog.dis && \
	rm -f $(TEST).o && \
	echo "Built $(TEST).S -> prog.bin"

clean:
	rm -f *.o *.elf *.bin *.dis
