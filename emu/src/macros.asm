;*******************************************************************************
;*                                  z80em86                                    *
;*           A Z80 CPU emulator coded in Intel 86 assembly language            *
;*                                                                             *
;*                                  Macros                                     *
;*                                                                             *
;*                    Copyright (C) 1992-2009 Stewart Kay                      *
;*******************************************************************************
;
;===============================================================================
; ChangeLog (most recent entries are at top)
;===============================================================================
; z80em86-88 - 5 October 2026
; - Xinst macros jump to the shared dispatch code DispA-DispD (INSTHAND.ASM),
;   which also counts T-states (TC0) and enters Tslow (TIMER.ASM).
; - Xinst macros increment R on every opcode fetch (M1).
;
; v1.0.0 - 10 February 2009, S.J.Kay
; - Convert sources from TASM to NASM format and prepare for GPL release.
; - Added 'BITS 16' and 'CPU 8086' and make all ASM files include this file.
; - Changed all uses of 'Z80' map segment to 'es:Z80'
;
; v1.00 - 5 April 1995 S.J.Kay
; - Last time code was worked on before releasing under the GPL.
;
; v0.00 - 1992 S.J.Kay
; - Started to code the Z80 emulator.

;===============================================================================
; z80em86 - A Z80 CPU emulator coded in Intel 86 assembly language.
; Copyright (C) 1992-2009 Stewart Kay
;
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

BITS 16
CPU 8086

; The opcode fetch and dispatch code is shared (DispA-DispD in INSTHAND.ASM):
; inlining it in every handler made the code segment larger than 64K once
; the T-state counting was added.
%ifndef INSTHAND
EXTERN  DispA, DispB, DispC, DispD
%endif
%ifndef TIMER
%ifndef INSTHAND
EXTERN  tleft                           ;T-states left (TIMER.ASM)
%endif
%endif

; F from the 8086 flags
%MACRO	XinstA	0
        jmp     DispA
        %ENDMACRO

; F already in AH
%MACRO	XinstB	0
        jmp     DispB
        %ENDMACRO

; F from the 8086 flags, P/V = 0 (no overflow)
%MACRO	XinstC	0
        jmp     DispC
        %ENDMACRO

; F from the 8086 flags, P/V = 1 (overflow)
%MACRO	XinstD	0
        jmp     DispD
        %ENDMACRO
