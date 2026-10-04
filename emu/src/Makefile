#*******************************************************************************
#*                              z80em86 Makefile                               *
#*           A Z80 CPU emulator coded in Intel 86 assembly language            *
#*                                                                             *
#*                    Copyright (C) 1992-2009 Stewart Kay                      *
#*******************************************************************************
#
#===============================================================================
# REVISION HISTORY (Most recent at top)
#===============================================================================
# z80em86-88 - 5 October 2026
# -----------------------------
# Add undoc.obj (undocumented Z80 instructions).
# Add timer.obj (real time speed, interrupts) and timing.obj (T-states).
# Add pc88.obj (PC-8801 style I/O ports, 88 mode).
# Link order keeps insthand/timer in the middle (ALINK 32K jump limit), and
# the build fails when ALINK reports an error.
#
# v1.0.0 - S.J.Kay 13/2/2009
# --------------------------
# Created initial Makefile.
#
#===============================================================================
# How to use this GNU make file.
#===============================================================================
# make help will show the options available.
#
#===============================================================================
# Requirements
#===============================================================================
# Requirements:
# - NASM assembler (Netwide Assembler)
# - ALINK cross linker (will be downloaded and built during the make process)

#===============================================================================
# Overrides
#===============================================================================
.SUFFIXES:

TOPDIR=..

#===============================================================================
# Application specific definitions
#===============================================================================
APP=z80em86
VERSION=1.0.1
TITLE=z80em86

# Set the debugging level
OPT_DEBUG=0

# Values passed as defines when compiling
APPVER=\"$(VERSION)\"
APPIDSTR=\"$(APP)\"

# Object files
# Link order: insthand (DispA-DispD), timer (Tslow) and pc88 sit in the middle of
# the code segment. ALINK rejects near jumps further than 32K ("Reloc out of
# range") and leaves them unpatched, and the handlers jump to these from
# everywhere.
OBJA=./arith16.obj ./bit.obj ./control.obj ./function.obj ./jump.obj
OBJA+=./load8.obj ./main.obj ./rotate.obj ./arith8.obj
OBJA+=./insthand.obj ./timer.obj ./pc88.obj ./table.obj ./window.obj
OBJA+=./call.obj ./exchange.obj ./hardware.obj ./io.obj ./load16.obj
OBJA+=./macros.obj ./res.obj ./set.obj ./video.obj ./undoc.obj
OBJA+=./timing.obj

# Dependencies
DEPENDENCIES=macros.asm io88.inc Makefile

HAVE_DOSEMU=$(wildcard ~/.dosemu/drive_c)

Z80HDD=~/.dosemu/drive_c/$(APP)/z80hdd.exe

#===============================================================================
# Cross compile and link.
#
# -O2 is needed to optimise code like TASM does, there does not appear to be a
# way to turn it off in TASM.
#===============================================================================
XOBJA=$(OBJA:./%=build/%)
LOBJA=$(XOBJA:%.obj=%.lst)

ifeq ($(OPT_DEBUG),1)
   DEBUG=
   OPT=
else
   DEBUG=
   OPT=-O2
endif

NASM=nasm
LINK=../alink/alink

AFLAGS=$(DEBUG) $(OPT) -f obj
AINC=
ALIB=
ADEF=-DAPPVER=$(APPVER) -DAPPIDSTR=$(APPIDSTR)

build/$(APP).exe: $(LINK) $(XOBJA) $(Z80HDD)
	$(LINK) $(XOBJA) -o build/$(APP).exe -m > build/alink.log; \
	status=$$?; cat build/alink.log; \
	if grep -q "^Error" build/alink.log; then rm -f build/$(APP).exe; exit 1; fi; \
	exit $$status

build/%.obj: %.asm $(DEPENDENCIES)
	@[ -d build ] || mkdir build
	$(NASM) $(AFLAGS) $(ADEF) $(*).asm -o build/$(*).obj -l build/$(*).lst

$(LINK):
	sh ../scripts/build_alink.sh ../alink ../temp \
	http://alink.sourceforge.net/files/alinksrc.zip

