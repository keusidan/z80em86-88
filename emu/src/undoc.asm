;*******************************************************************************
;*                                  z80em86                                    *
;*           A Z80 CPU emulator coded in Intel 86 assembly language            *
;*                                                                             *
;*                     Undocumented Z80 instructions                           *
;*                                                                             *
;*                    Copyright (C) 1992-2009 Stewart Kay                      *
;*******************************************************************************
;
;===============================================================================
; ChangeLog (most recent entries are at top)
;===============================================================================
; z80em86-88 - 5 October 2026
; - New file. Undocumented instructions that real Z80 CPUs execute:
;   * DD/FD prefixed ops on the index register halves IXH/IXL/IYH/IYL
;   * CB 30-37 SLL r / SLL (HL)  (shift left, bit 0 set to 1)
;   * DD CB d xx / FD CB d xx forms that also copy the result to a register
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
; Register use is the same as the rest of the emulator:
;   AL = Z80 A, 8086 FLAGS = Z80 F (N kept in FlagN), CX = BC, DX = DE,
;   BX = HL, BP = PC, ES:Z80+addr = Z80 memory.
; AH is free inside a handler: XinstA reloads it with LAHF.
; IXL = [Z80IX], IXH = [Z80IX+1] (same for IY).

SEGMENT	Z80map	public align=16
Z80:

SEGMENT	.code	public align=16

; declared in INSTHAND.ASM
EXTERN  Z80IX, Z80IY, FlagN

%include "macros.asm"

;===============================================================================
; DD/FD xx on IXH/IXL/IYH/IYL
;   %1 = name suffix (xh, xl, yh, yl), %2 = memory operand of that half
;===============================================================================
%MACRO	HALFOPS 2
GLOBAL  Z_INC%1, Z_DEC%1, Z_LD%1n
GLOBAL  Z_LDb%1, Z_LDc%1, Z_LDd%1, Z_LDe%1, Z_LDa%1
GLOBAL  Z_LD%1b, Z_LD%1c, Z_LD%1d, Z_LD%1e, Z_LD%1a
GLOBAL  Z_ADD%1, Z_ADC%1, Z_SUB%1, Z_SBC%1
GLOBAL  Z_AND%1, Z_XOR%1, Z_OR%1,  Z_CP%1

; INC/DEC r : S Z H V set, N, C unchanged (8086 INC/DEC keep CF too)
Z_INC%1:
        mov     BYTE [FlagN],0
        inc     BYTE %2
        jo      %%incv
        XinstC
%%incv: XinstD

Z_DEC%1:
        mov     BYTE [FlagN],2
        dec     BYTE %2
        jo      %%decv
        XinstC
%%decv: XinstD

Z_LD%1n:
        mov     ah,[es:Z80+bp]
        mov     %2,ah
        lahf
        inc     bp
        XinstB

Z_LDb%1: mov    ch,%2
        XinstA
Z_LDc%1: mov    cl,%2
        XinstA
Z_LDd%1: mov    dh,%2
        XinstA
Z_LDe%1: mov    dl,%2
        XinstA
Z_LDa%1: mov    al,%2
        XinstA

Z_LD%1b: mov    %2,ch
        XinstA
Z_LD%1c: mov    %2,cl
        XinstA
Z_LD%1d: mov    %2,dh
        XinstA
Z_LD%1e: mov    %2,dl
        XinstA
Z_LD%1a: mov    %2,al
        XinstA

Z_ADD%1:
        mov     BYTE [FlagN],0
        add     al,%2
        jo      %%addv
        XinstC
%%addv: XinstD

Z_ADC%1:
        mov     BYTE [FlagN],0
        adc     al,%2
        jo      %%adcv
        XinstC
%%adcv: XinstD

Z_SUB%1:
        mov     BYTE [FlagN],2
        sub     al,%2
        jo      %%subv
        XinstC
%%subv: XinstD

Z_SBC%1:
        mov     BYTE [FlagN],2
        sbb     al,%2
        jo      %%sbcv
        XinstC
%%sbcv: XinstD

Z_AND%1:
        and     al,%2
        mov     BYTE [FlagN],0
        lahf
        or      ah,00010000b
        XinstB

Z_XOR%1:
        xor     al,%2
        mov     BYTE [FlagN],0
        lahf
        and     ah,11101111b
        XinstB

Z_OR%1:
        or      al,%2
        mov     BYTE [FlagN],0
        lahf
        and     ah,11101111b
        XinstB

Z_CP%1:
        cmp     al,%2
        mov     BYTE [FlagN],2
        jo      %%cpv
        XinstC
%%cpv:  XinstD
%ENDMACRO

        HALFOPS xh, [Z80IX+1]
        HALFOPS xl, [Z80IX]
        HALFOPS yh, [Z80IY+1]
        HALFOPS yl, [Z80IY]

