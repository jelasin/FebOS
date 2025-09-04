# Makefile for nostd C bootloader

CC = gcc
LD = ld
OBJCOPY = objcopy

# 编译器标志：16位实模式，无标准库
CFLAGS = -m16 -ffreestanding -fno-stack-protector -fno-pie -fno-asynchronous-unwind-tables \
         -nostdlib -nostartfiles -nodefaultlibs -Os -Wall -Wextra

# 链接器标志
LDFLAGS = -T linker.ld -nostdlib --nmagic -m elf_i386

# 目标文件
TARGET = boot.bin
SOURCE = boot.c
OBJECT = boot.o
ELF = boot.elf

.PHONY: all clean run

all: $(TARGET)

# 编译C文件为目标文件
$(OBJECT): $(SOURCE)
	$(CC) $(CFLAGS) -c $< -o $@

# 链接为ELF文件
$(ELF): $(OBJECT) linker.ld
	$(LD) $(LDFLAGS) $< -o $@

# 转换为二进制文件
$(TARGET): $(ELF)
	$(OBJCOPY) -O binary $< $@
	# 确保文件大小为512字节
	truncate -s 512 $@

# 运行QEMU测试
run: $(TARGET)
	qemu-system-i386 -drive file=./$(TARGET),if=ide,format=raw

# 清理编译文件
clean:
	rm -f $(OBJECT) $(ELF) $(TARGET)

# 显示文件信息
info: $(TARGET)
	@echo "=== 文件大小 ==="
	ls -la $(TARGET)
	@echo "=== 十六进制转储 (最后16字节) ==="
	xxd -l 16 -s -16 $(TARGET)
