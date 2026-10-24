# Shelf PRD

仮称 **Shelf**（Bundle ID 仮：`dev.keimvm.Shelf`）。ファイルを一時的に置いておける、フローティングシェルフの macOS ネイティブアプリ。
実装は公開 macOS API のみで独自に設計する。設計の前提になる OS の挙動の検証結果は [verification.md](verification.md) を参照。

## 1. 目的

ファイルを別の場所やアプリへ運ぶとき、ドラッグ元とドラッグ先を同時に画面に出すのは手間がかかる。
ドラッグ中にカーソルを振るだけで「一時置き場」を出し、ファイルをいったん置いて、後から好きなアプリへドラッグして渡せるようにする。

### 成功の条件

- ドラッグ中のシェイクから 1 操作でシェルフが出る。
- 置いたファイルをどのアプリへも普通のドラッグで渡せる。
- シェルフを使っても**元ファイルは移動・変更されない**。

## 2. 対象ユーザーと利用場面

- Finder とアプリ間でファイルを頻繁に運ぶ macOS ユーザー。
- 例：
  - 複数のフォルダから集めたファイルを、まとめてメールに添付する。
  - Safari の画像やテキストを一時的に置き、別のアプリへ渡す。
  - フルスクリーンのアプリへ、別の Space にあるファイルを持ち込む。

## 3. ユーザーストーリー（MVP）

1. ファイルをドラッグしている最中にカーソルを振ると、カーソルのそばにシェルフが現れる。
2. シェルフにファイルを落とすと、そのファイルがシェルフに並ぶ。複数のファイルをまとめて置ける。
3. シェルフの項目を 1 つ、または全部まとめて、別のアプリへドラッグして渡せる。
4. ブラウザのテキストや URL、ファイルを直接持たない画像（File Promise）もシェルフに置ける。
5. シェルフはクリックしてもドラッグ元のアプリからフォーカスを奪わず、移動・クローズができる。
6. メニューバーから、またはどのアプリを使っていてもショートカットキーで、ドラッグなしで空のシェルフを開ける。

## 4. 機能要件

### 4.1 MVP

| ID | 機能 | 要件 |
|---|---|---|
| F1 | メニューバー常駐 | Dock に出ない（`LSUIElement`）。メニュー：新規シェルフ（ショートカットを併記）/ 新規シェルフのショートカット… / シェイク起動の ON/OFF / 感度（標準・高・最高）/ ログイン時に開く / 終了 |
| F12 | 新規シェルフのショートカット | 全アプリで効くショートカットで空のシェルフを開く。既定は ⌃⌥⌘N。メニューから変更・解除でき、設定は保持する。⌃・⌥・⌘ のどれかを含む組み合わせ、または F1〜F20 に限る。ほかのアプリが使っていて登録できない組み合わせは保存しない |
| F2 | ドラッグ検知 | 他アプリで始まったドラッグのうち、ドラッグ用ペーストボードが更新されたものを「外部ドラッグ中」とみなす。自アプリ発のドラッグは対象外 |
| F3 | シェイク検知 | 外部ドラッグ中のカーソル軌跡から、方向の反転が時間窓内に規定回数あればシェイクと判定する。1 回のドラッグで発火は 1 回まで。カーソルが既存シェルフ上にあるときは発火しない |
| F4 | シェルフ表示 | カーソル付近（画面内に収まる位置）に出す。アプリをアクティブにしない。他のウィンドウより手前、全 Space・フルスクリーン上にも表示する。上部のハンドルをドラッグして移動、閉じるボタンで閉じる。シェルフは同時に 10 個まで開ける。10 個開いているときは新しいシェルフを開かず、警告音を鳴らす |
| F5 | 受け入れ | ファイル URL（複数可）、File Promise、プレーンテキスト、Web URL |
| F6 | 取り出し | 項目を個別、または全項目まとめて他アプリへドラッグできる。送り出す操作は `.copy` のみ許可する |
| F7 | 空になったら閉じる | 取り出しで項目がなくなったシェルフは自動で閉じる。File Promise の受信待ちがあれば保留し、全件の受信が成功または失敗で完了した時点でも空なら閉じる |
| F8 | 一時保持 | 通常のファイルは参照（URL + bookmark）だけを保持する。Promise / テキスト / URL はシェルフごとの一時ディレクトリにファイルとして作る |
| F9 | 一時ファイルの掃除 | シェルフを閉じたときにそのシェルフの一時ディレクトリを削除する（取り出しで空になって閉じた場合は、宛先のコピーが終わるのを待つため 30 秒後）。起動時に前回の残りを削除する |
| F10 | 原本の追従 | 原本が移動・リネームされたら bookmark で新しい場所を解決する。解決できない、またはゴミ箱にある場合は項目を「見つかりません」と表示し、取り出し不可にする。戻されたら再び取り出せる |
| F11 | サムネイル | ファイルアイコンまたはサムネイルとファイル名を表示する |

