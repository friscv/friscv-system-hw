DTC ?= dtc

DTS := friscv.dts
DTB := $(DTS:.dts=.dtb)

.PHONY: all clean

all: $(DTB)

$(DTB): $(DTS)
	$(DTC) -I dts -O dtb -o $@ $<

clean:
	rm -f $(DTB)
