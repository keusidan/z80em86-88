;*******************************************************************************
;*                                  z80em86                                    *
;*           A Z80 CPU emulator coded in Intel 86 assembly language            *
;*                                                                             *
;*                     PC-8801 style I/O ports (88 mode)                       *
;*                                                                             *
;*                    Copyright (C) 1992-2009 Stewart Kay                      *
;*******************************************************************************
;
;===============================================================================
; ChangeLog (most recent entries are at top)
;===============================================================================
; z80em86-88 - 5 October 2026
; - New file. 88 mode: a CP/M program turns it on with OUT (0E0h),A (an
;   emulator function). While it is on, IN/OUT run in the TPA (bank 1, PC
;   below the common memory) access PC-8801 style ports instead of the
;   emulator functions used by the BIOS. The warm boot turns it off.
;   Ports (behaviour taken from MAME pc8001.cpp / pc8801.cpp / i8214.cpp):
;     40h  W: bit 5 BEEP (2400 Hz), bit 7 SING (speaker line)
;          R: bit 5 VRTC (vertical blank)
;     E4h  W: interrupt level: bit 3 = 1 all levels, else levels < bit 0-2
;     E6h  W: interrupt mask: bit 0 CLOCK, bit 1 VRTC, bit 2 RXRDY (1 = on)
;     30h, 32h W: stored
;     31h  W: bit 3 GRPH (graphics on: EGA 640x200 mode), bit 4 color
;     52h  W: stored
;     53h  W: bits 1-3 hide the blue/red/green plane
;     54h-5Bh W: palette 0-7 (digital: bit 0 B, 1 R, 2 G; analog when port
;          32h bit 5: bit 6 = 0 -> B bits 0-2, R bits 3-5, bit 6 = 1 -> G)
;     5Ch-5Fh W: C000h-FFFFh = GVRAM blue/red/green plane or main RAM
;          (the 16K are swapped with a copy), 5Ch R: selected plane
;     00h-0Eh R: keyboard matrix (bit = 0 while the key is down), filled from
;          the PC keyboard by kbmat (called from the INT 09h handler)
;   The graphics screen is drawn at every VRTC (60 Hz) while bit 3 of 31h is
;   on. The PC-8801 text layer is not emulated (CP/M console output goes to
;   the PC text screen, which is not shown in graphics mode).
;     other ports: writes ignored, reads return 0FFh
;===============================================================================
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;===============================================================================

SEGMENT	Z80map	public align=16
Z80:

SEGMENT	.code	public align=16

GLOBAL  pc88, p88out, p88in, pc88on, p88wbt, pc88off
GLOBAL  lvlmsk, intdis, grmode, redraw, grdraw, gvaloc, kbmat

; declared in TIMER.ASM
EXTERN  irqpend, irqmask, tforce, tick10
; declared in HARDWARE.ASM
EXTERN  FlHard, Z80bk1

%include "macros.asm"

pc88    db      0                       ;88 mode on
lvlmsk  db      0ffh                    ;levels allowed by port E4h
intdis  db      0                       ;i8214: no interrupt until re-armed
port30  db      0
port31  db      0
port32  db      0
port40  db      0
port52  db      0
port53  db      0
grmode  db      0                       ;EGA graphics mode is on
redraw  db      0                       ;draw the graphics at the next opcode
gvseg   dw      0                       ;4 x 16K: blue, red, green, main RAM
gvsel   db      3                       ;at C000h: 0-2 plane, 3 main RAM
keymat  times 16 db 0ffh                ;PC-8801 keyboard matrix, 0 = down
kbe0    db      0                       ;last scan code was the E0h prefix

;===============================================================================
; Emulator functions (OUT (n),A from the BIOS or from a program not in 88 mode)
;   pc88on : function E0h, turn 88 mode on
;   p88wbt : function 86h, warm boot: turn 88 mode off, then flush the HDD
;===============================================================================
pc88on: push    ax
        call    pc88rst
        mov     BYTE [pc88],1
        pop     ax
        retn

p88wbt: call    pc88off
        jmp     FlHard

pc88off:
        push    ax
        mov     BYTE [pc88],0
        call    pc88rst
        pop     ax
        retn

