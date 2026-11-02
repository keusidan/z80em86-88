#!/bin/sh
# qemu-run.sh - フロッピーイメージを QEMU で起動し、画面を PNG で保存する (ウィンドウは出さない)
# usage: scripts/qemu-run.sh <image> <wait_sec> [key ...]
#   image    : 起動する 360KB/1.44MB のフロッピーイメージ (例: build/msdos4.img)
#   wait_sec : 起動してから最初の撮影までの秒数
#   key      : そのあとに QEMU monitor の sendkey で送るキー。1 つ送るごとに 1 秒待って撮る
#              (例: e d l i n ret → 文字は 1 つずつ、Enter は ret、F3 は f3、Ctrl+C は ctrl-c)
#   出力     : build/qemu/shot_00.png (最初)、shot_01.png ... (キーごと)
#   環境変数 QEMU_CPU: -cpu (default: 486)
#   環境変数 QEMU_FDB: B: に付けるフロッピーイメージ (例: build/work.img)
#   環境変数 QEMU_KEYWAIT: キー 1 つごとの待ち秒数 (default: 1)
#   環境変数 QEMU_SHOTS: all (default) なら毎回撮る。last なら最初と最後だけ
# 例: scripts/qemu-run.sh build/msdos4.img 6 e d l i n spc h i dot a s m ret
# -display none なので画面には何も出ない。monitor は unix socket で操作する
set -eu

img=${1:?usage: $0 <image> <wait_sec> [key ...]}
wait=${2:?usage: $0 <image> <wait_sec> [key ...]}
shift 2
root=$(cd "$(dirname "$0")/.." && pwd)
out=$root/build/qemu
sock=$out/mon.sock
mkdir -p "$out"
rm -f "$sock" "$out"/shot_*.png "$out"/shot_*.ppm

qemu-system-i386 -display none -machine pc -cpu "${QEMU_CPU:-486}" -m 4 \
	-drive "file=$img,format=raw,if=floppy,index=0" ${QEMU_FDB:+-drive "file=$QEMU_FDB,format=raw,if=floppy,index=1"} \
	-boot a -monitor "unix:$sock,server,nowait" -serial none -parallel none \
	>"$out/qemu.log" 2>&1 &
pid=$!
trap 'kill $pid 2>/dev/null || true' EXIT

# monitor が開くまで待つ
i=0
while [ ! -S "$sock" ] && [ $i -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
[ -S "$sock" ] || { echo "qemu-run: monitor が開きません" >&2; cat "$out/qemu.log" >&2; exit 1; }

mon() { printf '%s\n' "$1" | socat - "UNIX-CONNECT:$sock" >/dev/null 2>&1; }
shot() {
	mon "screendump $out/shot_$1.ppm"
	sleep 0.5
	magick "$out/shot_$1.ppm" "$out/shot_$1.png" && rm -f "$out/shot_$1.ppm"
	echo "$out/shot_$1.png"
}

sleep "$wait"
shot 00
n=1
for k in "$@"; do
	mon "sendkey $k"
	sleep "${QEMU_KEYWAIT:-1}"
	if [ "${QEMU_SHOTS:-all}" = all ] || [ $n -eq $# ]; then
		shot "$(printf '%02d' $n)"
	fi
	n=$((n + 1))
done
