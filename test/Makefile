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
.PHONY: all entry tests blink poll halt jump arith hazard hazard_nops clean help

all: entry

help:
	@echo "Targets:"
	@echo "  make entry   - Build entry.S (basic test)"
	@echo "  make tests   - Build tests.S (full test suite)"
	@echo "  make blink   - Build blink.S (LED blink demo)"
	@echo "  make poll    - Build poll.S (poll switch -> LED)"
	@echo "  make halt    - Build halt.S (minimal halt test)"
	@echo "  make jump    - Build jump.S (single jump test)"
	@echo "  make arith   - Build arith.S (arithmetic/logic test)"
	@echo "  make hazard  - Build hazard.S (register hazard test)"
	@echo "  make hazard_nops - Build hazard_nops.S (hazard test with NOPs)"
	@echo "  make clean   - Remove build artifacts"

entry: entry.o
	$(LD) $(LDFLAGS) -o $(ELF) $<
	$(OBJCOPY) -O binary $(ELF) $(BIN)
	$(OBJDUMP) -d -M no-aliases,numeric $(ELF) > $(DIS)

tests: tests.o
	$(LD) $(LDFLAGS) -o $(ELF) $<
	$(OBJCOPY) -O binary $(ELF) $(BIN)
	$(OBJDUMP) -d -M no-aliases,numeric $(ELF) > $(DIS)

blink: blink.o
	$(LD) $(LDFLAGS) -o $(ELF) $<
	$(OBJCOPY) -O binary $(ELF) $(BIN)
	$(OBJDUMP) -d -M no-aliases,numeric $(ELF) > $(DIS)

poll: poll.o
	$(LD) $(LDFLAGS) -o $(ELF) $<
	$(OBJCOPY) -O binary $(ELF) $(BIN)
	$(OBJDUMP) -d -M no-aliases,numeric $(ELF) > $(DIS)

halt: halt.o
	$(LD) $(LDFLAGS) -o $(ELF) $<
	$(OBJCOPY) -O binary $(ELF) $(BIN)
	$(OBJDUMP) -d -M no-aliases,numeric $(ELF) > $(DIS)

jump: jump.o
	$(LD) $(LDFLAGS) -o $(ELF) $<
	$(OBJCOPY) -O binary $(ELF) $(BIN)
	$(OBJDUMP) -d -M no-aliases,numeric $(ELF) > $(DIS)

arith: arith.o
	$(LD) $(LDFLAGS) -o $(ELF) $<
	$(OBJCOPY) -O binary $(ELF) $(BIN)
	$(OBJDUMP) -d -M no-aliases,numeric $(ELF) > $(DIS)
	@echo ""
	@echo "Built arith.S -> $(BIN)"
	@ls -la $(BIN)
	@echo ""
	@cat $(DIS)

hazard: hazard.o
	$(LD) $(LDFLAGS) -o $(ELF) $<
	$(OBJCOPY) -O binary $(ELF) $(BIN)
	$(OBJDUMP) -d -M no-aliases,numeric $(ELF) > $(DIS)

hazard_nops: hazard_nops.o
	$(LD) $(LDFLAGS) -o $(ELF) $<
	$(OBJCOPY) -O binary $(ELF) $(BIN)
	$(OBJDUMP) -d -M no-aliases,numeric $(ELF) > $(DIS)

%.o: %.S
	$(AS) $(ASFLAGS) -o $@ $<

clean:
	rm -f *.o $(ELF) $(BIN) $(DIS)
	@echo "Cleaned build artifacts"
