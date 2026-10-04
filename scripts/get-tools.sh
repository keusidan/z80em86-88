#!/bin/sh
# get-tools.sh - DOS / CP/M 用ツールを取得して展開する
# usage: scripts/get-tools.sh nasm [version]   -> nasm/  (nasm.us の DOS 版 NASM, default 3.02)
#        scripts/get-tools.sh edit             -> edit/  (FreeDOS 1.3 の EDIT)
#        scripts/get-tools.sh zmac             -> zmac/  (Al Hawley の ZMAC, CP/M 用。中身は CRUNCH 圧縮のまま)
#        scripts/get-tools.sh z80em86          -> z80em86/ (Z80 エミュレータ z80em86 + CP/M 3 一式)
# 展開後のファイル名は unzip -LL で小文字にそろえる
set -eu

tool=${1:?usage: $0 nasm|edit|zmac|z80em86 [version]}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fetch() {
	echo "fetch: $1"
	curl -fL --retry 3 -o "$tmp/pkg.zip" "$1"
	unzip -tq "$tmp/pkg.zip"
}

case $tool in
nasm)
	ver=${2:-3.02}
	fetch "https://www.nasm.us/pub/nasm/releasebuilds/$ver/dos/nasm-$ver-dos.zip"
	# zip 内は nasm-<ver>/ 配下に平置き。-j で階層を捨てる
	mkdir -p nasm
	unzip -o -j -LL "$tmp/pkg.zip" -d nasm
	ls -l nasm
	;;
edit)
	fetch "https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/repositories/1.3/base/edit.zip"
	mkdir -p edit
	unzip -o -j -C -LL "$tmp/pkg.zip" BIN/EDIT.EXE BIN/EDIT.HLP DOC/EDIT/COPYING -d edit
	ls -l edit
	;;
zmac)
	fetch "https://cpm.retropc.se/cpm/develop/zmac.zip"
	# CP/M の user area (USER0..3) ごとの階層は残し、先頭の HAWLEY1/ だけ外す
	unzip -oq -LL "$tmp/pkg.zip" -d "$tmp/x"
	mkdir -p zmac
	cp -r "$tmp/x/hawley1/." zmac/
	ls -lR zmac
	;;
z80em86)
	# 本体 (GPL v2) と CP/M 3 一式。どちらも z80em86/ 配下に展開される前提の配布物
	fetch "http://www.cpm.z80.de/download/z80em86-1.0.1-dos.zip"
	unzip -o -LL "$tmp/pkg.zip" -d .
	fetch "http://www.cpm.z80.de/download/cpm3_z80em86.zip"
	# -n: 既存ファイルは上書きしない。z80hdd.dsk に入れた作業内容を消さないため
	unzip -n -LL "$tmp/pkg.zip" -d .
	chmod u+w z80em86/z80hdd.dsk
	ls -l z80em86
	;;
*)
	echo "unknown tool: $tool" >&2
	exit 1
	;;
esac
