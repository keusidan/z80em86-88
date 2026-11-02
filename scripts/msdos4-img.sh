#!/bin/sh
# msdos4-img.sh - ビルドした MS-DOS 4.00 の 360KB 起動フロッピー build/msdos4.img を作る
# usage: scripts/msdos4-img.sh
#   前提: scripts/msdos4-build.sh でビルド済み (msdos4/src/BIOS/IO.SYS など)
#   手順: (1) mkfs.fat で空の FAT12 を作る
#         (2) ブートセクタのコードだけ msboot.bin のものに差し替える (BPB は mkfs.fat のまま)
#         (3) DOSBox-X (-silent, ウィンドウなし) の中で IO.SYS, MSDOS.SYS の順にコピーする
#             (先頭 2 エントリで連続して置かないとブートできない)
#   キー配列は jpkey.asm (JP106) を AUTOEXEC.BAT で常駐させる
#   コピーする内容は scripts/mk4img.bat、起動後に走る AUTOEXEC.BAT は scripts/msdos4.aut
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
src=$root/msdos4/src
img=$root/build/msdos4.img

for f in BIOS/IO.SYS DOS/MSDOS.SYS CMD/COMMAND/COMMAND.COM BOOT/MSBOOT.BIN; do
	[ -f "$src/$f" ] || { echo "msdos4-img: $f がありません。scripts/msdos4-build.sh を先に実行してください" >&2; exit 1; }
done
mkdir -p "$root/build"
# 日本語キー配列の TSR (MS-DOS 4.00 の KEYB には JP がない)
nasm -f bin -o "$root/build/jpkey.com" "$root/jpkey.asm"
rm -f "$img" "$root/build/MK4IMG.TXT"

# (1) 360KB (2 面 x 40 トラック x 9 セクタ)。root 112 エントリ、1 クラスタ 2 セクタ
#     ボリュームラベル (-n) は付けない。ルートの先頭エントリを取られて IO.SYS が 2 番目になり、ブートできない
mkfs.fat -C -F 12 -r 112 -s 2 "$img" 360 >/dev/null

# (2) 先頭 62 バイト (ジャンプ + BPB + 拡張 BPB) は mkfs.fat のもの、残りのコードは msboot.bin の
#     0x7C00 以降 (org 7C00h でビルドされているので、ファイル内の位置は 0x7C00)
{
	head -c 62 "$img"
	tail -c +$((0x7c00 + 62 + 1)) "$src/BOOT/MSBOOT.BIN" | head -c $((512 - 62))
} > "$root/build/boot.tmp"
dd if="$root/build/boot.tmp" of="$img" bs=512 count=1 conv=notrunc status=none
rm -f "$root/build/boot.tmp"

# (3) DOSBox-X の中でファイルをコピーする
flatpak run --branch=stable --arch=x86_64 --die-with-parent com.dosbox_x.DOSBox-X \
	-silent -fastlaunch -conf "$root/slow486.conf" -set "cpu cycles=max" \
	-c "mount c $root" -c "mount d $root/msdos4" -c "call c:\\scripts\\mk4img.bat" \
	>/dev/null 2>&1

tr -d '\r' < "$root/build/MK4IMG.TXT"
