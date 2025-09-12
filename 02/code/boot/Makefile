# 编译器和链接器配置
AS = as
LD = ld
GCC = gcc
ASFLAGS = --32
GCCFLAGS = -m32 -march=i386 -nostdinc -Wall -fomit-frame-pointer -c -traditional-cpp
LDFLAGS = -m elf_i386 -s --oformat binary

# 目标文件配置
BOOT_TARGET = boot.img           # 引导扇区 (1 扇区)
LOADER_TARGET = loader.img       # setup/loader (SETUPLEN=4 扇区)
SYSTEM_TARGET = system.bin       # system (head.S) 纯二进制镜像
# 最终磁盘镜像文件名（注意：不得在变量值后留下多余空格，否则 QEMU 参数会被拆分）
COMBINED_TARGET = disk.img
BOOT_OBJECTS = boot.o
LOADER_OBJECTS = loader.o
SYSTEM_OBJECTS = head.o

# QEMU 配置
QEMU = qemu-system-i386
QEMU_FLAGS = -drive file=$(COMBINED_TARGET),if=ide,format=raw
QEMU_DEBUG_FLAGS = -s -S

# 默认目标
all: $(COMBINED_TARGET)

# 汇编 / 预处理 规则
%.o: %.S
	@if echo "$<" | grep -q 'head.S'; then \
	  echo "[GCC] 编译(预处理) $< -> $@"; \
	  $(GCC) $(GCCFLAGS) -o $@ $<; \
	else \
	  $(AS) $(ASFLAGS) -o $@ $<; \
	fi

# 引导扇区规则 (第一个扇区)
$(BOOT_TARGET): $(BOOT_OBJECTS)
	$(LD) $(LDFLAGS) -Ttext 0x0 -o $@ $^

# 加载器规则 (第二到第五扇区)
$(LOADER_TARGET): $(LOADER_OBJECTS)
	$(LD) $(LDFLAGS) -Ttext 0x0 -o $@ $^

# system(head.S) 规则（将来可扩展为 C/ASM 组合的内核）
$(SYSTEM_TARGET): $(SYSTEM_OBJECTS)
	$(LD) $(LDFLAGS) -Ttext 0x0 -e startup_32 -o $@ $^
	@echo "[INFO] system 构建完成(GCC+LD): $@ (大小: $$(stat -c%s $@) 字节)"

# 组合镜像规则 - 引导 + loader + system
$(COMBINED_TARGET): $(BOOT_TARGET) $(LOADER_TARGET) $(SYSTEM_TARGET)
	@echo "创建组合磁盘镜像..."
	rm -f $@
	@echo "写入引导扇区 (LBA 0)"
	dd if=$(BOOT_TARGET) of=$@ bs=512 count=1 conv=notrunc 2>/dev/null
	@echo "写入 loader (LBA 1-4)"
	dd if=$(LOADER_TARGET) of=$@ bs=512 seek=1 count=4 conv=notrunc 2>/dev/null
	@echo "追加 system (从 LBA 5 开始，紧随其后)"
	dd if=$(SYSTEM_TARGET) of=$@ bs=512 seek=5 conv=notrunc 2>/dev/null
	@echo "计算并执行 512 字节对齐填充"
	@SIZE=$$(stat -c%s $@); REM=$$((SIZE % 512)); \
	 if [ $$REM -ne 0 ]; then PAD=$$((512-REM)); \
	   echo "[ALIGN] 追加 $$PAD 字节使镜像 512 对齐"; \
	   dd if=/dev/zero bs=1 count=$$PAD >> $@ 2>/dev/null; \
	 fi; \
	 NEW=$$(stat -c%s $@); echo "组合镜像创建完成: $@ (原始: $$SIZE 字节, 对齐后: $$NEW 字节)"

# 运行目标
run: $(COMBINED_TARGET)
	$(QEMU) $(QEMU_FLAGS)

# 调试目标
debug: $(COMBINED_TARGET)
	@echo "启动 QEMU 调试模式，监听端口 1234"
	$(QEMU) $(QEMU_FLAGS) $(QEMU_DEBUG_FLAGS)

# 清理目标
clean:
	rm -f $(BOOT_OBJECTS) $(LOADER_OBJECTS) $(SYSTEM_OBJECTS) \
          $(BOOT_TARGET) $(LOADER_TARGET) $(SYSTEM_TARGET) $(COMBINED_TARGET)

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
	@echo "  BOOT_TARGET   = $(BOOT_TARGET)"
	@echo "  LOADER_TARGET = $(LOADER_TARGET) (SETUPLEN=4 扇区)"
	@echo "  SYSTEM_TARGET = $(SYSTEM_TARGET) (将被加载到 0x10000)"
	@echo "  COMBINED_IMG  = $(COMBINED_TARGET)"
	@echo "文件布局:"
	@echo "  LBA 0    (扇区1):  引导扇区 boot"
	@echo "  LBA 1-4  (扇区2-5): loader/setup"
	@echo "  LBA 5.. : system (head)"

# 分析镜像文件
analyze: $(COMBINED_TARGET)
	@echo "=== 镜像文件分析 ==="
	@echo "文件大小: $$(stat -c%s $(COMBINED_TARGET)) 字节"
	@echo "扇区数量(向下取整): $$(($$(stat -c%s $(COMBINED_TARGET)) / 512))"
	@echo ""
	@echo "=== 引导扇区签名检查 ==="
	@hexdump -C $(COMBINED_TARGET) | tail -2
	@echo ""
	@echo "=== 前32字节内容 ==="
	@hexdump -C $(COMBINED_TARGET) | head -3

.PHONY: all run debug clean help info analyze
