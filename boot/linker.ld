/* 链接脚本用于16位实模式bootloader */

ENTRY(_start)

SECTIONS
{
    . = 0x7C00;
    
    .text : {
        *(.text)
    }
    
    .data : {
        *(.data)
    }
    
    .rodata : {
        *(.rodata)
    }
    
    /* 确保启动签名位于正确位置 (0x7DFE) */
    . = 0x7DFE;
    .bootsig : {
        *(.bootsig)
    }
}
