RISCVCC ?= clang
RISCVCCFLAGS ?= --target=riscv32-none -march=rv32i_zicsr -nostdlib -flto -Os

OBJCOPY ?= llvm-objcopy

bootloader.o: bootloader.c crt0.S link_bootloader.ld
	$(RISCVCC) $(RISCVCCFLAGS) -T link_bootloader.ld -o bootloader.o bootloader.c crt0.S

%.bin: %.o
	$(OBJCOPY) -O binary $< $@

clean:
	rm -f *.o
	rm -f *.bin
