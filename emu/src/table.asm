;*******************************************************************************
;*                                  z80em86                                    *
;*           A Z80 CPU emulator coded in Intel 86 assembly language            *
;*                                                                             *
;*                 Z80 Opcodes and Function Interface tables                   *
;*                                                                             *
;*                    Copyright (C) 1992-2009 Stewart Kay                      *
;*******************************************************************************
;
;===============================================================================
; ChangeLog (most recent entries are at top)
;===============================================================================
; z80em86-88 - 5 October 2026
; - Fill undocumented slots: IXH/IXL/IYH/IYL ops, DD/FD on other opcodes
;   run the plain opcode, SLL, DDCB/FDCB copy forms, ED duplicates of
;   NEG/RETN/RETI/IM/LD (nn),HL/LD HL,(nn), other ED xx run as NOP.
;   ED 71 (OUT (C),0) still traps, as the other I/O opcodes.
; - Emulator function E0h: 88 mode on, 86h: 88 mode off then HDD flush.
; - ED 71: OUT (C),0 (PC-8801 port in 88 mode).
;
; v1.0.0 - 10 February 2009, S.J.Kay
; - Convert sources from TASM to NASM format and prepare for GPL release.
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

SEGMENT	.code	public align=16

GLOBAL  T0, T1, T2, T3, T4, T5, T6, T7, Tx

; declared in PC88.ASM (z80em86-88)
EXTERN  pc88on, p88wbt
; declared in IO.ASM (z80em86-88)
EXTERN  Z_OUTc0
; declared in UNDOC.ASM (z80em86-88)
EXTERN  Z_ADCxh, Z_ADCxl, Z_ADCyh, Z_ADCyl
EXTERN  Z_ADDxh, Z_ADDxl, Z_ADDyh, Z_ADDyl
EXTERN  Z_ANDxh, Z_ANDxl, Z_ANDyh, Z_ANDyl
EXTERN  Z_CPxh, Z_CPxl, Z_CPyh, Z_CPyl
EXTERN  Z_DECxh, Z_DECxl, Z_DECyh, Z_DECyl
EXTERN  Z_INCxh, Z_INCxl, Z_INCyh, Z_INCyl
EXTERN  Z_LDaxh, Z_LDaxl, Z_LDayh, Z_LDayl
EXTERN  Z_LDbxh, Z_LDbxl, Z_LDbyh, Z_LDbyl
EXTERN  Z_LDcxh, Z_LDcxl, Z_LDcyh, Z_LDcyl
EXTERN  Z_LDdxh, Z_LDdxl, Z_LDdyh, Z_LDdyl
EXTERN  Z_LDexh, Z_LDexl, Z_LDeyh, Z_LDeyl
EXTERN  Z_LDxha, Z_LDxhb, Z_LDxhc, Z_LDxhd
EXTERN  Z_LDxhe, Z_LDxhn, Z_LDxhxl, Z_LDxla
EXTERN  Z_LDxlb, Z_LDxlc, Z_LDxld, Z_LDxle
EXTERN  Z_LDxln, Z_LDxlxh, Z_LDyha, Z_LDyhb
EXTERN  Z_LDyhc, Z_LDyhd, Z_LDyhe, Z_LDyhn
EXTERN  Z_LDyhyl, Z_LDyla, Z_LDylb, Z_LDylc
EXTERN  Z_LDyld, Z_LDyle, Z_LDyln, Z_LDylyh
EXTERN  Z_ORxh, Z_ORxl, Z_ORyh, Z_ORyl
EXTERN  Z_RES0wa, Z_RES0wb, Z_RES0wc, Z_RES0wd
EXTERN  Z_RES0we, Z_RES0wh, Z_RES0wl, Z_RES1wa
EXTERN  Z_RES1wb, Z_RES1wc, Z_RES1wd, Z_RES1we
EXTERN  Z_RES1wh, Z_RES1wl, Z_RES2wa, Z_RES2wb
EXTERN  Z_RES2wc, Z_RES2wd, Z_RES2we, Z_RES2wh
EXTERN  Z_RES2wl, Z_RES3wa, Z_RES3wb, Z_RES3wc
EXTERN  Z_RES3wd, Z_RES3we, Z_RES3wh, Z_RES3wl
EXTERN  Z_RES4wa, Z_RES4wb, Z_RES4wc, Z_RES4wd
EXTERN  Z_RES4we, Z_RES4wh, Z_RES4wl, Z_RES5wa
EXTERN  Z_RES5wb, Z_RES5wc, Z_RES5wd, Z_RES5we
EXTERN  Z_RES5wh, Z_RES5wl, Z_RES6wa, Z_RES6wb
EXTERN  Z_RES6wc, Z_RES6wd, Z_RES6we, Z_RES6wh
EXTERN  Z_RES6wl, Z_RES7wa, Z_RES7wb, Z_RES7wc
EXTERN  Z_RES7wd, Z_RES7we, Z_RES7wh, Z_RES7wl
EXTERN  Z_RLCwa, Z_RLCwb, Z_RLCwc, Z_RLCwd
EXTERN  Z_RLCwe, Z_RLCwh, Z_RLCwl, Z_RLwa
EXTERN  Z_RLwb, Z_RLwc, Z_RLwd, Z_RLwe
EXTERN  Z_RLwh, Z_RLwl, Z_RRCwa, Z_RRCwb
EXTERN  Z_RRCwc, Z_RRCwd, Z_RRCwe, Z_RRCwh
EXTERN  Z_RRCwl, Z_RRwa, Z_RRwb, Z_RRwc
EXTERN  Z_RRwd, Z_RRwe, Z_RRwh, Z_RRwl
EXTERN  Z_SBCxh, Z_SBCxl, Z_SBCyh, Z_SBCyl
EXTERN  Z_SET0wa, Z_SET0wb, Z_SET0wc, Z_SET0wd
EXTERN  Z_SET0we, Z_SET0wh, Z_SET0wl, Z_SET1wa
EXTERN  Z_SET1wb, Z_SET1wc, Z_SET1wd, Z_SET1we
EXTERN  Z_SET1wh, Z_SET1wl, Z_SET2wa, Z_SET2wb
EXTERN  Z_SET2wc, Z_SET2wd, Z_SET2we, Z_SET2wh
EXTERN  Z_SET2wl, Z_SET3wa, Z_SET3wb, Z_SET3wc
EXTERN  Z_SET3wd, Z_SET3we, Z_SET3wh, Z_SET3wl
EXTERN  Z_SET4wa, Z_SET4wb, Z_SET4wc, Z_SET4wd
EXTERN  Z_SET4we, Z_SET4wh, Z_SET4wl, Z_SET5wa
EXTERN  Z_SET5wb, Z_SET5wc, Z_SET5wd, Z_SET5we
EXTERN  Z_SET5wh, Z_SET5wl, Z_SET6wa, Z_SET6wb
EXTERN  Z_SET6wc, Z_SET6wd, Z_SET6we, Z_SET6wh
EXTERN  Z_SET6wl, Z_SET7wa, Z_SET7wb, Z_SET7wc
EXTERN  Z_SET7wd, Z_SET7we, Z_SET7wh, Z_SET7wl
EXTERN  Z_SLAwa, Z_SLAwb, Z_SLAwc, Z_SLAwd
EXTERN  Z_SLAwe, Z_SLAwh, Z_SLAwl, Z_SLLa
EXTERN  Z_SLLb, Z_SLLc, Z_SLLd, Z_SLLe
EXTERN  Z_SLLh, Z_SLLl, Z_SLLw, Z_SLLwa
EXTERN  Z_SLLwb, Z_SLLwc, Z_SLLwd, Z_SLLwe
EXTERN  Z_SLLwh, Z_SLLwl, Z_SLLz, Z_SRAwa
EXTERN  Z_SRAwb, Z_SRAwc, Z_SRAwd, Z_SRAwe
EXTERN  Z_SRAwh, Z_SRAwl, Z_SRLwa, Z_SRLwb
EXTERN  Z_SRLwc, Z_SRLwd, Z_SRLwe, Z_SRLwh
EXTERN  Z_SRLwl, Z_SUBxh, Z_SUBxl, Z_SUByh
EXTERN  Z_SUByl, Z_XORxh, Z_XORxl, Z_XORyh
EXTERN  Z_XORyl

; declared in FUNCTION.ASM
EXTERN  trp0__,  trp1__,  fnc___
EXTERN  GtBoot
EXTERN  blkcnt,  blkget,  blkput,  blkfil
EXTERN  GtZseg,  intfnc
EXTERN  GetByt,  SetByt
EXTERN  prmsta,  prmget,  vidsta,  vidset
EXTERN  usrbyt,  failed,  rstz80,  extemu

