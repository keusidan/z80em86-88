; jpkey.asm - JP106 keyboard layout for MS-DOS (TSR, .COM)
;   MS-DOS 4.00 KEYB/KEYBOARD.SYS has no Japanese layout, so this replaces it.
;   build: nasm -f bin -o jpkey.com jpkey.asm
;   Hooks INT 09h. For the keys whose symbols differ between US and JP106, it puts
;   the JP character into the BIOS keyboard buffer itself; all other keys (and any
;   key with Ctrl or Alt held) go to the BIOS as usual.
; keep this file ASCII only: DOS EDIT cannot show UTF-8

        bits 16
        org 0x100

start:  jmp install

sig:    db "JPKEY1"             ; to detect a second install
old09:  dd 0

; scancode (set 1), char without Shift, char with Shift (0 = no character)
keys:   db 0x03, '2', '"'
        db 0x07, '6', '&'
        db 0x08, '7', "'"
        db 0x09, '8', '('
        db 0x0A, '9', ')'
        db 0x0B, '0', 0
        db 0x0C, '-', '='
        db 0x0D, '^', '~'
        db 0x1A, '@', '`'
        db 0x1B, '[', '{'
        db 0x27, ';', '+'
        db 0x28, ':', '*'
        db 0x2B, ']', '}'
        db 0x73, '\', '_'       ; ro key (left of right Shift)
        db 0x7D, '\', '|'       ; yen key (shown as \ in code page 437)
nkeys   equ ($ - keys) / 3

; BIOS data area (segment 0040h)
KBFLAG  equ 0x17                ; bit0/1 Shift, bit2 Ctrl, bit3 Alt
KBHEAD  equ 0x1A
KBTAIL  equ 0x1C
KBSTART equ 0x80
KBEND   equ 0x82
KBFLAG3 equ 0x96                ; bit1: the previous byte was the E0 prefix

int09:
        push ax
        push bx
        push si
        push ds
        in al, 0x60             ; scancode; reading it again in the BIOS is fine
        mov bx, 0x40
        mov ds, bx
        test byte [KBFLAG], 0x0C
        jnz .bios
        test byte [KBFLAG3], 0x02
        jnz .bios
        mov si, keys
        mov ah, nkeys
.find:  cmp al, [cs:si]
        je .hit
        add si, 3
        dec ah
        jnz .find
.bios:  pop ds
        pop si
        pop bx
        pop ax
        jmp far [cs:old09]

.hit:   mov ah, al              ; AH = scancode, AL = character
        mov al, [cs:si+1]
        test byte [KBFLAG], 0x03
        jz .put
        mov al, [cs:si+2]
.put:   or al, al
        jz .done
        mov si, [KBTAIL]        ; append AX to the ring buffer
        mov bx, si
        add bx, 2
        cmp bx, [KBEND]
        jne .room
        mov bx, [KBSTART]
.room:  cmp bx, [KBHEAD]
        je .done                ; buffer full: drop the key
        mov [si], ax
        mov [KBTAIL], bx
.done:  mov al, 0x20            ; end of interrupt to the PIC
        out 0x20, al
        pop ds
        pop si
        pop bx
        pop ax
        iret

; ---- everything below is freed after install ----

install:
        cld
        mov ax, 0x3509          ; ES:BX = current INT 09h
        int 0x21
        mov di, bx
        sub di, int09 - sig
        mov si, sig
        mov cx, 6
        repe cmpsb
        je .already
        mov [old09], bx
        mov [old09+2], es
        mov dx, int09
        mov ax, 0x2509
        int 0x21
        mov es, [0x2C]          ; free the environment block
        mov ah, 0x49
        int 0x21
        mov dx, msg_ok
        mov ah, 0x09
        int 0x21
        mov dx, (install - $$ + 0x100 + 15) / 16   ; keep PSP + resident part
        mov ax, 0x3100
        int 0x21

.already:
        mov dx, msg_again
        mov ah, 0x09
        int 0x21
        mov ax, 0x4C01
        int 0x21

msg_ok:    db "JPKEY: JP106 keyboard layout installed", 13, 10, "$"
msg_again: db "JPKEY: already installed", 13, 10, "$"
