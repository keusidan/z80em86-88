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
# 終了コード: 0=正常, 124=タイムアウト (z80em86 がダイアログで止まった可能性)。
#   タイムアウト時は DOSBox の画面を build/capture/ に撮ってから終了させる
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

# Flatpak のラッパー (dosbox-x) を止めてもサンドボックス内の本体が残るので、
# --die-with-parent で親と一緒に終了させる
DOSBOX="flatpak run --branch=stable --arch=x86_64 --die-with-parent com.dosbox_x.DOSBox-X"
mkdir -p "$root/build/capture"            # F12+P のスクリーンショットの保存先

# 制限時間を過ぎても終わらないとき (ダイアログで止まったときなど) は、この
# script が起動した DOSBox-X のウィンドウだけを DOSBox-X 自身の機能 (F12+P)
# で撮影してから終了させる。画面全体は撮らない、ほかのウィンドウには触れない
# (scripts/dosbox-shot.sh と同じ制約)
wins() { xdotool search --class '^dosbox-x$' 2>/dev/null | sort || true; }
have_xdo=0
command -v xdotool >/dev/null && have_xdo=1
[ $have_xdo = 1 ] && wins > "$root/build/capture/.run-before-$$"

rc=0
$DOSBOX -fastlaunch -conf "$root/$conf" -set "cpu cycles=$cycles" \
	-set "dosbox captures=$root/build/capture" \
	-set "sdl windowposition=${WINPOS:-1800,40}" \
	-c "mount c $root" -c "c:" -c "cd \\$emudir" -c "set Z80SPEED=$speed" \
	-c "z80em86 c:\\$dossub > c:\\build\\$name.txt" -c "exit" >/dev/null 2>&1 &
pid=$!
t=0                                      # 0.1 秒単位 (時間計測の分解能)
while kill -0 $pid 2>/dev/null && [ $t -lt $((limit * 10)) ]; do
	sleep 0.1
	t=$((t + 1))
done
if kill -0 $pid 2>/dev/null; then
	rc=124
	if [ $have_xdo = 1 ]; then
		new=$(wins | comm -13 "$root/build/capture/.run-before-$$" -)
		if [ "$(printf '%s' "$new" | grep -c .)" -eq 1 ] &&
			xprop -id "$new" WM_CLASS 2>/dev/null | grep -q '"dosbox-x", "dosbox-x"'; then
			touch "$root/build/capture/.run-mark-$$"
			xdotool key --window "$new" F12+p
			sleep 1
			find "$root/build/capture" -newer "$root/build/capture/.run-mark-$$" \
				-type f ! -name '.*' | sed 's/^/cpm-run: screenshot /' >&2
		fi
	fi
	kill $pid 2>/dev/null || true
	sleep 1
	kill -9 $pid 2>/dev/null || true
else
	wait $pid || rc=$?
fi
rm -f "$root/build/capture/.run-before-$$" "$root/build/capture/.run-mark-$$"

# DOS が作るファイル名は大文字になる
for f in "$root/$OUT" "$root/$out"; do
	[ -f "$f" ] && tr -d '\r' < "$f"
done
[ "$rc" -eq 124 ] && echo "cpm-run: timeout (${limit}s)" >&2
exit "$rc"
