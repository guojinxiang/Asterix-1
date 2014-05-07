	BITS 32

MBALIGN     equ  1<<0
MBMEMINFO     equ  1<<1
MBFLAGS       equ  MBALIGN | MBMEMINFO
MBMAGIC       equ  0x1BADB002
MBCHECKSUM    equ -(MBMAGIC + MBFLAGS)


section .multiboot
align 4
	dd MBMAGIC
	dd MBFLAGS
	dd MBCHECKSUM

section .data
	msg_notfound db ". Not found.", 0
	msg_found db ". Found!", 0
	msg_done db ". Done!", 0
	msg_failed db ". Failed.", 0
	welcomestr db "Welcome to the", 0
	project db "Asterix", 0
	kernelstr db "kernel", 0
	punct_space db " ", 0
	punct_dot   db ".", 0
	punct_ques  db "?", 0
	punct_comm  db ",", 0
	punct_excl  db "!", 0
	endl db 13, 10, 0
	padding db " ", 0
	cursor dw 0
	xpos db 0
	ypos db 0

section .text

global _start
global cpp_test
global get_cursor_pos_x
global get_cursor_pos_y

jmp _start
extern kernel_main

_start:
pusha
xor ax, ax
call kernel

setup:
	call load_cursor_pos
	mov word [cursor], 0x2607
	call set_cursor
	ret

kernel:
	call setup
	mov ah , 0x0F
	mov esi, welcomestr
	call puts
	mov esi, punct_space
	call puts
	mov ah, 0x01
	mov esi, project
	call puts
	mov ah, 0x0F
	mov esi, punct_space
	call puts
	mov esi, kernelstr
	call puts
	mov esi, punct_excl
	call puts
	mov esi, endl
	call puts
	mov esi, .msg_starting_setup
	call puts
	mov esi, endl
	call puts

	.start_cpuid:
		mov esi, .msg_cpuid_find
		call puts
		pusha
		call try_cpuid
		cmp eax, 1
		jne .cpuid_notfound
		popa
		mov esi, msg_found
		call puts
		jmp .end_cpuid
		.msg_cpuid_find db "Looking for CPUID..", 0

	.cpuid_notfound:
		popa
		mov esi, msg_notfound
		call puts
		call exit

	.end_cpuid:
		mov esi, endl
		call puts


	.start_long_mode:
		mov esi, .msg_long_mode_find
		call puts
		pusha
		call try_long_mode
		cmp eax, 1
		jne .long_mode_notfound
		popa
		mov esi, msg_found
		call puts
		mov esi, endl
		call puts
		mov esi, .msg_long_mode_enter
		call puts
		call enter_long_mode
		mov ah , 0x0F
		mov esi, msg_done
		call puts
		jmp .end_long_mode
		.msg_long_mode_find db "Looking for Long Mode..", 0
		.msg_long_mode_enter db "Entering Long Mode..", 0

	.long_mode_notfound:
		mov esi, msg_notfound
		call puts
		call exit

	.end_long_mode:
		mov esi, endl
		call puts


	.start_enable_paging:
		mov esi, .msg_enable_paging
		call puts
		pusha
		call enable_paging
		popa
		mov esi, msg_done
		call puts
		jmp .end_enable_paging
		.msg_enable_paging db "Enabling Paging..", 0

	.end_enable_paging:
		mov esi, endl
		call puts

	popa
	push ebx
	call kernel_main
	hlt
	mov ah, 0x0F

	mov esi, .msg_end
	call puts
	mov esi, endl
	call puts
	call exit

	jmp $
	.msg_starting_setup db "Starting setup phase..", 0
	.msg_end db "Nothing left to do.", 0


get_cursor_pos_x:
	mov al, byte [xpos]
	ret

get_cursor_pos_y:
	mov al, byte [ypos]
	ret

cpp_test:
	push ax
	mov ah, 0x0F
	mov esi, .msg_testing_cpp
	call puts
	mov esi, endl
	call puts
	pop ax
	ret
	.msg_testing_cpp db "Testing calls from C++..", 0


enable_paging:
	mov eax, cr0
	or eax, 1 << 32
	mov cr0, eax
	ret

enter_long_mode:
	pusha
	mov ecx, 0xC0000080
	rdmsr
	or eax, 1 << 8
	wrmsr
	popa
	ret

try_long_mode:
	pusha
	mov eax, 0x80000000
	cpuid
	cmp eax, 0x80000001
	jb .notavailable
	mov eax, 0x80000001
	cpuid
	test edx, 1 << 29
	jz .notavailable
	popa
	mov eax, 1
	ret
	.notavailable:
		popa
		mov eax, 1
		ret


try_cpuid:
	pusha
	pushfd
	pop eax
	mov ecx, eax
	xor eax, 1 << 21
	push eax
	popfd
	pushfd
	pop eax
	push ecx
	popfd
	xor eax, ecx
	jz .notfound
	popa
	mov eax, 1
	ret
	.notfound:
		popa
		mov eax, 0
		ret


dochar:
	call putc

puts:
	push ecx
	push eax
	lodsb
	cmp al, 0
	pop ecx
	mov ah, ch
	pop ecx
	jne dochar
	cmp word [cursor], 0x2607
	je .nocursor
	call update_cursor
	.nocursor:
	ret
 
putc:
	.test_cr:
		cmp al, 13
		jne .test_lf
		call cr
		ret

	.test_lf:
		cmp al, 10
		jne .normal_char
		call lf
		ret

	.normal_char:
		mov ecx, eax
		movzx eax, byte [ypos]
		mov edx, 160
		mul edx
		movzx ebx, byte [xpos]
		shl ebx, 1
	 
		mov edi, 0xb8000
		add edi, eax
		add edi, ebx
	 
		mov eax, ecx
		mov word [ds:edi], ax
		inc byte [xpos]
		ret
	ret

cr:
	mov byte [xpos], 0
	ret

lf:
	inc byte [ypos]
	ret

load_cursor_pos:
	mov byte [xpos], bl
	mov byte [ypos], cl
	ret

save_cursor_pos:
	mov bl, byte [xpos]
	mov cl, byte [ypos]
	ret

set_cursor:
	mov bx, word [cursor]
	pushad
	mov dx, 0x3D4
	mov al, 0x0A
	mov ah, bh
	out dx, ax
	inc ax
	mov ah, bl
	out dx, ax
	popad
	ret

update_cursor:
	pushad
	mov dl, byte [xpos]
	mov dh, byte [ypos]
	mov al, 80
	mul dh
	xor dh, dh
	add ax, dx
	mov cx, ax
	mov dx, 0x03d4
	mov al, 0x0e
	out dx, al
	inc dx
	mov al, ch
	out dx, al
	mov dx, 0x3d4
	mov al, 0x0f
	out dx, al
	inc dx
	mov al, cl
	popad
	ret

debug:
	mov esi, .msg_debug
	call puts
	ret
	.msg_debug db "debug"

exit:
	mov esi, .msg_exiting
	call puts
	mov esi, endl
	call puts
	jmp $
	ret
	.msg_exiting db "Exiting..", 0

section .bss
align 32
stack:
    resb 0x4000