; PC-8801 I/O state after power on (interrupts masked, beeper off)
pc88rst:
        push    bx
        call    pc88r
        pop     bx
        retn
pc88r:  cli
        xor     al,al
        mov     [irqmask],al
        mov     [irqpend],al
        mov     [intdis],al
        mov     BYTE [lvlmsk],0ffh
        sti
        mov     [port30],al
        mov     [port31],al
        mov     [port32],al
        mov     [port52],al
        mov     [port53],al
        call    beep                    ;AL = 0: speaker off
        mov     bx,15                   ;no key down
p88key: mov     BYTE [keymat+bx],0ffh
        dec     bx
        jns     p88key
        mov     al,3
        call    gvswap                  ;main RAM back at C000h
        call    grupd                   ;text mode (port 31h = 0)
        xor     bx,bx                   ;digital palette 0-7 = color 0-7
p88pal: mov     al,bl
        call    paldig
        inc     bl
        cmp     bl,8
        jb      p88pal
        retn

;===============================================================================
; p88out: write AL to port DI (0-255). All registers are kept.
;===============================================================================
p88out: push    cx
        push    bx
        push    ax
        mov     bx,di
        cmp     bl,40h
        jz      w40
        cmp     bl,0e4h
        jz      we4
        cmp     bl,0e6h
        jz      we6
        cmp     bl,30h
        jz      w30
        cmp     bl,31h
        jz      w31
        cmp     bl,32h
        jz      w32
        cmp     bl,52h
        jz      w52
        cmp     bl,53h
        jz      w53
        cmp     bl,54h
        jb      outret
        cmp     bl,5ch
        jb      wpal
        cmp     bl,60h
        jb      wgvs
outret: pop     ax
        pop     bx
        pop     cx
        retn

w30:    mov     [port30],al
        jmp     outret
w31:    mov     [port31],al
        call    grupd
        jmp     outret
w52:    mov     [port52],al
        jmp     outret
w53:    mov     [port53],al
        jmp     outret
wgvs:   mov     al,bl                   ;5Ch-5Fh: plane 0-3
        sub     al,5ch
        call    gvswap
        jmp     outret
wpal:   sub     bl,54h                  ;palette number
        test    BYTE [port32],00100000b
        jnz     wpalan
        call    paldig
        jmp     outret
wpalan: call    palana
        jmp     outret
w32:    mov     [port32],al
        jmp     outret

w40:    mov     [port40],al
        call    beep
        jmp     outret

; E4h: i8214 status (level) and re-arm
we4:    mov     ah,0ffh                 ;bit 3: all levels
        test    al,00001000b
        jnz     we4set
        mov     cl,al                   ;levels below AL & 7
        and     cl,00000111b
        mov     ah,1
        shl     ah,cl
        dec     ah
we4set: cli
        mov     [lvlmsk],ah
        mov     BYTE [intdis],0
        call    irqchk
        sti
        jmp     outret

; E6h: mask bits 0-2 = CLOCK, VRTC, RXRDY -> levels 2, 1, 0
we6:    xor     ah,ah
        test    al,00000001b
        jz      we6v
        or      ah,00000100b            ;level 2 CLOCK
we6v:   test    al,00000010b
        jz      we6r
        or      ah,00000010b            ;level 1 VRTC
we6r:   test    al,00000100b
        jz      we6set
        or      ah,00000001b            ;level 0 RXRDY
we6set: cli
        mov     [irqmask],ah
        call    irqchk
        sti
        jmp     outret

; a pending request that can be taken now: check it at the next opcode
; (interrupts off)
irqchk: mov     al,[irqpend]
        and     al,[irqmask]
        and     al,[lvlmsk]
        jz      irqcok
        cmp     BYTE [intdis],0
        jnz     irqcok
        call    tforce
irqcok: retn

;===============================================================================
; beep: speaker from port 40h value AL
;   bit 5 BEEP: 2400 Hz tone (PIT channel 2), bit 7 SING: speaker line
;===============================================================================
beep:   push    ax
        mov     ah,al
        in      al,61h
        and     al,11111100b            ;gate and data off
        test    ah,00100000b
        jz      beepsg
        push    ax
        mov     al,0b6h                 ;channel 2, lo/hi, mode 3
        out     43h,al
        mov     ax,1193182/2400
        out     42h,al
        mov     al,ah
        out     42h,al
        pop     ax
        or      al,00000011b            ;gate on, data on
        jmp     beepst
