[BITS 64]

; tinytcp64.asm - 64-bit Linux TCP server
; Copyright (C) 2014-2021 Lloyd Dilley
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
; Ported to FreeBSD on 12/28/2021

%include "config.inc"
%ifdef LINUX
%define SOCKET_CALL 41
%define BIND_CALL 49
%define LISTEN_CALL 50
%define ACCEPT_CALL 43
%define CLOSE_CALL 3
%define WRITE_CALL 1
%define EXIT_CALL 60
%else
%define SOCKET_CALL 97
%define BIND_CALL 104
%define LISTEN_CALL 106
%define ACCEPT_CALL 30
%define CLOSE_CALL 6
%define WRITE_CALL 4
%define EXIT_CALL 1
%endif

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
      ;at sockaddr_in.sin_address, dd 0x0100007F
      at sockaddr_in.sin_address, dd 0x00000000  ; all interfaces
      at sockaddr_in.sin_zero, dq 0
    iend

section .text
global _start
_start:
  ; Get a file descriptor for binding
  mov rax, SOCKET_CALL
  mov rdi, 2            ; AF_INET/PF_INET (AF = Address Family/PF = Protocol Family)
  mov rsi, 1            ; SOCK_STREAM
  mov rdx, 0            ; protocol
  syscall
  mov r13, rax
  push rax              ; store return value (fd)
  test rax, rax         ; check if -1 was returned
  js exit_error

  ; Bind to a socket
  mov rax, BIND_CALL
  pop rdi               ; file descriptor from SOCKET_CALL
  mov rbx, rdi          ; preserve server fd (rbx is saved across calls)
  mov rsi, sockaddr
  mov rdx, 16           ; size of sin_address is 16 bytes (64-bit address)
  syscall
  push rax
  test rax, rax
  js exit_error

  ; Listen for connections
  mov rax, LISTEN_CALL
  mov rdi, rbx          ; fd
  mov rsi, 10           ; backlog
  syscall
  push rax
  test rax, rax
  js exit_error
  ; Notify user that we're ready to listen for incoming connections
  mov rax, WRITE_CALL
  mov rdi, 1            ; file descriptor (1 is stdout)
  mov rsi, waiting
  mov rdx, waiting_len
  syscall
  call accept

accept:
  ; Accept connections
  mov rax, ACCEPT_CALL
  mov rdi, rbx          ; fd
  mov rsi, peeraddr
  lea rdx, [addr_len]
  syscall
  push rax
  test rax, rax
  js exit_error

  ; Send data
  mov rax, WRITE_CALL
  pop rdi               ; peer fd
  mov r15, rdi          ; preserve peer fd (r15 is saved across calls)
  mov rsi, greeting
  mov rdx, greeting_len
  syscall
  push rax
  test rax, rax
  js exit_error

  ; Close peer socket
  mov rax, CLOSE_CALL
  mov rdi, r15          ; fd
  syscall
  push rax
  test rax, rax
  js exit_error
  ;jz shutdown
  call accept           ; loop forever if preceding line is commented out

shutdown:
  ; Close server socket
  mov rax, CLOSE_CALL
  mov rdi, rbx
  syscall
  push rax
  test rax, rax
  js exit_error

  ; Exit normally
  mov rax, EXIT_CALL
  xor rdi, rdi          ; return code 0
  syscall

exit_error:
  mov rax, WRITE_CALL
  mov rdi, 1
  mov rsi, error
  mov rdx, error_len
  syscall

  mov rax, EXIT_CALL
  pop rdi               ; stored error code
  syscall
