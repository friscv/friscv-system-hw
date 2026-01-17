# Makefile for FRISC-V Project
# PYNQ-Z2 Target

PROJECT_NAME := friscv-system-hw
PROJECT_DIR := $(CURDIR)/$(PROJECT_NAME)
SCRIPTS_DIR := $(CURDIR)/scripts
OVERLAY_DIR := $(CURDIR)/overlay

VIVADO := vivado
VIVADO_BATCH := $(VIVADO) -mode batch -nolog -nojournal -source
VIVADO_GUI := $(VIVADO) -mode gui -nolog -nojournal
XSDB := xsdb

.PHONY: all
all: project

# Create Vivado project
.PHONY: project
project:
	@echo "Creating Vivado project..."
	$(VIVADO_BATCH) $(SCRIPTS_DIR)/create_project.tcl
	@echo "Done! Project created at: $(PROJECT_DIR)/$(PROJECT_NAME).xpr"

# Export block designs to TCL
.PHONY: export-bd
export-bd:
	@if [ ! -f $(PROJECT_DIR)/$(PROJECT_NAME).xpr ]; then \
		echo "ERROR: Project not found. Run 'make project' first."; \
		exit 1; \
	fi
	@echo "Exporting block designs to TCL..."
	$(VIVADO_BATCH) $(SCRIPTS_DIR)/export_bd.tcl

