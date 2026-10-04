;*******************************************************************************
;*                                  z80em86                                    *
;*           A Z80 CPU emulator coded in Intel 86 assembly language            *
;*                                                                             *
;*                          Input and Output Group                             *
;*                                                                             *
;*                    Copyright (C) 1992-2009 Stewart Kay                      *
;*******************************************************************************
;
;===============================================================================
; ChangeLog (most recent entries are at top)
;===============================================================================
; z80em86-88 - 5 October 2026
; - IN A,(n), IN r,(C), OUT (C),r, OUT (C),0, INI..OTDR access PC-8801 ports
;   in 88 mode
;   (PC88.ASM). Outside 88 mode they still stop the emulator.
;
; v1.0.0 - 10 February 2009, S.J.Kay
; - Convert sources from TASM to NASM format and prepare for GPL release.
; - Changed 'lea' instructions to  'mov'.
; - Added 'align=16' to all SEGMENT declarations. (nasm def is align=1)
;
; v1.00 - 29 April 1995 S.J.Kay
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

SEGMENT	Z80map	public align=16
Z80:

SEGMENT	.code	public align=16

GLOBAL	Z_INan
GLOBAL	Z_INbc,  Z_INcc,  Z_INdc,  Z_INec
GLOBAL	Z_INhc,  Z_INlc,  Z_INfc,  Z_INac
GLOBAL	Z_OUTcb, Z_OUTcc, Z_OUTcd, Z_OUTce
GLOBAL	Z_OUTch, Z_OUTcl, Z_OUTca
GLOBAL	Z_INI,   Z_INIR,  Z_IND,   Z_INDR
GLOBAL	Z_OUTI,  Z_OTIR,  Z_OUTD,  Z_OTDR

; declared in FUNCTION.ASM
EXTERN  Nocde0, Nocde1
; declared in INSTHAND.ASM
EXTERN  FlagN

%include "macros.asm"
%include "io88.inc"

GLOBAL	Z_OUTc0

iotmp   db      0
iof     db      0

; IN r,(C) in 88 mode: S Z P from the value, H = 0, N = 0, C kept
%MACRO	IN88C 2                         ;%1 = 8086 reg, %2 = label if not 88
        lahf
        P88USR  %2
        mov     si,ax                   ;Z80 AF
        mov     di,cx
        and     di,00ffh                ;port = C
        call    p88in
        mov     [iotmp],al
        mov     ax,si
        mov     [iof],ah
        mov     ah,[iotmp]
        or      ah,ah                   ;S Z P of the value (8086 CF = 0)
        lahf
        and     ah,11000100b
        mov     BYTE [FlagN],0
        and     BYTE [iof],00000001b    ;keep C
        or      ah,[iof]
%ifnidni %1,none
        mov     %1,[iotmp]
%endif
        XinstB
%ENDMACRO

; INI/IND/INIR/INDR/OUTI/OUTD/OTIR/OTDR in 88 mode: port C, memory (HL),
; B counts down. Flags: S Z P from B (Z = 1 when B = 0), N = 1.
;   %1 = 1 out / 0 in, %2 = inc/dec, %3 = 1 repeat, %4 = label if not 88
%MACRO	BLK88 4
        lahf
        P88USR  %4
        mov     si,ax                   ;Z80 AF
%%next: mov     di,cx
        and     di,00ffh                ;port = C
%if %1
        mov     al,[es:Z80+bx]
        call    p88out
%else
        call    p88in
        mov     [es:Z80+bx],al
%endif
        %2      bx
        dec     ch
%if %3
        jz      %%done
        sub     WORD [tleft],21         ;each repeat is 21T
        jmp     %%next
%%done:
%endif
        mov     ax,si
        or      ch,ch                   ;S Z P from B
        lahf
        mov     BYTE [FlagN],2
        XinstB
%ENDMACRO

; OUT (C),r in 88 mode
%MACRO	OUT88C 2                        ;%1 = value (8086 reg), %2 = not 88
        lahf
        P88USR  %2
        mov     di,cx
        and     di,00ffh                ;port = C
        push    ax
        mov     al,%1
        call    p88out
        pop     ax
        XinstB
%ENDMACRO

;***********************************************************
;*      IN      B,(C)            Flags: S Z - H - P/V N C  *
;*                                      ^ ^ x ^ x  P  0 .  *
;***********************************************************
Z_INbc:
        IN88C   ch,inbcx
