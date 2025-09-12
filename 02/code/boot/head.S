.code32
.text
.globl startup_32
startup_32:
    movl $0x18, %eax
    movw %ax, %gs
    movl $0x0, %edi
    movb $0xf, %ah
    movb $0x42, %al
    movw %ax, %gs:(%edi)

    movl $0x10, %eax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
loop:
    jmp loop