; declared in HARDWARE.ASM
EXTERN  bnkuse,  bnksel,  bnkmve,  bnkdta
EXTERN  bnkdma
EXTERN  kbd1in,  kbd1st,  kbd1ip
EXTERN  kbd2in,  kbd2st,  kbd2ip
EXTERN  lptini,  lptsta,  lptout
EXTERN  comini,  comist,  cominp,  comost
EXTERN  comout
EXTERN  gettme,  settme,  getdte,  setdte
EXTERN  rdflop,  wrflop,  rdhard,  wrhard
EXTERN  GtHard,  FlHard

; declared in VIDEO.ASM
EXTERN  crt1in,  crt1st,  crt1op
EXTERN  crt2in,  crt2st,  crt2op

;$CB opcodes for IX
EXTERN  Z_RLCw,  Z_RRCw,  Z_RLw,   Z_RRw
EXTERN  Z_SLAw,  Z_SRAw,  Z_SRLw
EXTERN  Z_BIT0w, Z_BIT1w, Z_BIT2w, Z_BIT3w
EXTERN  Z_BIT4w, Z_BIT5w, Z_BIT6w, Z_BIT7w
EXTERN  Z_RES0w, Z_RES1w, Z_RES2w, Z_RES3w
EXTERN  Z_RES4w, Z_RES5w, Z_RES6w, Z_RES7w
EXTERN  Z_SET0w, Z_SET1w, Z_SET2w, Z_SET3w
EXTERN  Z_SET4w, Z_SET5w, Z_SET6w, Z_SET7w

;$CB opcodes for IY
EXTERN  Z_RLCv,  Z_RRCv,  Z_RLv,   Z_RRv
EXTERN  Z_SLAv,  Z_SRAv,  Z_SRLv
EXTERN  Z_BIT0v, Z_BIT1v, Z_BIT2v, Z_BIT3v
EXTERN  Z_BIT4v, Z_BIT5v, Z_BIT6v, Z_BIT7v
EXTERN  Z_RES0v, Z_RES1v, Z_RES2v, Z_RES3v
EXTERN  Z_RES4v, Z_RES5v, Z_RES6v, Z_RES7v
EXTERN  Z_SET0v, Z_SET1v, Z_SET2v, Z_SET3v
EXTERN  Z_SET4v, Z_SET5v, Z_SET6v, Z_SET7v

;1st opcode for IX
EXTERN  Z_ADxbc, Z_ADxde, Z_LDxn,  Z_LDmx
EXTERN  Z_INCx,  Z_ADxx,  Z_LDxm,  Z_DECx
EXTERN  Z_INCw,  Z_DECw,  Z_LDwn,  Z_ADxsp
EXTERN  Z_LDbw,  Z_LDcw,  Z_LDdw,  Z_LDew
EXTERN  Z_LDhw,  Z_LDlw,  Z_LDwb,  Z_LDwc
EXTERN  Z_LDwd,  Z_LDwe,  Z_LDwh,  Z_LDwl
EXTERN  Z_LDwa,  Z_LDaw,  Z_ADDw,  Z_ADCw
EXTERN  Z_SUBw,  Z_SBCw,  Z_ANDw,  Z_XORw
EXTERN  Z_ORw,   Z_CPw,   CBxops,  Z_POPx
EXTERN  Z_EXspx, Z_PUSHx, Z_JPx,   Z_LDspx

;1st opcode for IY
EXTERN  Z_ADybc, Z_ADyde, Z_LDyn,  Z_LDmy
EXTERN  Z_INCy,  Z_ADyy,  Z_LDym,  Z_DECy
EXTERN  Z_INCv,  Z_DECv,  Z_LDvn,  Z_ADysp
EXTERN  Z_LDbv,  Z_LDcv,  Z_LDdv,  Z_LDev
EXTERN  Z_LDhv,  Z_LDlv,  Z_LDvb,  Z_LDvc
EXTERN  Z_LDvd,  Z_LDve,  Z_LDvh,  Z_LDvl
EXTERN  Z_LDva,  Z_LDav,  Z_ADDv,  Z_ADCv
EXTERN  Z_SUBv,  Z_SBCv,  Z_ANDv,  Z_XORv
EXTERN  Z_ORv,   Z_CPv,   CByops,  Z_POPy
EXTERN  Z_EXspy, Z_PUSHy, Z_JPy,   Z_LDspy

;$ED Opcode Table
EXTERN  Z_INbc,  Z_OUTcb, Z_SChlbc,Z_LDmbc
EXTERN  Z_NEG,   Z_RETN,  Z_IM0,   Z_LDia
EXTERN  Z_INcc,  Z_OUTcc, Z_AChlbc,Z_LDbcm
EXTERN  Z_RETI,  Z_LDra,  Z_INdc,  Z_OUTcd
EXTERN  Z_SChlde,Z_LDmde, Z_IM1,   Z_LDai
EXTERN  Z_INec,  Z_OUTce, Z_AChlde,Z_LDdem
EXTERN  Z_IM2,   Z_LDar,  Z_INhc,  Z_OUTch
EXTERN  Z_SChlhl,Z_RRD,   Z_INlc,  Z_OUTcl
EXTERN  Z_AChlhl,Z_RLD,   Z_INfc,  Z_SChlsp
EXTERN  Z_LDmsp, Z_INac,  Z_OUTca, Z_AChlsp
EXTERN  Z_LDspm, Z_LDI,   Z_CPI,   Z_INI
EXTERN  Z_OUTI,  Z_LDD,   Z_CPD,   Z_IND
EXTERN  Z_OUTD,  Z_LDIR,  Z_CPIR,  Z_INIR
EXTERN  Z_OTIR,  Z_LDDR,  Z_CPDR,  Z_INDR
EXTERN  Z_OTDR

 ;$CB opcode table