### 4.2 MVP 外（今後の候補）

- 修飾キーを押しながらのドラッグでシェルフを出す
- ノッチへのドロップ
- 初回ドロップ後・画面端へのリトラクト（退避）
- シェルフ内容の永続化、最近のシェルフ
- Quick Look、項目の名前変更・並べ替え
- 複数選択した項目だけをまとめて取り出す
- 画像の生データ（TIFF / PNG データ）の受け入れ
- シェイク判定から除外するアプリ
- 「移動」での取り出し（設定で許可）
- Share Extension、Services メニュー、Shortcuts（App Intents）
- クラウド送信、AirDrop

## 5. 非機能要件

| ID | 区分 | 要件 |
|---|---|---|
| N1 | 原本の保護 | アプリは原本ファイルに一切書き込まない。取り出しは `.copy` のみとし、ドロップ先による移動も起こさない |
| N2 | Sandbox | App Sandbox を有効にする。Entitlements は `app-sandbox`、`files.user-selected.read-write`、`files.bookmarks.app-scope` に限る |
| N3 | 権限 | Accessibility などの追加の権限を要求しない |
| N4 | 性能 | ドラッグしていない間はイベント処理以外の処理をしない。ドラッグ中のシェイク判定は軽量（サンプル数を時間窓で制限）にする |
| N5 | 一時データ | 一時ファイルは Sandbox コンテナの一時ディレクトリ内に限る。シェルフを閉じたら残さない |
| N6 | 依存 | 外部ライブラリを使わない。Swift + AppKit、macOS 14 以降 |
| N7 | 独立性 | 既存アプリのコード・アセット・文言・名称を使わない |

## 6. アーキテクチャ

### 6.1 技術選定

- **Swift + AppKit**。ウィンドウレベル、非アクティブパネル、グローバルイベント監視、ドラッグ API を直接扱う必要があるため、SwiftUI ではなく AppKit を主体にする。
- **Xcode プロジェクト**（`Shelf.xcodeproj`）。Info.plist・Entitlements・署名・Sandbox を標準の手順で扱え、`xcodebuild` でビルドとテストができる。ファイル参照の管理を減らすため、フォルダ同期グループ（`PBXFileSystemSynchronizedRootGroup`）を使う。
- 最小 OS は macOS 14。

### 6.2 構成

