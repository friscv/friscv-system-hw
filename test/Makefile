# Toolchain
PREFIX = riscv32-unknown-elf-
AS = $(PREFIX)as
LD = $(PREFIX)ld
OBJCOPY = $(PREFIX)objcopy
OBJDUMP = $(PREFIX)objdump

# Flags
ASFLAGS = -march=rv32ia -mabi=ilp32
LDFLAGS = -T linker.ld

# Output files
OUTPUT = prog
ELF = $(OUTPUT).elf
BIN = $(OUTPUT).bin
DIS = $(OUTPUT).dis

# Default target
.PHONY: all clean help

all:
	@echo "Usage: make <filename>.S"
	@echo "Example: make jump.S"

help:
	@echo "Usage:"
	@echo "  make <filename>.S   - Build any assembly file"
	@echo "  Example: make tests.S"
	@echo ""
	@echo "  Produces: prog.elf, prog.bin, prog.dis"
	@echo "  make clean          - Remove build artifacts"

# Generic rule to build any .S file (always rebuild)
# Use filter to only match files that exist
.PHONY: $(wildcard *.S)
$(wildcard *.S):
	@$(AS) $(ASFLAGS) -o $(basename $@).o $@ && \
	$(LD) $(LDFLAGS) -o $(ELF) $(basename $@).o && \
	$(OBJCOPY) -O binary $(ELF) $(BIN) && \
	$(OBJDUMP) -d -M no-aliases,numeric $(ELF) > $(DIS) && \
	rm -f $(basename $@).o && \
	echo "" && \
	echo "Built $@ -> $(BIN), $(DIS)"

# Catch-all for .S files that don't exist yet
%.S:
	@if [ -f "$@" ]; then \
		$(AS) $(ASFLAGS) -o $(basename $@).o $@ && \
		$(LD) $(LDFLAGS) -o $(ELF) $(basename $@).o && \
		$(OBJCOPY) -O binary $(ELF) $(BIN) && \
		$(OBJDUMP) -d -M no-aliases,numeric $(ELF) > $(DIS) && \
		rm -f $(basename $@).o && \
		echo "" && \
		echo "Built $@ -> $(BIN), $(DIS)"; \
	else \
		echo "Error: File $@ not found"; \
		exit 1; \
	fi

clean:
	rm -f *.o $(ELF) $(BIN) $(DIS)
	@echo "Cleaned build artifacts"