EXTERN  Z_RLCb,  Z_RLCc,  Z_RLCd,  Z_RLCe
EXTERN  Z_RLCh,  Z_RLCl,  Z_RLCz,  Z_RLCa
EXTERN  Z_RRCb,  Z_RRCc,  Z_RRCd,  Z_RRCe
EXTERN  Z_RRCh,  Z_RRCl,  Z_RRCz,  Z_RRCa
EXTERN  Z_RLb,   Z_RLc,   Z_RLd,   Z_RLe
EXTERN  Z_RLh,   Z_RLl,   Z_RLz,   Z_RLa
EXTERN  Z_RRb,   Z_RRc,   Z_RRd,   Z_RRe
EXTERN  Z_RRh,   Z_RRl,   Z_RRz,   Z_RRa
EXTERN  Z_SLAb,  Z_SLAc,  Z_SLAd,  Z_SLAe
EXTERN  Z_SLAh,  Z_SLAl,  Z_SLAz,  Z_SLAa
EXTERN  Z_SRAb,  Z_SRAc,  Z_SRAd,  Z_SRAe
EXTERN  Z_SRAh,  Z_SRAl,  Z_SRAz,  Z_SRAa
EXTERN  Z_SRLb,  Z_SRLc,  Z_SRLd,  Z_SRLe
EXTERN  Z_SRLh,  Z_SRLl,  Z_SRLz,  Z_SRLa
EXTERN  Z_BIT0b, Z_BIT0c, Z_BIT0d, Z_BIT0e
EXTERN  Z_BIT0h, Z_BIT0l, Z_BIT0z, Z_BIT0a
EXTERN  Z_BIT1b, Z_BIT1c, Z_BIT1d, Z_BIT1e
EXTERN  Z_BIT1h, Z_BIT1l, Z_BIT1z, Z_BIT1a
EXTERN  Z_BIT2b, Z_BIT2c, Z_BIT2d, Z_BIT2e
EXTERN  Z_BIT2h, Z_BIT2l, Z_BIT2z, Z_BIT2a
EXTERN  Z_BIT3b, Z_BIT3c, Z_BIT3d, Z_BIT3e
EXTERN  Z_BIT3h, Z_BIT3l, Z_BIT3z, Z_BIT3a
EXTERN  Z_BIT4b, Z_BIT4c, Z_BIT4d, Z_BIT4e
EXTERN  Z_BIT4h, Z_BIT4l, Z_BIT4z, Z_BIT4a
EXTERN  Z_BIT5b, Z_BIT5c, Z_BIT5d, Z_BIT5e
EXTERN  Z_BIT5h, Z_BIT5l, Z_BIT5z, Z_BIT5a
EXTERN  Z_BIT6b, Z_BIT6c, Z_BIT6d, Z_BIT6e
EXTERN  Z_BIT6h, Z_BIT6l, Z_BIT6z, Z_BIT6a
EXTERN  Z_BIT7b, Z_BIT7c, Z_BIT7d, Z_BIT7e
EXTERN  Z_BIT7h, Z_BIT7l, Z_BIT7z, Z_BIT7a
EXTERN  Z_RES0b, Z_RES0c, Z_RES0d, Z_RES0e
EXTERN  Z_RES0h, Z_RES0l, Z_RES0z, Z_RES0a
EXTERN  Z_RES1b, Z_RES1c, Z_RES1d, Z_RES1e
EXTERN  Z_RES1h, Z_RES1l, Z_RES1z, Z_RES1a
EXTERN  Z_RES2b, Z_RES2c, Z_RES2d, Z_RES2e
EXTERN  Z_RES2h, Z_RES2l, Z_RES2z, Z_RES2a
EXTERN  Z_RES3b, Z_RES3c, Z_RES3d, Z_RES3e
EXTERN  Z_RES3h, Z_RES3l, Z_RES3z, Z_RES3a
EXTERN  Z_RES4b, Z_RES4c, Z_RES4d, Z_RES4e
EXTERN  Z_RES4h, Z_RES4l, Z_RES4z, Z_RES4a
EXTERN  Z_RES5b, Z_RES5c, Z_RES5d, Z_RES5e
EXTERN  Z_RES5h, Z_RES5l, Z_RES5z, Z_RES5a
EXTERN  Z_RES6b, Z_RES6c, Z_RES6d, Z_RES6e
EXTERN  Z_RES6h, Z_RES6l, Z_RES6z, Z_RES6a
EXTERN  Z_RES7b, Z_RES7c, Z_RES7d, Z_RES7e
EXTERN  Z_RES7h, Z_RES7l, Z_RES7z, Z_RES7a
EXTERN  Z_SET0b, Z_SET0c, Z_SET0d, Z_SET0e
EXTERN  Z_SET0h, Z_SET0l, Z_SET0z, Z_SET0a
EXTERN  Z_SET1b, Z_SET1c, Z_SET1d, Z_SET1e
EXTERN  Z_SET1h, Z_SET1l, Z_SET1z, Z_SET1a
EXTERN  Z_SET2b, Z_SET2c, Z_SET2d, Z_SET2e
EXTERN  Z_SET2h, Z_SET2l, Z_SET2z, Z_SET2a
EXTERN  Z_SET3b, Z_SET3c, Z_SET3d, Z_SET3e
EXTERN  Z_SET3h, Z_SET3l, Z_SET3z, Z_SET3a
EXTERN  Z_SET4b, Z_SET4c, Z_SET4d, Z_SET4e
EXTERN  Z_SET4h, Z_SET4l, Z_SET4z, Z_SET4a
EXTERN  Z_SET5b, Z_SET5c, Z_SET5d, Z_SET5e
EXTERN  Z_SET5h, Z_SET5l, Z_SET5z, Z_SET5a
EXTERN  Z_SET6b, Z_SET6c, Z_SET6d, Z_SET6e
EXTERN  Z_SET6h, Z_SET6l, Z_SET6z, Z_SET6a
EXTERN  Z_SET7b, Z_SET7c, Z_SET7d, Z_SET7e
EXTERN  Z_SET7h, Z_SET7l, Z_SET7z, Z_SET7a

;1st opcode
EXTERN  Z_NOP,   Z_LDbcn, Z_LDbca, Z_INCbc
EXTERN  Z_INCb,  Z_DECb,  Z_LDbn,  Z_RLCA
EXTERN  Z_EXafaf,Z_ADhlbc,Z_LDabc, Z_DECbc
EXTERN  Z_INCc,  Z_DECc,  Z_LDcn,  Z_RRCA
EXTERN  Z_DJNZ,  Z_LDden, Z_LDdea, Z_INCde
EXTERN  Z_INCd,  Z_DECd,  Z_LDdn,  Z_RLA
EXTERN  Z_JR,    Z_ADhlde,Z_LDade, Z_DECde
EXTERN  Z_INCe,  Z_DECe,  Z_LDen,  Z_RRA
EXTERN  Z_JRNZ,  Z_LDhln, Z_LDmhl, Z_INChl
EXTERN  Z_INCh,  Z_DECh,  Z_LDhn,  Z_DAA
EXTERN  Z_JRZ,   Z_ADhlhl,Z_LDhlm, Z_DEChl
EXTERN  Z_INCl,  Z_DECl,  Z_LDln,  Z_CPL
EXTERN  Z_JRNC,  Z_LDspn, Z_LDma,  Z_INCsp
EXTERN  Z_INCz,  Z_DECz,  Z_LDzn,  Z_SCF
EXTERN  Z_JRC,   Z_ADhlsp,Z_LDam,  Z_DECsp
EXTERN  Z_INCa,  Z_DECa,  Z_LDan,  Z_CCF
EXTERN  Z_LDbb,  Z_LDbc,  Z_LDbd,  Z_LDbe
EXTERN  Z_LDbh,  Z_LDbl,  Z_LDbz,  Z_LDba
EXTERN  Z_LDcb,  Z_LDcc,  Z_LDcd,  Z_LDce
EXTERN  Z_LDch,  Z_LDcl,  Z_LDcz,  Z_LDca
EXTERN  Z_LDdb,  Z_LDdc,  Z_LDdd,  Z_LDde
EXTERN  Z_LDdh,  Z_LDdl,  Z_LDdz,  Z_LDda
EXTERN  Z_LDeb,  Z_LDec,  Z_LDed,  Z_LDee
EXTERN  Z_LDeh,  Z_LDel,  Z_LDez,  Z_LDea
EXTERN  Z_LDhb,  Z_LDhc,  Z_LDhd,  Z_LDhe
EXTERN  Z_LDhh,  Z_LDhl,  Z_LDhz,  Z_LDha
EXTERN  Z_LDlb,  Z_LDlc,  Z_LDld,  Z_LDle
EXTERN  Z_LDlh,  Z_LDll,  Z_LDlz,  Z_LDla
EXTERN  Z_LDzb,  Z_LDzc,  Z_LDzd,  Z_LDze
EXTERN  Z_LDzh,  Z_LDzl,  Z_HALT,  Z_LDza
EXTERN  Z_LDab,  Z_LDac,  Z_LDad,  Z_LDae
EXTERN  Z_LDah,  Z_LDal,  Z_LDaz,  Z_LDaa
EXTERN  Z_ADDb,  Z_ADDc,  Z_ADDd,  Z_ADDe
EXTERN  Z_ADDh,  Z_ADDl,  Z_ADDz,  Z_ADDa
EXTERN  Z_ADCb,  Z_ADCc,  Z_ADCd,  Z_ADCe
EXTERN  Z_ADCh,  Z_ADCl,  Z_ADCz,  Z_ADCa
EXTERN  Z_SUBb,  Z_SUBc,  Z_SUBd,  Z_SUBe
EXTERN  Z_SUBh,  Z_SUBl,  Z_SUBz,  Z_SUBa
EXTERN  Z_SBCb,  Z_SBCc,  Z_SBCd,  Z_SBCe
EXTERN  Z_SBCh,  Z_SBCl,  Z_SBCz,  Z_SBCa
EXTERN  Z_ANDb,  Z_ANDc,  Z_ANDd,  Z_ANDe
EXTERN  Z_ANDh,  Z_ANDl,  Z_ANDz,  Z_ANDa
EXTERN  Z_XORb,  Z_XORc,  Z_XORd,  Z_XORe
EXTERN  Z_XORh,  Z_XORl,  Z_XORz,  Z_XORa
EXTERN  Z_ORb,   Z_ORc,   Z_ORd,   Z_ORe
EXTERN  Z_ORh,   Z_ORl,   Z_ORz,   Z_ORa
EXTERN  Z_CPb,   Z_CPc,   Z_CPd,   Z_CPe
EXTERN  Z_CPh,   Z_CPl,   Z_CPz,   Z_CPa
EXTERN  Z_RETNZ, Z_POPbc, Z_JPNZ,  Z_JP
EXTERN  Z_CALLNZ,Z_PUSHbc,Z_ADDn,  Z_RST0
EXTERN  Z_RETZ,  Z_RET,   Z_JPZ,   CBops
EXTERN  Z_CALLZ, Z_CALL,  Z_ADCn,  Z_RST1
EXTERN  Z_RETNC, Z_POPde, Z_JPNC,  Z_8086
EXTERN  Z_CALLNC,Z_PUSHde,Z_SUBn,  Z_RST2
EXTERN  Z_RETC,  Z_EXX,   Z_JPC,   Z_INan
EXTERN  Z_CALLC, IXops,   Z_SBCn,  Z_RST3
EXTERN  Z_RETPO, Z_POPhl, Z_JPPO,  Z_EXsphl
EXTERN  Z_CALLPO,Z_PUSHhl,Z_ANDn,  Z_RST4
EXTERN  Z_RETPE, Z_JPhl,  Z_JPPE,  Z_EXdehl
EXTERN  Z_CALLPE,EDops,   Z_XORn,  Z_RST5
EXTERN  Z_RETP,  Z_POPaf, Z_JPP,   Z_DI
EXTERN  Z_CALLP, Z_PUSHaf,Z_ORn,   Z_RST6
EXTERN  Z_RETM,  Z_LDsphl,Z_JPM,   Z_EI
EXTERN  Z_CALLM, IYops,   Z_CPn,   Z_RST7