# Generate Bitstream and Deploy to overlay/ (clean all runs first)
.PHONY: bitstream
bitstream:
	@if [ ! -f $(PROJECT_DIR)/$(PROJECT_NAME).xpr ]; then \
		echo "ERROR: Project not found. Run 'make project' first."; \
		exit 1; \
	fi
	@echo "=== CLEANING OLD BITSTREAM FILES ==="
	@rm -rf $(PROJECT_DIR)/$(PROJECT_NAME).runs/impl_1
	@rm -rf $(PROJECT_DIR)/$(PROJECT_NAME).runs/synth_1
	@rm -rf $(PROJECT_DIR)/$(PROJECT_NAME).runs/design_1_friscv_soc_wrapper_0_synth_1
	@rm -rf $(PROJECT_DIR)/$(PROJECT_NAME).runs/design_1_ps_0_synth_1
	@rm -rf $(PROJECT_DIR)/$(PROJECT_NAME).cache
	@rm -rf $(PROJECT_DIR)/$(PROJECT_NAME).gen
	@rm -f bd/design_1/ip/design_1_friscv_soc_wrapper_0/*.dcp
	@rm -f bd/design_1/ip/design_1_friscv_soc_wrapper_0/synth/*.v
	@rm -f $(OVERLAY_DIR)/friscv.bit $(OVERLAY_DIR)/friscv.hwh
	@rm -f $(CURDIR)/$(PROJECT_NAME).xsa
	@echo "Old files cleaned."
	@echo ""
	@echo "=== BUILDING NEW BITSTREAM ==="
	$(VIVADO_BATCH) $(SCRIPTS_DIR)/build_bitstream.tcl
	
	@echo ""
	@echo "=== DEPLOYING ARTIFACTS TO $(OVERLAY_DIR) ==="
	@mkdir -p $(OVERLAY_DIR)
	
	@find $(PROJECT_DIR)/$(PROJECT_NAME).runs/impl_1 -name "*.bit" -exec cp {} $(OVERLAY_DIR)/friscv.bit \;
	
	@find $(PROJECT_DIR) -name "*.hwh" -exec cp {} $(OVERLAY_DIR)/friscv.hwh \;
	
	@if [ ! -f $(OVERLAY_DIR)/friscv.hwh ]; then \
		echo "WARNING: .hwh not found directly. Extracting from XSA..."; \
		if [ -f $(CURDIR)/$(PROJECT_NAME).xsa ]; then \
			unzip -p $(CURDIR)/$(PROJECT_NAME).xsa *hw_handoff/*.hwh > $(OVERLAY_DIR)/friscv.hwh || \
			unzip -p $(CURDIR)/$(PROJECT_NAME).xsa *.hwh > $(OVERLAY_DIR)/friscv.hwh; \
			echo "Extracted HWH from XSA."; \
		else \
			echo "ERROR: Could not find .hwh or .xsa file!"; \
			exit 1; \
		fi \
	fi

	@echo "Extracting ps7_init.tcl from XSA..."
	@if [ -f $(CURDIR)/$(PROJECT_NAME).xsa ]; then \
		mkdir -p $(SCRIPTS_DIR)/.ps_init_tmp && \
		cd $(SCRIPTS_DIR)/.ps_init_tmp && \
		unzip -q $(CURDIR)/$(PROJECT_NAME).xsa && \
		find . -name "ps7_init.tcl" -exec cp {} $(SCRIPTS_DIR)/ps7_init.tcl \; && \
		cd $(CURDIR) && \
		rm -rf $(SCRIPTS_DIR)/.ps_init_tmp && \
		echo "Extracted ps7_init.tcl to $(SCRIPTS_DIR)/"; \
	else \
		echo "WARNING: XSA file not found, skipping ps7_init.tcl extraction"; \
	fi

	@echo "Removing generated XSA file..."
	@rm -f $(CURDIR)/$(PROJECT_NAME).xsa
	
	@echo ""
	@echo "=== BUILD COMPLETE ==="
	@echo "Bitstream: $(OVERLAY_DIR)/friscv.bit"
	@ls -lh $(OVERLAY_DIR)/friscv.bit
	@md5sum $(OVERLAY_DIR)/friscv.bit
	@echo ""
	@echo "Hardware handoff: $(OVERLAY_DIR)/friscv.hwh"
	@ls -lh $(OVERLAY_DIR)/friscv.hwh

# Program FPGA directly via JTAG (bypasses PYNQ overlay system)
.PHONY: program
program:
	@if [ ! -f $(OVERLAY_DIR)/friscv.bit ]; then \
		echo "ERROR: Bitstream not found. Run 'make bitstream' first."; \
		exit 1; \
	fi
	@echo "=== PROGRAMMING FPGA VIA JTAG ==="
	@echo "Make sure the board is connected via USB JTAG"
	@echo "Bitstream: $(OVERLAY_DIR)/friscv.bit"
	@md5sum $(OVERLAY_DIR)/friscv.bit
	@echo ""
	$(VIVADO_BATCH) $(SCRIPTS_DIR)/program_fpga.tcl -tclargs $(OVERLAY_DIR)/friscv.bit
	@echo ""
	@echo "FPGA programmed successfully!"

# Check FPGA status
.PHONY: status
status:
	@echo "=== CHECKING FPGA STATUS ==="
	$(XSDB) $(SCRIPTS_DIR)/check_status.tcl

# Load program to memory
.PHONY: load
load:
	@if [ ! -f test/prog.bin ]; then \
		echo "ERROR: test/prog.bin not found."; \
		exit 1; \
	fi
	@echo "=== LOADING PROGRAM TO MEMORY ==="
	@echo "Binary: test/prog.bin"
	@echo "Address: 0x0"
	$(XSDB) $(SCRIPTS_DIR)/load_program.tcl test/prog.bin 0x0

# Release FRISC-V core from reset
.PHONY: run
run:
	@echo "=== RELEASING FRISC-V CORE FROM RESET ==="
	$(XSDB) $(SCRIPTS_DIR)/release_reset.tcl

# Program FPGA, load prog.bin, and run
.PHONY: go
go: program load run

# Open project in GUI
.PHONY: open
open:
	@if [ ! -f $(PROJECT_DIR)/$(PROJECT_NAME).xpr ]; then \
		echo "Project not found. Creating..."; \
		$(MAKE) project; \
	fi
	$(VIVADO_GUI) $(PROJECT_DIR)/$(PROJECT_NAME).xpr &

# Clean project directory
.PHONY: clean
clean:
	@echo "Removing project directory..."
	rm -rf $(CURDIR)/.Xil/
	rm -rf $(PROJECT_DIR)
	@echo "Cleaning generated block design files..."
	@find bd/ -type f -not -name '*.tcl' -delete 2>/dev/null || true
	@find bd/ -type d -empty -delete 2>/dev/null || true
	@echo "Clean complete!"

# Generate ZSBL ROM from software/zsbl.S
.PHONY: zsbl-rom
zsbl-rom:
	@if [ ! -f "software/zsbl.S" ]; then \
		echo "ERROR: software/zsbl.S not found"; \
		exit 1; \
	fi; \
	echo "Generating ZSBL ROM from software/zsbl.S..."; \
	python3 $(SCRIPTS_DIR)/gen_zsbl_rom.py "software/zsbl.S" "rtl/friscv_zsbl_rom.sv" --linker-script "software/zsbl_linker.ld" --start-addr 0x1000

# Generate ZSBL ROM from test file (uses ZSBL linker at 0x1000)
.PHONY: zsbl-rom-%
zsbl-rom-%:
	@test_file="test/$*.S"; \
	if [ ! -f "$$test_file" ]; then \
		echo "ERROR: Test file not found: $$test_file"; \
		exit 1; \
	fi; \
	if [ ! -f "software/zsbl_linker.ld" ]; then \
		echo "ERROR: software/zsbl_linker.ld not found"; \
		exit 1; \
	fi; \
	echo "Generating ZSBL ROM from $$test_file with ZSBL linker..."; \
	python3 $(SCRIPTS_DIR)/gen_zsbl_rom.py "$$test_file" "rtl/friscv_zsbl_rom.sv" --start-addr 0x1000

# Show help
.PHONY: help
help:
	@echo "FRISCV Hardware Project - PYNQ-Z2"
	@echo ""
	@echo "Targets:"
	@echo "  make           - Create Vivado project (default)"
	@echo "  make project   - Create Vivado project"
	@echo "  make export-bd - Export block designs to TCL"
	@echo "  make open      - Open project in Vivado GUI"
	@echo "  make clean     - Remove project directory"
	@echo ""
	@echo "  make zsbl-rom              - Generate bootloader ROM from software/zsbl.S"
	@echo "  make zsbl-rom-<test>       - Generate ROM from test/<test>.S (e.g., zsbl-rom-halt)"
	@echo ""
	@echo "  make bitstream             - Build bitstream (includes ROM)"
	@echo "  make program               - Program FPGA directly via JTAG (USB cable)"
	@echo ""
	@echo "  make status                - Check FPGA status"
	@echo "  make load                  - Load software/prog.bin to address 0x0"
	@echo "  make run                   - Release FRISC-V core from reset"
	@echo ""
	@echo "  make help                  - Show this help"
	@echo ""
	@echo "Typical workflow:"
	@echo "  1. make bitstream          # Build bitstream with ROM"
	@echo "  2. make program            # Program FPGA via JTAG"
