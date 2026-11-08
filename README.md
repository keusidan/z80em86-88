# z80em86-88

DOSBox-X の中で、PC-8801 くらい遅い環境で Z80 / x86 アセンブリを書いて遊び、学ぶための開発環境です。
中心にあるのは、Stewart Kay 氏の Z80 エミュレータ **z80em86**（8086 アセンブリで書かれた DOS 用の CP/M 3 マシン）の改造版です。

- Z80 を **4MHz の実時間**で動かします（命令ごとに T ステートを数え、PC のタイマーで速度を合わせます）。
- 公式命令に加えて、**非公式命令**（IXH/IXL/IYH/IYL、SLL、DDCB のコピー版など）と、**割り込み**（IM 0/1/2、HALT、EI の 1 命令遅延）を実装しています。
- **88 モード**では、CP/M のプログラムから PC-8801 風の I/O ポート（割り込み、ビープ音、GVRAM の 640×200 8 色グラフィック、キーボードマトリクス）を使えます。
- 動作確認：ZEXDOC（Z80 命令の網羅テスト）67/67 OK。

これは学習用の個人プロジェクトです。PC-8801 の完全な再現は目指していません（できること・できないことは下にまとめています）。

## 必要なもの（ホスト側）

- DOSBox-X（Flatpak 版 `com.dosbox_x.DOSBox-X` を想定しています。`flatpak override --user --filesystem=<このディレクトリ>` で読めるようにしておいてください）
- `nasm`、`gcc`、`make`、`unzip`、`curl`、`wget`、`python3`
- （任意）`xdotool`：DOSBox の画面だけを撮るスクリプト `scripts/dosbox-shot.sh` と、ハングしたときの自動スクリーンショットで使います。

## セットアップ

```sh
make nasm edit zmac z80em86   # DOS 版 NASM, FreeDOS EDIT, ZMAC, z80em86 + CP/M 3 を取得
make emu                      # emu/ の改造版 z80em86 をビルドして z80em86/ に入れる
```

ZMAC（CP/M 用の Z80 アセンブラ）は CRUNCH 圧縮のまま配布されています。CP/M の中で同梱の `UNCR` を使って解凍してください（`scripts/cpm-run.sh` で submit ファイルを流すと自動化できます）。

取得したツールはどれも第三者の配布物なので、リポジトリには含めていません（`.gitignore`）。

## 使い方

