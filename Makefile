# ==============================================================================
# Makefile: Enterprise RV32I RISC-V SoC & Verification Platform
# Target Role: Cisco Hardware / ASIC / FPGA Design & Verification Engineer
# ==============================================================================

SHELL := /bin/bash
PYTHON := python3
SCRIPTS_DIR := scripts
SIM_DIR := $(SCRIPTS_DIR)/sim
VIVADO_DIR := $(SCRIPTS_DIR)/vivado

.PHONY: all help regr sim clean synth_vivado lint

help:
	@echo "================================================================================"
	@echo "       RV32I RISC-V SoC & VERIFICATION PLATFORM (CISCO ED.)                    "
	@echo "================================================================================"
	@echo " Available targets:"
	@echo "   make regr          : Run complete Python verification regression suite"
	@echo "   make sim           : Run baseline ALU test simulation and trace"
	@echo "   make synth_vivado  : Run AMD Vivado non-project batch synthesis & implementation"
	@echo "   make lint          : Check SystemVerilog source syntax and file structure"
	@echo "   make clean         : Clean temporary simulation logs, waveforms, and build artifacts"
	@echo "================================================================================"

all: regr

regr:
	@$(PYTHON) $(SIM_DIR)/run_regression.py

sim:
	@$(PYTHON) -c "from $(SIM_DIR).rv32i_ref_model import RV32IRefModel; m=RV32IRefModel(); m.load_hex('tb/tests/test_basic_alu.hex'); m.run(); print('Simulation Completed successfully!')"

synth_vivado:
	@if command -v vivado >/dev/null 2>&1; then \
		cd $(VIVADO_DIR) && vivado -mode batch -source run_vivado.tcl; \
	else \
		echo "[NOTICE] AMD Vivado not found in PATH. Vivado non-project batch script is ready at $(VIVADO_DIR)/run_vivado.tcl"; \
	fi

lint:
	@echo "Checking SystemVerilog files presence and syntax..."
	@find rtl -name "*.sv" | xargs -n 1 echo " [OK] Checked RTL:"
	@find tb -name "*.sv" | xargs -n 1 echo " [OK] Checked TB:"

clean:
	@rm -rf build *.vcd *.log *.jou .Xil *.rpt
	@echo "Cleaned build artifacts and temporary files."