beepsg: test    ah,10000000b
        jz      beepst
        or      al,00000010b            ;speaker line high
beepst: out     61h,al
        pop     ax
        retn

;===============================================================================
; p88in: read port DI (0-255) into AL. All other registers are kept.
;===============================================================================
p88in:  push    cx
        push    bx
        mov     bx,di
        cmp     bl,10h
        jb      ikey
        cmp     bl,40h
        jz      i40
        cmp     bl,5ch
        jz      i5c
        mov     al,0ffh                 ;nothing there
inret:  pop     bx
        pop     cx
        retn

; 40h: bit 5 = VRTC, 1 for 2 of the 10 ticks of each 60 Hz frame (about
; the blanking time of a 200 line screen)
i40:    xor     al,al
        cmp     BYTE [tick10],2
        jae     inret
        or      al,00100000b
        jmp     inret

; 5Ch: 0F8h + bit of the selected plane (0 for main RAM)
i5c:    mov     al,0f8h
        mov     bl,[gvsel]
        cmp     bl,3
        jz      inret
        mov     cl,bl
        mov     bh,1
        shl     bh,cl
        or      al,bh
        jmp     inret

;===============================================================================
; Palette. Kept as 3 bit levels (0-7) of B R G per color and written to the
; VGA DAC (6 bit, level * 9). EGA palette registers can not show pure 88
; colors in the 200 line mode 0Eh (CGA style RGB + intensity), the DAC can.
; Attribute palette register i is set to i, so DAC entry i = 88 color i.
;   paldig: BL = number, AL = digital value (bit 0 B, 1 R, 2 G)
;   palana: BL = number, AL = analog value (port 32h bit 5 = 1)
;===============================================================================
palb    times 8 db 0
palr    times 8 db 0
palg    times 8 db 0

paldig: push    ax
        push    bx
        xor     bh,bh
        mov     ah,al
        xor     al,al
        test    ah,00000001b
        jz      pdb
        mov     al,7
pdb:    mov     [palb+bx],al
        xor     al,al
        test    ah,00000010b
        jz      pdr
        mov     al,7
pdr:    mov     [palr+bx],al
        xor     al,al
        test    ah,00000100b
        jz      pdg
        mov     al,7
pdg:    mov     [palg+bx],al
        call    palset
        pop     bx
        pop     ax
        retn

palana: push    ax
        push    bx
        xor     bh,bh
        test    al,01000000b
        jnz     pagrn
        mov     ah,al
        and     ah,00000111b
        mov     [palb+bx],ah
        shr     al,1
        shr     al,1
        shr     al,1
        and     al,00000111b
        mov     [palr+bx],al
        jmp     paset
pagrn:  and     al,00000111b
        mov     [palg+bx],al
paset:  call    palset
        pop     bx
        pop     ax
        retn

; write DAC entry BL from the levels (only when in graphics mode)
palset: cmp     BYTE [grmode],0
        jz      palsno
        push    ax
        push    bx
        push    cx
        push    dx
        xor     bh,bh
        mov     al,[palr+bx]
        mov     ah,9
        mul     ah
        mov     dh,al                   ;red 0-63
        mov     al,[palg+bx]
        mov     ah,9
        mul     ah
        mov     ch,al                   ;green
        mov     al,[palb+bx]
        mov     ah,9
        mul     ah
        mov     cl,al                   ;blue
        mov     ax,1010h                ;set one DAC register (BX)
        int     10h
        pop     dx
        pop     cx
        pop     bx
        pop     ax
palsno: retn

;===============================================================================
; grupd: graphics mode on/off from port 31h bit 3 (GRPH)
;===============================================================================
grupd:  push    ax
        push    bx
        mov     al,[port31]
        and     al,00001000b
        jz      grtext
        cmp     BYTE [grmode],0
        jnz     grret
        push    cx
        push    dx
        push    si
        push    di
        push    bp
        push    es
        mov     ax,000eh                ;EGA 640 x 200, 16 colors
        int     10h
        mov     BYTE [grmode],1
        xor     bx,bx