inbcx: sahf
        mov     si,inbc
        jmp     NEAR Nocde0
inbc:   db      'IN      B,(C)$'

;***********************************************************
;*      IN      C,(C)            Flags: S Z - H - P/V N C  *
;*                                      ^ ^ x ^ x  P  0 .  *
;***********************************************************
Z_INcc:
        IN88C   cl,inccx
inccx: sahf
        mov     si,incc_
        jmp     NEAR Nocde0
incc_:  db      'IN      C,(C)$'

;***********************************************************
;*      IN      D,(C)            Flags: S Z - H - P/V N C  *
;*                                      ^ ^ x ^ x  P  0 .  *
;***********************************************************
Z_INdc:
        IN88C   dh,indcx
indcx: sahf
        mov     si,indc
        jmp     NEAR Nocde0
indc:   db      'IN      D,(C)$'

;***********************************************************
;*      IN      E,(C)            Flags: S Z - H - P/V N C  *
;*                                      ^ ^ x ^ x  P  0 .  *
;***********************************************************
Z_INec:
        IN88C   dl,inecx
inecx: sahf
        mov     si,inec
        jmp     NEAR Nocde0
inec:   db      'IN      E,(C)$'

;***********************************************************
;*      IN      H,(C)            Flags: S Z - H - P/V N C  *
;*                                      ^ ^ x ^ x  P  0 .  *
;***********************************************************
Z_INhc:
        IN88C   bh,inhcx
inhcx: sahf
        mov     si,inhc
        jmp     NEAR Nocde0
inhc:   db      'IN      H,(C)$'

;***********************************************************
;*      IN      L,(C)            Flags: S Z - H - P/V N C  *
;*                                      ^ ^ x ^ x  P  0 .  *
;***********************************************************
Z_INlc:
        IN88C   bl,inlcx
inlcx: sahf
        mov     si,inlc
        jmp     NEAR Nocde0
inlc:   db      'IN      L,(C)$'

;***********************************************************
;*      IN      A,(C)            Flags: S Z - H - P/V N C  *
;*                                      ^ ^ x ^ x  P  0 .  *
;***********************************************************
Z_INac:
        IN88C   al,inacx
inacx: sahf
        mov     si,inac
        jmp     NEAR Nocde0
inac:   db      'IN      A,(C)$'

;***********************************************************
;*      IN      (HL),(C)         Flags: S Z - H - P/V N C  *
;*                                      ? ? x ? x  ?  ? ?  *
;***********************************************************
Z_INfc:
        IN88C   none,infcx              ;flags only, the value is dropped
infcx:  sahf
        mov     si,infc
        jmp     NEAR Nocde0
infc:   db      'IN      (HL),(C)$'

;***********************************************************
;*      IN      A,(NN)           Flags: S Z - H - P/V N C  *
;*                                      . . x . x  .  . .  *
;***********************************************************
Z_INan:
        lahf
        P88USR  inanx
        mov     di,[es:Z80+bp]
        and     di,00ffh                ;port = n (flags not changed)
        inc     bp
        call    p88in                   ;AL = value, AH = Z80 F kept
        XinstB
inanx:  sahf
        mov     si,inan
        jmp     NEAR Nocde1
inan:   db      'IN      A,(NN)$'

;***********************************************************
;*      INI                      Flags: S Z - H - P/V N C  *
;*                                      x ^ x x x  x  1 x  *
;***********************************************************
Z_INI:
        BLK88   0,inc,0,inix
inix:    sahf
        mov     si,ini
        jmp     NEAR Nocde0
ini:    db      'INI$'

;***********************************************************
;*      IND                      Flags: S Z - H - P/V N C  *
;*                                      x ^ x x x  x  1 x  *
;***********************************************************
Z_IND:
        BLK88   0,dec,0,indx
indx:    sahf
        mov     si,ind
        jmp     NEAR Nocde0
ind:    db      'IND$'

;***********************************************************
;*      INIR                     Flags: S Z - H - P/V N C  *
;*                                      x 1 x x x  x  1 x  *
;***********************************************************
Z_INIR:
        BLK88   0,inc,1,inirx
inirx:   sahf
        mov     si,inir
        jmp     NEAR Nocde0
inir:   db      'INIR$'

;***********************************************************
;*      INDR                     Flags: S Z - H - P/V N C  *
;*                                      x 1 x x x  x  1 x  *
;***********************************************************
Z_INDR:
        BLK88   0,dec,1,indrx
