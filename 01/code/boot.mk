######################################################################
# boot.mk - 16 位引导程序构建脚本 (GCC + ld + objcopy)
# 目标: 将 C 源 (boot.c) 构建为符合 BIOS 启动要求的 512 字节镜像 boot.bin
# 流程:
#   1) 预处理/编译: gcc 以 16 位模式 (-m16) 生成位置相关代码的目标文件 boot.o
#   2) 链接: 使用自定义链接脚本 boot.ld 把代码定位到 0x7C00, 输出中间 ELF (boot.elf)
#   3) 裁剪: objcopy 仅抽取可加载节为扁平二进制 -> boot.bin
#   4) 修整: truncate 保证精确 512 字节 (不足补 0); 末尾 0x55AA 由源码+链接脚本保证
#   5) 运行: qemu-system-i386 直接把 boot.bin 当作硬盘镜像首扇区加载执行
# 提示:
#   * 使用 --nmagic 避免页对齐膨胀
#   * -ffreestanding/-nostdlib 禁用标准运行时依赖
#   * 如需调试: 可对 boot.elf 使用 objdump -D 或 gdb 分析
######################################################################

CC = gcc             # C 编译器
LD = ld              # GNU 链接器
OBJCOPY = objcopy    # 用于从 ELF 提取裸二进制

# 编译器标志：16位实模式，无标准库
# -m16: 生成 16 位代码 (实模式)
# -ffreestanding: 不假设有标准库/运行时
# -fno-stack-protector: 不生成栈保护代码 (不需要)
# -fno-pie: 不生成位置无关代码 (PIC/PIE)
# -fno-asynchronous-unwind-tables: 不生成异常处理表 (不需要)
# -Os: 优化代码尺寸
# -Wall -Wextra: 启用警告
CFLAGS = -m16 \
	-ffreestanding \
	-fno-stack-protector \
	-fno-pie \
	-fno-asynchronous-unwind-tables \
	-nostdlib -nostartfiles -nodefaultlibs \
	-Os \
	-Wall -Wextra

# 链接器标志 (保持紧凑, 自定义脚本, 关闭标准库与页对齐)
# -T boot.ld: 使用自定义链接脚本 (见 boot.ld)
# -nostdlib: 不链接标准库
# --nmagic: 取消页对齐 (节紧凑排列)
# -m elf_i386: 生成 32 位 x86 ELF (兼容 16 位实模式)
LDFLAGS = -T boot.ld \
	-nostdlib \
	--nmagic \
	-m elf_i386

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
$(ELF): $(OBJECT) boot.ld
	$(LD) $(LDFLAGS) $< -o $@

# 裁剪阶段: 取出所有 ALLOC 节 -> 裸二进制
$(TARGET): $(ELF)
	$(OBJCOPY) -O binary $< $@
# 保证精确 512 字节 (不足补0; 若超出说明溢出, 应修代码而非依赖截断)
	truncate -s 512 $@

# 运行QEMU测试
run: $(TARGET)
	qemu-system-i386 -drive file=./$(TARGET),if=ide,format=raw

# 运行QEMU调试
debug: $(TARGET)
	qemu-system-i386 -drive file=./$(TARGET),if=ide,format=raw -S -s

# 清理编译文件
clean:
	rm -f $(OBJECT) $(ELF) $(TARGET)

# 显示文件信息
info: $(TARGET)
	@echo "=== 文件大小 ==="
	ls -la $(TARGET)
	@echo "=== 十六进制转储 (最后16字节 55 aa) ==="
	xxd -l 16 -s -16 $(TARGET)
