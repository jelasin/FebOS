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

	# 恢复代码段给字符串访问
	movw %cs, %ax
	movw %ax, %ds
	# 打印字符字体信息
	movw $font_msg, %si
	call print_string
	# 切换回数据段获取数值
	movw $INITSEG, %ax
	movw %ax, %ds
	movw (8), %dx        # EGA/VGA状态信息

	# 恢复代码段给print_hex
	movw %cs, %ax
	movw %ax, %ds
	call print_hex

	movw $INITSEG, %ax
	movw %ax, %ds
	movw (10), %dx       # 显示内存大小
	movw %cs, %ax
	movw %ax, %ds
	call print_hex

	movw $INITSEG, %ax
	movw %ax, %ds
	movw (12), %dx       # 特征位信息
	movw %cs, %ax
	movw %ax, %ds
	call print_hex

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

	# 打印hd0参数
	movw %cs, %ax          # 切回代码段打印字符串
	movw %ax, %ds
	movw $hd0_msg, %si
	call print_string

	movw $INITSEG, %ax     # 切换到参数所在段
	movw %ax, %ds
	movw $0x0080, %si      # SI指向hd0参数 
	movw $16, %cx          # 共16字节

.print_hd0_loop:
	lodsb                  # AL = [DS:SI]
	pushw %cx
	call print_hex8        # 打印1字节(2位hex)
	# 打印空格
	movb $' ', %al
	movb $0x0e, %ah
	movb $0x00, %bh
	movb $0x07, %bl
	int $0x10
	popw %cx
	loop .print_hd0_loop

	# 换行
	movw %cs, %ax
	movw %ax, %ds
	movw $newline, %si
	call print_string

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
	je has_disk1          # 如果相等，硬盘存在
	jmp no_disk1          # 其他返回值按不存在处理

no_disk1:
	# === 第二块硬盘不存在，清空其参数区域 ===
	movw $INITSEG, %ax    # 设置目标段
	movw %ax, %es
	movw $0x0090, %di     # 目标地址
	movw $0x10, %cx       # 清空16字节
	movw $0x00, %ax       # 用0填充
	rep
	stosb                 # 将AL的值存储到ES:DI，并递增DI

	# 打印hd1不存在信息
	movw %cs, %ax
	movw %ax, %ds
	movw $hd1_absent_msg, %si
	call print_string
	jmp after_hd1          # 跳过参数打印

has_disk1:
	# === 恢复数据段寄存器 ===
	movw %cs, %ax         # 恢复DS为代码段
	movw %ax, %ds

	# 如果hd1存在（或已清空），打印其参数（清空后即全0）
	movw $hd1_msg, %si
	call print_string

	movw $INITSEG, %ax
	movw %ax, %ds
	movw $0x0090, %si      # SI指向hd1参数
	movw $16, %cx
.print_hd1_loop:
	lodsb
	pushw %cx
	call print_hex8
	movb $' ', %al         # 空格
	movb $0x0e, %ah
	movb $0x00, %bh
	movb $0x07, %bl
	int $0x10
	popw %cx
	loop .print_hd1_loop

	movw %cs, %ax
	movw %ax, %ds
	movw $newline, %si
	call print_string

after_hd1:
	# 切换到文本模式 80x25 (mode 3) 并清屏 (在仍可用 BIOS 中断前进行)
	movw $0x0003, %ax
	int $0x10
	movb $0x06, %ah
	movb $0x00, %al
	movb $0x07, %bh
	xor %cx, %cx
	movw $0x184f, %dx
	int $0x10
	# 重置 vga_print 光标
	movw %cs, %ax
	movw %ax, %ds
	movw $0, cursor_pos

	# === 加载 GDT ===
	# 计算 gdt_start 的物理地址: (CS << 4) + offset(gdt_start)
	# 写入到 gdt_descriptor (6 字节: limit(2) + base(4)) 并执行 lgdt
	movw %cs, %ax           # AX = 当前代码段
	pushw %ax
	pushw %bx
	pushw %dx
	movw %ax, %dx           # DX = CS (用于高位计算)
	shl $4, %ax             # AX = CS << 4  (段基址低 16 位候选)
	movw $gdt_start, %bx    # BX = gdt_start 偏移
	addw %bx, %ax           # AX = 低 16 位物理地址
	movw %ax, gdt_descriptor+2  # 填写 base 低 16 位
	# 计算高 16 位: (CS<<4) 的高 4 位 + 低 16 位加法产生的进位
	movw %dx, %bx           # BX = CS
	shr $12, %bx            # BX = (CS >> 12) = (CS<<4) 的高 4 位
	adcw $0, %bx            # 进位加入
	movw %bx, gdt_descriptor+4  # base 高 16 位
	popw %dx
	popw %bx
	popw %ax
	movw %cs, %ax           # 重新确保 DS=CS
	movw %ax, %ds
	lgdt gdt_descriptor     # 加载 GDT
	movw $gdt_load_msg, %si
	call vga_print

	# === 系统搬移 ===
	movw %cs, %ax
	movw %ax, %ds
	movw $reloc_start_msg, %si
	call vga_print

	cli
	cld
	movw $0x1000, %ax
	movw %ax, %ds
	movw $0x0000, %ax
	movw %ax, %es
	xor %si, %si
	xor %di, %di
	movw $0x8000, %cx
	rep movsw
	sti

	movw %cs, %ax
	movw %ax, %ds
	movw $reloc_done_msg, %si
	call vga_print

	# open A20 (占位, 未实现)

	# jmp protect mode (占位, 未实现)