indrx:   sahf
        mov     si,indr
        jmp     NEAR Nocde0
indr:   db      'INDR$'

;***********************************************************
;*      OUT     (C),B            Flags: S Z - H - P/V N C  *
;*                                      . . x . x  .  . .  *
;***********************************************************
Z_OUTcb:
        OUT88C  ch,outbcx
outbcx: sahf
        mov     si,outcb
        jmp     NEAR Nocde0
outcb:  db      'OUT     (C),B$'

;***********************************************************
;*      OUT     (C),C            Flags: S Z - H - P/V N C  *
;*                                      . . x . x  .  . .  *
;***********************************************************
Z_OUTcc:
        OUT88C  cl,outccx
outccx: sahf
        mov     si,outcc
        jmp     NEAR Nocde0
outcc:  db      'OUT     (C),C$'

;***********************************************************
;*      OUT     (C),D            Flags: S Z - H - P/V N C  *
;*                                      . . x . x  .  . .  *
;***********************************************************
Z_OUTcd:
        OUT88C  dh,outdcx
outdcx: sahf
        mov     si,outcd
        jmp     NEAR Nocde0
outcd:  db      'OUT     (C),D$'

;***********************************************************
;*      OUT     (C),E            Flags: S Z - H - P/V N C  *
;*                                      . . x . x  .  . .  *
;***********************************************************
Z_OUTce:
        OUT88C  dl,outecx
outecx: sahf
        mov     si,outce
        jmp     NEAR Nocde0
outce:  db      'OUT     (C),E$'

;***********************************************************
;*      OUT     (C),H            Flags: S Z - H - P/V N C  *
;*                                      . . x . x  .  . .  *
;***********************************************************
Z_OUTch:
        OUT88C  bh,outhcx
outhcx: sahf
        mov     si,outch
        jmp     NEAR Nocde0
outch:  db      'OUT     (C),H$'

;***********************************************************
;*      OUT     (C),L            Flags: S Z - H - P/V N C  *
;*                                      . . x . x  .  . .  *
;***********************************************************
Z_OUTcl:
        OUT88C  bl,outlcx
outlcx: sahf
        mov     si,outcl
        jmp     NEAR Nocde0
outcl:  db      'OUT     (C),L$'

;***********************************************************
;*      OUT     (C),A            Flags: S Z - H - P/V N C  *
;*                                      . . x . x  .  . .  *
;***********************************************************
Z_OUTca:
        OUT88C  al,outacx
outacx: sahf
        mov     si,outca
        jmp     NEAR Nocde0
outca:  db      'OUT     (C),A$'

;***********************************************************
;*      OUT     (NN),A           Flags: S Z - H - P/V N C  *
;*                                      . . x . x  .  . .  *
;***********************************************************

; OUT (C),0 (ED 71, undocumented)
Z_OUTc0:
        OUT88C  0,out0cx
out0cx: sahf
        mov     si,outc0
        jmp     NEAR Nocde0
outc0:  db      'OUT     (C),0$'

; used for 8086 interfacing

;***********************************************************
;*      OUTI                     Flags: S Z - H - P/V N C  *
;*                                      x ^ x x x  x  1 x  *
;***********************************************************
Z_OUTI:
        BLK88   1,inc,0,outix
outix:   sahf
        mov     si,outi
        jmp     NEAR Nocde0
outi:   db      'OUTI$'

;***********************************************************
;*      OUTD                     Flags: S Z - H - P/V N C  *
;*                                      x ^ x x x  x  1 x  *
;***********************************************************
Z_OUTD:
        BLK88   1,dec,0,outdx
outdx:   sahf
        mov     si,outd
        jmp     NEAR Nocde0
outd:   db      'OUTD$'

;***********************************************************
;*      OTIR                     Flags: S Z - H - P/V N C  *
;*                                      x 1 x x x  x  1 x  *
;***********************************************************
Z_OTIR:
        BLK88   1,inc,1,otirx
otirx:   sahf
        mov     si,otir
        jmp     NEAR Nocde0
otir:   db      'OTIR$'

;***********************************************************
;*      OTDR                     Flags: S Z - H - P/V N C  *
;*                                      x 1 x x x  x  1 x  *
;***********************************************************
Z_OTDR:
        BLK88   1,dec,1,otdrx
otdrx:   sahf
        mov     si,otdr
        jmp     NEAR Nocde0
otdr:   db      'OTDR$'

        end
