# === 常量定义部分 ===
SETUPLEN = 4           # setup模块占用的扇区数量（4个扇区）
BOOTSEG  = 0x7c0       # 引导扇区被BIOS加载到的段地址（0x7c00物理地址）
INITSEG  = 0x9000      # 引导扇区将要移动到的目标段地址（0x90000物理地址）
SETUPSEG = 0x9020      # setup模块将要加载到的段地址（0x90200物理地址）
SYSSEG   = 0x1000      # system将被加载到的段地址（0x10000物理地址）
SYSSIZE  = 0x3000      # 以16字节(段落/paragraph=16B)为单位的最大加载大小: 0x3000*16=192KB
ENDSEG   = SYSSEG + SYSSIZE  # 系统结束段地址（上界）
ROOT_DEV = 0x000       # 根设备号，0表示由setup程序自动检测

.code16              # 告诉汇编器生成16位实模式代码
.text                # 代码段开始

.global _start       # 声明全局符号_start，作为程序入口点
_start:
	jmp start2       # 无条件跳转到start2标签，跳过可能的数据区域

start2:
	# === 第一阶段：初始化环境 ===
	# 设置所有段寄存器指向引导扇区当前位置
	movw $BOOTSEG, %ax   # 将引导段地址0x7c0加载到AX
	movw %ax, %ds        # 设置数据段寄存器DS = 0x7c0
	movw %ax, %es        # 设置附加段寄存器ES = 0x7c0
	movw %ax, %fs        # 设置FS段寄存器 = 0x7c0
	movw %ax, %gs        # 设置GS段寄存器 = 0x7c0
	movw %ax, %ss        # 设置栈段寄存器SS = 0x7c0
	movw $0x0000, %sp    # 设置栈指针SP = 0x0000（栈顶在0x7c0:0 = 0x7c00）

	# === 设置图形显示模式 ===
	movw $0x0013, %ax    # AH=0x00(设置显示模式), AL=0x13(320x200 256色) AL=0x03(80x25文本模式)
	int $0x10            # 调用BIOS视频服务中断

	# === 显示启动信息 ===
	movw $msg_1, %si     # 将msg_1字符串地址加载到SI寄存器
	call print_string    # 调用字符串打印子程序

	# === 第二阶段：重定位引导代码 ===
	# 将引导扇区从0x7c00复制到0x90000，为后续加载腾出空间
	movw $BOOTSEG, %ax   # 源段地址：0x7c0
	movw %ax, %ds        # 设置DS为源段
	movw $INITSEG, %ax   # 目标段地址：0x9000  
	movw %ax, %es        # 设置ES为目标段
	movw $256, %cx       # 复制256个字（512字节，正好一个扇区）
	subw %si, %si        # SI = 0（源偏移地址）
	subw %di, %di        # DI = 0（目标偏移地址）
	rep                  # 重复执行下一条指令CX次
	movsw                # 从DS:SI复制字到ES:DI，并自动增加SI和DI

	# === 跳转到新位置继续执行 ===
	jmpl $INITSEG, $go   # 远跳转到0x9000:go，切换到新的代码位置

go:
	# === 第三阶段：在新位置重新初始化 ===
	movw %cs, %ax        # 将当前代码段寄存器CS的值复制到AX
	movw %ax, %ds        # 设置数据段 = 代码段
	movw %ax, %es        # 设置附加段 = 代码段  
	movw %ax, %ss        # 设置栈段 = 代码段
	movw $0xFF00, %sp    # 重新设置栈指针到高地址

load_setup:
	# === 第四阶段：从硬盘加载setup模块 ===
	movw $SETUPSEG, %ax
	movw %ax, %es        # ES = 0x9020
	movw $0, %bx         # BX = 0, 所以加载到 0x9020:0

	movw $0x0080, %dx    # DH=0(磁头0), DL=0x80(驱动器0x80，即第一块硬盘)
	movw $0x0002, %cx    # CH=0(磁道0), CL=2(从第2扇区开始，第1扇区是引导扇区)
	movb $SETUPLEN, %al  # AL=4，要读取的扇区数
	movb $0x02, %ah      # AH=2，BIOS磁盘服务功能号：读扇区
	int $0x13            # 调用BIOS磁盘服务中断
	jnc ok_load_setup    # 如果CF标志位=0（无错误），跳转到成功处理

	# === 错误处理：重置磁盘驱动器并重试 ===
	movw $0x0080, %dx    # DL=0x80，指定第一块硬盘
	movw $0x0000, %ax    # AH=0，BIOS磁盘服务功能号：重置磁盘系统
	int $0x13            # 调用BIOS磁盘服务
	jmp load_setup       # 重新尝试加载setup

