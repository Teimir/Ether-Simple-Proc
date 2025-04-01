
VERILOG_FILES = src\ram.sv src\core.sv src\top.sv src\rtc.sv tb\tb_processor.sv
TOP_MODULE_NAME = tb_processor

ifeq ($(origin OS),environment)
  DEL_DUMP = python -c "import pathlib; pathlib.Path('dump.vcd').unlink()"
  DEL_VVP = python -c "import pathlib; pathlib.Path('processor_tb.vvp').unlink()"
else
  DEL_DUMP = rm -f dump.vcd
  DEL_VVP = rm -f processor_tb.vvp
endif

.PHONY: all
all: icarus_sim

.PHONY: icarus_sim
icarus_sim: processor_tb.vvp
	vvp $^

processor_tb.vvp: $(VERILOG_FILES)
	iverilog -o $@ -g2012 -s $(TOP_MODULE_NAME) $^

.PHONY: see_vcd
see_vcd: dump.vcd
	gtkwave $^

.PHONY: clean_all
clean_all:
	$(DEL_DUMP)
	$(DEL_VVP)

.PHONY: help
help:
	@echo "Targets: help icarus_sim see_vcd clean_all"