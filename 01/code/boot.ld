/*
 * boot.ld - 16 位实模式引导程序链接脚本 (使用 GNU ld)
 * 目的:
 *   把所有需要放进单个 512 字节启动扇区的代码/数据按 BIOS 预期地址 0x7C00 排布,
 *   并在偏移 0x1FE(=510) 放入签名 0x55AA, 生成后由 objcopy 转成裸二进制。
 * 关键点:
 *   1) 把链接地址(VMA/LMA) base 设为 0x7C00, 与 BIOS 加载位置一致。
 *   2) 控制节顺序: .text -> .data -> .rodata -> .bss -> 签名.
 *   3) 通过强制位置计数器 . = 0x7DFE 精确放置签名节 .bootsig。
 *   4) 末尾 ASSERT 确认总大小不超过 512 字节, 防止静默截断。
 * 使用流程:
 *   gcc -m16 ... -c boot.c -o boot.o
 *   ld -T boot.ld -nostdlib --nmagic -m elf_i386 boot.o -o boot.elf
 *   objcopy -O binary boot.elf boot.bin
 */

ENTRY(_start)              /* 指定 ELF 入口符号, 便于调试器和 objdump 知道起点 */

SECTIONS                  /* 区段布局定义开始 */
{
    . = 0x7C00;           /* 设置位置计数器 = 0x7C00; 后续 ALLOC 区段的 VMA/LMA 起点 */
    
    .text : {             /* 代码段: 聚合所有输入目标的 .text */
        *(.text)           /* 通配: 当前只有一个 boot.o */
    }                     /* 结束后 '.' 前移到 .text 末尾, 可能含对齐填充 */
    
    .data : {             /* 已初始化可写数据 (当前可能为空) */
        *(.data)
    }
    
    .rodata : {           /* 只读数据: 字符串常量等 (print 的字符串放这里) */
        *(.rodata)
    }

    /* 未初始化数据段: .bss 不占镜像实际存储, 运行时期望为 0 (objcopy 会把空洞填 0) */
    .bss : {
        *(.bss)
    }
    
    /* 强制将位置计数器跳到 0x7DFE (= 0x7C00 + 0x1FE), 即扇区最后两个字节的位置 */
    . = 0x7DFE;           /* 若前面总内容 > 510 字节, 这里会产生重叠/错误 (或 ASSERT 失败) */
    .bootsig : {          /* 启动签名节: 存放 0xAA55 (小端 -> 55 AA) */
        *(.bootsig)
    }

    __image_end = .;      /* 记录当前结束地址 (应为 0x7E00 若正好 512 字节) */
}

/* 容量保护: 结束地址 - 起始地址 <= 512, 否则报错阻止生成超大镜像 */
ASSERT(__image_end - 0x7C00 <= 512, "[linker] boot sector overflow (>512 bytes)");