```
Shelf.xcodeproj
Shelf/
  App/
    main.swift                   エントリポイント（nib なしで AppDelegate を設定）
    AppDelegate.swift            起動、各コンポーネントの組み立て
    StatusItemController.swift   メニューバー（F1）
    Preferences.swift            UserDefaults（シェイク ON/OFF、感度、ショートカット）
    HotKey.swift                 キーの組み合わせ、メニュー表示用の文字列（F12）
    GlobalHotKey.swift           RegisterEventHotKey による全アプリ共通のショートカット（F12）
    HotKeyRecorder.swift         ショートカットを記録するパネル（F12）
  Drag/
    GlobalDragMonitor.swift      グローバル/ローカルのマウス監視、ドラッグ用ペーストボード監視（F2）
    ShakeDetector.swift          座標列からシェイクを判定する純ロジック（F3）
    ShakeSensitivity.swift       感度ごとの閾値
  Shelf/
    ShelfManager.swift           シェルフの生成・配置・破棄、複数シェルフ管理（F4, F7）
    ShelfPanel.swift             NSPanel サブクラス（F4）
    ShelfViewController.swift    項目一覧（NSCollectionView）
    ShelfItemView.swift          サムネイルと名前（F11）
    ShelfDropView.swift          NSDraggingDestination（F5）
    ShelfDragSource.swift        NSDraggingSource と、取り出しを始めるビュー（F6）
  Items/
    ShelfItem.swift              .file(FileReference) / .generated(URL, kind)
    Shelf.swift                  1 つのシェルフの項目モデル
    InboundReader.swift          NSPasteboard から ShelfItem を作る（F5）
    FileReference.swift          URL + bookmark、解決（F8, F10）
    TemporaryStorage.swift       シェルフごとの一時ディレクトリ（F8, F9）
  Resources/
    Info.plist                   LSUIElement = YES
    Shelf.entitlements
ShelfTests/
  ShakeDetectorTests.swift
  HotKeyTests.swift              修飾キーの変換、記録できる組み合わせ、設定の保持
  GlobalDragMonitorTests.swift   NSEvent を使わず座標・時刻・変更回数を与えて検証
  ShelfManagerTests.swift        シェルフの配置（画面内に収める）
  InboundReaderTests.swift       一意名の NSPasteboard を使う
  TemporaryStorageTests.swift
  ShelfTests.swift
  FileReferenceTests.swift       移動・リネーム・削除・ゴミ箱
```

### 6.3 処理の流れ

```
leftMouseDown ──▶ GlobalDragMonitor: ドラッグ用ペーストボードの changeCount を記録
leftMouseDragged ─▶ changeCount が変化していれば「外部ドラッグ中」
                    └▶ ShakeDetector.add(point, time)
                         └▶ シェイク成立 ──▶ ShelfManager.presentShelf(near: point)
leftMouseUp ────▶ 状態をリセット

ShelfDropView ──▶ InboundReader ──▶ Shelf.append(items)
                    ├ ファイル URL ……… FileReference（参照のみ）
                    └ Promise/テキスト/URL ─▶ TemporaryStorage に書き出し
ShelfItemView / 「すべて」──▶ Shelf.refreshFiles（bookmark を解決）
                    └▶ ShelfDragSource（.copy）──▶ 他アプリ
                         └ 終了時に取り出した項目を削除、空なら ShelfManager.close
```

### 6.4 主要な設計

**ドラッグ検知（F2）**
- `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp])` で他アプリのマウス操作を受ける。自アプリ上の操作はローカルモニタで受け、両方を 1 つの座標列にまとめる（外部ドラッグ中でも、自パネル上の座標はローカルモニタ側に届く。verification.md K6）。
- マウス押下時の `NSPasteboard(name: .drag).changeCount` を記録し、ドラッグ中に値が変わったら外部ドラッグとみなす。ペーストボードの内容はドロップされるまで読まない（プライバシー確認を避けるため）。
- Sandbox 下でもドラッグ中のイベントがグローバルモニタに届くことを確認済み（verification.md U1）。届かない環境に備え、マウス押下中だけ `NSEvent.mouseLocation` をタイマーで取得する方式を代替として残す。

**シェイク判定（F3）**
- 入力は時刻付きの座標。最小移動量未満の動きは無視し、移動方向のベクトルを区間ごとに求める。前の区間と同じ向きに進んでいる間は区間の終点をカーソルに合わせて進め、次の区間が折り返し点から始まるようにする（振り幅が区間長の 2 倍未満だと、始点が振れの中央に残って判定が止まるため。verification.md §3）。
- 前の区間との角度が大きく変わった（120° 超）ら「反転」と数える。方向は問わない。
- 直近の時間窓の反転が規定回数に達したらシェイク成立。
- 感度は「反転回数」「区間の最小長」「時間窓」の組で表す。値は Phase 5 で調整した：標準 4 回・24pt・0.9 秒、高 3 回・24pt・0.8 秒、最高 3 回・20pt・1.1 秒（反転角はいずれも 120°）。照準を合わせる動き（行き過ぎて戻し、少し進める）で反転が 2 回起きるため、どの段階も 3 回以上とする。
- 時刻を外から渡すことで、UI なしで単体テストできるようにする。