| コマンド | 内容 |
|---|---|
| `make` / `make run` / `make run-builtin` / `make debug` / `make dos` | x86：ホストの nasm で `hello.asm` をビルド／ビルドして本物の MS-DOS 4.00 を起動（B: で `hello`。下の `msdos4-run` 参照）／DOSBox-X 内蔵 DOS で実行／DEBUG で開く／DOS シェル（`C:\NASM`、`C:\EDIT` に PATH が通る） |
| `make z80check` | Z80 命令のテスト（`z80check.z80`）を CP/M 内で ZMAC → ZML → 実行 |
| `make zexdoc` | ZEXDOC を CP/M 内でビルドして実行（速度制限なしで約 30 分） |
| `scripts/cpm-run.sh <file.sub>` | z80em86 に CP/M の submit ファイルを流して、コンソール出力を表示 |
| `make msdos4` → `make msdos4-build` → `make msdos4-img` → `make msdos4-run` | 本物の MS-DOS 4.00（[microsoft/MS-DOS](https://github.com/microsoft/MS-DOS)、MIT）のソースを取得→DOSBox-X の中でビルド（ウィンドウなし、約 3 分）→起動フロッピー `build/msdos4.img` を作る→DOSBox-X で起動。EDLIN の F1/F3 などが MS-DOS どおりに動く。A: が起動フロッピー、B: がホストの `work/` の中身、C: は起動時のプロジェクトの写し（読むだけ。書いたものはホストに戻らない。`path a:\;c:\nasm` で NASM を MS-DOS の中でも使える）（起動前に `work/`→B:、終了後に B:→`work/` を自動で入れ替える。フラットなフォルダー、ファイル名は 8.3 の英数字だけ）。キー配列は JP106（MS-DOS 4.00 の KEYB には日本語配列がないので、自作の常駐プログラム `jpkey.asm` を AUTOEXEC.BAT で読み込む） |
| `scripts/qemu-run.sh <image> <秒> [キー...]` | イメージを QEMU でウィンドウなしに起動し、画面を PNG で保存（キーも送れる） |
| `scripts/bench-cmp.sh <exe>...` | z80em86.exe の速さの比較 |
| `scripts/dosbox-shot.sh <file.sub> <秒>` | DOSBox の画面だけを、DOSBox-X 自身の機能（F12+P）で撮影 |

設定ファイル：`slow486.conf`（486、DOS 版 NASM 用。NASM 3.02 の DOS 版は 386 では動きません）、`slow88.conf`（8086、z80em86 用）。

### Z80 の速度

DOS の環境変数 `Z80SPEED` で切り替えます（`scripts/cpm-run.sh` では同名の環境変数）。

| 値 | 速度 |
|---|---|
| `4`（既定） | 4MHz（PC-8801 の標準） |
| `8` | 8MHz |
| `0` | 制限なし（テスト用） |

## 88 モード

CP/M のプログラムが `OUT (0E0h),A` を実行するとオンになり、プログラムを終了する（ウォームブート）とオフになります。
88 モードの間、ユーザー領域（TPA）で実行した `IN` / `OUT` は、PC-8801 風のポートにつながります。BIOS からの `OUT (n),A` は、従来どおりエミュレータの機能呼び出しとして動きます。

| ポート | 向き | 内容 |
|---|---|---|
| 00h〜0Bh | R | キーボードマトリクス（押されている間 0）。f1〜f5 = F1〜F5、STOP = F9、COPY = F10、HELP = End、ROLL UP/DOWN = PgUp/PgDn、GRPH = 左 Alt、カナ = 右 Alt |
| 30h, 32h | W | 保存のみ（32h の bit5 はアナログパレットの選択） |
| 31h | W | bit3 GRPH：グラフィック表示（EGA 640×200 で表示） |
| 40h | W | bit5 BEEP（2400Hz）、bit7 SING（スピーカー） |
| 40h | R | bit5 VRTC（垂直帰線期間） |
| 52h, 53h | W | 53h の bit1〜3 で青・赤・緑のプレーンを隠す |
| 54h〜5Bh | W | パレット 0〜7（デジタル：bit0 青、bit1 赤、bit2 緑。アナログにも対応） |
| 5Ch〜5Fh | W | C000h〜FFFFh を GVRAM の青・赤・緑のプレーン／本来の RAM に切り替え |
| 5Ch | R | 選択中のプレーン |
| E4h | W | 割り込みレベル（bit3 = 1 で全レベル、0 なら bit0〜2 未満のレベル） |
| E6h | W | 割り込みマスク：bit0 CLOCK（600Hz）、bit1 VRTC（60Hz）、bit2 RXRDY |

- 割り込みは IM 2 で受けます。ベクタは `I×256 + レベル×2`（レベル 0 = RXRDY、1 = VRTC、2 = CLOCK）です。
- **実機と同じ注意**：GVRAM を C000h に出している間は、スタックを C000h より下に置き、BDOS を呼ばないでください。
- 割り込みは、プログラムがユーザー領域を実行している間だけ受け付けます（BIOS の実行中に来た要求は、BIOS から戻ってから受け付けます）。
- 例：`irqtest.z80`（割り込み）、`gvtest.z80`（グラフィック）、`keytest.z80`（キーボード）

**扱っていないもの**：FM 音源（OPN）、テキスト画面（CRTC/DMA）、N88-BASIC の ROM、ディスク装置。CP/M のコンソール出力は PC のテキスト画面に出るので、グラフィック表示中は見えません。

ポートの動作は MAME の [pc8001.cpp](https://github.com/mamedev/mame/blob/master/src/mame/nec/pc8001.cpp)、[pc8801.cpp](https://github.com/mamedev/mame/blob/master/src/mame/nec/pc8801.cpp)、[pc88_kbd.cpp](https://github.com/mamedev/mame/blob/master/src/mame/nec/pc88_kbd.cpp)、[i8214.cpp](https://github.com/mamedev/mame/blob/master/src/devices/machine/i8214.cpp) を参考にしています。

## z80em86 に加えた変更

変更の一覧は [emu/doc/ChangeLog](emu/doc/ChangeLog) と、各ソースファイルの冒頭にあります。主なものは次のとおりです。

- 非公式命令（新規ファイル `undoc.asm`）。`LD I,A` のバグ修正、R レジスタの正確なカウント、BC=0 のブロック命令
- T ステートの表（`timing.asm`、`scripts/gen-timing.py` で Zilog UM0080 の値から生成）、600Hz のタイマーによる速度調整と割り込み（`timer.asm`）
- 88 モード（`pc88.asm`、`io88.inc`）
- ALINK（ビルド時に取得するリンカ）の修正：32KB を超える near ジャンプを黙って書き込まない問題

## ライセンス

- `emu/` の z80em86 とその改造：**GPL v2 以降**（Copyright (C) 1992-2009 Stewart Kay、改造部分も GPL v2）。[emu/doc/license.txt](emu/doc/license.txt)
- このリポジトリのそれ以外のファイル（Makefile、scripts、テストプログラム）：GPL v2 以降（[COPYING](COPYING)）
- 取得して使う第三者のソフトウェアは、それぞれの license に従います。特に **CP/M 3 一式（`cpm3_z80em86.zip`）のカスタマイズ部分は個人利用に限られている**ため、リポジトリには含めていません。

## 参考資料

- [Zilog Z80 CPU User Manual (UM0080)](https://www.zilog.com/docs/z80/um0080.pdf)：命令とタイミングの基準
- [z80em86 と CP/M 3（The Unofficial CP/M Web Site）](http://www.cpm.z80.de/source.html)
- [Frank Cringle's Z80 instruction set exerciser (ZEXDOC/ZEXALL)](https://mdfs.net/Software/Z80/Exerciser/)
- [NASM](https://www.nasm.us/)、[FreeDOS EDIT](https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/repositories/1.3/base/)、[ZMAC（Al Hawley）](https://cpm.retropc.se/cpm/develop.html)
