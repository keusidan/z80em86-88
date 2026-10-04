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
;     30h-32h W: stored (display control)
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
GLOBAL  lvlmsk, intdis

; declared in TIMER.ASM
EXTERN  irqpend, irqmask, tforce, tick10
; declared in HARDWARE.ASM
EXTERN  FlHard

%include "macros.asm"

pc88    db      0                       ;88 mode on
lvlmsk  db      0ffh                    ;levels allowed by port E4h
intdis  db      0                       ;i8214: no interrupt until re-armed
port30  db      0
port31  db      0
port32  db      0
port40  db      0

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
        cli
        xor     al,al
        mov     [irqmask],al
        mov     [irqpend],al
        mov     [intdis],al
        mov     BYTE [lvlmsk],0ffh
        sti
        mov     [port30],al
        mov     [port31],al
        mov     [port32],al
        call    beep                    ;AL = 0: speaker off
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
outret: pop     ax
        pop     bx
        pop     cx
        retn

w30:    mov     [port30],al
        jmp     outret
w31:    mov     [port31],al
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
p88in:  push    bx
        mov     bx,di
        cmp     bl,40h
        jz      i40
        mov     al,0ffh                 ;nothing there
inret:  pop     bx
        retn

; 40h: bit 5 = VRTC, 1 for 2 of the 10 ticks of each 60 Hz frame (about
; the blanking time of a 200 line screen)
i40:    xor     al,al
        cmp     BYTE [tick10],2
        jae     inret
        or      al,00100000b
        jmp     inret
