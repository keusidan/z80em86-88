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

# emu/src の z80em86 をビルドし、実行環境 z80em86/ の exe を置き換える
emu:
	$(MAKE) -C emu/src
	cp emu/src/build/z80em86.exe z80em86/z80em86.exe

# z80check.z80 を CP/M 内で ZMAC → ZML → 実行する (cycles=max)
z80check:
	scripts/cpm-run.sh scripts/z80check.sub

clean:
	rm -rf build

.PHONY: all run debug dos nasm edit zmac z80em86 emu z80check clean
