# Shelf

ファイルの一時置き場になるフローティングシェルフ。メニューバーに常駐する macOS アプリ。

ファイルをドラッグしている最中にカーソルを振るとシェルフが現れる。ファイルをいったんシェルフに置き、後から別のアプリへドラッグして渡せる。元のファイルは移動も変更もされない。

- macOS 14 以降。Apple Silicon と Intel のユニバーサルバイナリ。
- ad-hoc 署名（Developer ID の署名と公証はしていない）。
- 仕様は [docs/PRD.md](docs/PRD.md)、OS の挙動の検証結果は [docs/verification.md](docs/verification.md) を参照。

## 使い方

### シェルフを開く

- **シェイク**：ファイルなどをドラッグしたまま、カーソルを左右に素早く振る。カーソルのそばにシェルフが出る。
- **ショートカット**：どのアプリを使っていても ⌃⌥⌘N で空のシェルフを開ける。
- **メニュー**：メニューバーのアイコン →「新規シェルフ」。

シェルフは同時に 10 個まで開ける。シェルフを操作しても、使っているアプリからフォーカスは移らない。全 Space とフルスクリーンのアプリの上にも出る。

### 置く・取り出す

- 置けるもの：ファイル（複数可）、ブラウザのテキスト・URL・画像。テキストは `.txt`、URL は `.webloc` としてシェルフの一時ファイルになる。
- 項目をドラッグして別のアプリへ渡す。ハンドル右端のアイコン（項目数を表示）をドラッグすると、全項目をまとめて渡せる。
- 取り出しは常にコピーになる。同じボリュームの Finder へドロップしても原本は元の場所に残る。
- 取り出した項目はシェルフから消え、空になったシェルフは自動で閉じる。上部のハンドルで移動、× で閉じる。
- 置いた後に原本を移動・リネームしても追従する。削除またはゴミ箱へ移動すると「見つかりません」と表示され、取り出せなくなる（戻せば再び取り出せる）。
- シェルフを閉じると、その一時ファイルは削除される。シェルフの内容はアプリを終了すると残らない。

### メニュー

| 項目 | 内容 |
|---|---|
| 新規シェルフ | 空のシェルフを開く。横に現在のショートカットを表示する |
| 新規シェルフのショートカット… | ショートカットを変更・解除する。押した組み合わせが記録され、Return で決定、Esc で取り消し。⌃・⌥・⌘ のいずれかを含む組み合わせか F1〜F20 に限る |
| シェイクで開く | シェイクでシェルフを開くかどうか |
| 感度 | シェイクの感度（標準・高・最高）。高いほど少ない振りで開く |
| ログイン時に開く | ログイン項目に登録する（`SMAppService`）。システム設定 → 一般 → ログイン項目でオフにされているとチェックが「−」になり、選ぶとシステム設定が開く |
| Shelf を終了 | 終了する |

Accessibility などの追加の権限は求めない。

## インストール

### この Mac でビルドする

Xcode が必要。Shelf を終了してから実行する（起動中だと止まる）。

```sh
scripts/install.sh
```

Release 構成でビルドし、`/Applications/Shelf.app` を置き換えて起動する。

- 成果物は `build/DerivedData.noindex/Build/Products/Release/Shelf.app`（`build/` は git の管理外）。`.noindex` は、ビルドした Shelf.app を Spotlight に出さないため。
- Xcode から Debug 実行したものと `/Applications` のものは同じ Bundle ID なので、同時に起動しない。

### 他の Mac に入れる

GitHub Releases の `Shelf.zip` を `/Applications` に展開する。Xcode と clone は不要。

インストールと更新（Shelf を終了してから）:

```sh
curl -fL -o /tmp/Shelf.zip https://github.com/keimvm/shelf-app/releases/latest/download/Shelf.zip && rm -rf /Applications/Shelf.app && ditto -x -k /tmp/Shelf.zip /Applications
```

- ブラウザでダウンロードした場合は Gatekeeper に止められる。システム設定 → プライバシーとセキュリティ →「このまま開く」で 1 回許可する。`curl` でダウンロードした場合は止められない見込み（未確認）。
- 「ログイン時に開く」は Mac ごとに設定する。

## 開発

### テスト

```sh
xcodebuild test -project Shelf.xcodeproj -scheme Shelf
```

### リリース

1. `MARKETING_VERSION`（Xcode のターゲット設定の Version）を上げる。
2. コミットして `git push` する。
3. 実行する:

```sh
scripts/release.sh
```

`build/Shelf.zip` を作り、GitHub Release `v<MARKETING_VERSION>` として公開する。次のいずれかなら止まる：未コミットの変更がある、HEAD が push されていない、同じバージョンが公開済み。`scripts/release.sh --dry-run` は zip を作るだけで公開しない。

### アイコン

`Shelf/Resources/Assets.xcassets/AppIcon.appiconset` の PNG は `swift scripts/make-icon.swift` で生成する。デザインを変えるときはスクリプトを編集して再生成する。

## ライセンス

MIT。[LICENSE](LICENSE) を参照。
