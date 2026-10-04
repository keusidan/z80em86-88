#!/bin/sh
# bench-cmp.sh - z80em86.exe の素の速さを比べる (bench.z80 の実行時間)
# usage: scripts/bench-cmp.sh <z80em86.exe>...
#   各 exe を build/cmp/ に置き、cycles 20000 固定・Z80SPEED=0 (速度制限なし) で
#   「空の実行」と「bench の実行」の時間を測り、その差 (bench だけの時間) を出す。
#   submit ファイル名は DOS の 8.3 に収めること。
#   build/cmp/z80hdd.dsk に BENCH.COM が必要 (なければ z80em86/z80hdd.dsk を
#   コピーする。bench は make z80check と同じ手順で事前にビルドしておくこと)
# 例: scripts/bench-cmp.sh build/orig/z80em86.exe emu/src/build/z80em86.exe
set -eu

[ $# -ge 1 ] || { echo "usage: $0 <z80em86.exe>..." >&2; exit 1; }
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
mkdir -p build/cmp
[ -f build/cmp/z80hdd.dsk ] || cp z80em86/z80hdd.dsk build/cmp/
chmod u+w build/cmp/z80hdd.dsk
printf 'device conout:=crt2\r\n' > build/cmpe.sub
printf 'device conout:=crt2\r\nbench\r\n' > build/cmpb.sub

# 1 回の実行時間 (秒)。制限時間を過ぎたら cpm-run.sh が画面を撮って止める
runtime() {
	t0=$(date +%s.%N)
	CYCLES="fixed 20000" Z80SPEED=0 EMUDIR=build/cmp OUTNAME=cmp \
		scripts/cpm-run.sh "$1" slow88.conf "$2" > build/cmp-out.txt || {
		echo "bench-cmp: $1 failed (see build/capture/)" >&2; exit 1; }
	t1=$(date +%s.%N)
	echo "$t1 - $t0" | bc
}

printf '%-36s %8s %8s %8s\n' exe empty total bench
for exe in "$@"; do
	cp "$exe" build/cmp/z80em86.exe
	e=$(runtime build/cmpe.sub 6)
	b=$(runtime build/cmpb.sub 15)
	grep -q "bench done" build/cmp-out.txt || { echo "bench-cmp: no 'bench done'" >&2; exit 1; }
	printf '%-36s %8.2f %8.2f %8.2f\n' "$exe" "$e" "$b" "$(echo "$b - $e" | bc)"
done