ifneq ($(HAVE_DOSEMU),)
$(Z80HDD): z80hdd.pas
	@[ -d ~/.dosemu/drive_c/$(APP) ] || mkdir ~/.dosemu/drive_c/$(APP)
	cp z80hdd.pas ~/.dosemu/drive_c/$(APP)
	dosemu -dumb "cd $(APP)|tpc z80hdd.pas"
	cp ~/.dosemu/drive_c/$(APP)/z80hdd.exe build/
else
$(Z80HDD):
	@echo "No '~/.dosemu/drive_c/' dosemu home account was located"
	@echo "Can't create Z80HDD.EXE"
endif	
	
#===============================================================================
# General maintenance
#===============================================================================
clean:
	rm -f $(XOBJA) $(LOBJA) build/$(APP).exe build/$(APP).map \
              $(TOPDIR)/distributions/$(APP)-$(VERSION).tar.gz \
              $(TOPDIR)/distributions/$(APP)-$(VERSION)-dos.zip \
              $(Z80HDD)

cleanall: clean
	rm -Rf build/
	rm -Rf $(LINK)

#===============================================================================
# Install and remove installed files
#===============================================================================
ifneq ($(HAVE_DOSEMU),)
install:
	@[ -d ~/.dosemu/drive_c/$(APP) ] || mkdir ~/.dosemu/drive_c/$(APP)
	cp build/$(APP).exe ~/.dosemu/drive_c/$(APP)/
uninstall:
	rm ~/.dosemu/drive_c/$(APP)/$(APP).exe
else
install:
	@echo "No '~/.dosemu/drive_c/' dosemu home account was located"
	
uninstall:
	@echo "No '~/.dosemu/drive_c/' dosemu home account was located"
endif

#===============================================================================
# Run the program under dosemu.
#
# A bootable Z80HDD.DSK image is required in '~/.dosemu/drive_c/z80em86/'
# for non floppy drive booting and is the default unless a floppy drive is
# specified.
#
# If the Z80HDD.DSK is not found the user will be prompted for a floppy
# disk in drive A:
#===============================================================================
HAVE_INSTALL=$(wildcard ~/.dosemu/drive_c/$(APP)/$(APP).exe)

ifneq ($(HAVE_INSTALL),)
run:
	dosemu "cd $(APP)|z80em86"

runa:
	dosemu "cd $(APP)|z80em86 -a"

runb:
	dosemu "cd $(APP)|z80em86 -b"

else
run:
	@echo "$(APP).exe has not been installed"

runa:
	@echo "$(APP).exe has not been installed"

runb:
	@echo "$(APP).exe has not been installed"

endif

#===============================================================================
# Help
#===============================================================================
help:
	@echo "This is the $(APP) v$(VERSION) Z80 emulator GNU makefile"
	@echo ""
	@echo "Specify one of the following:"
	@echo "make                  cross compiled DOS build"
	@echo "make clean            removes build and distribution files"
	@echo "make cleanall         cleans and removes alink generated files"
	@echo "make install          install files under dosemu"
	@echo "make uninstall        uninstall files under dosemu"
	@echo "make run              run booting Z80HDD.DSK under dosemu"
	@echo "make runa             run forcing booting A: under dosemu"
	@echo "make runb             run forcing booting B: under dosemu"
	@echo "make help             this help information"
	@echo ""
	@echo "Packaging system only:"	
	@echo "make srcdist          make source distribution"
	@echo "make alldist          make source and DOS binary distribution"
	@echo "make doszipdist       make DOS ZIP binary distribution"
	@echo "make upload           upload distribution packages"

#===============================================================================
# Create source distribution.
#===============================================================================
srcdist:
	cd $(TOPDIR) && make srcdist V=$(VERSION)
	
#===============================================================================
# Create all distributions.
#===============================================================================
alldist:
	cd $(TOPDIR) && make alldist V=$(VERSION)

#===============================================================================
# Create a DOS binary ZIP file distribution.
#===============================================================================
doszipdist:
	cd $(TOPDIR) && make doszipdist V=$(VERSION)

#===============================================================================
# Upload all the distribution files.
#===============================================================================
upload:
	cd $(TOPDIR) && make upload_to_sf V=$(VERSION)
