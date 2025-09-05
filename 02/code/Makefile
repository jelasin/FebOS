# 编译器和链接器配置
AS = as
LD = ld
ASFLAGS = --32
LDFLAGS = -m elf_i386 -s --oformat binary

# 目标文件配置
BOOT_TARGET = boot.img
LOADER_TARGET = loader.img
COMBINED_TARGET = system.img
BOOT_OBJECTS = boot.o
LOADER_OBJECTS = loader.o

# QEMU 配置
QEMU = qemu-system-i386
QEMU_FLAGS = -drive file=$(COMBINED_TARGET),if=ide,format=raw
QEMU_DEBUG_FLAGS = -s -S

# 默认目标
all: $(COMBINED_TARGET)

# 汇编规则
%.o: %.S
	$(AS) $(ASFLAGS) -o $@ $<

# 引导扇区规则 (第一个扇区)
$(BOOT_TARGET): $(BOOT_OBJECTS)
	$(LD) $(LDFLAGS) -Ttext 0x0 -o $@ $^

# 加载器规则 (第二到第五扇区)
$(LOADER_TARGET): $(LOADER_OBJECTS)
	$(LD) $(LDFLAGS) -Ttext 0x0 -o $@ $^

# 组合镜像规则 - 将引导扇区和加载器合并
$(COMBINED_TARGET): $(BOOT_TARGET) $(LOADER_TARGET)
	@echo "创建组合镜像文件..."
	# 创建引导扇区 (512字节)
	dd if=$(BOOT_TARGET) of=$@ bs=512 count=1 conv=notrunc 2>/dev/null
	# 添加加载器到第2-5扇区 (4个扇区，2048字节)
	dd if=$(LOADER_TARGET) of=$@ bs=512 seek=1 count=4 conv=notrunc 2>/dev/null
	# 确保文件大小为 2560 字节 (5个扇区)
	dd if=/dev/zero of=$@ bs=512 seek=5 count=0 2>/dev/null
	@echo "组合镜像创建完成: $@ (大小: $$(stat -c%s $@) 字节)"

# 运行目标
run: $(COMBINED_TARGET)
	$(QEMU) $(QEMU_FLAGS)

# 调试目标
debug: $(COMBINED_TARGET)
	@echo "启动 QEMU 调试模式，监听端口 1234"
	@echo "在另一个终端中运行: gdb -ex 'target remote localhost:1234'"
	$(QEMU) $(QEMU_FLAGS) $(QEMU_DEBUG_FLAGS)

# 清理目标
clean:
	rm -f $(BOOT_OBJECTS) $(LOADER_OBJECTS) $(BOOT_TARGET) $(LOADER_TARGET) $(COMBINED_TARGET)

# 显示帮助信息
help:
	@echo "可用目标:"
	@echo "  all       - 编译完整的两阶段引导系统 (默认)"
	@echo "  boot.img  - 只编译第一阶段引导扇区"
	@echo "  loader.img- 只编译第二阶段加载器"
	@echo "  run       - 在 QEMU 中运行完整系统"
	@echo "  debug     - 在调试模式下启动 QEMU"
	@echo "  clean     - 清理生成的文件"
	@echo "  help      - 显示此帮助信息"
	@echo "  info      - 显示构建信息"

# 显示构建信息
info:
	@echo "编译器设置:"
	@echo "  AS = $(AS)"
	@echo "  LD = $(LD)"
	@echo "  ASFLAGS = $(ASFLAGS)"
	@echo "  LDFLAGS = $(LDFLAGS)"
	@echo "目标文件:"
	@echo "  BOOT_TARGET = $(BOOT_TARGET)"
	@echo "  LOADER_TARGET = $(LOADER_TARGET)"
	@echo "  COMBINED_TARGET = $(COMBINED_TARGET)"
	@echo "文件布局:"
	@echo "  扇区 1:     引导扇区 (boot.S)"
	@echo "  扇区 2-5:   加载器 (loader.S)"

# 分析镜像文件
analyze: $(COMBINED_TARGET)
	@echo "=== 镜像文件分析 ==="
	@echo "文件大小: $$(stat -c%s $(COMBINED_TARGET)) 字节"
	@echo "扇区数量: $$(($$(stat -c%s $(COMBINED_TARGET)) / 512))"
	@echo ""
	@echo "=== 引导扇区签名检查 ==="
	@hexdump -C $(COMBINED_TARGET) | tail -2
	@echo ""
	@echo "=== 前32字节内容 ==="
	@hexdump -C $(COMBINED_TARGET) | head -3

.PHONY: all run debug clean help info analyze