;                  8086 high level interface functions
T7  dw  kbd1in,  kbd1st,  kbd1ip,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  kbd2in,  kbd2st,  kbd2ip,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  crt1in,  crt1st,  crt1op,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  crt2in,  crt2st,  crt2op,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  lptini,  lptsta,  lptout,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  comini,  comist,  cominp,  comost,  comout,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  gettme,  settme,  getdte,  setdte,  fnc___,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  rdflop,  wrflop,  rdhard,  wrhard,  GtBoot,  GtHard,  p88wbt,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  blkcnt,  blkget,  blkput,  blkfil,  fnc___,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  GtZseg,  intfnc,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  GetByt,  SetByt,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  pc88on,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___,  fnc___
    dw  bnkuse,  bnksel,  bnkmve,  bnkdta,  bnkdma,  fnc___,  fnc___,  fnc___
    dw  prmsta,  prmget,  vidsta,  vidset,  usrbyt,  failed,  rstz80,  extemu
   
;                          $CB opcodes for IX
;
T6  dw  Z_RLCwb, Z_RLCwc, Z_RLCwd, Z_RLCwe, Z_RLCwh, Z_RLCwl, Z_RLCw,  Z_RLCwa
    dw  Z_RRCwb, Z_RRCwc, Z_RRCwd, Z_RRCwe, Z_RRCwh, Z_RRCwl, Z_RRCw,  Z_RRCwa
    dw  Z_RLwb,  Z_RLwc,  Z_RLwd,  Z_RLwe,  Z_RLwh,  Z_RLwl,  Z_RLw,   Z_RLwa
    dw  Z_RRwb,  Z_RRwc,  Z_RRwd,  Z_RRwe,  Z_RRwh,  Z_RRwl,  Z_RRw,   Z_RRwa
    dw  Z_SLAwb, Z_SLAwc, Z_SLAwd, Z_SLAwe, Z_SLAwh, Z_SLAwl, Z_SLAw,  Z_SLAwa
    dw  Z_SRAwb, Z_SRAwc, Z_SRAwd, Z_SRAwe, Z_SRAwh, Z_SRAwl, Z_SRAw,  Z_SRAwa
    dw  Z_SLLwb, Z_SLLwc, Z_SLLwd, Z_SLLwe, Z_SLLwh, Z_SLLwl, Z_SLLw,  Z_SLLwa
    dw  Z_SRLwb, Z_SRLwc, Z_SRLwd, Z_SRLwe, Z_SRLwh, Z_SRLwl, Z_SRLw,  Z_SRLwa
    dw  Z_BIT0w, Z_BIT0w, Z_BIT0w, Z_BIT0w, Z_BIT0w, Z_BIT0w, Z_BIT0w, Z_BIT0w
    dw  Z_BIT1w, Z_BIT1w, Z_BIT1w, Z_BIT1w, Z_BIT1w, Z_BIT1w, Z_BIT1w, Z_BIT1w
    dw  Z_BIT2w, Z_BIT2w, Z_BIT2w, Z_BIT2w, Z_BIT2w, Z_BIT2w, Z_BIT2w, Z_BIT2w
    dw  Z_BIT3w, Z_BIT3w, Z_BIT3w, Z_BIT3w, Z_BIT3w, Z_BIT3w, Z_BIT3w, Z_BIT3w
    dw  Z_BIT4w, Z_BIT4w, Z_BIT4w, Z_BIT4w, Z_BIT4w, Z_BIT4w, Z_BIT4w, Z_BIT4w
    dw  Z_BIT5w, Z_BIT5w, Z_BIT5w, Z_BIT5w, Z_BIT5w, Z_BIT5w, Z_BIT5w, Z_BIT5w
    dw  Z_BIT6w, Z_BIT6w, Z_BIT6w, Z_BIT6w, Z_BIT6w, Z_BIT6w, Z_BIT6w, Z_BIT6w
    dw  Z_BIT7w, Z_BIT7w, Z_BIT7w, Z_BIT7w, Z_BIT7w, Z_BIT7w, Z_BIT7w, Z_BIT7w
    dw  Z_RES0wb,Z_RES0wc,Z_RES0wd,Z_RES0we,Z_RES0wh,Z_RES0wl,Z_RES0w, Z_RES0wa
    dw  Z_RES1wb,Z_RES1wc,Z_RES1wd,Z_RES1we,Z_RES1wh,Z_RES1wl,Z_RES1w, Z_RES1wa
    dw  Z_RES2wb,Z_RES2wc,Z_RES2wd,Z_RES2we,Z_RES2wh,Z_RES2wl,Z_RES2w, Z_RES2wa
    dw  Z_RES3wb,Z_RES3wc,Z_RES3wd,Z_RES3we,Z_RES3wh,Z_RES3wl,Z_RES3w, Z_RES3wa
    dw  Z_RES4wb,Z_RES4wc,Z_RES4wd,Z_RES4we,Z_RES4wh,Z_RES4wl,Z_RES4w, Z_RES4wa
    dw  Z_RES5wb,Z_RES5wc,Z_RES5wd,Z_RES5we,Z_RES5wh,Z_RES5wl,Z_RES5w, Z_RES5wa
    dw  Z_RES6wb,Z_RES6wc,Z_RES6wd,Z_RES6we,Z_RES6wh,Z_RES6wl,Z_RES6w, Z_RES6wa
    dw  Z_RES7wb,Z_RES7wc,Z_RES7wd,Z_RES7we,Z_RES7wh,Z_RES7wl,Z_RES7w, Z_RES7wa
    dw  Z_SET0wb,Z_SET0wc,Z_SET0wd,Z_SET0we,Z_SET0wh,Z_SET0wl,Z_SET0w, Z_SET0wa
    dw  Z_SET1wb,Z_SET1wc,Z_SET1wd,Z_SET1we,Z_SET1wh,Z_SET1wl,Z_SET1w, Z_SET1wa
    dw  Z_SET2wb,Z_SET2wc,Z_SET2wd,Z_SET2we,Z_SET2wh,Z_SET2wl,Z_SET2w, Z_SET2wa
    dw  Z_SET3wb,Z_SET3wc,Z_SET3wd,Z_SET3we,Z_SET3wh,Z_SET3wl,Z_SET3w, Z_SET3wa
    dw  Z_SET4wb,Z_SET4wc,Z_SET4wd,Z_SET4we,Z_SET4wh,Z_SET4wl,Z_SET4w, Z_SET4wa
    dw  Z_SET5wb,Z_SET5wc,Z_SET5wd,Z_SET5we,Z_SET5wh,Z_SET5wl,Z_SET5w, Z_SET5wa
    dw  Z_SET6wb,Z_SET6wc,Z_SET6wd,Z_SET6we,Z_SET6wh,Z_SET6wl,Z_SET6w, Z_SET6wa
    dw  Z_SET7wb,Z_SET7wc,Z_SET7wd,Z_SET7we,Z_SET7wh,Z_SET7wl,Z_SET7w, Z_SET7wa

