;===============================================================================
; io88.inc - z80em86-88: is an IN/OUT opcode a PC-8801 port access ?
; Included by INSTHAND.ASM and IO.ASM. This file is part of z80em86-88 (GPL v2).
;
; P88USR label : jump to label when the opcode is NOT a PC-8801 access, that
; is when 88 mode is off, or the code runs in bank 0 or in the common memory
; (the BIOS uses OUT (n),A for the emulator functions).
; Changes the 8086 flags: do LAHF first.
;===============================================================================
EXTERN  pc88, p88out, p88in
EXTERN  cdebnk, memsze

%MACRO	P88USR 1
        cmp     BYTE [pc88],0
        jz      %1
        cmp     BYTE [cdebnk],1         ;TPA is bank #1
        jnz     %1
        cmp     bp,[memsze]             ;below the common memory
        jae     %1
%ENDMACRO