**シェルフ（F4）**
- `NSPanel`、`styleMask` に `.nonactivatingPanel`。`level = .floating`、`collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`、`hidesOnDeactivate = false`。`isMovableByWindowBackground` は使わない（項目のドラッグでパネルごと動くため。verification.md K1）。`isMovable = false` にして透明タイトルバーによる移動も止める（タイトルバー内の「すべて」から取り出すとパネルも動くため。verification.md K7）。移動は上部のハンドルで `window.performDrag(with:)` を呼んで行う（`isMovable = false` でも動く）。
- 表示は `orderFrontRegardless`。アプリはアクティブにしない。
- この設定でフルスクリーン Space 上の表示と、非アクティブのままのドロップ受け付けを確認済み（verification.md U4）。
- 「フォーカスを奪わない」の確認には `NSApp.isActive` ではなく `frontmostApplication` を使う（パネルがキーになると `isActive` は `true` になるため。verification.md K5）。

**受け入れ（F5）**
- `registerForDraggedTypes` に、ファイル URL、`NSFilePromiseReceiver.readableDraggedTypes`、文字列、URL を登録する。
- 優先順：ファイル URL → File Promise → URL → テキスト。
- `draggingEntered` は、ソース mask に `.copy` があれば `.copy`、なければ `.generic` を返す（Finder は `.generic` のみを渡すことがある。verification.md K4）。
- 自アプリ発のドラッグ（`draggingSource` が自分）のドロップは受け付けない（verification.md K3）。
- File Promise は `receivePromisedFiles(atDestination:)` でシェルフの一時ディレクトリ内のドロップごとのフォルダへ受け取る（同名ファイルの衝突を避けるため）。受け取りのコールバックはバックグラウンドのキューで呼ばれるので、メインアクターに戻してから項目を追加する。届いたファイルから順にシェルフへ並べる。
- テキストは `.txt`（1 行目をファイル名にする）、Web URL は `.webloc`（ページ名、なければホスト名をファイル名にする）として一時ディレクトリに作る。名前が重複したら「名前 2」のように番号を付ける。長い名前は拡張子と連番を含めて UTF-8 で 255 バイト以内に収め、文字の途中で切らない。
- 既にシェルフにあるファイルを再度ドロップしても、項目は増やさない。

**取り出し（F6, F7）**
- 取り出しを始めるのは各項目のビューと、ハンドルバー右端の「すべて」（取り出せる項目数を表示）。どちらも `acceptsFirstMouse(for:)` で `true` を返す（他アプリが前面のときも 1 回目のクリックでドラッグできるように。verification.md K2）。アイコンや名前のクリックもこのビューで受ける。
- 取り出しは、そのビューで `mouseDown` を受けた後、3pt 以上動いた `mouseDragged` に限って開始する（外部ドラッグ中に迷い込む `mouseDragged` で誤って始まるため。verification.md K3）。
- 開始の直前に原本の場所を解決し直し（F10）、取り出せる項目のファイル URL を pasteboard writer にして `beginDraggingSession` を始める。「すべて」は全項目をまとめて送る。「見つかりません」の項目は送らず、それしかなければドラッグを始めない。
- `sourceOperationMaskFor` は、アプリの外へは `.copy`、アプリ内へは空を返す。Finder への同一ボリュームのドロップでも移動にならないことを確認済み（verification.md U3）。
- `draggingSession(_:endedAt:operation:)` で操作がなし以外なら、取り出した項目をシェルフから外す。空になったらシェルフを閉じる。ただし File Promise の受信待ちがあれば、全件の成功・失敗が確定するまで閉じず、届いたファイルを残す。全件失敗して空のままなら、その時点で閉じる。このとき一時ディレクトリは 30 秒後に消す（宛先はドロップの後で非同期にコピーすることがあるため。推測）。生成ファイルの項目を外しても、ファイルはシェルフを閉じるまで残す。