;                          $CB opcodes for IY
;
T5  dw  Z_RLCwb, Z_RLCwc, Z_RLCwd, Z_RLCwe, Z_RLCwh, Z_RLCwl, Z_RLCv,  Z_RLCwa
    dw  Z_RRCwb, Z_RRCwc, Z_RRCwd, Z_RRCwe, Z_RRCwh, Z_RRCwl, Z_RRCv,  Z_RRCwa
    dw  Z_RLwb,  Z_RLwc,  Z_RLwd,  Z_RLwe,  Z_RLwh,  Z_RLwl,  Z_RLv,   Z_RLwa
    dw  Z_RRwb,  Z_RRwc,  Z_RRwd,  Z_RRwe,  Z_RRwh,  Z_RRwl,  Z_RRv,   Z_RRwa
    dw  Z_SLAwb, Z_SLAwc, Z_SLAwd, Z_SLAwe, Z_SLAwh, Z_SLAwl, Z_SLAv,  Z_SLAwa
    dw  Z_SRAwb, Z_SRAwc, Z_SRAwd, Z_SRAwe, Z_SRAwh, Z_SRAwl, Z_SRAv,  Z_SRAwa
    dw  Z_SLLwb, Z_SLLwc, Z_SLLwd, Z_SLLwe, Z_SLLwh, Z_SLLwl, Z_SLLw,  Z_SLLwa
    dw  Z_SRLwb, Z_SRLwc, Z_SRLwd, Z_SRLwe, Z_SRLwh, Z_SRLwl, Z_SRLv,  Z_SRLwa
    dw  Z_BIT0v, Z_BIT0v, Z_BIT0v, Z_BIT0v, Z_BIT0v, Z_BIT0v, Z_BIT0v, Z_BIT0v
    dw  Z_BIT1v, Z_BIT1v, Z_BIT1v, Z_BIT1v, Z_BIT1v, Z_BIT1v, Z_BIT1v, Z_BIT1v
    dw  Z_BIT2v, Z_BIT2v, Z_BIT2v, Z_BIT2v, Z_BIT2v, Z_BIT2v, Z_BIT2v, Z_BIT2v
    dw  Z_BIT3v, Z_BIT3v, Z_BIT3v, Z_BIT3v, Z_BIT3v, Z_BIT3v, Z_BIT3v, Z_BIT3v
    dw  Z_BIT4v, Z_BIT4v, Z_BIT4v, Z_BIT4v, Z_BIT4v, Z_BIT4v, Z_BIT4v, Z_BIT4v
    dw  Z_BIT5v, Z_BIT5v, Z_BIT5v, Z_BIT5v, Z_BIT5v, Z_BIT5v, Z_BIT5v, Z_BIT5v
    dw  Z_BIT6v, Z_BIT6v, Z_BIT6v, Z_BIT6v, Z_BIT6v, Z_BIT6v, Z_BIT6v, Z_BIT6v
    dw  Z_BIT7v, Z_BIT7v, Z_BIT7v, Z_BIT7v, Z_BIT7v, Z_BIT7v, Z_BIT7v, Z_BIT7v
    dw  Z_RES0wb,Z_RES0wc,Z_RES0wd,Z_RES0we,Z_RES0wh,Z_RES0wl,Z_RES0v, Z_RES0wa
    dw  Z_RES1wb,Z_RES1wc,Z_RES1wd,Z_RES1we,Z_RES1wh,Z_RES1wl,Z_RES1v, Z_RES1wa
    dw  Z_RES2wb,Z_RES2wc,Z_RES2wd,Z_RES2we,Z_RES2wh,Z_RES2wl,Z_RES2v, Z_RES2wa
    dw  Z_RES3wb,Z_RES3wc,Z_RES3wd,Z_RES3we,Z_RES3wh,Z_RES3wl,Z_RES3v, Z_RES3wa
    dw  Z_RES4wb,Z_RES4wc,Z_RES4wd,Z_RES4we,Z_RES4wh,Z_RES4wl,Z_RES4v, Z_RES4wa
    dw  Z_RES5wb,Z_RES5wc,Z_RES5wd,Z_RES5we,Z_RES5wh,Z_RES5wl,Z_RES5v, Z_RES5wa
    dw  Z_RES6wb,Z_RES6wc,Z_RES6wd,Z_RES6we,Z_RES6wh,Z_RES6wl,Z_RES6v, Z_RES6wa
    dw  Z_RES7wb,Z_RES7wc,Z_RES7wd,Z_RES7we,Z_RES7wh,Z_RES7wl,Z_RES7v, Z_RES7wa
    dw  Z_SET0wb,Z_SET0wc,Z_SET0wd,Z_SET0we,Z_SET0wh,Z_SET0wl,Z_SET0v, Z_SET0wa
    dw  Z_SET1wb,Z_SET1wc,Z_SET1wd,Z_SET1we,Z_SET1wh,Z_SET1wl,Z_SET1v, Z_SET1wa
    dw  Z_SET2wb,Z_SET2wc,Z_SET2wd,Z_SET2we,Z_SET2wh,Z_SET2wl,Z_SET2v, Z_SET2wa
    dw  Z_SET3wb,Z_SET3wc,Z_SET3wd,Z_SET3we,Z_SET3wh,Z_SET3wl,Z_SET3v, Z_SET3wa
    dw  Z_SET4wb,Z_SET4wc,Z_SET4wd,Z_SET4we,Z_SET4wh,Z_SET4wl,Z_SET4v, Z_SET4wa
    dw  Z_SET5wb,Z_SET5wc,Z_SET5wd,Z_SET5we,Z_SET5wh,Z_SET5wl,Z_SET5v, Z_SET5wa
    dw  Z_SET6wb,Z_SET6wc,Z_SET6wd,Z_SET6we,Z_SET6wh,Z_SET6wl,Z_SET6v, Z_SET6wa
    dw  Z_SET7wb,Z_SET7wc,Z_SET7wd,Z_SET7we,Z_SET7wh,Z_SET7wl,Z_SET7v, Z_SET7wa

;                            1st opcode for IX
;
T4  dw  Z_NOP,   Z_LDbcn, Z_LDbca, Z_INCbc, Z_INCb,  Z_DECb,  Z_LDbn,  Z_RLCA
    dw  Z_EXafaf,Z_ADxbc, Z_LDabc, Z_DECbc, Z_INCc,  Z_DECc,  Z_LDcn,  Z_RRCA
    dw  Z_DJNZ,  Z_LDden, Z_LDdea, Z_INCde, Z_INCd,  Z_DECd,  Z_LDdn,  Z_RLA
    dw  Z_JR,    Z_ADxde, Z_LDade, Z_DECde, Z_INCe,  Z_DECe,  Z_LDen,  Z_RRA
    dw  Z_JRNZ,  Z_LDxn,  Z_LDmx,  Z_INCx,  Z_INCxh, Z_DECxh, Z_LDxhn, Z_DAA
    dw  Z_JRZ,   Z_ADxx,  Z_LDxm,  Z_DECx,  Z_INCxl, Z_DECxl, Z_LDxln, Z_CPL
    dw  Z_JRNC,  Z_LDspn, Z_LDma,  Z_INCsp, Z_INCw,  Z_DECw,  Z_LDwn,  Z_SCF
    dw  Z_JRC,   Z_ADxsp, Z_LDam,  Z_DECsp, Z_INCa,  Z_DECa,  Z_LDan,  Z_CCF
    dw  Z_LDbb,  Z_LDbc,  Z_LDbd,  Z_LDbe,  Z_LDbxh, Z_LDbxl, Z_LDbw,  Z_LDba
    dw  Z_LDcb,  Z_LDcc,  Z_LDcd,  Z_LDce,  Z_LDcxh, Z_LDcxl, Z_LDcw,  Z_LDca
    dw  Z_LDdb,  Z_LDdc,  Z_LDdd,  Z_LDde,  Z_LDdxh, Z_LDdxl, Z_LDdw,  Z_LDda
    dw  Z_LDeb,  Z_LDec,  Z_LDed,  Z_LDee,  Z_LDexh, Z_LDexl, Z_LDew,  Z_LDea
    dw  Z_LDxhb, Z_LDxhc, Z_LDxhd, Z_LDxhe, Z_NOP,   Z_LDxhxl,Z_LDhw,  Z_LDxha
    dw  Z_LDxlb, Z_LDxlc, Z_LDxld, Z_LDxle, Z_LDxlxh,Z_NOP,   Z_LDlw,  Z_LDxla
    dw  Z_LDwb,  Z_LDwc,  Z_LDwd,  Z_LDwe,  Z_LDwh,  Z_LDwl,  Z_HALT,  Z_LDwa
    dw  Z_LDab,  Z_LDac,  Z_LDad,  Z_LDae,  Z_LDaxh, Z_LDaxl, Z_LDaw,  Z_LDaa
    dw  Z_ADDb,  Z_ADDc,  Z_ADDd,  Z_ADDe,  Z_ADDxh, Z_ADDxl, Z_ADDw,  Z_ADDa
    dw  Z_ADCb,  Z_ADCc,  Z_ADCd,  Z_ADCe,  Z_ADCxh, Z_ADCxl, Z_ADCw,  Z_ADCa
    dw  Z_SUBb,  Z_SUBc,  Z_SUBd,  Z_SUBe,  Z_SUBxh, Z_SUBxl, Z_SUBw,  Z_SUBa
    dw  Z_SBCb,  Z_SBCc,  Z_SBCd,  Z_SBCe,  Z_SBCxh, Z_SBCxl, Z_SBCw,  Z_SBCa
    dw  Z_ANDb,  Z_ANDc,  Z_ANDd,  Z_ANDe,  Z_ANDxh, Z_ANDxl, Z_ANDw,  Z_ANDa
    dw  Z_XORb,  Z_XORc,  Z_XORd,  Z_XORe,  Z_XORxh, Z_XORxl, Z_XORw,  Z_XORa
    dw  Z_ORb,   Z_ORc,   Z_ORd,   Z_ORe,   Z_ORxh,  Z_ORxl,  Z_ORw,   Z_ORa
    dw  Z_CPb,   Z_CPc,   Z_CPd,   Z_CPe,   Z_CPxh,  Z_CPxl,  Z_CPw,   Z_CPa
    dw  Z_RETNZ, Z_POPbc, Z_JPNZ,  Z_JP,    Z_CALLNZ,Z_PUSHbc,Z_ADDn,  Z_RST0
    dw  Z_RETZ,  Z_RET,   Z_JPZ,   CBxops,  Z_CALLZ, Z_CALL,  Z_ADCn,  Z_RST1
    dw  Z_RETNC, Z_POPde, Z_JPNC,  Z_8086,  Z_CALLNC,Z_PUSHde,Z_SUBn,  Z_RST2
    dw  Z_RETC,  Z_EXX,   Z_JPC,   Z_INan,  Z_CALLC, IXops,   Z_SBCn,  Z_RST3
    dw  Z_RETPO, Z_POPx,  Z_JPPO,  Z_EXspx, Z_CALLPO,Z_PUSHx, Z_ANDn,  Z_RST4
    dw  Z_RETPE, Z_JPx,   Z_JPPE,  Z_EXdehl,Z_CALLPE,EDops,   Z_XORn,  Z_RST5
    dw  Z_RETP,  Z_POPaf, Z_JPP,   Z_DI,    Z_CALLP, Z_PUSHaf,Z_ORn,   Z_RST6
    dw  Z_RETM,  Z_LDspx, Z_JPM,   Z_EI,    Z_CALLM, IYops,   Z_CPn,   Z_RST7

