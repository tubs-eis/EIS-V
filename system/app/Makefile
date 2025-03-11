RISCVCC ?= clang
RISCVCCFLAGS ?= --target=riscv32-none -march=rv32i_zicsr -nostdlib -Os -flto -msmall-data-limit=0

OBJCOPY ?= llvm-objcopy

TARGET ?= /dev/ttyUSB1

.SECONDARY:

%.o: %.c crt0.S link_app.ld
	$(RISCVCC) $(RISCVCCFLAGS) -T link_app.ld -o $@ $< crt0.S

%.bin: %.o
	$(OBJCOPY) -O binary $< $@

%.hex: %.bin
	xxd -g 4 $< | cut -d " " -f 2-5 > $@

%.bootloaderimage: %.hex
	cp $< $@
	echo "z" >> $@

%.flash: %.bootloaderimage
	cat $< > ${TARGET}

clean:
	rm -f *.o
	rm -f *.bin
	rm -f *.hex
	rm -f *.bootloaderimage
