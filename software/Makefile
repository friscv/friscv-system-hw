DTC     ?= dtc
DTCFLAGS = -I dts -O dtb -@

all: friscv.dtb

friscv.dtb: friscv.dts
	$(DTC) $(DTCFLAGS) -o $@ $<

clean:
	rm -f friscv.dtb

.PHONY: all clean
