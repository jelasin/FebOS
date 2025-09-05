# loader 实现

## 启动流程概述

## 代码文件结构

## 相关知识点补充

### int 0x13h 中断

BIOS 磁盘服务中断，用于在实模式下访问磁盘（软盘 / 硬盘 / 光盘等）。早期阶段 loader 常用它把后续阶段代码读入内存。

核心寄存器约定 (传统 CHS 接口):

- AH: 功能号
- AL: 读/写的扇区数 (部分功能含义不同)
- DL: 驱动器号 (0x00~ 软驱, 0x80~ 硬盘第一个)
- CH: 柱面低 8 位
- CL: bits 0-5 扇区号(1 起), bits 6-7 柱面高 2 位
- DH: 磁头号
- ES:BX: 数据缓冲区起始实模式段:偏移
- CF(进位标志): 调用后=1 表示失败; 失败时 AH 返回错误码
  常见错误码: 0x01 参数错误, 0x02 地址不可读, 0x04 驱动器初始化失败, 0x20 控制器失败 等

常用功能号 (AH):

- 00h: 重置驱动器
- 02h: 读扇区 (CHS)
- 03h: 写扇区 (CHS)
- 08h: 获取驱动器参数 (返回最大柱面/磁头/扇区等)
- 0fh: 获取显示器的显示模式
- 41h: 检测扩展 EDD 是否可用 (BX=55AAh)
- 42h: 扩展读 (LBA, 使用 DAP 结构)
- 43h: 扩展写
(当磁盘容量超出传统 CHS 可寻址范围，需要使用 41h/42h 扩展接口)

CHS 寻址计算 (仅供理解):

- 逻辑扇区号 `L = (C * heads + H) * SPT + (S - 1)`
其上限受限于 1024 柱面、256 磁头(实际上 255)、63 扇区 ≈ 8GB（实际更小），因此大磁盘使用 EDD (LBA)。

典型读取若干扇区 (CHS) 汇编示例:

```asm
; 输入: 期望从 (C,H,S) 开始读取 count 扇区到 ES:BX
; 这里示例读取第 2 扇区 (S=2) 起的 4 个扇区到 0x0000:0x7E00
; 假设驱动器 0x80, 柱面 0, 磁头 0
mov ax, 0x0000
mov es, ax
mov bx, 0x7E00

mov ah, 0x02        ; 功能号: 读
mov al, 0x04        ; 4 个扇区
mov ch, 0x00        ; 柱面 0 (低 8 位)
mov cl, 0x02        ; 扇区号=2 (bits0-5=2), bits6-7=柱面高位=0
mov dh, 0x00        ; 磁头 0
mov dl, 0x80        ; 第一个硬盘
int 0x13
jc disk_error       ; CF=1 失败
; 成功继续
jmp short continue

disk_error:
mov si, msg_err
; 此处可输出错误信息或重试 (常见做法: 重置 AH=00h 再试若干次)

continue:
; 后续处理...
msg_err db "Disk read error",0
```

重试策略:

1. 失败 -> 调用 AH=00h 重置 -> 再试 (一般 3 次)。
2. 仍失败 -> 显示错误并停机或进入调试分支。

扩展读 (EDD, AH=42h):

- 需要先调用 AH=41h 检测支持 (返回 BX=AA55h)
- 准备 DAP (Disk Address Packet)，结构(典型 16 字节):
  Offset  Size  描述
  00h     1     size=10h
  01h     1     保留=0
  02h     2     扇区数
  04h     2     目标缓冲区偏移
  06h     2     目标缓冲区段
  08h     8     起始 LBA (QWORD)
- DS:SI 指向 DAP, AH=42h, DL=驱动器号, int 13h

何时切换到扩展接口:

- 需要访问超过 CHS 上限的 LBA
- 统一使用 LBA 逻辑更清晰（但需 BIOS 支持 EDD）

调试技巧:

- 失败时读取 AH 错误码
- 可在失败路径里用 BIOS int 10h 打印字符
- 确保中断前禁止/适度使用栈，段寄存器正确

总结:

- 实模式早期 loader 先用 0x13h 传统接口读取少量扇区足够启动第二阶段
- 更完整的二阶段可引入 LBA (扩展 0x13h) 或直接切换到保护模式 + 自己的驱动

### int 0x15h 中断

BIOS “系统服务”集合，和 loader 关系最紧密的通常只有两类:

1) 物理内存布局探测 (为分页/内存分配做准备)
2) A20 线开启 (允许访问 1MB 以上线性地址)