;                            1st opcode for IY
;
T3  dw  Z_NOP,   Z_LDbcn, Z_LDbca, Z_INCbc, Z_INCb,  Z_DECb,  Z_LDbn,  Z_RLCA
    dw  Z_EXafaf,Z_ADybc, Z_LDabc, Z_DECbc, Z_INCc,  Z_DECc,  Z_LDcn,  Z_RRCA
    dw  Z_DJNZ,  Z_LDden, Z_LDdea, Z_INCde, Z_INCd,  Z_DECd,  Z_LDdn,  Z_RLA
    dw  Z_JR,    Z_ADyde, Z_LDade, Z_DECde, Z_INCe,  Z_DECe,  Z_LDen,  Z_RRA
    dw  Z_JRNZ,  Z_LDyn,  Z_LDmy,  Z_INCy,  Z_INCyh, Z_DECyh, Z_LDyhn, Z_DAA
    dw  Z_JRZ,   Z_ADyy,  Z_LDym,  Z_DECy,  Z_INCyl, Z_DECyl, Z_LDyln, Z_CPL
    dw  Z_JRNC,  Z_LDspn, Z_LDma,  Z_INCsp, Z_INCv,  Z_DECv,  Z_LDvn,  Z_SCF
    dw  Z_JRC,   Z_ADysp, Z_LDam,  Z_DECsp, Z_INCa,  Z_DECa,  Z_LDan,  Z_CCF
    dw  Z_LDbb,  Z_LDbc,  Z_LDbd,  Z_LDbe,  Z_LDbyh, Z_LDbyl, Z_LDbv,  Z_LDba
    dw  Z_LDcb,  Z_LDcc,  Z_LDcd,  Z_LDce,  Z_LDcyh, Z_LDcyl, Z_LDcv,  Z_LDca
    dw  Z_LDdb,  Z_LDdc,  Z_LDdd,  Z_LDde,  Z_LDdyh, Z_LDdyl, Z_LDdv,  Z_LDda
    dw  Z_LDeb,  Z_LDec,  Z_LDed,  Z_LDee,  Z_LDeyh, Z_LDeyl, Z_LDev,  Z_LDea
    dw  Z_LDyhb, Z_LDyhc, Z_LDyhd, Z_LDyhe, Z_NOP,   Z_LDyhyl,Z_LDhv,  Z_LDyha
    dw  Z_LDylb, Z_LDylc, Z_LDyld, Z_LDyle, Z_LDylyh,Z_NOP,   Z_LDlv,  Z_LDyla
    dw  Z_LDvb,  Z_LDvc,  Z_LDvd,  Z_LDve,  Z_LDvh,  Z_LDvl,  Z_HALT,  Z_LDva
    dw  Z_LDab,  Z_LDac,  Z_LDad,  Z_LDae,  Z_LDayh, Z_LDayl, Z_LDav,  Z_LDaa
    dw  Z_ADDb,  Z_ADDc,  Z_ADDd,  Z_ADDe,  Z_ADDyh, Z_ADDyl, Z_ADDv,  Z_ADDa
    dw  Z_ADCb,  Z_ADCc,  Z_ADCd,  Z_ADCe,  Z_ADCyh, Z_ADCyl, Z_ADCv,  Z_ADCa
    dw  Z_SUBb,  Z_SUBc,  Z_SUBd,  Z_SUBe,  Z_SUByh, Z_SUByl, Z_SUBv,  Z_SUBa
    dw  Z_SBCb,  Z_SBCc,  Z_SBCd,  Z_SBCe,  Z_SBCyh, Z_SBCyl, Z_SBCv,  Z_SBCa
    dw  Z_ANDb,  Z_ANDc,  Z_ANDd,  Z_ANDe,  Z_ANDyh, Z_ANDyl, Z_ANDv,  Z_ANDa
    dw  Z_XORb,  Z_XORc,  Z_XORd,  Z_XORe,  Z_XORyh, Z_XORyl, Z_XORv,  Z_XORa
    dw  Z_ORb,   Z_ORc,   Z_ORd,   Z_ORe,   Z_ORyh,  Z_ORyl,  Z_ORv,   Z_ORa
    dw  Z_CPb,   Z_CPc,   Z_CPd,   Z_CPe,   Z_CPyh,  Z_CPyl,  Z_CPv,   Z_CPa
    dw  Z_RETNZ, Z_POPbc, Z_JPNZ,  Z_JP,    Z_CALLNZ,Z_PUSHbc,Z_ADDn,  Z_RST0
    dw  Z_RETZ,  Z_RET,   Z_JPZ,   CByops,  Z_CALLZ, Z_CALL,  Z_ADCn,  Z_RST1
    dw  Z_RETNC, Z_POPde, Z_JPNC,  Z_8086,  Z_CALLNC,Z_PUSHde,Z_SUBn,  Z_RST2
    dw  Z_RETC,  Z_EXX,   Z_JPC,   Z_INan,  Z_CALLC, IXops,   Z_SBCn,  Z_RST3
    dw  Z_RETPO, Z_POPy,  Z_JPPO,  Z_EXspy, Z_CALLPO,Z_PUSHy, Z_ANDn,  Z_RST4
    dw  Z_RETPE, Z_JPy,   Z_JPPE,  Z_EXdehl,Z_CALLPE,EDops,   Z_XORn,  Z_RST5
    dw  Z_RETP,  Z_POPaf, Z_JPP,   Z_DI,    Z_CALLP, Z_PUSHaf,Z_ORn,   Z_RST6
    dw  Z_RETM,  Z_LDspy, Z_JPM,   Z_EI,    Z_CALLM, IYops,   Z_CPn,   Z_RST7

;                             $ED Opcode Table
;
T2  dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_INbc,  Z_OUTcb, Z_SChlbc,Z_LDmbc, Z_NEG,   Z_RETN,  Z_IM0,   Z_LDia
    dw  Z_INcc,  Z_OUTcc, Z_AChlbc,Z_LDbcm, Z_NEG,   Z_RETI,  Z_IM0,   Z_LDra
    dw  Z_INdc,  Z_OUTcd, Z_SChlde,Z_LDmde, Z_NEG,   Z_RETN,  Z_IM1,   Z_LDai
    dw  Z_INec,  Z_OUTce, Z_AChlde,Z_LDdem, Z_NEG,   Z_RETI,  Z_IM2,   Z_LDar
    dw  Z_INhc,  Z_OUTch, Z_SChlhl,Z_LDmhl, Z_NEG,   Z_RETN,  Z_IM0,   Z_RRD
    dw  Z_INlc,  Z_OUTcl, Z_AChlhl,Z_LDhlm, Z_NEG,   Z_RETI,  Z_IM0,   Z_RLD
    dw  Z_INfc,  Z_OUTc0, Z_SChlsp,Z_LDmsp, Z_NEG,   Z_RETN,  Z_IM1,   Z_NOP
    dw  Z_INac,  Z_OUTca, Z_AChlsp,Z_LDspm, Z_NEG,   Z_RETI,  Z_IM2,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_LDI,   Z_CPI,   Z_INI,   Z_OUTI,  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_LDD,   Z_CPD,   Z_IND,   Z_OUTD,  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_LDIR,  Z_CPIR,  Z_INIR,  Z_OTIR,  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_LDDR,  Z_CPDR,  Z_INDR,  Z_OTDR,  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP
    dw  Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP,   Z_NOP

