BOOTSEG=0x7c0

.code16
.text
.global _start

_start:
	jmp start2

start2:
	movw $BOOTSEG,%ax
	movw %ax,%ds
	movw %ax,%es
	movw %ax,%fs
	movw %ax,%gs
	movw $BOOTSEG, %sp # 设置栈指针

	# 设置视频模式为 320x200 256色图形模式
	movw $0x0013, %ax   # ah=0x00 (设置模式), al=0x13 (模式号)
	int $0x10

	# 使用 Teletype (ah=0x0e) 循环打印字符串
	movw $msg, %si
	movb $0x0e, %ah     # ah = 0x0e -> Teletype 输出功能
	movb $0x00, %bh     # bh = 0x00 -> 视频页码 0
	movb $0x0c, %bl     # bl = 0x0c -> 前景色: 亮红色 (在图形模式下生效)

print_loop:
	lodsb               # 从 [ds:si] 加载一个字节到 al, 并增加 si
	cmpb $0, %al        # 检查是否是字符串结尾 (null)
	je halt             # 如果是，则跳转到 halt
	int $0x10           # 调用 BIOS 视频服务
	jmp print_loop      # 继续循环

halt:
	jmp halt            # 无限循环，停止执行

msg:
	.ascii "[Boot] success...\r\n"
	.byte 0             # 字符串以 null 结尾

.org 510
boot_flag:
	.word 0xaa55