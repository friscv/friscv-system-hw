CROSS_COMPILE ?= riscv64-linux-gnu-
DTC           ?= dtc
DTCFLAGS      = -I dts -O dtb -@

OPENSBI_DIR   = opensbi
OPENSBI_OUT   = $(OPENSBI_DIR)/build/platform/generic/firmware

all: friscv.dtb opensbi

friscv.dtb: friscv.dts
	$(DTC) $(DTCFLAGS) -o $@ $<

OPENSBI_FLAGS = \
	PLATFORM=generic \
	PLATFORM_RISCV_XLEN=32 \
	PLATFORM_RISCV_ISA=rv32ima_zifencei_zicsr \
	PLATFORM_RISCV_ABI=ilp32 \
	FW_JUMP=y \
	FW_JUMP_ADDR=0x80400000 \
	FW_JUMP_FDT_ADDR=0x80200000 \
	CROSS_COMPILE=$(CROSS_COMPILE)

opensbi: $(OPENSBI_DIR)/Makefile
	$(MAKE) -C $(OPENSBI_DIR) $(OPENSBI_FLAGS)
	cp $(OPENSBI_OUT)/fw_jump.bin fw_jump.bin

$(OPENSBI_DIR)/Makefile:
	@echo "ERROR: opensbi submodule not initialised."
	@echo "       Run: git submodule update --init software/opensbi"
	@exit 1

opensbi-clean:
	$(MAKE) -C $(OPENSBI_DIR) clean

clean: opensbi-clean
	rm -f friscv.dtb fw_jump.bin

.PHONY: all clean opensbi opensbi-clean