;                           $CB opcode table
;
T1  dw  Z_RLCb,  Z_RLCc,  Z_RLCd,  Z_RLCe,  Z_RLCh,  Z_RLCl,  Z_RLCz,  Z_RLCa
    dw  Z_RRCb,  Z_RRCc,  Z_RRCd,  Z_RRCe,  Z_RRCh,  Z_RRCl,  Z_RRCz,  Z_RRCa
    dw  Z_RLb,   Z_RLc,   Z_RLd,   Z_RLe,   Z_RLh,   Z_RLl,   Z_RLz,   Z_RLa
    dw  Z_RRb,   Z_RRc,   Z_RRd,   Z_RRe,   Z_RRh,   Z_RRl,   Z_RRz,   Z_RRa
    dw  Z_SLAb,  Z_SLAc,  Z_SLAd,  Z_SLAe,  Z_SLAh,  Z_SLAl,  Z_SLAz,  Z_SLAa
    dw  Z_SRAb,  Z_SRAc,  Z_SRAd,  Z_SRAe,  Z_SRAh,  Z_SRAl,  Z_SRAz,  Z_SRAa
    dw  Z_SLLb,  Z_SLLc,  Z_SLLd,  Z_SLLe,  Z_SLLh,  Z_SLLl,  Z_SLLz,  Z_SLLa
    dw  Z_SRLb,  Z_SRLc,  Z_SRLd,  Z_SRLe,  Z_SRLh,  Z_SRLl,  Z_SRLz,  Z_SRLa
    dw  Z_BIT0b, Z_BIT0c, Z_BIT0d, Z_BIT0e, Z_BIT0h, Z_BIT0l, Z_BIT0z, Z_BIT0a
    dw  Z_BIT1b, Z_BIT1c, Z_BIT1d, Z_BIT1e, Z_BIT1h, Z_BIT1l, Z_BIT1z, Z_BIT1a
    dw  Z_BIT2b, Z_BIT2c, Z_BIT2d, Z_BIT2e, Z_BIT2h, Z_BIT2l, Z_BIT2z, Z_BIT2a
    dw  Z_BIT3b, Z_BIT3c, Z_BIT3d, Z_BIT3e, Z_BIT3h, Z_BIT3l, Z_BIT3z, Z_BIT3a
    dw  Z_BIT4b, Z_BIT4c, Z_BIT4d, Z_BIT4e, Z_BIT4h, Z_BIT4l, Z_BIT4z, Z_BIT4a
    dw  Z_BIT5b, Z_BIT5c, Z_BIT5d, Z_BIT5e, Z_BIT5h, Z_BIT5l, Z_BIT5z, Z_BIT5a
    dw  Z_BIT6b, Z_BIT6c, Z_BIT6d, Z_BIT6e, Z_BIT6h, Z_BIT6l, Z_BIT6z, Z_BIT6a
    dw  Z_BIT7b, Z_BIT7c, Z_BIT7d, Z_BIT7e, Z_BIT7h, Z_BIT7l, Z_BIT7z, Z_BIT7a
    dw  Z_RES0b, Z_RES0c, Z_RES0d, Z_RES0e, Z_RES0h, Z_RES0l, Z_RES0z, Z_RES0a
    dw  Z_RES1b, Z_RES1c, Z_RES1d, Z_RES1e, Z_RES1h, Z_RES1l, Z_RES1z, Z_RES1a
    dw  Z_RES2b, Z_RES2c, Z_RES2d, Z_RES2e, Z_RES2h, Z_RES2l, Z_RES2z, Z_RES2a
    dw  Z_RES3b, Z_RES3c, Z_RES3d, Z_RES3e, Z_RES3h, Z_RES3l, Z_RES3z, Z_RES3a
    dw  Z_RES4b, Z_RES4c, Z_RES4d, Z_RES4e, Z_RES4h, Z_RES4l, Z_RES4z, Z_RES4a
    dw  Z_RES5b, Z_RES5c, Z_RES5d, Z_RES5e, Z_RES5h, Z_RES5l, Z_RES5z, Z_RES5a
    dw  Z_RES6b, Z_RES6c, Z_RES6d, Z_RES6e, Z_RES6h, Z_RES6l, Z_RES6z, Z_RES6a
    dw  Z_RES7b, Z_RES7c, Z_RES7d, Z_RES7e, Z_RES7h, Z_RES7l, Z_RES7z, Z_RES7a
    dw  Z_SET0b, Z_SET0c, Z_SET0d, Z_SET0e, Z_SET0h, Z_SET0l, Z_SET0z, Z_SET0a
    dw  Z_SET1b, Z_SET1c, Z_SET1d, Z_SET1e, Z_SET1h, Z_SET1l, Z_SET1z, Z_SET1a
    dw  Z_SET2b, Z_SET2c, Z_SET2d, Z_SET2e, Z_SET2h, Z_SET2l, Z_SET2z, Z_SET2a
    dw  Z_SET3b, Z_SET3c, Z_SET3d, Z_SET3e, Z_SET3h, Z_SET3l, Z_SET3z, Z_SET3a
    dw  Z_SET4b, Z_SET4c, Z_SET4d, Z_SET4e, Z_SET4h, Z_SET4l, Z_SET4z, Z_SET4a
    dw  Z_SET5b, Z_SET5c, Z_SET5d, Z_SET5e, Z_SET5h, Z_SET5l, Z_SET5z, Z_SET5a
    dw  Z_SET6b, Z_SET6c, Z_SET6d, Z_SET6e, Z_SET6h, Z_SET6l, Z_SET6z, Z_SET6a
    dw  Z_SET7b, Z_SET7c, Z_SET7d, Z_SET7e, Z_SET7h, Z_SET7l, Z_SET7z, Z_SET7a