halt:
	movw %cs, %ax
	movw %ax, %ds
	movw $setup_success_msg, %si
	call vga_print
	halt_loop:
	hlt
	jmp halt_loop

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

# =========================================================================
# === 子程序: 打印8位十六进制数 (AL) ===
# 输入: AL=要打印的字节
# 破坏: AX,BX
# =========================================================================
print_hex8:
	pushw %ax
	pushw %bx
	movb %al, %bl          # 保存原字节
	movb %bl, %al          # 高4位
	shr $4, %al
	call print_hex_nibble
	movb %bl, %al          # 低4位
	andb $0x0f, %al
	call print_hex_nibble
	popw %bx
	popw %ax
	ret

# =========================================================================
# === 子程序: 打印4位十六进制数 (AL低4位) ===
# 输入: AL=0..15
# 破坏: AX
# =========================================================================
print_hex_nibble:
	cmpb $10, %al
	jb .nibble_digit
	addb $7, %al
.nibble_digit:
	addb $0x30, %al
	movb $0x0e, %ah
	movb $0x00, %bh
	movb $0x05, %bl
	int $0x10
	ret

# ============================================================================
# 直接写显存的简易打印 vga_print
# 输入: SI 指向以 0 结尾字符串, 使用文本模式 80x25, 写入 0xB800: 当前位置递增
# 仅支持 '\r' '\n'; 颜色属性固定 0x0F
# 使用寄存器: AX,BX,CX,DX,SI,DI（不保存）
# ============================================================================
vga_print:
	pushw %ds
	pushw %es
	movw $0xB800, %ax
	movw %ax, %es
	# 简单：使用静态光标变量 (放在代码段数据里) cursor_pos (字)
	movw %cs, %ax
	movw %ax, %ds
	movw cursor_pos, %di      # DI = 当前位置(以字节为单位)
	movb $0x0F, %bl           # 颜色属性
.vp_loop:
	lodsb                     # AL = 字符
	cmpb $0, %al
	je .vp_done
	cmpb $'\n', %al
	je .vp_newline
	cmpb $'\r', %al
	je .vp_cr
	movb %al, %es:(%di)
	incw %di
	movb %bl, %es:(%di)
	incw %di
	jmp .vp_loop
.vp_cr:
	# 回车: DI 回到当前行行首 (列0). 行宽=160 字节
	movw %di, %ax
	movw $160, %bx
	xorw %dx, %dx
	divw %bx                 # AX=行号, DX=列偏移
	subw %dx, %di            # 退回列偏移 -> 行首
	jmp .vp_loop
.vp_newline:
	# 换行: 跳到下一行行首
	# 算当前行号+1，再乘160
	movw %di, %ax
	movw $160, %bx
	xorw %dx, %dx
	divw %bx      # AX=行号
	incw %ax
	mul %bx       # AX = (行号+1)*160
	movw %ax, %di
	jmp .vp_loop
.vp_done:
	movw %di, cursor_pos
	popw %es
	popw %ds
	ret

cursor_pos:
	.word 0           # 初始光标(字节偏移)

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

font_msg:
	.ascii "Font info: \r\n"                  # 字符字体信息
	.byte 0

hd0_msg:
	.ascii "HD0 params: \r\n"
	.byte 0

hd1_msg:
	.ascii "HD1 params: \r\n"
	.byte 0

hd1_absent_msg:
	.ascii "HD1 not present, params zeroed.\r\n"
	.byte 0

newline:
	.ascii "\r\n"                         # 换行符
	.byte 0

setup_success_msg:
    .ascii "[Loader] Setup completed...\r\n"  # 设置完成消息
    .byte 0                                       # 字符串结束符

reloc_start_msg:
	.ascii "[Loader] Relocating system 0x10000 -> 0x00000 (512KB)\r\n"
	.byte 0

reloc_done_msg:
	.ascii "[Loader] Relocation done.\r\n"
	.byte 0

gdt_load_msg:
	.ascii "[Loader] GDT loaded (flat code=0x08, data=0x10, vga=0x18).\r\n"
	.byte 0

# ===== GDT 定义 (单一版本, 包含 VGA 段) =====
.align 8
gdt_start:
	# 0x00 空描述符
	.word 0,0
	.word 0,0
	# 0x08 代码段: base=0 limit=4GB 粒度4K D=1 32位 可执行可读
	.word 0xFFFF, 0x0000
	.word 0x9A00, 0x00CF
	# 0x10 数据段: base=0 limit=4GB 粒度4K D=1 可读写
	.word 0xFFFF, 0x0000
	.word 0x9200, 0x00CF
	# 0x18 VGA 段: base=0xB8000 limit=0x0FFFF 粒度字节 (G=0) D=1
	.word 0xFFFF, 0x8000        # limit 0:15, base 0:15
	.word 0x920B, 0x0040        # base 16:23 + access, flags + limit 16:19 + base 24:31
gdt_end:

gdt_descriptor:                 # 6 字节伪描述符, base 运行时回填
	.word gdt_end - gdt_start - 1
	.word 0
	.word 0

CODE_SEL = 0x08
DATA_SEL = 0x10
VGA_SEL  = 0x18
