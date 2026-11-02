#!/bin/sh
# msdos4-work.sh - ホストの work/ と、MS-DOS 4.00 の B: (build/work.img, 1.44MB) の間でファイルを入れ替える
# usage: scripts/msdos4-work.sh push   work/ の中身で B: を作り直す (その前の B: は build/work.prev.img に退避)
#        scripts/msdos4-work.sh pull   B: の中身を work/ に書き戻す
#   work/ が正。make msdos4-run は 起動前に push、終了後に pull を自動で行う
#   フラットなフォルダーだけ (サブフォルダーは入れ替えない)。ファイル名は 8.3 形式 (英数字だけ)
#   画面にウィンドウを出さない (DOSBox-X の -silent)
set -eu

mode=${1:?usage: $0 push|pull}
root=$(cd "$(dirname "$0")/.." && pwd)
img=$root/build/work.img

mkdir -p "$root/work" "$root/build"

case $mode in
push)
	[ -f "$img" ] && mv -f "$img" "$root/build/work.prev.img"
	mkfs.fat -C -F 12 -n WORK "$img" 1440 >/dev/null
	bat='c:\scripts\wpush.bat'
	list=$root/build/WPUSH.TXT
	;;
pull)
	[ -f "$img" ] || { echo "msdos4-work: $img がありません (push が先)" >&2; exit 1; }
	bat='c:\scripts\wpull.bat'
	list=$root/build/WPULL.TXT
	;;
*)
	echo "usage: $0 push|pull" >&2
	exit 1
	;;
esac

rm -f "$list"
# -silent: ウィンドウなし。Flatpak のラッパーを止めても本体が残るので --die-with-parent
timeout 120 flatpak run --branch=stable --arch=x86_64 --die-with-parent com.dosbox_x.DOSBox-X \
	-silent -fastlaunch -conf "$root/slow486.conf" -set "cpu cycles=max" \
	-c "mount c $root" -c "call $bat" >/dev/null 2>&1 || true

[ -f "$list" ] && tr -d '\r' < "$list"
