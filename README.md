# tinytcp64

x86-64 Linux TCP server in assembly

To build:

1.) nasm -f elf64 -o tinytcp64.o tinytcp64.asm

2.) ld -o tinytcp64 tinytcp64.o

Optionally shave off symbols for increased leanness:

3.) strip -s tinytcp64

Feel free to expand on functionality (create a telnet or web server for example.)
