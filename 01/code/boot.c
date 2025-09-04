/*
 * 简易 16 位实模式引导程序 (GCC -m16 生成, 经自定义链接脚本定位到 0x7C00)
 * 功能: 进入 BIOS 图形模式 0x13 (320x200x256) 然后用 int 10h teletype 输出一行文字, 挂起。
 * 结构:
 *   _start -> 初始化段/栈 -> 调用 boot_main
 *   boot_main -> 设置视频模式 -> 打印字符串 -> hlt 循环
 * 注意: 这里所有函数均在 16 位模式下运行, 使用少量内联汇编调用 BIOS 中断。
 */

/* bios_set_video_mode
 * 入口: mode = 视频模式号 (例如 0x13)
 * 寄存器约定: int 10h, AH=0x00 设置模式, AL=模式号
 * 这里把 8 位 mode 放入 AX (高字节自动为 0), 然后触发 int 10h。
 */
static inline void bios_set_video_mode(unsigned char mode) {
    unsigned short ax = (unsigned short)mode; // AX = 00mm (mm 为模式号)
    __asm__ volatile ("int $0x10"       // BIOS 视频服务
                      :                 // 无输出
                      : "a"(ax)        // 约束: 把 ax 变量放入寄存器 AX
                      : "memory");     // 声明: 该中断可能影响内存, 禁止编译器乱重排
}

/* bios_teletype
 * 使用 BIOS int 10h AH=0x0E teletype 输出一个字符, 自动推进光标。
 * 输入:
 *   c = 要输出的字符
 *   color = 前景色 (图形模式下 BL 使用; BH=页号=0)
 * 构造: AX = 0x0Ecc (cc=字符), BX = 0x00color
 */
static inline void bios_teletype(char c, unsigned char color) {
    unsigned short ax = 0x0E00 | (unsigned char)c; // AH = 0x0E, AL = 字符
    unsigned short bx = color;                     // BH = 0, BL = 颜色索引
    __asm__ volatile ("int $0x10"
                      :
                      : "a"(ax), "b"(bx)
                      : "memory");
}

/* print
 * 逐字节读取以 '\0' 终止的字符串并调用 bios_teletype 输出。
 */
static void print(const char *s, unsigned char color) {
    while (*s) {               // 遇到 '\0' 结束
        bios_teletype(*s++, color);
    }
}

/* boot_main
 * 引导主逻辑: 设置模式 -> 输出文本 -> 无限休眠。
 * 使用 HLT 减少 CPU 空转 (在有中断的环境下会被唤醒; 这里单纯保持停机)。
 */
void boot_main(void) {
    bios_set_video_mode(0x13);                 // 进入 320x200 256 色图形模式
    static const char msg[] =                       // 常量字符串放入 .rodata
        "Ciallo!                         \r\n";     // 末尾带 CRLF 方便文本模式时换行
    print(msg, 0x0C);                      // 颜色 0x0C = 亮红 (高亮+红)
    for (;;) {                                      // 无限循环
        __asm__ volatile ("hlt");                   // HLT: 节能等待
    }
}

/* _start
 * 链接脚本指定的入口。声明 naked: 不生成函数序言/结语, 我们手工控制栈与寄存器。
 * 步骤:
 *   1. 关中断 (CLI) 防止在切换 SS:SP 时被打断。
 *   2. AX=0 清空; 设置 SS=0, SP=0x7C00 (简单把栈放在加载区域上方, 演示用途)。
 *   3. 统一把 DS/ES/FS/GS 清零, 符号引用将是物理地址低 16 位 (因为段基址=0）。
 *   4. 开中断 (STI) 恢复; CALL 进入 C 代码; 返回后自旋 (jmp .)。
 */
__attribute__((naked, used)) void _start(void) {
    __asm__ volatile (
        "cli\n"                /* 关中断 */
        "xor %%ax, %%ax\n"     /* AX = 0 */
        "mov %%ax, %%ss\n"     /* SS = 0 */
        "mov $0x7C00, %%sp\n"  /* SP = 0x7C00 (临时栈顶) */
        "mov %%ax, %%ds\n"     /* DS = 0  (数据段) */
        "mov %%ax, %%es\n"     /* ES = 0  */
        "mov %%ax, %%fs\n"     /* FS = 0  */
        "mov %%ax, %%gs\n"     /* GS = 0  */
        "sti\n"                /* 开中断 */
        "call boot_main\n"     /* 进入 C 主逻辑 */
        "jmp .\n"              /* 若返回, 自旋停留 */
        : : : "ax"
    );
}

/* 启动扇区签名 (.bootsig 节在链接脚本中被强制放到 0x7DFE)
 * 内容 0xAA55 (小端序写出 55 AA) 告诉 BIOS 该扇区是有效引导扇区。 */
__attribute__((section(".bootsig"), used))
const unsigned short boot_signature = 0xAA55;