**一時保持（F8〜F10）**
- ファイルはドロップ時に URL と bookmark を作って保持する。原本の中身もメタデータも変更しない。
- Sandbox 下でアクセス権が切れる場合に備え、bookmark は app-scope の security-scoped bookmark とし、利用時に `startAccessingSecurityScopedResource` を呼ぶ。プロセス存続中はドロップで得たアクセス権が続くことを確認済みだが、原本の追従（F10）と将来の永続化のため bookmark は作る（verification.md U3）。
- 原本の追従（F10）：カーソルがシェルフに入ったとき（`NSTrackingArea`、`.activeAlways`）と取り出しの直前に、bookmark を `.withSecurityScope` で解決する。解決した URL には `startAccessingSecurityScopedResource` を呼び、シェルフを閉じるまでアクセスを保つ。stale なら新しい場所で bookmark を作り直す。解決できない、またはパスに `.Trash` / `.Trashes` を含む場合は「見つかりません」とする（bookmark はゴミ箱の中まで追うため）。bookmark は残すので、戻されれば再び見つかる。常時の監視はしない（N4）。
- 生成ファイルの置き場は `FileManager.default.temporaryDirectory/Shelves/<shelfID>/`。シェルフを閉じたときと起動時に削除する。

**新規シェルフのショートカット（F12）**
- 登録は Carbon の `RegisterEventHotKey`。公開 API で、Sandbox 下でも Accessibility の権限なしで使える（N3）。`NSEvent.addGlobalMonitorForEvents` でのキー監視は権限が要るので使わない。
- 設定は `UserDefaults` にキーコードと修飾キーで保存する。「なし」は空の辞書で表し、既定値（⌃⌥⌘N）と区別する。
- メニューの「新規シェルフ」には、実際に登録できているショートカットだけを `keyEquivalent` で表示する。キーの文字は現在の ASCII 入力用レイアウトから求める（日本語入力中でも「N」と出すため）。
- 記録は、`.nonactivatingPanel` のパネルをキーにして受ける。メニューバーの項目から `NSApp.activate()` してもアプリはアクティブにならず、`NSAlert` ではキー入力を受けられなかった。パネルはアクティブにしなくてもキー入力を受けた（いずれも合成したクリック・キー入力で確認）。記録中は現在のショートカットの登録を外し、押した組み合わせがパネルに届くようにする。
- ほかのアプリがすでに登録している組み合わせは、押してもパネルに届かない（確認済み。推測：先に登録した側が受け取るため）。

### 6.5 ビルドと配布

手順は [README](../README.md) に書く。

- ビルドは Release 構成で `build/DerivedData.noindex` に出す（`scripts/build.sh`）。成果物は `build/DerivedData.noindex/Build/Products/Release/Shelf.app`。
- 自分の Mac では `/Applications/Shelf.app` に置いて使う（`scripts/install.sh`）。
- 他の Mac には GitHub Releases（プライベートリポジトリ）で配る。`scripts/release.sh` が `ditto` で zip にして `v<MARKETING_VERSION>` として公開し、受け取る側は `gh release download` で取得する。
- 署名は ad-hoc のまま。Developer ID の署名と公証は、自分以外に配るときに検討する。

## 7. 実装ロードマップ

| Phase | 内容 | 完了条件 |
|---|---|---|
| 0 | スパイク：verification.md の U1〜U4 を最小コードで確認 | **完了（2026-10-21）**。結果は verification.md §2、設計への反映は本書 §6.4 |
| 1 | プロジェクト雛形、メニューバー、`ShakeDetector` と単体テスト | **完了（2026-10-21）**。`xcodebuild test` が通り、メニューバーにアイコンが出る。「新規シェルフ」は Phase 2 まで無効 |
| 2 | `GlobalDragMonitor` の統合、シェルフの表示・移動・クローズ | Finder のドラッグ中のシェイクでシェルフが出る。**実装完了（2026-10-21）**：ドライバによる実ドラッグで、シェイクでの表示、ハンドルでの移動、閉じるボタン、シェルフ上でのシェイク抑止を確認。Finder からのドラッグとメニューの「新規シェルフ」も手動で確認済み |
| 3 | 受け入れ（ファイル / Promise / テキスト / URL）、`TemporaryStorage` | 4 種類をドロップでき、一時ファイルが閉じると消える。**実装完了（2026-10-21）**：ドライバによる実ドラッグで 4 種類の受け入れ、同じファイルの重複除外、閉じたときの一時ディレクトリ削除を確認。Safari からのテキスト・URL・画像も手動で確認済み |
| 4 | 取り出し（個別・全項目、`.copy`）、空になったら閉じる、bookmark での追従 | 受け入れ基準をすべて満たす。**実装完了（2026-10-21）**：ドライバによる実ドラッグで、Finder への個別・全項目の取り出しが `.copy` になること（宛先は新しい inode、原本の inode・更新日時・SHA-1 は不変）、全項目の取り出しでシェルフが閉じ一時ディレクトリが 30 秒後に消えること、原本のリネームへの追従、削除・ゴミ箱への移動で「見つかりません」になり取り出せないこと、ゴミ箱から戻すと再び取り出せること、自パネルへのドロップでは項目が残ることを確認。メール・Safari への取り出しと、Promise・テキスト・URL の項目の取り出しは Phase 5 で確認（verification.md §3.4） |
| 5 | 感度の調整、受け入れテスト | 3 段階の感度で誤検知と未検知が許容範囲。**実装完了（2026-10-22）**：`ShakeDetector` の判定が止まる不具合を直し、合成した軌跡のシミュレーションと実ドラッグで閾値を選んだ（verification.md §3）。受け入れ基準はドライバによる実ドラッグですべて確認。実際のマウス・トラックパッドでの体感確認は手動確認が残る |

