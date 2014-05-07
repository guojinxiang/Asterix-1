all: asterix.iso

SRC_DIR = src
INC_DIR = include
BOOTLOADER_DIR = bootloader
BOOTLOADER_PATH = ${SRC_DIR}/${BOOTLOADER_DIR}
KERNEL_DIR = kernel
KERNEL_PATH = ${SRC_DIR}/${KERNEL_DIR}
BOOTSECTOR = bootsector.bin.tmp
INCLUDE_DIRS = src/ include/
KERNEL_INCLUDE_DIRS = ${INCLUDE_DIRS} include/kernel/

boot.bin:
	nasm ${BOOTLOADER_PATH}/bootloader.asm ${foreach dir, ${INCLUDE_DIRS}, -I${dir}} -f bin -o $@
.PHONY : boot.bin

boot: boot.bin
bootloader: boot.bin

kernel.bin: src/kernel/kernel.asm.o src/kernel/kernel.cpp.o
	ld $^ -m elf_i386 -T src/kernel/kernel.ld -o $@
.PHONY : kernel.bin

kernel: kernel.bin

sysroot: boot.bin kernel
	rm   -rf sysroot
	mkdir -p sysroot
	mkdir -p sysroot/boot
	cp grub/*  -r sysroot/
	cp kernel.bin sysroot/boot/kernel.bin
	cp boot.bin   sysroot/boot/boot.bin


asterix.iso: sysroot bootloader kernel
	grub-mkrescue -o $@ sysroot &> /dev/null
.PHONY : asterix.iso

asterix: asterix.iso
disk:    asterix.iso
cdrom:   asterix.iso
cd:      asterix.iso

stats:
	cloc --yaml . | grep -E 'Assembly:|C:|C\+\+:' -A 4 | sed 's/nFiles/files/'
	echo -n "Total: " && cloc --yaml . | grep -E 'SUM:' -A 4 | grep 'code: ' | sed 's/.*code: //g;s/$$/ SLoC/g'
.PHONY : stats
.SILENT : stats

%.asm.o: %.asm
	nasm ${foreach dir, ${INCLUDE_DIRS}, -I${dir}} -f elf32 $^ -o $@

%.cpp.o: %.cpp
	g++ -std=c++11 $^ -c -m32 -ffreestanding ${foreach dir, ${INCLUDE_DIRS}, -I${dir}} -o $@

%.c.o: %.c
	gcc -std=c11   $^ -c -m32 -ffreestanding ${foreach dir, ${INCLUDE_DIRS}, -I${dir}} -o $@

clean:
	rm *.bin
	rm *.iso
	rm *.o
.PHONY : clean
