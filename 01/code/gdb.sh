#!/bin/sh

pwndbg -q \
    -ex "file boot.elf" \
    -ex "set architecture i8086" \
    -ex "target remote :1234" \
    -ex "b *0x7C00" \
    -ex "c"