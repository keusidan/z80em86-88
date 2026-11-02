#!/bin/sh
# get-tools.sh - DOS / CP/M 用ツールを取得して展開する
# usage: scripts/get-tools.sh nasm [version]   -> nasm/  (nasm.us の DOS 版 NASM, default 3.02)
#        scripts/get-tools.sh edit             -> edit/  (FreeDOS 1.3 の EDIT)
#        scripts/get-tools.sh zmac             -> zmac/  (Al Hawley の ZMAC, CP/M 用。中身は CRUNCH 圧縮のまま)
#        scripts/get-tools.sh z80em86          -> z80em86/ (Z80 エミュレータ z80em86 + CP/M 3 一式)
#        scripts/get-tools.sh zex              -> zex/  (Frank Cringle の ZEXDOC/ZEXALL ソース, GPL)
#        scripts/get-tools.sh msdos4           -> msdos4/ (microsoft/MS-DOS の v4.0, MIT。src/ にビルド用ツール一式入り, 約 21MB)
# 展開後のファイル名は unzip -LL で小文字にそろえる
set -eu

tool=${1:?usage: $0 nasm|edit|zmac|z80em86|zex|msdos4 [version]}

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
zex)
	fetch "https://mdfs.net/Software/Z80/Exerciser/YAZE.zip"
	mkdir -p zex
	unzip -o -LL "$tmp/pkg.zip" -d zex
	ls -l zex
	;;
msdos4)
	# リポジトリ全体は PDF で巨大なので、v4.0 だけを sparse checkout する
	git clone -q --depth 1 --filter=blob:none --sparse https://github.com/microsoft/MS-DOS.git "$tmp/repo"
	git -C "$tmp/repo" sparse-checkout set v4.0
	# 前のビルドの生成物 (古い boot.cl1 など) が残ると nmake が最新と見なして飛ばすので、作り直す。
	# ビルドが読み取り専用にしたファイル (attrib +R) があるので、先に書き込みを許可する
	if [ -d msdos4 ]; then chmod -R u+w msdos4; rm -rf msdos4; fi
	mkdir -p msdos4
	cp -r "$tmp/repo/v4.0/." msdos4/
	# GitHub 上のソースは、CP437 の罫線文字などが U+FFFD (EF BF BD の 3 バイト) に化けている。
	# コメント行が 3 倍に伸びて MASM が "Line too long" で止まるので、1 バイトの '=' に置き換える
	bad=$(printf '\357\277\275')
	LC_ALL=C grep -rIl "$bad" msdos4 | xargs -r env LC_ALL=C sed -i "s/$bad/=/g"
	# リポジトリのテキストはほぼ全部が LF のみ。DOS のツール (nosrvbld など) は CRLF 前提なので直す
	# 注意: grep -I -L はバイナリ (EXE など) も「CR を含まないファイル」として出すので、
	# 先に grep -rIl '' でテキストだけを選ぶ。選ばないと MASM.EXE などが壊れる
	LC_ALL=C grep -rIl '' msdos4 | xargs -r env LC_ALL=C grep -L "$(printf '\r')" |
		xargs -r env LC_ALL=C sed -i 's/$/\r/'
	# .SKL の末尾の Ctrl-Z (EOF マーカー) があると、nosrvbld が後ろのメッセージを取り違える
	# (msdos.skl の NLS_YES が "Y" ではなく別のメッセージになる)。その行を消す
	find msdos4 -iname '*.SKL' | xargs -r env LC_ALL=C sed -i '/^\x1a\r*$/d'
	ls msdos4 msdos4/src
	;;
*)
	echo "unknown tool: $tool" >&2
	exit 1
	;;
esac
