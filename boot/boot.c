// nostd C bootloader
// 对应原汇编代码的C版本

#define BOOTSEG 0x7c0

// 禁用标准库
#pragma GCC optimize ("Os")
#pragma GCC diagnostic ignored "-Wunused-parameter"

// 使用更直接的汇编代码
void _start(void) {
    __asm__ volatile (
        // 设置段寄存器
        "movw $0x7c0, %%ax\n"
        "movw %%ax, %%ds\n"
        "movw %%ax, %%es\n"
        "movw %%ax, %%fs\n"
        "movw %%ax, %%gs\n"
        
        // 显示字符串 - 使用原汇编的方法
        "movw $msg, %%ax\n"
        "movw %%ax, %%bp\n"
        "movw $0x1301, %%ax\n"
        "movw $0x0c, %%bx\n"
        "movw $12, %%cx\n"
        "movb $0, %%dl\n"
        "int $0x10\n"
        
        // 无限循环
        "loop:\n"
        "jmp loop\n"
        
        // 字符串数据
        "msg:\n"
        ".ascii \"Hello World!\"\n"
        
        :
        :
        : "ax", "bx", "cx", "dx", "memory"
    );
}

// 启动扇区签名，必须位于第510-511字节
__attribute__((section(".bootsig")))
__attribute__((used))
const unsigned short boot_signature = 0xAA55;