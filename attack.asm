global _start

SYS_EXIT equ 60
;file operations
SYS_READ equ 0
SYS_OPEN equ 2

SECRET equ 68020

section .rodata

    bufsize dw 1024
    sequence dw 6
    sequence1 dw 8
    sequence2 dw 0
    sequence3 dw 2
    sequence4 dw 0


section .bss

    buf resb 1024

section .data


    consecutive_found db 0
    sequence_found db 0
    bounded_found db 0
    sum dd 0

section .text

exit_error:
    mov rax, SYS_EXIT
    mov rdi, 1
    syscall

exit_ok:
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall

_start:
    cmp qword [rsp], 2
    jne exit_error
    mov rdi, [rsp + 16]
    call open_file
    mov r12, rax                            ;store file descriptor in r12

    call parse_file                         ;call parsing file procedure
    cmp dword [sum], SECRET                 ;check if final sum is valid
    jne exit_error                          ;exit(1) in case of invalid sum
    mov r12b, byte [sequence_found]         ;check whether there exist consecutive numbers [6, 8, 0, 2, 0]
    mov r13b, byte [bounded_found]          ;and properly bounded number
    and r12b, r13b                          ;in given file or not
    jz exit_error
    jmp exit_ok                             ;exit(0) program

open_file:
    mov rax, SYS_OPEN
    xor rsi, rsi
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl exit_error
    ret

read_file:
    mov rax, SYS_READ
    mov rdi, r12
    mov rsi, buf
    movzx rdx, word [bufsize]
    syscall
    cmp rax, 0
    jl exit_error
    ret

parse_file:                                 ;procedure parsing input file
    call read_file
    cmp rax, 0                              ;stop parsing if we've read all the file
    je stop_parsing
    mov r13, 0b11                           ;check if quantity of bytes read from the file
    and r13, rax                            ;is divisible by 4 to settle
    jnz exit_error                          ;invalid input file problem
    xor r13, r13
    call decode_message                     ;decode encrypted message in read buffer of data
    cmp rax, 0
    jne parse_file                          ;read file part by part to 1024-bytes buffer using loop
    ret

decode_message:
    mov r14d, [buf + r13d]                  ;take 32-bit number from buffer
    add r13d, 4                             ;move buffer-read offset by 32 bits
    bswap r14d                              ;make read number to be interpreted properly (Little endian)
    add dword [sum], r14d                   ;update sum of all numbers read
    cmp r14d, SECRET                        ;check whether read number is special (68020)
    je exit_error
    call consecutive                        ;check whether read number is proper part of wanted sequence
    call compare                            ;check whether read number fits given boundaries
    cmp r13, rax                            ;loop iterator
    jl decode_message
    ret

consecutive_reset:
    mov byte [consecutive_found], 0         ;sequence has been broken so the counter becomes 0...
    cmp r14d, 6                             ;... unless number that has been already read was equal to 6
    je new_seq_possibility
    ret

new_seq_possibility:
    mov byte [consecutive_found], 1         ;number 6 broke sequence and becomes
    ret                                     ;beginning of new possibility

got_sequence:
    mov byte [sequence_found], 1            ;wanted sequence has been found so
    ret                                     ;update flag responsible for storing this information

consecutive:
    cmp byte [consecutive_found], 5         ;there is no need to look for wanted
    je got_sequence                         ;sequence if it's been already found
    movzx ebx, byte [consecutive_found]
    movzx r15d, word [sequence + ebx * 2]   ;check what number for sequence we need
    cmp r15d, r14d                          ;compare wanted number with read number
    jne consecutive_reset
    inc byte [consecutive_found]            ;increment sequence counter
    cmp byte [consecutive_found], 5         ;if counter is equal to 5 now
    je got_sequence                         ;set proper flag on true
    ret

not_in_bounds:
    ret

got_bounded:
    ret

compare:
    cmp byte [bounded_found], 1             ;do not look for bounded number
    je got_bounded                          ;if we've already found one
    cmp r14d, SECRET
    jng not_in_bounds                       ;read number does not fit lower bound, leave here
    cmp r14d, 0x80000000
    jnb not_in_bounds                       ;read number does not fit upper bound, leave here
    mov byte [bounded_found], 1             ;number meets all 2 requirements to fit boundaries
    ret                                     ;so we've just found proper one

stop_parsing:
    ret
