#!/bin/sh
platform=`uname`
if [ "${platform}" = "Linux" ]; then
  echo "%define LINUX" >> config.inc
fi
nasm -f elf64 -o tinytcp64.o tinytcp64.asm -p config.inc
ld -o tinytcp64 tinytcp64.o
strip -s tinytcp64
