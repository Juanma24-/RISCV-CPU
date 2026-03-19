##
# INSTRUCTION DECODER MAKEFILE
#
# @file
# @version 0.1
# Makefile

# Simulation defaults
SIM ?= ghdl
TOPLEVEL_LANG ?= vhdl

# Get the directory where this Makefile lives, then go up two levels
PROJ_BASE := $(abspath $(CURDIR)/../..)

# Specify the VHDL source files
# Add your source files here, order matters if not using VHDL-2008
VHDL_SOURCES += $(PROJ_BASE)/RTL/MEMORIES/mem_pkg.vhd
VHDL_SOURCES += $(PROJ_BASE)/RTL/CPU/cpu_pkg.vhd
VHDL_SOURCES += $(PROJ_BASE)/RTL/CPU/instr_decoder.vhd
VHDL_SOURCES += $(PROJ_BASE)/Test/instr_decoder/tb_instr_decoder_ghdl_wrapper.vhdl



# TOPLEVEL is the name of the entity in your VHDL file
TOPLEVEL = instr_decoder_tb_wrapper

# MODULE is the name of the Python test file (without the .py extension)
MODULE = test_instr_decoder

# Extra arguments for the simulator
# Example for GHDL:
ifeq ($(SIM), ghdl)
	SIM_ARGS += --wave=wave.ghw
    EXTRA_ARGS += --std=08 -v
endif

# Include the cocotb make rules
include $(shell cocotb-config --makefiles)/Makefile.sim


# end
