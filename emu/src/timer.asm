;*******************************************************************************
;*                                  z80em86                                    *
;*           A Z80 CPU emulator coded in Intel 86 assembly language            *
;*                                                                             *
;*              Real time speed control and Z80 interrupts                     *
;*                                                                             *
;*                    Copyright (C) 1992-2009 Stewart Kay                      *
;*******************************************************************************
;
;===============================================================================
; ChangeLog (most recent entries are at top)
;===============================================================================
; z80em86-88 - 5 October 2026
; - New file.
;   * The PC timer (PIT channel 0) is set to 600 Hz. Each tick gives the Z80
;     TPT T-states (4 MHz / 600 = 6667). The dispatch macros subtract the
;     T-states of each opcode (tables in TIMING.ASM) from tleft and enter
;     Tslow when it goes negative, where the emulator waits for the next tick.
;   * DOS environment Z80SPEED=4 (default), 8 (8 MHz) or 0 (no limit).
;   * Z80 maskable interrupts (IM 0/1/2) are accepted in Tslow. Sources set
;     bits in irqpend (only when enabled in irqmask, set later by the I/O ports).
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
;
; T-state budget
;   The real budget is B = tleft - tdebt (tdebt is 32 bit).
;   - The dispatch macros only subtract from tleft (16 bit, fast path).
;   - Large costs (LDIR etc.) are added to tdebt by tblk.
;   - To make the next instruction boundary enter Tslow (interrupt request,
;     EI), tforce moves tleft into tdebt and sets tleft = -1; B is unchanged.
;   - Tslow folds tdebt back into tleft (tnorm).
;
; Interrupt request bits (irqpend / irqmask), PC-8801 levels:
;   bit 0 = level 0 (RXRDY), bit 1 = level 1 (VRTC 60 Hz), bit 2 = level 2
;   (CLOCK 600 Hz). The lowest bit has the highest priority, the IM 2 vector
;   offset is level * 2.

SEGMENT	Z80map	public align=16
Z80:

SEGMENT	.code	public align=16

%define TIMER
GLOBAL  tleft, Tslow, tmrini, tmrres, tblk, tblkn, tforce, tmrrst
GLOBAL  IFF1, eidly, halted, imode, irqpend, irqmask

; declared in INSTHAND.ASM
EXTERN  IFF, Z80I, Z80SP
; declared in TABLE.ASM
EXTERN  T0

%include "macros.asm"

PITHZ   equ     600                     ;timer ticks per second
PITDIV  equ     1989                    ;1193182 / 600
TPT4MHZ equ     6667                    ;4 MHz / 600

tleft   dw      0                       ;T-states left (fast counter)
tdebt   dw      0,0                     ;T-state debt (32 bit, lo/hi)
tforced db      0                       ;tleft was forced to -1
TPT     dw      TPT4MHZ                 ;T-states per timer tick
tfast   db      0                       ;Z80SPEED=0: no speed limit
envnam  db      'Z80SPEED='             ;DOS environment variable
ENVLEN  equ     $-envnam
tcap    dw      2*TPT4MHZ               ;largest budget kept (no bursts)
tcost   dw      0                       ;cost of the opcode fetched in Tslow
tblkn   dw      0                       ;BC at the start of a block op

IFF1    db      0                       ;Z80 IFF1 (IFF in INSTHAND is IFF2)
eidly   db      0                       ;EI: no interrupt before next opcode
halted  db      0                       ;HALT is waiting for an interrupt
imode   db      0                       ;interrupt mode 0, 1 or 2
irqpend db      0                       ;pending interrupt requests
irqmask db      0                       ;enabled interrupt sources
tick10  db      0                       ;600 Hz -> 60 Hz divider
pitacc  dw      0                       ;BIOS 18.2 Hz chain accumulator
oldi08  dw      0,0                     ;original INT 08h vector

;===============================================================================
; Install / remove the 600 Hz timer
;   tmrini is called with ES = PSP. The speed is taken from the DOS
;   environment: Z80SPEED=4 (default, 4 MHz), 8 (8 MHz), 0 (no limit).
;===============================================================================
tmrini: push    es
        mov     es,[es:2ch]             ;environment segment
        xor     di,di
        cld
envnxt: cmp     BYTE [es:di],0          ;end of the environment ?
        jz      envend
        mov     si,envnam
        mov     cx,ENVLEN
        repe    cmpsb
        jz      envfnd
        dec     di                      ;back to the char that did not match
envskp: cmp     BYTE [es:di],0          ;skip the rest of this string
        jz      envstr
        inc     di
        jmp     envskp
envstr: inc     di
        jmp     envnxt
