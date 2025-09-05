.code16                    # 指定生成16位代码
.text                      # 代码段
.global _start_setup       # 声明全局符号，供链接器使用

.equ INITSEG, 0x9000      # 定义常量：初始化段地址为 0x9000

_start_setup:
	# === 段寄存器初始化 ===
	movw %cs, %ax         # 将代码段寄存器CS的值复制到AX
	movw %ax, %ds         # 设置数据段寄存器DS = CS
	movw %ax, %es         # 设置扩展段寄存器ES = CS
	                      # 这样所有段都指向同一内存区域

    # === 显示启动信息 ===
	movw $setup_msg, %si  # SI指向要打印的消息字符串
	call print_string     # 调用字符串打印子程序

	# === 获取并保存光标位置 ===
	movw $INITSEG, %ax    # 设置数据段为初始化段
	movw %ax, %ds
	movb $0x03, %ah       # BIOS功能号0x03：获取光标位置
	xor %bh, %bh          # BH=0，视频页号
	int $0x10             # 调用BIOS视频服务中断
	movw %dx, (0)         # 将光标位置(DH=行,DL=列)保存到地址0
	
	# 恢复代码段给字符串访问
	movw %cs, %ax
	movw %ax, %ds
	# 打印光标位置信息
	movw $cursor_msg, %si
	call print_string
	# 切换回数据段获取数值
	movw $INITSEG, %ax
	movw %ax, %ds
	movw (0), %dx
	# 恢复代码段给print_hex
	movw %cs, %ax
	movw %ax, %ds
	call print_hex

	# === 获取并保存扩展内存大小 ===
	movw $INITSEG, %ax    # 设置数据段为初始化段
	movw %ax, %ds
	movb $0x88, %ah       # BIOS功能号0x88：获取扩展内存大小
	int $0x15             # 调用BIOS系统服务中断
	movw %ax, (2)         # 将内存大小(KB)保存到地址2
	
	# 恢复代码段给字符串访问
	movw %cs, %ax
	movw %ax, %ds
	# 打印内存大小信息
	movw $memory_msg, %si
	call print_string
	# 切换回数据段获取数值
	movw $INITSEG, %ax
	movw %ax, %ds
	movw (2), %dx
	# 恢复代码段给print_hex
	movw %cs, %ax
	movw %ax, %ds
	call print_hex

	# === 获取并保存显示模式信息 ===
	movw $INITSEG, %ax    # 设置数据段为初始化段
	movw %ax, %ds
	movb $0x0f, %ah       # BIOS功能号0x0f：获取当前视频模式
	int $0x10             # 调用BIOS视频服务中断
	movw %bx, (4)         # 保存视频页号到地址4
	movw %ax, (6)         # 保存视频模式到地址6
	
	# 恢复代码段给字符串访问
	movw %cs, %ax
	movw %ax, %ds
	# 打印视频模式信息
	movw $video_msg, %si
	call print_string
	# 切换回数据段获取数值
	movw $INITSEG, %ax
	movw %ax, %ds
	movw (6), %dx
	# 恢复代码段给print_hex
	movw %cs, %ax
	movw %ax, %ds
	call print_hex

	# === 获取并保存字符字体信息 ===
	movb $0x12, %ah       # BIOS功能号0x12：获取视频配置信息
	movb $0x10, %bl       # BL=0x10，获取EGA/VGA配置信息
	int $0x10             # 调用BIOS视频服务中断
	movw %ax, (8)         # 保存EGA/VGA状态信息
	movw %bx, (10)        # 保存显示内存大小
	movw %cx, (12)        # 保存特征位信息

	# === 获取第一块硬盘(hd0)参数 ===
	movw $0x0000, %ax     # 设置段寄存器为0
	movw %ax, %ds
	ldsw (4 * 0x41), %si  # 从中断向量表0x41处加载硬盘参数表地址到DS:SI
	                      # 0x41是第一块硬盘参数中断向量
	movw $INITSEG, %ax    # 设置目标段为初始化段
	movw %ax, %es
	movw $0x0080, %di     # 目标偏移地址0x0080
	movw $0x10, %cx       # 复制16字节
	rep                   # 重复执行下一条指令
	movsb                 # 从DS:SI复制字节到ES:DI，并递增SI和DI

	# === 获取第二块硬盘(hd1)参数 ===
	movw $0x0000, %ax     # 重置段寄存器
	movw %ax, %ds
	ldsw (4 * 0x46), %si  # 从中断向量表0x46处加载第二块硬盘参数表地址
	movw $INITSEG, %ax    # 设置目标段
	movw %ax, %es
	movw $0x0090, %di     # 目标偏移地址0x0090
	movw $0x10, %cx       # 复制16字节
	rep
	movsb

	# === 检测第二块硬盘是否真实存在 ===
	movw $0x1500, %ax     # AH=0x15，BIOS磁盘服务：获取磁盘类型
	movb $0x81, %dl       # DL=0x81，第二块硬盘
	int $0x13             # 调用BIOS磁盘服务中断
	jc no_disk1           # 如果进位标志置位(出错)，跳转到no_disk1
	cmpb $3, %ah          # 检查返回值：AH=3表示硬盘存在
	je is_disk1           # 如果相等，硬盘存在，跳转到is_disk1