;                              1st opcode
;
T0  dw  Z_NOP,   Z_LDbcn, Z_LDbca, Z_INCbc, Z_INCb,  Z_DECb,  Z_LDbn,  Z_RLCA
    dw  Z_EXafaf,Z_ADhlbc,Z_LDabc, Z_DECbc, Z_INCc,  Z_DECc,  Z_LDcn,  Z_RRCA
    dw  Z_DJNZ,  Z_LDden, Z_LDdea, Z_INCde, Z_INCd,  Z_DECd,  Z_LDdn,  Z_RLA
    dw  Z_JR,    Z_ADhlde,Z_LDade, Z_DECde, Z_INCe,  Z_DECe,  Z_LDen,  Z_RRA
    dw  Z_JRNZ,  Z_LDhln, Z_LDmhl, Z_INChl, Z_INCh,  Z_DECh,  Z_LDhn,  Z_DAA
    dw  Z_JRZ,   Z_ADhlhl,Z_LDhlm, Z_DEChl, Z_INCl,  Z_DECl,  Z_LDln,  Z_CPL
    dw  Z_JRNC,  Z_LDspn, Z_LDma,  Z_INCsp, Z_INCz,  Z_DECz,  Z_LDzn,  Z_SCF
    dw  Z_JRC,   Z_ADhlsp,Z_LDam,  Z_DECsp, Z_INCa,  Z_DECa,  Z_LDan,  Z_CCF
    dw  Z_LDbb,  Z_LDbc,  Z_LDbd,  Z_LDbe,  Z_LDbh,  Z_LDbl,  Z_LDbz,  Z_LDba
    dw  Z_LDcb,  Z_LDcc,  Z_LDcd,  Z_LDce,  Z_LDch,  Z_LDcl,  Z_LDcz,  Z_LDca
    dw  Z_LDdb,  Z_LDdc,  Z_LDdd,  Z_LDde,  Z_LDdh,  Z_LDdl,  Z_LDdz,  Z_LDda
    dw  Z_LDeb,  Z_LDec,  Z_LDed,  Z_LDee,  Z_LDeh,  Z_LDel,  Z_LDez,  Z_LDea
    dw  Z_LDhb,  Z_LDhc,  Z_LDhd,  Z_LDhe,  Z_LDhh,  Z_LDhl,  Z_LDhz,  Z_LDha
    dw  Z_LDlb,  Z_LDlc,  Z_LDld,  Z_LDle,  Z_LDlh,  Z_LDll,  Z_LDlz,  Z_LDla
    dw  Z_LDzb,  Z_LDzc,  Z_LDzd,  Z_LDze,  Z_LDzh,  Z_LDzl,  Z_HALT,  Z_LDza
    dw  Z_LDab,  Z_LDac,  Z_LDad,  Z_LDae,  Z_LDah,  Z_LDal,  Z_LDaz,  Z_LDaa
    dw  Z_ADDb,  Z_ADDc,  Z_ADDd,  Z_ADDe,  Z_ADDh,  Z_ADDl,  Z_ADDz,  Z_ADDa
    dw  Z_ADCb,  Z_ADCc,  Z_ADCd,  Z_ADCe,  Z_ADCh,  Z_ADCl,  Z_ADCz,  Z_ADCa
    dw  Z_SUBb,  Z_SUBc,  Z_SUBd,  Z_SUBe,  Z_SUBh,  Z_SUBl,  Z_SUBz,  Z_SUBa
    dw  Z_SBCb,  Z_SBCc,  Z_SBCd,  Z_SBCe,  Z_SBCh,  Z_SBCl,  Z_SBCz,  Z_SBCa
    dw  Z_ANDb,  Z_ANDc,  Z_ANDd,  Z_ANDe,  Z_ANDh,  Z_ANDl,  Z_ANDz,  Z_ANDa
    dw  Z_XORb,  Z_XORc,  Z_XORd,  Z_XORe,  Z_XORh,  Z_XORl,  Z_XORz,  Z_XORa
    dw  Z_ORb,   Z_ORc,   Z_ORd,   Z_ORe,   Z_ORh,   Z_ORl,   Z_ORz,   Z_ORa
    dw  Z_CPb,   Z_CPc,   Z_CPd,   Z_CPe,   Z_CPh,   Z_CPl,   Z_CPz,   Z_CPa
    dw  Z_RETNZ, Z_POPbc, Z_JPNZ,  Z_JP,    Z_CALLNZ,Z_PUSHbc,Z_ADDn,  Z_RST0
    dw  Z_RETZ,  Z_RET,   Z_JPZ,   CBops,   Z_CALLZ, Z_CALL,  Z_ADCn,  Z_RST1
    dw  Z_RETNC, Z_POPde, Z_JPNC,  Z_8086,  Z_CALLNC,Z_PUSHde,Z_SUBn,  Z_RST2
    dw  Z_RETC,  Z_EXX,   Z_JPC,   Z_INan,  Z_CALLC, IXops,   Z_SBCn,  Z_RST3
    dw  Z_RETPO, Z_POPhl, Z_JPPO,  Z_EXsphl,Z_CALLPO,Z_PUSHhl,Z_ANDn,  Z_RST4
    dw  Z_RETPE, Z_JPhl,  Z_JPPE,  Z_EXdehl,Z_CALLPE,EDops,   Z_XORn,  Z_RST5
    dw  Z_RETP,  Z_POPaf, Z_JPP,   Z_DI,    Z_CALLP, Z_PUSHaf,Z_ORn,   Z_RST6
    dw  Z_RETM,  Z_LDsphl,Z_JPM,   Z_EI,    Z_CALLM, IYops,   Z_CPn,   Z_RST7

;                       1st opcode table, COPY OF T0
;
Tx  dw  Z_NOP,   Z_LDbcn, Z_LDbca, Z_INCbc, Z_INCb,  Z_DECb,  Z_LDbn,  Z_RLCA
    dw  Z_EXafaf,Z_ADhlbc,Z_LDabc, Z_DECbc, Z_INCc,  Z_DECc,  Z_LDcn,  Z_RRCA
    dw  Z_DJNZ,  Z_LDden, Z_LDdea, Z_INCde, Z_INCd,  Z_DECd,  Z_LDdn,  Z_RLA
    dw  Z_JR,    Z_ADhlde,Z_LDade, Z_DECde, Z_INCe,  Z_DECe,  Z_LDen,  Z_RRA
    dw  Z_JRNZ,  Z_LDhln, Z_LDmhl, Z_INChl, Z_INCh,  Z_DECh,  Z_LDhn,  Z_DAA
    dw  Z_JRZ,   Z_ADhlhl,Z_LDhlm, Z_DEChl, Z_INCl,  Z_DECl,  Z_LDln,  Z_CPL
    dw  Z_JRNC,  Z_LDspn, Z_LDma,  Z_INCsp, Z_INCz,  Z_DECz,  Z_LDzn,  Z_SCF
    dw  Z_JRC,   Z_ADhlsp,Z_LDam,  Z_DECsp, Z_INCa,  Z_DECa,  Z_LDan,  Z_CCF
    dw  Z_LDbb,  Z_LDbc,  Z_LDbd,  Z_LDbe,  Z_LDbh,  Z_LDbl,  Z_LDbz,  Z_LDba
    dw  Z_LDcb,  Z_LDcc,  Z_LDcd,  Z_LDce,  Z_LDch,  Z_LDcl,  Z_LDcz,  Z_LDca
    dw  Z_LDdb,  Z_LDdc,  Z_LDdd,  Z_LDde,  Z_LDdh,  Z_LDdl,  Z_LDdz,  Z_LDda
    dw  Z_LDeb,  Z_LDec,  Z_LDed,  Z_LDee,  Z_LDeh,  Z_LDel,  Z_LDez,  Z_LDea
    dw  Z_LDhb,  Z_LDhc,  Z_LDhd,  Z_LDhe,  Z_LDhh,  Z_LDhl,  Z_LDhz,  Z_LDha
    dw  Z_LDlb,  Z_LDlc,  Z_LDld,  Z_LDle,  Z_LDlh,  Z_LDll,  Z_LDlz,  Z_LDla
    dw  Z_LDzb,  Z_LDzc,  Z_LDzd,  Z_LDze,  Z_LDzh,  Z_LDzl,  Z_HALT,  Z_LDza
    dw  Z_LDab,  Z_LDac,  Z_LDad,  Z_LDae,  Z_LDah,  Z_LDal,  Z_LDaz,  Z_LDaa
    dw  Z_ADDb,  Z_ADDc,  Z_ADDd,  Z_ADDe,  Z_ADDh,  Z_ADDl,  Z_ADDz,  Z_ADDa
    dw  Z_ADCb,  Z_ADCc,  Z_ADCd,  Z_ADCe,  Z_ADCh,  Z_ADCl,  Z_ADCz,  Z_ADCa
    dw  Z_SUBb,  Z_SUBc,  Z_SUBd,  Z_SUBe,  Z_SUBh,  Z_SUBl,  Z_SUBz,  Z_SUBa
    dw  Z_SBCb,  Z_SBCc,  Z_SBCd,  Z_SBCe,  Z_SBCh,  Z_SBCl,  Z_SBCz,  Z_SBCa
    dw  Z_ANDb,  Z_ANDc,  Z_ANDd,  Z_ANDe,  Z_ANDh,  Z_ANDl,  Z_ANDz,  Z_ANDa
    dw  Z_XORb,  Z_XORc,  Z_XORd,  Z_XORe,  Z_XORh,  Z_XORl,  Z_XORz,  Z_XORa
    dw  Z_ORb,   Z_ORc,   Z_ORd,   Z_ORe,   Z_ORh,   Z_ORl,   Z_ORz,   Z_ORa
    dw  Z_CPb,   Z_CPc,   Z_CPd,   Z_CPe,   Z_CPh,   Z_CPl,   Z_CPz,   Z_CPa
    dw  Z_RETNZ, Z_POPbc, Z_JPNZ,  Z_JP,    Z_CALLNZ,Z_PUSHbc,Z_ADDn,  Z_RST0
    dw  Z_RETZ,  Z_RET,   Z_JPZ,   CBops,   Z_CALLZ, Z_CALL,  Z_ADCn,  Z_RST1
    dw  Z_RETNC, Z_POPde, Z_JPNC,  Z_8086,  Z_CALLNC,Z_PUSHde,Z_SUBn,  Z_RST2
    dw  Z_RETC,  Z_EXX,   Z_JPC,   Z_INan,  Z_CALLC, IXops,   Z_SBCn,  Z_RST3
    dw  Z_RETPO, Z_POPhl, Z_JPPO,  Z_EXsphl,Z_CALLPO,Z_PUSHhl,Z_ANDn,  Z_RST4
    dw  Z_RETPE, Z_JPhl,  Z_JPPE,  Z_EXdehl,Z_CALLPE,EDops,   Z_XORn,  Z_RST5
    dw  Z_RETP,  Z_POPaf, Z_JPP,   Z_DI,    Z_CALLP, Z_PUSHaf,Z_ORn,   Z_RST6
    dw  Z_RETM,  Z_LDsphl,Z_JPM,   Z_EI,    Z_CALLM, IYops,   Z_CPn,   Z_RST7

        end
