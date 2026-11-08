# AGENTS.md — z80em86-88（このリポジトリ専用のルール）

ユーザー共通のルールは `/home/ponzu/AGENTS.md`（リポジトリの外）にあります。先にそちらを読み、このファイルはその上に足すものとして扱ってください。
作業の経緯と、引き継ぎの時点での状態は [docs/handoff_11-09-2026_06-44-13.md](docs/handoff_11-09-2026_06-44-13.md) にあります。

## このリポジトリは何か

- DOSBox-X の中で、遅い PC（486 / 8086）を再現して x86 と Z80 のアセンブリを学ぶ環境です。概要と使い方は [README.md](README.md) を見てください。
- ユーザーは 42Tokyo の学生で、**DOS と x86 アセンブリの初心者**です。今は [docs/lesson-dos-asm.md](docs/lesson-dos-asm.md) の課題を順に解いています。
- 標準の実行環境は、**本物の MS-DOS 4.00**（[microsoft/MS-DOS](https://github.com/microsoft/MS-DOS) のソースからビルド）です。`make run` で起動します。

## 場所

| もの | パス |
|---|---|
| ユーザーが使う main の作業フォルダー | `/home/ponzu/Documents/dosbox`（branch `main`） |
| エージェント用の worktree（使っていた場合） | `/home/ponzu/Documents/dosbox/.claude/worktrees/<名前>` |
| remote | `origin` = `github.com/keusidan/z80em86-88` |
| ユーザーのスクリーンショット | `/home/ponzu/capture/`（DOSBox-X の F12+P、または DOSBox-X のメニューで撮ったもの。ファイル名の例：`guest os_006.png`） |
| ユーザーの作業ファイル（git に入れない） | main の `work/`（MS-DOS の B:）、`LESSON/`、`MEMO.TXT` |

## 変更を頼まれたときの流れ（ユーザーとの取り決め）

1. 変更して、検証する（下の「検証のしかた」）。
2. 作業している branch に commit して、その branch を push する。
3. main の作業フォルダーを fast-forward する：`git -C /home/ponzu/Documents/dosbox merge --ff-only refs/heads/<branch>`
4. main を push する：`git -C /home/ponzu/Documents/dosbox push origin main`
5. commit の hash と、push したものを報告する。

- ユーザーは main の作業フォルダーで `make run` などを打ちます。worktree に残しただけの変更は、ユーザーには届きません。
- force push（`--force`、`--force-with-lease`）と remote の branch 削除はしません。fast-forward や push が拒否されたら、merge / rebase / force で通さず、止めてユーザーに相談します。
- 質問や説明だけの依頼では、commit しません。
- push の前に、秘密情報や `.gitignore` の対象（第三者のツール、CP/M 3 の一式）が入っていないことを確かめます。

## 画面とウィンドウのルール（重要）

- **エージェントが自分で試すとき、デスクトップにウィンドウを出さない。** ウィンドウが開くたびに、ユーザーのフォーカスが奪われます。
  - DOSBox-X：`-silent`（画面を出さず、autoexec が終わると終了する）。長い手順は 8.3 形式の短い名前の `.bat` に書き、`-c "call c:\scripts\xxx.bat"` の 1 行で呼ぶ（`-c` が 11 行ほどを超えると、黙って無視された）。結果はファイルに書かせて読む。
  - QEMU：`scripts/qemu-run.sh`（`-display none`、monitor の unix socket で `sendkey` と `screendump`）。PNG は `build/qemu/` にできる。
  - Flatpak 版の DOSBox-X からは、ホストの `/tmp`（エージェントの scratchpad を含む）が見えない。試験用のファイルは、プロジェクトの `build/` の下に置く。
- **デスクトップ全体のスクリーンショットを撮らない**（spectacle、import、grim など）。見るのは、ユーザーが送ったスクリーンショットか、上の方法で撮った画面だけ。
- ユーザーが自分で開く DOSBox-X のウィンドウは、画面の右側に出す（左で動画を見ているため）。`scripts/cpm-run.sh` の `WINPOS`（既定 `1800,40`）。
- `pkill -f <語>` は、その語が自分のシェルのコマンドラインにも含まれていると、自分のシェルまで消える。プロセスは PID で止める。

## CPU の速さ

**CPU を速くしない**（ユーザーの方針）。`slow486.conf` の `cycles=fixed 300` はそのままにします。時間がかかることも、当時を体験する学びの一部です。
エージェントが自分の試験やビルドで `-set "cpu cycles=max"` を使うのはかまいません（`scripts/msdos4-*.sh` はそうしています）。

## 構成の要点（MS-DOS 4.00）

| ドライブ | 中身 | 注意 |
|---|---|---|
| A: | `build/msdos4.img`（360KB の起動フロッピー） | `jpkey.asm`、`scripts/mk4img.bat`、`scripts/msdos4.aut`、`scripts/msdos4-img.sh` のどれかが新しくなると、`make` が作り直す（A: に書いたものは消える） |
| B: | `build/work.img`（1.44MB）。ホストの `work/` と同期 | 起動前に `work/` → B:（push）、DOSBox-X を閉じたあとに B: → `work/`（pull）。**一番上のファイルだけ**。8.3 形式の英数字の名前だけ。前回の B: は `build/work.prev.img` に残る |
| C: | 起動時のプロジェクトフォルダー | Makefile の `DOSBOX` が `mount c` してから `boot` するので、DOSBox-X が FAT に変換してゲストに見せる。**ゲストから書いたものはホストに戻らない**（2026-11-03 に試験で確認） |

- 起動直後の PATH は空です。ユーザーは毎回 `path a:\;c:\nasm` と打ちます（AUTOEXEC.BAT に入れる案は、ユーザーが「今はしない」と答えた）。
- NASM 3.02（DJGPP 版、`C:\NASM\NASM.EXE`、1.7MB）は、`CWSDPMI.EXE` を自動で読み込み、MS-DOS 4.00 の中でも動きます（試験で確認）。遅いのは、0.3 MIPS ほどの CPU で大きな 32 ビットのプログラムを起動するためです。
- キー配列：MS-DOS 4.00 の KEYB / KEYBOARD.SYS には日本語配列がないので、自作の TSR(Terminate and Stay Resident) `jpkey.asm`（INT 09h を横取りし、JP106 の記号を BIOS のキーバッファに入れる）を AUTOEXEC.BAT で読み込みます。QEMU では全記号を確認済み。ユーザーも DOSBox-X で `\` や `:` を問題なく打てている。
- EDLIN は MS-DOS 4.00 のもの（F1 / F2 / F3 のテンプレートが効く）。`make dos` の FreeDOS 版 EDLIN では F3 が効かない。

## 検証のしかた

| 変えたもの | 確かめ方 |
|---|---|
| Makefile | `make -n <target>` |
| 起動フロッピー（`jpkey.asm` など） | `scripts/msdos4-img.sh` のあと、`scripts/qemu-run.sh build/msdos4.img 8 <キー...>` で画面を撮って見る |
| B: の同期 | `scripts/msdos4-work.sh push` → `QEMU_FDB=build/work.img scripts/qemu-run.sh ...` → `scripts/msdos4-work.sh pull` |
| DOSBox-X の中での動き（C: など） | `-silent` で、AUTOEXEC.BAT を差し替えた起動フロッピーの写しを `boot` し、結果を B: に書かせて読む |
| 課題の md | 書いた手順を、上の方法で実際に打って確かめる |

QEMU の `sendkey` の名前：`:` は `shift-semicolon`（US 配列の名前。jpkey が入ると JP の `+` になるので、JP の `:` は `apostrophe`）、Enter は `ret`、`\` は `ro` か `yen`。

## ユーザーへの答え方

- 日本語で答える。初心者なので、コマンドや仕組みは表と短い例で説明し、「なぜそうなるか」も書く。
- スクリーンショットを見るときは、`l` と `I`、`0` と `O` のように紛らわしい文字を**拡大して確かめる**（ユーザーは、わざと引っかけることがある）。
- 試していないことは「未確認」と書く。出典を付ける（Ralf Brown's Interrupt List、NASM のマニュアル、Microsoft Learn、Wikipedia など）。
- 課題の答えを、聞かれる前に全部書かない。ヒントを出し、ユーザーが書いたものを見て直す。
