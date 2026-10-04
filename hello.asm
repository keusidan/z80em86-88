; hello.asm - print a string and exit (DOS .COM)
;   build: nasm -f bin -o hello.com hello.asm   (host / DOS)
; keep this file ASCII only: DOS EDIT cannot show UTF-8

        bits 16
        org 0x100               ; .COM is loaded right after the PSP (CS:0100h)

start:
        mov dx, msg             ; DS:DX -> '$'-terminated string
        mov ah, 0x09            ; INT 21h AH=09h: print string
        int 0x21

        mov ax, 0x4C00          ; INT 21h AH=4Ch: exit, AL = return code 0
        int 0x21

msg:    db "Hello, slow world!", 13, 10, "$"