常用功能 (AX):

- E820h: 获取系统内存映射 (首选, 现代 BIOS)
- E801h: 早期扩展内存大小 (作为 E820 失败的次级方案)
- 8800h / 8801h: 仅返回扩展内存 KB 数 (最老旧兜底)
- 2401h: 启用 A20
- 2402h: 关闭 A20 (一般不用)
- 2403h: 查询 A20 状态
(还有很多电源管理 / 系统控制功能，这里省略)

内存探测 (E820):
输入:

- EAX = E820h
- EDX = 'SMAP' (ASCII: 53 4D 41 50h)
- EBX = 0 (第一次), BIOS 返回的 EBX 继续传入下一次
- ECX = 缓冲区大小 (至少 20)
- ES:DI = 缓冲区
输出:
- CF=0 成功
- EAX = 'SMAP'
- EBX = 下一个继续值 (为 0 表示结束)
- ECX = 实际写入大小 (>=20)
- 缓冲区结构 (20/24 字节常见):
  QWORD Base
  QWORD Length
  DWORD Type   (1=可用RAM, 2=保留, 3=ACPI可回收, 4=ACPI NVS, 5=坏内存)
  (可选 DWORD Attr: bit0=1 表示可用区可热插拔等)

示例: 收集内存映射 (保留最多 N 条)

```asm
; 目标: 把 E820 记录写到 mem_map 缓冲, 每条 24 字节 (含 Attr)
; 假设: ES 已指向 mem_map 段, DI=0, 保存条目数量到 mem_count
; 注意: 需在 16 位实模式下，使用 32 位寄存器前要确保汇编器允许 (或用 db/dw 方式解析)
xor ebx, ebx          ; continuation = 0
mov edx, 'SMAP'
mov eax, 0E820h
mov ecx, 24           ; 期望 24 字节
mov di, 0
mov word [mem_count], 0

e820_loop:
mov eax, 0E820h
mov edx, 'SMAP'
mov ecx, 24
push di               ; 记录当前写入偏移
int 15h
jc  e820_done         ; CF=1 结束/失败 (若失败可尝试降级 E801)
cmp eax, 'SMAP'
jne e820_done
pop dx                ; 取回之前 push 的 di (恢复)
; 过滤长度=0 的记录
mov eax, [es:di+8]    ; Length 低 4 字节 (简化，不处理 >4G)
or  eax, eax
jz  e820_next
; 递增计数
mov ax, [mem_count]
inc ax
mov [mem_count], ax

e820_next:
add di, 24
cmp ebx, 0
jne e820_loop
jmp short e820_done

e820_done:
; mem_count = 有效记录数
; 后续可遍历筛选 Type=1 作为可用物理页框
```

降级策略:

1) E820 失败 -> 尝试 AX=E801h (返回 1MB 以上内存与 16MB 以上扩展)
2) 再失败 -> 使用 AX=8800h (只能获得简单扩展内存大小)
3) 若都失败，使用保守固定内存假设 (比如只用前 16MB)

开启 A20 (允许访问 1MB 以上):
优先:

- int 15h AX=2403h 检查 -> 未开启则 AX=2401h
若失败再:
- 键盘控制器方式 (写 0xD1 命令/0xDF 数据)
- Fast A20 (端口 0x92 设置 bit1)
验证:
- 比较 0x000000 与 0x100000 处读值 (修改/还原) 是否脱钩。

示例 (int 15h):

```asm
mov ax, 2403h
int 15h
jc  try_alt_a20
test ah, 1            ; AH bit0=1 表示已开启
jnz a20_ok
mov ax, 2401h
int 15h
jc  try_alt_a20
jmp short a20_ok

try_alt_a20:
; 这里可实现端口 0x92 快速 A20:
in  al, 0x92
or  al, 00000010b
out 0x92, al
; 或 fallback 到 KBC 方法 (略)

a20_ok:
; 继续：准备 GDT / 进入保护模式
```

进入保护模式前必须:

1) 获取/整理物理内存布局 (E820 优先)
2) 启用 A20
3) 准备 GDT / IDT / 分页（若使用）
4) 关闭中断，再设置 CR0.PE=1

总结:

- int 15h 提供标准内存探测与 A20 控制，是 16 位阶段到 32 位/64 位过渡关键一步
- 优先使用 E820，保存所有条目以便后续物理页分配器使用
- 始终验证 A20 已开启，避免地址回绕导致的数据破坏
