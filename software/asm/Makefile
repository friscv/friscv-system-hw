# Toolchain
PREFIX = riscv32-unknown-elf-
AS = $(PREFIX)as
LD = $(PREFIX)ld
OBJCOPY = $(PREFIX)objcopy
OBJDUMP = $(PREFIX)objdump

# Flags
ASFLAGS = -march=rv32i -mabi=ilp32
LDFLAGS = -T linker.ld

# Output files
OUTPUT = prog
ELF = $(OUTPUT).elf
BIN = $(OUTPUT).bin
DIS = $(OUTPUT).dis

# Default target
.PHONY: all entry tests clean help

all: entry

help:
	@echo "FRISCV Assembly Build System"
	@echo ""
	@echo "Targets:"
	@echo "  make entry  - Build entry.S (basic test)"
	@echo "  make tests  - Build tests.S (full test suite)"
	@echo "  make clean  - Remove build artifacts"
	@echo ""
	@echo "Output files:"
	@echo "  prog.bin    - Raw binary for simulation"
	@echo "  prog.dis    - Disassembly for debugging"
	@echo "  prog.elf    - ELF file (intermediate)"

entry: entry.o
	$(LD) $(LDFLAGS) -o $(ELF) $<
	$(OBJCOPY) -O binary $(ELF) $(BIN)
	$(OBJDUMP) -d -M no-aliases,numeric $(ELF) > $(DIS)
	@echo ""
	@echo "Built entry.S -> $(BIN)"
	@ls -la $(BIN)
	@echo ""
	@cat $(DIS)

tests: tests.o
	$(LD) $(LDFLAGS) -o $(ELF) $<
	$(OBJCOPY) -O binary $(ELF) $(BIN)
	$(OBJDUMP) -d -M no-aliases,numeric $(ELF) > $(DIS)
	@echo ""
	@echo "Built tests.S -> $(BIN)"
	@ls -la $(BIN)
	@echo ""
	@head -100 $(DIS)
	@echo "... (see $(DIS) for full disassembly)"

%.o: %.S
	$(AS) $(ASFLAGS) -o $@ $<

clean:
	rm -f *.o $(ELF) $(BIN) $(DIS)
	@echo "Cleaned build artifacts"
