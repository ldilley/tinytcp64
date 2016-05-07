[BITS 64]

; tinytcp64.asm - 64-bit Linux TCP server
; Copyright (C) 2014, 2016 Lloyd Dilley
; http://www.dilley.me/
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License along
; with this program; if not, write to the Free Software Foundation, Inc.,
; 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

; Creation date: 04/02/2014

struc sockaddr_in
  .sin_family resw 1
  .sin_port resw 1
  .sin_address resd 1
  .sin_zero resq 1
endstruc

section .bss
  peeraddr:
    istruc sockaddr_in
      at sockaddr_in.sin_family, resw 1
      at sockaddr_in.sin_port, resw 1
      at sockaddr_in.sin_address, resd 1
      at sockaddr_in.sin_zero, resq 1
    iend

section .data
  waiting:      db 'Waiting for connections...',0x0A
  waiting_len:  equ $-waiting
  greeting:     db 'Greetings!',0x0A
  greeting_len: equ $-greeting
  error:        db 'An error was encountered!',0x0A
  error_len:    equ $-error
  addr_len:     dq 16
  sockaddr:
    istruc sockaddr_in
      ; AF_INET
      at sockaddr_in.sin_family, dw 2
      ; TCP port 9990 (network byte order)
      at sockaddr_in.sin_port, dw 0x0627
      ; 127.0.0.1 (network byte order)
      at sockaddr_in.sin_address, dd 0x0100007F
      at sockaddr_in.sin_zero, dq 0
    iend

section .text
global _start
_start:
  ; Get a file descriptor for sys_bind
  mov rax, 41           ; sys_socket
  mov rdi, 2            ; AF_INET
  mov rsi, 1            ; SOCK_STREAM
  mov rdx, 0            ; protocol
  syscall
  mov r13, rax
  push rax              ; store return value (fd)
  test rax, rax         ; check if -1 was returned
  js exit_error

  ; Bind to a socket
  mov rax, 49           ; sys_bind
  pop rdi               ; file descriptor from sys_socket
  mov rbx, rdi          ; preserve server fd (rbx is saved across calls)
  mov rsi, sockaddr
  mov rdx, 16           ; size of sin_address is 16 bytes (64-bit address)
  syscall
  push rax
  test rax, rax
  js exit_error

  ; Listen for connections
  mov rax, 50           ; sys_listen
  mov rdi, rbx          ; fd
  mov rsi, 10           ; backlog
  syscall
  push rax
  test rax, rax
  js exit_error
  ; Notify user that we're ready to listen for incoming connections
  mov rax, 1            ; sys_write
  mov rdi, 1            ; file descriptor (1 is stdout)
  mov rsi, waiting
  mov rdx, waiting_len
  syscall
  call accept

accept:
  ; Accept connections
  mov rax, 43           ; sys_accept
  mov rdi, rbx          ; fd
  mov rsi, peeraddr
  lea rdx, [addr_len]
  syscall
  push rax
  test rax, rax
  js exit_error

  ; Send data
  mov rax, 1
  pop rdi               ; peer fd
  mov r15, rdi          ; preserve peer fd (r15 is saved across calls)
  mov rsi, greeting
  mov rdx, greeting_len
  syscall
  push rax
  test rax, rax
  js exit_error

  ; Close peer socket
  mov rax, 3            ; sys_close
  mov rdi, r15          ; fd
  syscall
  push rax
  test rax, rax
  js exit_error
  ;jz shutdown
  call accept           ; loop forever if preceding line is commented out

shutdown:
  ; Close server socket
  mov rax, 3
  mov rdi, rbx
  syscall
  push rax
  test rax, rax
  js exit_error

  ; Exit normally
  mov rax, 60           ; sys_exit
  xor rdi, rdi          ; return code 0
  syscall

exit_error:
  mov rax, 1
  mov rdi, 1
  mov rsi, error
  mov rdx, error_len
  syscall

  mov rax, 60
  pop rdi               ; stored error code
  syscall