envfnd: mov     al,[es:di]
        cmp     al,'0'
        jnz     env8
        mov     BYTE [tfast],1
        jmp     envend
env8:   cmp     al,'8'
        jnz     envend
        mov     WORD [TPT],2*TPT4MHZ
        mov     WORD [tcap],4*TPT4MHZ
envend: pop     es
        push    es
        xor     ax,ax
        mov     es,ax
        mov     ax,[es:08h*4+0]
        mov     [oldi08+0],ax
        mov     ax,[es:08h*4+2]
        mov     [oldi08+2],ax
        cli
        mov     WORD [es:08h*4+0],tmrint
        mov     [es:08h*4+2],cs
        mov     al,36h                  ;channel 0, lo/hi, mode 3
        out     43h,al
        mov     ax,PITDIV
        out     40h,al
        mov     al,ah
        out     40h,al
        sti
        pop     es
        retn

tmrres: push    es
        xor     ax,ax
        mov     es,ax
        cli
        mov     al,36h
        out     43h,al
        xor     al,al                   ;divisor 0 = 65536 (18.2 Hz)
        out     40h,al
        out     40h,al
        mov     ax,[oldi08+0]
        mov     [es:08h*4+0],ax
        mov     ax,[oldi08+2]
        mov     [es:08h*4+2],ax
        sti
        pop     es
        retn

; Reset the timing and interrupt state (Z80 reset)
tmrrst: xor     ax,ax
        cli
        mov     [tleft],ax
        mov     [tdebt+0],ax
        mov     [tdebt+2],ax
        mov     [tforced],al
        mov     [IFF1],al
        mov     [eidly],al
        mov     [halted],al
        mov     [imode],al
        mov     [irqpend],al
        mov     [irqmask],al
        sti
        retn

;===============================================================================
; INT 08h, 600 Hz
;===============================================================================
tmrint: push    ax
        push    ds
        mov     ax,cs
        mov     ds,ax
        cmp     BYTE [tforced],0
        jnz     tmrdbt
        mov     ax,[tleft]              ;give one tick of T-states
        add     ax,[TPT]
        cmp     ax,[tcap]
        jle     tmrset
        mov     ax,[tcap]
tmrset: mov     [tleft],ax
        jmp     tmrirq
tmrdbt: mov     ax,[TPT]                ;tleft is forced: pay into tdebt
        sub     [tdebt+0],ax
        sbb     WORD [tdebt+2],0
tmrirq: mov     al,00000100b            ;level 2: CLOCK 600 Hz
        inc     BYTE [tick10]
        cmp     BYTE [tick10],PITHZ/60
        jb      tmrreq
        mov     BYTE [tick10],0
        or      al,00000010b            ;level 1: VRTC 60 Hz
tmrreq: and     al,[irqmask]
        jz      tmrbio
        or      [irqpend],al
        call    tforce                  ;check it at the next opcode
tmrbio: add     WORD [pitacc],PITDIV    ;time for the BIOS 18.2 Hz tick ?
        jc      tmrold
        mov     al,20h                  ;end of interrupt
        out     20h,al
        pop     ds
        pop     ax
        iret
tmrold: pop     ds
        pop     ax
        jmp     far [cs:oldi08]         ;BIOS tick, it sends the EOI

;===============================================================================
; tforce: make the next opcode fetch enter Tslow (call with interrupts off)
;   tdebt -= tleft + 1, tleft = -1 : the budget B is unchanged
;===============================================================================
tforce: cmp     BYTE [tforced],0
        jnz     tfrcok
        push    ax
        push    dx
        mov     ax,[tleft]
        inc     ax
        cwd
        sub     [tdebt+0],ax
        sbb     [tdebt+2],dx
        mov     WORD [tleft],-1
        mov     BYTE [tforced],1
        pop     dx
        pop     ax
tfrcok: retn

;===============================================================================
; tnorm: fold tdebt into tleft (call with interrupts off)
;   B = tleft - tdebt. Fits in 16 bit: tleft = min(B, tcap), tdebt = 0.
;   Else tleft = -32768 and tdebt keeps the rest.
;   Return: tleft >= 0 when the budget is not exhausted.
;===============================================================================
tnorm:  push    ax
        push    dx
        mov     ax,[tleft]
        cwd
        sub     ax,[tdebt+0]
        sbb     dx,[tdebt+2]            ;DX:AX = B
        mov     BYTE [tforced],0
        or      dx,dx
        js      tnneg
        jnz     tncap                   ;B >= 65536
        cmp     ax,[tcap]
        jbe     tnfit