; LD between the two halves of the same index register (AH as scratch)
GLOBAL  Z_LDxhxl, Z_LDxlxh, Z_LDyhyl, Z_LDylyh
Z_LDxhxl:
        mov     ah,[Z80IX]
        mov     [Z80IX+1],ah
        XinstA
Z_LDxlxh:
        mov     ah,[Z80IX+1]
        mov     [Z80IX],ah
        XinstA
Z_LDyhyl:
        mov     ah,[Z80IY]
        mov     [Z80IY+1],ah
        XinstA
Z_LDylyh:
        mov     ah,[Z80IY+1]
        mov     [Z80IY],ah
        XinstA

;===============================================================================
; SLL : shift left, bit 0 <- 1, C <- bit 7.  Flags like SLA (H=0, N=0, P=parity)
; STC + RCL gives the result and C; RCL does not set S Z P, so INC/DEC is used
; to set them (the same trick as RLC in ROTATE.ASM).
;===============================================================================
%MACRO	SLLREG 2
GLOBAL  Z_SLL%1
Z_SLL%1:
        stc
        rcl     %2,1
        mov     BYTE [FlagN],0
        inc     %2
        dec     %2
        lahf
        and     ah,11101111b
        XinstB
%ENDMACRO

        SLLREG  b, ch
        SLLREG  c, cl
        SLLREG  d, dh
        SLLREG  e, dl
        SLLREG  h, bh
        SLLREG  l, bl
        SLLREG  a, al
        SLLREG  z, BYTE [es:Z80+bx]

; SLL (IX+d) / SLL (IY+d) : SI = IX/IY + d (set by CBxops/CByops)
GLOBAL  Z_SLLw
Z_SLLw:
        stc
        rcl     BYTE [es:Z80+si],1
        mov     BYTE [FlagN],0
        inc     BYTE [es:Z80+si]
        dec     BYTE [es:Z80+si]
        lahf
        and     ah,11101111b
        XinstB

;===============================================================================
; DD CB d xx / FD CB d xx with xx & 7 != 6:
; the operation is done on (IX+d) and the result is also loaded into r.
; SI = IX/IY + d (set by CBxops/CByops). MOV does not change AH (= Z80 F),
; so the copy is placed after the flags are taken.
;   handler name: Z_<op>w<r>, e.g. Z_RLCwb = RLC (IX+d) -> B
;===============================================================================
; RLC/RRC/RL/RR/SLL: 8086 rotates do not set S Z P, INC/DEC sets them
%MACRO	ROT1 5                          ; name, pre, 8086 op, suffix, reg
GLOBAL  Z_%1w%4
Z_%1w%4:
        %2
        %3      BYTE [es:Z80+si],1
        mov     BYTE [FlagN],0
        inc     BYTE [es:Z80+si]
        dec     BYTE [es:Z80+si]
        lahf
        and     ah,11101111b
        mov     %5,[es:Z80+si]
        XinstB
%ENDMACRO

; SLA/SRA/SRL: 8086 shifts set S Z P
%MACRO	SHF1 4                          ; name, 8086 op, suffix, reg
GLOBAL  Z_%1w%3
Z_%1w%3:
        %2      BYTE [es:Z80+si],1
        lahf
        and     ah,11101111b
        mov     BYTE [FlagN],0
        mov     %4,[es:Z80+si]
        XinstB
%ENDMACRO

; RES/SET: flags unchanged
%MACRO	RES1 3                          ; bit, suffix, reg
GLOBAL  Z_RES%1w%2
Z_RES%1w%2:
        lahf
        and     BYTE [es:Z80+si],~(1 << %1) & 0ffh
        mov     %3,[es:Z80+si]
        XinstB
%ENDMACRO
%MACRO	SET1 3                          ; bit, suffix, reg
GLOBAL  Z_SET%1w%2
Z_SET%1w%2:
        lahf
        or      BYTE [es:Z80+si],1 << %1
        mov     %3,[es:Z80+si]
        XinstB
%ENDMACRO

; expand macro %1 (with leading args %2..) for the 7 registers B C D E H L A
%MACRO	EACHREG 1-*
        %1      %{2:-1}, b, ch
        %1      %{2:-1}, c, cl
        %1      %{2:-1}, d, dh
        %1      %{2:-1}, e, dl
        %1      %{2:-1}, h, bh
        %1      %{2:-1}, l, bl
        %1      %{2:-1}, a, al
%ENDMACRO

        EACHREG ROT1, RLC, nop, rol
        EACHREG ROT1, RRC, nop, ror
        EACHREG ROT1, RL,  nop, rcl
        EACHREG ROT1, RR,  nop, rcr
        EACHREG ROT1, SLL, stc, rcl
        EACHREG SHF1, SLA, shl
        EACHREG SHF1, SRA, sar
        EACHREG SHF1, SRL, shr

%assign bitn 0
%rep 8
        EACHREG RES1, bitn
        EACHREG SET1, bitn
%assign bitn bitn+1
%endrep

