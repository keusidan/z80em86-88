#!/bin/sh
# dosbox-shot.sh - DOSBox-X の画面だけを、DOSBox-X 自身の機能 (F12+P) で撮影する
# usage: scripts/dosbox-shot.sh <file.sub> <delay_sec> [count] [interval_sec]
#   file.sub : scripts/cpm-run.sh に渡す submit ファイル
#   delay    : DOSBox-X のウィンドウが出てから最初に撮るまでの秒数
#   count    : 撮影回数 (default 1)、interval: 撮影の間隔 (default 1)
#   環境変数 (Z80SPEED, EMUDIR, OUTNAME, CYCLES) は cpm-run.sh にそのまま渡る
#   SENDKEYS : 環境変数。delay のあと、撮影の前にこのウィンドウへ送るキー
#              (xdotool のキー名を空白区切り。例: "a shift+b Up")。count=0 なら
#              キーだけ送って撮影しない
# 例: Z80SPEED=4 EMUDIR=build/emutest OUTNAME=emutest \
#       scripts/dosbox-shot.sh build/rung.sub 6
#
# プライバシーのための制約 (この script の外へは手を出さない):
#   - 画面全体を撮るツール (spectacle, import, grim など) は使わない。撮影は
#     DOSBox-X のスクリーンショット機能だけで、保存されるのは DOSBox の画面だけ
#   - キーを送る相手は「この script が起動した DOSBox-X のウィンドウ」だけ。
#     起動前からあったウィンドウには触れない。新しいウィンドウがちょうど 1 つで
#     ないときは何もしないで中止する
#   - 送るキーは F12+P と、呼び出し側が SENDKEYS で明示したキーだけ。
#     SENDKEYS も --window でこのウィンドウにだけ送る (前面化はしない)
#   - キーを送る直前に、そのウィンドウの WM_CLASS が dosbox-x であることを確認する
#   - 前面化 (windowactivate) が必要なときは、前面化のあとで前面のウィンドウが
#     対象と一致することを確かめてから送る。一致しなければ送らずに中止する
#   - 保存先は build/capture/ (cpm-run.sh が DOSBox-X に設定する)
set -eu

sub=${1:?usage: $0 <file.sub> <delay_sec> [count] [interval_sec]}
delay=${2:?usage: $0 <file.sub> <delay_sec> [count] [interval_sec]}
count=${3:-1}
interval=${4:-1}
root=$(cd "$(dirname "$0")/.." && pwd)
cap="$root/build/capture"
mkdir -p "$cap"

die() { echo "dosbox-shot: $*" >&2; exit 1; }

command -v xdotool >/dev/null || die "xdotool がありません"

# DOSBox-X のウィンドウ一覧 (WM_CLASS で探す)
wins() { xdotool search --class '^dosbox-x$' 2>/dev/null | sort || true; }

stamp="$cap/.shot-start"
touch "$stamp"
wins > "$cap/.shot-before"

"$root/scripts/cpm-run.sh" "$sub" &
run=$!

# この script が起動したウィンドウを待つ (起動前の一覧にないもの)
target=
i=0
while [ $i -lt 30 ]; do
	sleep 1
	new=$(wins | comm -13 "$cap/.shot-before" -)
	n=$(printf '%s' "$new" | grep -c . || true)
	if [ "$n" -eq 1 ]; then
		target=$new
		break
	elif [ "$n" -gt 1 ]; then
		die "新しい DOSBox-X のウィンドウが複数あります。中止します"
	fi
	i=$((i + 1))
done
[ -n "$target" ] || die "DOSBox-X のウィンドウが見つかりません"

is_dosbox() {
	xprop -id "$1" WM_CLASS 2>/dev/null | grep -q '"dosbox-x", "dosbox-x"'
}

shot() {
	is_dosbox "$target" || die "対象が DOSBox-X ではありません。中止します"
	mark="$cap/.shot-mark"
	touch "$mark"
	# 1) 前面化しないで、そのウィンドウにだけ送る
	xdotool key --window "$target" F12+p
	sleep 1
	if [ -n "$(find "$cap" -newer "$mark" -type f ! -name '.*')" ]; then
		return 0
	fi
	# 2) 前面化して、前面が対象と一致するときだけ送る
	xdotool windowactivate --sync "$target" 2>/dev/null || true
	sleep 0.3
	active=$(xdotool getactivewindow 2>/dev/null || true)
	[ "$active" = "$target" ] || die "前面のウィンドウが DOSBox-X ではないので送りません"
	is_dosbox "$active" || die "前面のウィンドウが DOSBox-X ではないので送りません"
	xdotool key F12+p
	sleep 1
}

sleep "$delay"
if [ -n "${SENDKEYS:-}" ]; then
	is_dosbox "$target" || die "対象が DOSBox-X ではありません。中止します"
	for key in $SENDKEYS; do
		xdotool key --window "$target" --delay 150 "$key"
		sleep 0.3
	done
fi
k=0
while [ $k -lt "$count" ]; do
	shot
	k=$((k + 1))
	[ $k -lt "$count" ] && sleep "$interval"
done

wait "$run" || true
find "$cap" -newer "$stamp" -type f ! -name '.*' | sort
rm -f "$stamp" "$cap/.shot-mark" "$cap/.shot-before"
