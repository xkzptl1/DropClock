# DropClock

*English: [README.md](README.md)*

DropClock は **1280×720 の透過ディスプレイ**向けに作った Windows 用の時計です。

時刻の数字も、文字も、季節の柄も、スプライトとして描いているわけではありません。画面上端のエミッタ列から出た水が重力で落下し、**その途中の一瞬だけ形として読める**。そのあとも加速し続け、縦に伸びて崩れ、画面外へ消えていきます。何も表示されていない時間も作品の一部です。

**ソフトウェアのみの描画**です。物理的な水の装置を制御するものではありません。

## ダウンロード

**[最新の Windows ビルドをダウンロード](https://github.com/xkzptl1/DropClock/releases/latest)**
— `DropClock.exe` 単体で動きます。インストール不要、ランタイムも不要です。

**署名していないバイナリ**なので、初回起動時に Windows SmartScreen の警告が出ます。
**「詳細情報」→「実行」** で起動してください。同じリリースに入っている
`DropClock.console.exe` は、コンソール出力が見える同一ビルドです（診断用）。

## 現在の状態

動作するプロトタイプ。

- 時刻（`HH:MM`）・曜日・日付
- 装飾柄 6 種: 青海波 / 桜 / 梅 / ストライプ / カーテン / 音符と五線譜
- 時刻と柄と無表示を織り交ぜたシーケンス再生
- ボーダーレス全画面、マルチモニター選択、設定オーバーレイ、Windows 自動起動
- 1280×720 で 60fps

未実装: 夏・秋・冬の柄、着水スプラッシュ、スクリーンセーバー化。

## 必要なもの

- Windows 10/11
- ソースから動かす場合は [Godot 4.7](https://godotengine.org/)（書き出した `.exe` には不要）

## 実行

```bash
godot --path . -- --dev
```

主な引数:

| 引数 | 意味 |
|---|---|
| `--dev` / `--dev=WxH` | ウィンドウ表示・カーソルあり |
| `--screen=N` | 全画面表示するモニター番号 |
| `--list-screens` | 接続モニターを表示して終了 |
| `--pattern=ID` / `--live` | 柄をプレビュー（静止 / 動かす） |
| `--list-patterns` | パターンライブラリを表示して終了 |
| `--glyph-test=TEXT` | 文字を形成位置に静止表示 |
| `--season=NAME` | 季節を強制 `spring` / `summer` / `autumn` / `winter` |
| `--mode=NAME` | 描画モード `segments`（既定）/ `drops` |
| `--cycle=SECONDS` | 一巡の長さ |
| `--capture=FILE` | PNG を保存して終了 |
| `--autostart=on\|off\|status` | Windows 自動起動（書き出した `.exe` でのみ動作） |

`Esc` で終了。`Ctrl+Alt+D` で設定オーバーレイ。

## ビルド

ソースからビルドする場合のみ必要です。動かすだけなら
[リリースビルド](https://github.com/xkzptl1/DropClock/releases/latest) を使ってください。

```bash
godot --headless --path . --export-release "Windows Desktop" export/DropClock.exe
```

Godot 4.7 の Windows エクスポートテンプレートが必要です。`export_presets.cfg` はバージョン管理していない（`.gitignore` 参照）ため、ローカルで作り直してください。`Windows Desktop` プリセットで、pck 埋め込み・コンソールラッパー有効・`include_filter="assets/patterns/*.txt"`（これがないと**書き出した版だけ柄が消えます**）。

## 仕組み

**水の単位は「粒」ではありません。** エミッタ列の各レーンには弁があり、`OPEN` から `CLOSE` までの間に出た水がひとつながりの単位になります。短ければ粒、長ければ水糸、閉じなければカーテン。

柄はマスクとして持ちます。同じレーン上で**縦に連続したセルは 1 本のパルスへ統合**され、独立した水滴にはなりません。これが粒・水糸・カーテンを単一の仕組みから出す鍵です。統合の効果は大きく、カーテンの柄では 47,040 セルが 336 パルスになります。

弁の開閉時刻は、形成させたい瞬間から逆算します。

```text
open_time  = 形成時刻 − time_to_fall(連続領域の下端)
close_time = 形成時刻 − time_to_fall(連続領域の上端)
```

形成後は先端のほうが速いので、セグメントは自然に伸びて崩れます。**崩壊のアニメーションは書いていません。**

## 正準キャンバス

シミュレーションはすべて **1280×720 固定**の座標系で行います。ウィンドウサイズ・DPI・最大化/復元・モニター移動は、最終的な表示変換（一様スケール + レターボックス）にしか影響しません。エミッタ間隔・柄の配置・重力・タイミングは一切変わりません。

## ドキュメント

- [docs/DROP_CLOCK_SPEC.md](docs/DROP_CLOCK_SPEC.md) — 製品・表示仕様
- [docs/WATER_RENDERING.md](docs/WATER_RENDERING.md) — 落下する水の描画仕様
- [docs/SAKURA_PATTERN.md](docs/SAKURA_PATTERN.md) — 桜 / 春の仕様
- [docs/REFERENCE.md](docs/REFERENCE.md) — 公開参考資料
- [docs/IP_NOTES.md](docs/IP_NOTES.md) — ソフトウェア限定の境界に関する覚書
- [docs/GITHUB_RELEASE.md](docs/GITHUB_RELEASE.md) — 公開・リリース要件

## 独立性 / 帰属

DropClock は、プログラム制御による水のカーテンや重力落下型の水表示に着想を得た、**独立したソフトウェアのみの視覚シミュレーション**です。物理的な水表示機器を制御するものではなく、JR西日本・大阪ステーションシティ・株式会社光栄の制御ソフトウェアや意匠と提携・承認・派生の関係にはありません。

柄の形状はすべて独自に生成したもので、第三者の画像をトレースしたり同梱したりしていません。

## ライセンス

[MIT](LICENSE)