grpal:  mov     bh,bl                   ;attribute palette i = DAC i
        mov     ax,1000h
        int     10h
        xor     bh,bh
        call    palset                  ;DAC i = 88 color i
        inc     bl
        cmp     bl,8
        jb      grpal
        mov     BYTE [redraw],1
        pop     es
        pop     bp
        pop     di
        pop     si
        pop     dx
        pop     cx
        jmp     grret
grtext: cmp     BYTE [grmode],0
        jz      grret
        mov     BYTE [grmode],0
        push    cx
        push    dx
        push    si
        push    di
        push    bp
        push    es
        mov     ax,0003h                ;back to 80 x 25 text
        int     10h
        pop     es
        pop     bp
        pop     di
        pop     si
        pop     dx
        pop     cx
grret:  pop     bx
        pop     ax
        retn

;===============================================================================
; gvswap: put plane AL (0-2, 3 = main RAM) at C000h-FFFFh of bank #1
;   The 16K now there is copied to its own store first. Keeps all registers.
;===============================================================================
gvswap: cmp     al,[gvsel]
        jz      gvsret
        cmp     WORD [gvseg],0          ;store allocated ?
        jnz     gvsok
        call    gvaloc
        jc      gvsret                  ;no memory: GVRAM is not available
gvsok:  push    ax
        push    cx
        push    si
        push    di
        push    ds
        push    es
        mov     ah,[gvsel]
        mov     [gvsel],al
        mov     cl,al                   ;new
        cld
        mov     al,ah                   ;store the old 16K
        call    gvstore                 ;ES = store segment of AL
        mov     ds,[Z80bk1]
        mov     si,0c000h
        xor     di,di
        mov     cx,2000h
        rep     movsw
        pop     es                      ;(caller ES)
        push    es
        mov     ax,cs
        mov     ds,ax
        mov     al,[gvsel]              ;load the new 16K
        call    gvstore
        push    es
        pop     ds                      ;DS = store
        mov     es,[cs:Z80bk1]
        xor     si,si
        mov     di,0c000h
        mov     cx,2000h
        rep     movsw
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     cx
        pop     ax
gvsret: retn

; ES = store segment of plane AL (0-3)
gvstore:
        push    ax
        xor     ah,ah
        mov     cl,10
        shl     ax,cl                   ;* 400h paragraphs (16K)
        add     ax,[gvseg]
        mov     es,ax
        pop     ax
        retn

; allocate the 64K store and clear the planes. Carry set when no memory.
; Called at start (MAIN.ASM) before the RAM disk takes the free memory.
gvaloc: push    ax
        push    bx
        push    cx
        push    di
        push    es
        mov     ah,48h
        mov     bx,1000h                ;64K
        int     21h
        jc      gvafail
        mov     [gvseg],ax
        mov     es,ax
        xor     di,di
        xor     ax,ax
        mov     cx,6000h                ;3 planes x 16K
        cld
        rep     stosw
        clc
gvafail:
        pop     es
        pop     di
        pop     cx
        pop     bx
        pop     ax
        retn

;===============================================================================
; grdraw: copy the 3 planes to the EGA screen (called from Tslow when redraw
; is set, at the opcode after a VRTC). Keeps all registers.
;===============================================================================
grdraw: mov     BYTE [redraw],0
        cmp     BYTE [grmode],0
        jz      grdno
        cmp     WORD [gvseg],0
        jz      grdno
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    ds
        push    es
        cld
        xor     bl,bl                   ;plane 0-2
grdpl:  mov     dx,3c4h                 ;sequencer map mask = this plane
        mov     al,2
        out     dx,al
        inc     dx
        mov     cl,bl
        mov     al,1
        shl     al,cl
        out     dx,al
        shl     al,1                    ;hidden by port 53h (bits 1-3) ?
        test    [cs:port53],al
        jnz     grdclr
        cmp     bl,[cs:gvsel]
        jnz     grdsto
        mov     ds,[cs:Z80bk1]          ;this plane is at C000h now
        mov     si,0c000h
        jmp     grdcpy