no_disk1:
	# === 第二块硬盘不存在，清空其参数区域 ===
	movw $INITSEG, %ax    # 设置目标段
	movw %ax, %es
	movw $0x0090, %di     # 目标地址
	movw $0x10, %cx       # 清空16字节
	movw $0x00, %ax       # 用0填充
	rep
	stosb                 # 将AL的值存储到ES:DI，并递增DI

is_disk1:
	# === 恢复数据段寄存器 ===
	movw %cs, %ax         # 恢复DS为代码段
	movw %ax, %ds

    # === 显示完成信息 ===
	movw $setup_success_msg, %si  # SI指向成功消息
	call print_string             # 调用打印子程序

halt:
	# === 程序结束，进入死循环 ===
	jmp halt              # 无限循环，停止执行

# ============================================================================
# === 子程序: 打印以null结尾的字符串 ===
# 输入参数: SI寄存器指向字符串首地址
# 输出: 在屏幕上显示字符串
# 使用寄存器: AX, BX, SI
# ============================================================================
print_string:
	movb $0x0e, %ah       # AH=0x0e，BIOS TTY模式字符输出功能
	movb $0x00, %bh       # BH=0，视频页号(第0页)
	movb $0x0D, %bl       # BL=0x0D，字符属性

.print_char:              # 字符输出循环
	lodsb                 # 从DS:SI加载一个字节到AL，同时SI自增1
	cmpb $0, %al          # 检查是否为字符串结束符(null)
	je .print_done        # 如果是结束符，跳转到函数结束
	int $0x10             # 调用BIOS中断0x10显示字符
	jmp .print_char       # 继续处理下一个字符

.print_done:
	ret                   # 返回调用者

# ============================================================================
# === 子程序: 打印16位十六进制数 ===
# 输入参数: DX寄存器包含要打印的16位数值
# 输出: 在屏幕上显示4位十六进制数（格式：0xXXXX）
# 使用寄存器: AX, BX, CX, DX, SI (保护原始DX值)
# ============================================================================
print_hex:
	pushw %dx             # 保存原始DX值到栈
	
	# 打印 "0x" 前缀
	movw $hex_prefix, %si
	call print_string
	
	movw $4, %cx          # 要处理4个十六进制位
	
.hex_loop:
	rolw $4, %dx          # 将DX左旋转4位，把最高4位移到最低位
	movw %dx, %ax         # 复制到AX
	andw $0x000f, %ax     # 只保留最低4位
	
	# 转换为ASCII字符
	cmpw $10, %ax         # 比较是否小于10
	jl .hex_digit         # 如果<10，是数字0-9
	addw $7, %ax          # 如果>=10，调整为字母A-F
.hex_digit:
	addw $0x30, %ax       # 转换为ASCII ('0'=0x30)
	
	# 输出字符
	movb %al, %al         # 确保AL包含字符
	movb $0x0e, %ah       # BIOS TTY输出功能
	movb $0x00, %bh       # 视频页号
	movb $0x05, %bl       # 字符属性：白色
	int $0x10             # 调用BIOS中断显示字符
	
	loop .hex_loop        # 循环处理下一位
	
	# 打印换行
	movw $newline, %si
	call print_string
	
	popw %dx              # 恢复原始DX值
	ret                   # 返回调用者

# ============================================================================
# === 数据区域 ===
# ============================================================================
setup_msg:
	.ascii "[Loader] Setup is running...\r\n\r\n"  # 设置阶段开始消息
	.byte 0                               # 字符串结束符

cursor_msg:
	.ascii "Cursor position: "            # 光标位置信息
	.byte 0

memory_msg:
	.ascii "Extended memory: "            # 扩展内存信息  
	.byte 0

video_msg:
	.ascii "Video mode: "                 # 视频模式信息
	.byte 0

hex_prefix:
	.ascii "0x"                           # 十六进制前缀
	.byte 0

newline:
	.ascii "\r\n"                         # 换行符
	.byte 0

setup_success_msg:
    .ascii "\r\n[Loader] Setup completed...\r\n"  # 设置完成消息
    .byte 0                                         # 字符串结束符