ok_load_setup:
	# === 显示加载成功信息 ===
	movw $msg_2, %si     # 将msg_2字符串地址加载到SI
	call print_string    # 调用字符串打印子程序

	# === 第五阶段：读取 system (head) 到 0x10000 ===
	# 此处仿照 Linux 0.11 的 read_it/read_track 逻辑进行精简版本实现
	movw $SYSSEG, %ax      # 目标段 = 0x1000
	movw %ax, %es
	xorw %bx, %bx          # 偏移 0
	call read_system       # 读取 system (从磁盘的后续扇区开始)
	call kill_motor        # 关闭软盘/磁盘马达（兼容逻辑）

	# === 第六阶段：转交控制权给 setup 模块 ===
	jmpl $SETUPSEG, $0     # 远跳转到0x9020:0，开始执行setup代码

halt:
	# === 异常处理：系统挂起 ===
	hlt                  # CPU进入停机状态，等待中断
	jmp halt             # 死循环，防止意外继续执行

# ===========================================================
# 读取 system (head) 模块到 0x10000 (ES 初始 = SYSSEG)
# 简化策略：假设 system 紧随 loader 之后，从 LBA = 1+SETUPLEN 开始连续存放。
# 不做跨 64KB 边界复杂处理，只顺序填充，直到达到 SYSSIZE 或读失败。
# ===========================================================
read_system:
	pushw %ax
	pushw %bx
	pushw %cx
	pushw %dx

	# 起始 LBA (CHS 简化: 只适用于单柱面情况下的 demo；真实实现需 CHS 转换)
	movw $0, %dx        # DH=head=0, DL=0x80 硬盘(后面补)
	movb $0x80, %dl     # 设备: 第一块硬盘
	movw $0, %cx        # CH=0, CL稍后设置
	movw $(1+SETUPLEN), %si  # 当前逻辑扇区号 (从第5扇区开始)
	movw $(1+SETUPLEN), %di  # 记录起始，备用
	movw $0, %bp             # 已读的扇区计数

.rs_loop:
	cmpw $SYSSIZE, %bp    # 已读扇区是否超过（用“段”粗略限制）
	jae .rs_done

	# 将逻辑扇区号转为 CHS (极度简化: 只支持同一柱面前若干扇区)
	movw %si, %ax
	addw $1, %ax          # BIOS 扇区号从1开始
	movb %al, %cl         # CL=扇区号 (低6位)
	movb $0, %ch          # CH=0 (track 0)

	movw $0x0201, %ax     # AH=2 读磁盘; AL=1 扇区
	int $0x13
	jc .rs_done           # 出错则结束

	# 前进到下一个缓冲区位置
	addw $512, %bx
	jc .next_segment
	jmp .cont

.next_segment:
	# 进入下一个段 (避免偏移溢出); 不能直接对段寄存器做 add
	movw %es, %ax
	addw $0x1000, %ax    # 前进 64KB (0x10000 bytes / 16 = 0x1000 段)
	movw %ax, %es
	xorw %bx, %bx

.cont:
	incw %si
	incw %bp
	jmp .rs_loop

.rs_done:
	popw %dx
	popw %cx
	popw %bx
	popw %ax
	ret

# 关闭磁盘马达
kill_motor:
	pushw %dx
	movw $0x3f2, %dx
	movb $0x00, %al
	outb %al, (%dx)
	popw %dx
	ret

# === 子程序定义 ===
# 功能：在屏幕上打印以null结尾的字符串
# 输入：SI寄存器指向字符串首地址
# 输出：在屏幕上显示字符串
print_string:
	movb $0x0e, %ah      # AH=0x0e，BIOS视频服务功能号：TTY模式输出字符
	movb $0x00, %bh      # BH=0，视频页号（通常为0）
	movb $0x0c, %bl      # BL=0x0c，字符颜色属性：亮红色
.print_char:
	lodsb                # 从DS:SI加载一个字节到AL，并自动递增SI
	cmpb $0, %al         # 比较AL是否为0（字符串结束符）
	je .print_done       # 如果AL=0，跳转到完成标签
	int $0x10            # 调用BIOS视频服务，显示AL中的字符
	jmp .print_char      # 跳回循环开始，处理下一个字符
.print_done:
	ret                  # 返回调用者

# === 数据定义部分 ===
msg_1:
	.ascii "[Boot] success...!\r\n"      # 启动成功消息
	.byte 0              # 字符串结束符（null终止符）

msg_2:
	.ascii "[Boot] loader been loaded...\r\n"  # setup加载成功消息
	.byte 0              # 字符串结束符

# === 引导扇区结构 ===	
.org 508                 # 定位到偏移508字节处（扇区末尾-4字节）
root_dev:
	.word ROOT_DEV       # 2字节：根设备号
boot_flag:
	.word 0xaa55         # 2字节：引导扇区标志，BIOS通过此标志识别可引导扇区
