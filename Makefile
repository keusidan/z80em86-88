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

# 標準: 本物の MS-DOS 4.00 を起動する。hello.com は work/ 経由で B: に入る (B: で hello と打つ)
run: $(BIN)
	mkdir -p work
	cp $(BIN) work/HELLO.COM
	$(MAKE) msdos4-run

# DOSBox-X 内蔵の DOS で hello.com をそのまま実行する (従来の make run)
run-builtin: $(BIN)
	$(DOSBOX) -c "build\$(NAME).com"

debug: $(BIN)
	$(DOSBOX) -c "debug build\$(NAME).com"

# 4DOS で起動し、打ったコマンドを build/CMD.LOG に記録する (scripts/doslog.btm)
dos:
	$(DOSBOX) -c "set PATH=C:\NASM;C:\EDIT;%PATH%" -c "4dos /k c:\scripts\doslog.btm"

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

msdos4:
	scripts/get-tools.sh msdos4

# MS-DOS 4.00 のソースを DOSBox-X の中でビルドする (ウィンドウなし、3 分ほど)
msdos4-build:
	scripts/msdos4-build.sh

# ビルドした MS-DOS 4.00 の起動フロッピー build/msdos4.img を作る
msdos4-img:
	scripts/msdos4-img.sh

# 本物の MS-DOS 4.00 を DOSBox-X で起動する。A: = 起動フロッピー、B: = ホストの work/ の中身
# 起動前に work/ → B: (push)、終了後に B: → work/ (pull) を自動で行う。DOSBox-X が異常終了しても pull する
# jpkey.asm や AUTOEXEC.BAT を変えたら作り直す (A: に書いたものは消える)
build/msdos4.img: jpkey.asm scripts/mk4img.bat scripts/msdos4.aut scripts/msdos4-img.sh
	scripts/msdos4-img.sh

msdos4-run: build/msdos4.img
	scripts/msdos4-work.sh push
	-$(DOSBOX) -c "imgmount 1 c:\build\work.img -t floppy -fs none" -c "boot c:\build\msdos4.img"
	scripts/msdos4-work.sh pull

# emu/src の z80em86 をビルドし、実行環境 z80em86/ の exe を置き換える
emu:
	$(MAKE) -C emu/src
	cp emu/src/build/z80em86.exe z80em86/z80em86.exe

# z80check.z80 を CP/M 内で ZMAC → ZML → 実行する (cycles=max)
z80check:
	scripts/cpm-run.sh scripts/z80check.sub

# ZEXDOC (Z80 命令の網羅テスト) を CP/M 内でビルドして実行する。数十分かかる
# ZML は ASEG を出力しないので、ASEG + ORG 100h を CSEG に置き換えてからアセンブルする。
# msbt は 0103h 固定 (期待 CRC に番地が入る)。ZMAC は再配置可能な番地の LOW/HIGH を
# 再配置しないので、その 9 か所は数値に置き換える
zexdoc: | build
	test -f zex/zexdoc.z80 || scripts/get-tools.sh zex
	sed 's/^\taseg\r$$/\tcseg\r/; /^\torg\t100h\r$$/d; s/low msbt/03h/g; s/high msbt/01h/g' \
		zex/zexdoc.z80 > build/zexdoc.z80
	scripts/cpm-run.sh scripts/zexdoc.sub slow88.conf 10800 | tee build/zexdoc.log

clean:
	rm -rf build

.PHONY: all run run-builtin debug dos nasm edit zmac z80em86 zex msdos4 msdos4-build msdos4-img msdos4-run emu z80check zexdoc clean
