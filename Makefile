NAME    := hello
BIN     := build/$(NAME).com
MACHINE ?= 486
CONF    := $(CURDIR)/slow$(MACHINE).conf
NASM_VER ?= 3.02

# Flatpak 版はカレントディレクトリを引き継ぐ保証がないので、すべて絶対パスで渡す
DOSBOX := dosbox-x -fastlaunch -conf $(CONF) -c "mount c $(CURDIR)" -c "c:"

all: $(BIN)

$(BIN): $(NAME).asm | build
	nasm -f bin -l build/$(NAME).lst -o $@ $<

build:
	mkdir -p $@

run: $(BIN)
	$(DOSBOX) -c "build\$(NAME).com"

debug: $(BIN)
	$(DOSBOX) -c "debug build\$(NAME).com"

dos:
	$(DOSBOX) -c "set PATH=C:\NASM;C:\EDIT;%PATH%"

nasm:
	scripts/get-tools.sh nasm $(NASM_VER)

edit:
	scripts/get-tools.sh edit

zmac:
	scripts/get-tools.sh zmac

z80em86:
	scripts/get-tools.sh z80em86

zex:
	scripts/get-tools.sh zex

# emu/src の z80em86 をビルドし、実行環境 z80em86/ の exe を置き換える
emu:
	$(MAKE) -C emu/src
	cp emu/src/build/z80em86.exe z80em86/z80em86.exe

# z80check.z80 を CP/M 内で ZMAC → ZML → 実行する (cycles=max)
z80check:
	scripts/cpm-run.sh scripts/z80check.sub

# ZEXDOC (Z80 命令の網羅テスト) を CP/M 内でビルドして実行する。数十分かかる
# ZML は ASEG を出力しないので、ASEG + ORG 100h を CSEG に置き換えてからアセンブルする
zexdoc: | build
	test -f zex/zexdoc.z80 || scripts/get-tools.sh zex
	sed 's/^\taseg\r$$/\tcseg\r/; /^\torg\t100h\r$$/d' zex/zexdoc.z80 > build/zexdoc.z80
	scripts/cpm-run.sh scripts/zexdoc.sub slow88.conf 10800 | tee build/zexdoc.log

clean:
	rm -rf build

.PHONY: all run debug dos nasm edit zmac z80em86 zex emu z80check zexdoc clean
