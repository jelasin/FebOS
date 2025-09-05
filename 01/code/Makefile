# 编译器和链接器配置
AS = as
LD = ld
ASFLAGS = --32
LDFLAGS = -m elf_i386 -Ttext 0x0 -s --oformat binary

# 目标文件配置
TARGET = boot.img
OBJECTS = boot.o
SOURCES = boot.S

# QEMU 配置
QEMU = qemu-system-i386
QEMU_FLAGS = -drive file=$(TARGET),if=ide,format=raw
QEMU_DEBUG_FLAGS = -s -S

# 默认目标
all: $(TARGET)

# 汇编规则
%.o: %.S
	$(AS) $(ASFLAGS) -o $@ $<

# 链接规则
$(TARGET): $(OBJECTS)
	$(LD) $(LDFLAGS) -o $@ $^

# 运行目标
run: $(TARGET)
	$(QEMU) $(QEMU_FLAGS)

# 调试目标
debug: $(TARGET)
	@echo "启动 QEMU 调试模式，监听端口 1234"
	@echo "在另一个终端中运行: gdb -ex 'target remote localhost:1234'"
	$(QEMU) $(QEMU_FLAGS) $(QEMU_DEBUG_FLAGS)

# 清理目标
clean:
	rm -f $(OBJECTS) $(TARGET)

# 显示帮助信息
help:
	@echo "可用目标:"
	@echo "  all    - 编译引导镜像 (默认)"
	@echo "  run    - 在 QEMU 中运行引导镜像"
	@echo "  debug  - 在调试模式下启动 QEMU"
	@echo "  clean  - 清理生成的文件"
	@echo "  help   - 显示此帮助信息"

# 显示变量信息（用于调试 Makefile）
info:
	@echo "编译器设置:"
	@echo "  AS = $(AS)"
	@echo "  LD = $(LD)"
	@echo "  ASFLAGS = $(ASFLAGS)"
	@echo "  LDFLAGS = $(LDFLAGS)"
	@echo "目标文件:"
	@echo "  TARGET = $(TARGET)"
	@echo "  OBJECTS = $(OBJECTS)"
	@echo "  SOURCES = $(SOURCES)"

.PHONY: all run debug clean help info