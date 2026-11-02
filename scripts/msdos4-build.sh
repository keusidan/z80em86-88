#!/bin/sh
# msdos4-build.sh - msdos4/src (MS-DOS 4.00 のソース) を DOSBox-X の中で nmake でビルドする
# usage: scripts/msdos4-build.sh [timeout_sec] [nmake の引数...]
#   前提: make msdos4 でソースを取得済み (msdos4/src/TOOLS に MASM, CL, LINK, NMAKE が入っている)
#   C: = プロジェクトのルート、D: = msdos4/ (SETENV.BAT の BAKROOT=d: に合わせる)
#   画面にウィンドウを出さない (DOSBox-X の -silent。フォーカスを奪わない)
#   ログ: build/MSDOS4.LOG (nmake の出力。DOS 側のファイル名は 8.3 なので msdos4.log)
#   環境変数 CYCLES: DOSBox-X の cycles (default: max)
#   環境変数 BAT: 実行する DOS 側の batch (default: c:\scripts\msdos4.bat)
#   timeout_sec: default 1800。終わらなければ DOSBox-X を止めて 124 で終了
# 例: scripts/msdos4-build.sh 600 -I
set -eu

limit=${1:-1800}
[ $# -gt 0 ] && shift
args=${*:--I}
bat=${BAT:-c:\\scripts\\msdos4.bat}
root=$(cd "$(dirname "$0")/.." && pwd)

[ -d "$root/msdos4/src/TOOLS" ] || { echo "msdos4-build: make msdos4 を先に実行してください" >&2; exit 1; }
mkdir -p "$root/build"
rm -f "$root/build/MSDOS4.LOG" "$root/build/msdos4.log"

# 環境変数の設定は scripts/msdos4.bat に書く。-c を何行も並べると、12 行目あたりから
# 先が実行されなかった (autoexec の長さの上限と思われる)
# -silent: ウィンドウなしで実行し、autoexec が終わったら終了する
# Flatpak のラッパーを止めても本体が残るので --die-with-parent を付ける
flatpak run --branch=stable --arch=x86_64 --die-with-parent com.dosbox_x.DOSBox-X \
	-silent -fastlaunch -conf "$root/slow486.conf" -set "cpu cycles=${CYCLES:-max}" \
	-c "mount c $root" -c "mount d $root/msdos4" \
	-c "call $bat $args" \
	>/dev/null 2>&1 &
pid=$!

t=0
while kill -0 $pid 2>/dev/null && [ $t -lt $((limit * 10)) ]; do
	sleep 0.1
	t=$((t + 1))
done
rc=0
if kill -0 $pid 2>/dev/null; then
	rc=124
	kill $pid 2>/dev/null || true
	sleep 1
	kill -9 $pid 2>/dev/null || true
	echo "msdos4-build: timeout (${limit}s)" >&2
fi

# DOS が作るファイル名は大文字になる
for f in "$root/build/MSDOS4.LOG" "$root/build/msdos4.log"; do
	[ -f "$f" ] && { tr -d '\r' < "$f" | tail -40; break; }
done
exit "$rc"