grdsto: mov     al,bl
        call    gvstore                 ;ES = store (changes CL)
        mov     ax,es
        mov     ds,ax
        xor     si,si
grdcpy: mov     ax,0a000h
        mov     es,ax
        xor     di,di
        mov     cx,8000                 ;16000 bytes = 640 x 200 / 8
        rep     movsw
        jmp     grdnxt
grdclr: mov     ax,0a000h
        mov     es,ax
        xor     di,di
        mov     cx,8000
        xor     ax,ax
        rep     stosw
grdnxt: mov     ax,cs
        mov     ds,ax
        inc     bl
        cmp     bl,3
        jb      grdpl
        mov     dx,3c4h                 ;all planes again
        mov     al,2
        out     dx,al
        inc     dx
        mov     al,0fh
        out     dx,al
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
grdno:  retn

; 00h-0Fh: keyboard matrix
ikey:   xor     bh,bh
        mov     al,[keymat+bx]
        jmp     inret

;===============================================================================
; kbmat: PC scan code AL (set 1, from port 60h) -> PC-8801 keyboard matrix.
;   Called from the INT 09h handler (HARDWARE.ASM) with DS = CS. Keeps all
;   registers. The PC keys go to the BIOS as before, too.
;   Table byte = port * 8 + bit, 0FFh = no 88 key. Key choices: f1-f5 = F1-F5,
;   STOP = F9, COPY = F10, HELP = End, ROLL UP/DOWN = PgUp/PgDn, GRPH = left
;   Alt, KANA = right Alt, DEL/INS = BS/Ins/Del, CLR/HOME = Home
;   (F11/F12 are used by DOSBox-X). Matrix from MAME pc88_kbd.cpp.
;===============================================================================
kbmat:  push    ax
        push    bx
        push    cx
        cmp     al,0e0h
        jnz     kbcode
        mov     BYTE [kbe0],1
        jmp     kbret
kbcode: mov     ah,al                   ;bit 7 = key up
        and     al,01111111b
        mov     bx,kbbase
        cmp     BYTE [kbe0],0
        jz      kbtab
        mov     bx,kbext
kbtab:  mov     BYTE [kbe0],0
        xlatb                           ;AL = [BX + AL]
        cmp     al,0ffh
        jz      kbret
        mov     cl,al
        and     cl,00000111b
        mov     ch,1
        shl     ch,cl                   ;bit mask
        mov     cl,3
        shr     al,cl
        xor     bh,bh
        mov     bl,al                   ;port
        test    ah,10000000b
        jnz     kbup
        not     ch
        and     [keymat+bx],ch          ;down: bit = 0
        jmp     kbret
kbup:   or      [keymat+bx],ch          ;up: bit = 1
kbret:  pop     cx
        pop     bx
        pop     ax
        retn

kbbase:
        db      0ffh,04fh,031h,032h,033h,034h,035h,036h,037h,038h,039h,030h,02fh,02eh,043h,050h
        db      021h,027h,015h,022h,024h,029h,025h,019h,01fh,020h,010h,02bh,00fh,047h,011h,023h
        db      014h,016h,017h,018h,01ah,01bh,01ch,03bh,03ah,03fh,046h,02dh,02ah,028h,013h,026h
        db      012h,01eh,01dh,03ch,03dh,03eh,046h,00ah,044h,04eh,057h,049h,04ah,04bh,04ch,04dh
        db      0ffh,0ffh,0ffh,048h,054h,0ffh,0ffh,007h,008h,009h,055h,004h,005h,006h,00bh,001h
        db      002h,003h,000h,00eh,0ffh,0ffh,02ch,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        db      0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        db      0ffh,0ffh,0ffh,03fh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,02ch,0ffh,0ffh
kbext:
        db      0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        db      0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,00fh,047h,0ffh,0ffh
        db      0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        db      0ffh,0ffh,0ffh,0ffh,0ffh,056h,0ffh,0ffh,045h,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        db      0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,040h,041h,058h,0ffh,052h,0ffh,042h,0ffh,053h
        db      051h,059h,043h,043h,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        db      0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
        db      0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh
