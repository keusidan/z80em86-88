#!/bin/sh
# cpm-run.sh - z80em86 (CP/M 3) に submit ファイルを流し、コンソール出力を表示する
# usage: scripts/cpm-run.sh <file.sub> [conf] [timeout_sec]
#   file.sub : プロジェクト内の submit ファイル (CRLF, 8.3 の名前)。1 行目で
#              "device conout:=crt2" として出力を STDOUT に向けること
#   conf     : DOSBox-X の設定 (default: slow88.conf を cycles=$CYCLES で上書き)
#   CYCLES   : 環境変数。DOSBox-X の cycles (default: max)
#   EMUDIR   : 環境変数。z80em86.exe と z80hdd.dsk のあるディレクトリ
#              (プロジェクトからの相対パス, default: z80em86)
#   OUTNAME  : 環境変数。出力を build/<OUTNAME>.txt に書く (default: cpmrun)
#              同時に 2 つ動かすときは EMUDIR と OUTNAME を別にすること
#   WINPOS   : 環境変数。DOSBox-X のウィンドウ位置 "x,y" (default: 1800,40 =
#              2560x1440 の画面の右上。動画などの邪魔にならないように)
#   Z80SPEED : 環境変数。z80em86 の速度 4 (4MHz), 8 (8MHz), 0 (制限なし)。
#              default: 0 (テストを速く終わらせるため)
# 例: scripts/cpm-run.sh scripts/z80check.sub
#     CYCLES="fixed 20000" scripts/cpm-run.sh scripts/bench.sub
# 終了コード: 0=正常, 124=タイムアウト (z80em86 がダイアログで止まった可能性)
set -eu

sub=${1:?usage: $0 <file.sub> [conf] [timeout_sec]}
conf=${2:-slow88.conf}
limit=${3:-120}
cycles=${CYCLES:-max}
speed=${Z80SPEED:-0}
emudir=$(printf '%s' "${EMUDIR:-z80em86}" | tr '/' '\\\\')
root=$(cd "$(dirname "$0")/.." && pwd)
name=${OUTNAME:-cpmrun}
out=build/$name.txt
OUT=build/$(printf '%s' "$name" | tr 'a-z' 'A-Z').TXT

mkdir -p "$root/build"
rm -f "$root/$OUT" "$root/$out"

# DOS 側のパスは C:\ がプロジェクトのルート。/ を \ に置き換える
dossub=$(printf '%s' "$sub" | tr '/' '\\')

rc=0
# Flatpak のラッパー (dosbox-x) を timeout で止めてもサンドボックス内の本体が
# 残るので、--die-with-parent で親と一緒に終了させる
DOSBOX="flatpak run --branch=stable --arch=x86_64 --die-with-parent com.dosbox_x.DOSBox-X"

mkdir -p "$root/build/capture"            # F12+P のスクリーンショットの保存先
timeout "$limit" $DOSBOX -fastlaunch -conf "$root/$conf" -set "cpu cycles=$cycles" \
	-set "dosbox captures=$root/build/capture" \
	-set "sdl windowposition=${WINPOS:-1800,40}" \
	-c "mount c $root" -c "c:" -c "cd \\$emudir" -c "set Z80SPEED=$speed" \
	-c "z80em86 c:\\$dossub > c:\\build\\$name.txt" -c "exit" >/dev/null 2>&1 || rc=$?

# DOS が作るファイル名は大文字になる
for f in "$root/$OUT" "$root/$out"; do
	[ -f "$f" ] && tr -d '\r' < "$f"
done
[ "$rc" -eq 124 ] && echo "cpm-run: timeout (${limit}s)" >&2
exit "$rc"