## 8. 受け入れ基準

2026-10-22 に、ドライバによる実ドラッグ（合成マウスイベント）ですべて確認した（verification.md §3.4）。

- [x] `xcodebuild test -scheme Shelf` で `ShakeDetector`、`InboundReader`、`TemporaryStorage`、`Shelf` のテストが通る。
- [x] Finder からファイルをドラッグしてカーソルを振ると、カーソル付近にシェルフが出る。フルスクリーンの Space 上でも出る。
- [x] ドラッグしていないとき、およびウィンドウの移動や範囲選択などドラッグ用ペーストボードを更新しない操作中にカーソルを振っても、シェルフは出ない。
- [x] シェルフに置いたファイルを Finder・メール・Safari へドラッグするとコピーされる。原本のパス・更新日時・内容（`stat` / `shasum` で比較）が変わらない。
- [x] 同じボリュームの別フォルダへドロップしても、原本は元の場所に残る。
- [x] Safari からテキスト・URL・画像（Promise）をドロップすると一時ファイルができ、シェルフを閉じると消える。
- [x] 全項目を取り出すとシェルフが閉じる。
- [x] 原本をリネームしてもシェルフの項目から取り出せる。原本を削除すると「見つかりません」になる。
- [x] シェルフを操作しても、ドラッグ元のアプリがアクティブなままである。
- [x] Accessibility 等の権限ダイアログが出ない。

今回の修正の手動確認手順（実操作は未確認）:

- ファイルを 1 件置いたシェルフに、受信に時間がかかる画像などの File Promise をドロップする。先に置いたファイルを取り出しても閉じず、受信後に画像が並ぶこと、その画像を取り出すと閉じることを確認する。
- 長いページ名（例: ASCII 260 文字）のリンクを同じシェルフに 2 回ドロップする。名前が短縮された 2 件のリンクが並び、拡張子と重複時の番号が残り、どちらからも元の URL を開けることを確認する。

## 9. リスク

| リスク | 影響 | 対策 |
|---|---|---|
| Sandbox 下でドラッグ中のマウスイベントがグローバルモニタに届かない（U1） | シェイク検知ができない | 解消（届くことを確認）。ポーリングは代替として残す |
| ドラッグ用ペーストボードの読み取りでプライバシー確認が出る（U2） | 操作のたびにダイアログ | 解消（ドラッグ用は常に許可）。内容はドロップ時だけ読む方針は維持 |
| ドロップしたファイルへのアクセス権が切れる（U3） | 取り出し・サムネイルが失敗 | 解消（プロセス存続中は維持）。bookmark はドロップ直後に作成 |
| フルスクリーン上で表示されない・ドロップを受けない（U4） | 主要な利用場面で使えない | 解消（`.floating` で表示・受け付けを確認） |
| シェイクの誤検知・未検知 | 操作感の低下 | 感度 3 段階、1 ドラッグ 1 回の制限。照準の修正（反転 2 回）では発火しないよう全段階で反転 3 回以上。合成軌跡で調整済み（verification.md §3）で、実際の手での調整は残る |
| 一時ファイルの残留 | ディスクの浪費 | 閉じたときと起動時に削除 |
