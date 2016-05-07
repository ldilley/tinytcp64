#!/bin/sh
nasm -f elf64 -o tinytcp64.o tinytcp64.asm
ld -o tinytcp64 tinytcp64.o
strip -s tinytcp64