tncap:  mov     ax,[tcap]
tnfit:  mov     [tleft],ax
        xor     ax,ax
        mov     [tdebt+0],ax
        mov     [tdebt+2],ax
        jmp     tnret
tnneg:  cmp     dx,-1
        jnz     tnbig
        or      ax,ax                   ;B >= -32768 ?
        js      tnfit
tnbig:  mov     WORD [tleft],-32768     ;tdebt = -32768 - B
        neg     dx
        neg     ax
        sbb     dx,0                    ;DX:AX = -B
        sub     ax,32768
        sbb     dx,0
        mov     [tdebt+0],ax
        mov     [tdebt+2],dx
tnret:  pop     dx
        pop     ax
        retn

;===============================================================================
; tblk: T-states of the repeated part of LDIR/LDDR/CPIR/CPDR
;   [tblkn] = BC at the start, CX = BC at the end.
;   n = start - end (0 = 65536) iterations, extra = (n - 1) * 21.
;   All registers are kept (the caller keeps Z80 F in AH).
;===============================================================================
tblk:   push    ax
        push    dx
        push    si
        mov     ax,[tblkn]
        sub     ax,cx                   ;n, 0 = 65536
        dec     ax                      ;n - 1 (0..65535)
        mov     si,21
        mul     si                      ;DX:AX = (n - 1) * 21
        cli
        add     [tdebt+0],ax
        adc     [tdebt+2],dx
        call    tforce
        sti
        pop     si
        pop     dx
        pop     ax
        retn

;===============================================================================
; Tslow: entered from the dispatch macros when tleft < 0
;   SI = Z80 AF (F in high byte), DI = opcode * 2, AX = T-states of that
;   opcode (already subtracted), BP = PC after the opcode byte.
;===============================================================================
Tslow:  mov     [tcost],ax
tslchk: cli
        call    tnorm
        sti
        mov     al,[irqpend]
        and     al,[irqmask]
        jz      tslnoi
        cmp     BYTE [eidly],0          ;just after EI: run one more opcode
        jnz     tsleid
        cmp     BYTE [IFF1],0
        jnz     tslacc
tslnoi: mov     BYTE [eidly],0
        cmp     WORD [tleft],0
        jge     tslrun
        cmp     BYTE [tfast],0          ;no speed limit: refill and run
        jnz     tslful
        sti
        hlt                             ;wait for the next timer tick
        jmp     tslchk
tsleid: cmp     WORD [tleft],0          ;budget first, keep eidly while waiting
        jge     tsleok
        cmp     BYTE [tfast],0
        jz      tslewt
        cli
        mov     ax,[tcap]
        mov     [tleft],ax
        sti
        jmp     tsleok
tslewt: sti
        hlt
        jmp     tslchk
tsleok: mov     BYTE [eidly],0          ;run the opcode after EI, accept the
        cli                             ;interrupt at the next one
        call    tforce
        sti
        jmp     tslrun

tslful: cli
        mov     ax,[tcap]
        mov     [tleft],ax
        sti
; run the fetched opcode
tslrun: mov     ax,si
        sahf
        jmp     WORD [T0+di]

; accept a maskable interrupt
tslacc: mov     ax,[tcost]
        add     [tleft],ax              ;the opcode is not executed
        dec     bp                      ;PC of that opcode
        cmp     BYTE [halted],0
        jz      tslnhl
        mov     BYTE [halted],0
        inc     bp                      ;return to the opcode after HALT
tslnhl: xor     al,al
        mov     [IFF1],al
        mov     [IFF],al                ;IFF2 = 0 (P/V of LD A,I)
        mov     al,[irqpend]            ;take the highest priority level
        and     al,[irqmask]
        xor     di,di                   ;level (CX = Z80 BC is not used)
        mov     ah,1
tsllvl: test    al,ah
        jnz     tslclr
        shl     ah,1
        inc     di
        jmp     tsllvl
tslclr: not     ah
        and     [irqpend],ah
        mov     ax,di
        add     al,al                   ;IM 2 vector offset = level * 2
        mov     di,[Z80SP]              ;push PC
        dec     di
        dec     di
        mov     [Z80SP],di
        mov     [es:Z80+di],bp
        cmp     BYTE [imode],2
        jnz     tslrst
        mov     ah,[Z80I]               ;IM 2: PC = (I * 256 + vector)
        mov     di,ax
        mov     bp,[es:Z80+di]
        sub     WORD [tleft],19
        jmp     tslnew
tslrst: mov     bp,0038h                ;IM 0 (RST 38h on the bus) / IM 1
        sub     WORD [tleft],13
tslnew: mov     ax,si                   ;fetch the opcode at the new PC
        XinstB                          ;(AH = Z80 F, not the 8086 flags)
