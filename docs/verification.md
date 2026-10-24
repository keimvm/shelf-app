# 検証記録

設計の前提になる OS の挙動を、使い捨てのスパイクコードで確かめた記録。
各記述は **事実**（観察済み・根拠あり）、**推測**（事実からの推論）、**未確認**（未検証）に分類する。

## 1. 検証項目

| ID | 確認内容 | 方法 | 不成立時の代替 |
|---|---|---|---|
| U1 | Sandbox 下で他アプリ発のドラッグ中に `leftMouseDragged` がグローバルモニタへ届くか | Finder からファイルをドラッグし、イベント受信をログ | `NSEvent.pressedMouseButtons` が押下中の間だけ 60Hz タイマーで `NSEvent.mouseLocation` をポーリング |
| U2 | `NSPasteboard(name: .drag)` の `changeCount` / `types` 読み取りでプライバシー確認が出ないか | 同上、確認ダイアログの有無を確認 | `changeCount` のみで判定し、内容はドロップ時にだけ読む |
| U3 | ドロップで得たファイル URL へのアクセスがプロセス存続中維持されるか | ドロップ後に時間をおいて読み取り・サムネイル生成・ドラッグアウト | ドロップ直後に app-scope bookmark を作成し、利用時に `startAccessingSecurityScopedResource` |
| U4 | パネルがフルスクリーン Space 上に出て、非アクティブでもドロップを受けるか | `level` = `.floating` / `.statusBar`、`collectionBehavior` の組み合わせを比較 | レベルを上げる、`.stationary` を追加 |

| ID | 状態 | 結果の要約 |
|---|---|---|
| U1 | 確認済み（合成イベント） | Sandbox 下でも、他アプリ発のドラッグ中の `leftMouseDragged` / `leftMouseUp` がグローバルモニタに届く。ポーリングも使える |
| U2 | 確認済み | `changeCount` / `types` は読める。ドラッグ用ペーストボードの `accessBehavior` は常に許可（`.alwaysAllow`）。確認ダイアログの記録なし |
| U3 | 確認済み | ドロップした URL は 60 秒後も読め、app-scope bookmark も作れて解決できる。`.copy` のみの取り出しで原本は不変 |
| U4 | 確認済み（`.floating`） | フルスクリーン Space 上でも表示され、非アクティブのままドロップを受ける |

## 2. Phase 0 検証結果（2026-10-21）

### 2.1 方法

- コード：[spikes/phase0](../spikes/phase0/README.md)。いずれも使い捨て。
  - `ShelfSpike`：検証対象。App Sandbox 有効（ad-hoc 署名、Entitlements は `app-sandbox`・`files.user-selected.read-write`・`files.bookmarks.app-scope`）、`LSUIElement`。パネルは `NSPanel`（`.nonactivatingPanel`）、`level = .floating`、`collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`、`hidesOnDeactivate = false`。
  - `DragSource`：Sandbox なしの補助アプリ。Finder と同じく全操作（mask = 23）を許可してファイルドラッグを開始する。
  - `Driver`：`CGEvent` を HID イベントタップへ送り、マウス操作を再現する。
- 結果はすべて統合ログ（subsystem `dev.keimvm.ShelfSpike`）で記録した。
- ドラッグ元として `DragSource` と **Finder**（リスト表示の項目）の両方を使った。
- 環境：macOS 27.0.1（26A434）、内蔵ディスプレイ 1台（1800×1169pt）。

### 2.2 結果

#### U1：Sandbox 下でのドラッグ中イベント受信 — 確認済み

**事実**
- 起動時に `APP_SANDBOX_CONTAINER_ID` があり、ホームはコンテナ（`~/Library/Containers/dev.keimvm.ShelfSpike/Data`）。付与していないファイルの読み取りは失敗した（対照実験：`readable=false`）。Sandbox は有効に働いている。
- `DragSource` 発、Finder 発のどちらのドラッグでも、ドラッグセッション中の `leftMouseDragged` がグローバルモニタに届いた（1 回のドラッグで 108 件、ドラッグ用ペーストボード更新後に届いたのも 108 件）。終了の `leftMouseUp` もグローバルモニタに届いた。
- Accessibility 権限の確認は出ていない（`ShelfSpike` は権限を要求していない）。
- ポーリング（60Hz タイマーで `pressedMouseButtons` / `mouseLocation`）でも同じドラッグを追えた（1 回のドラッグで約 210 サンプル）。
- カーソルが自アプリのパネルに入ると、`leftMouseDragged` が 1 件だけ**ローカル**モニタ側に届く（毎回 `localDragged=1`）。

**推測**
- グローバルモニタだけでシェイク検知に十分。ポーリングは代替手段として残せる。
- 自パネル上の座標はローカルモニタから来るため、両方のモニタを 1 つの座標列にまとめる必要がある。

**未確認（残り）**
- 合成イベント（`CGEvent`）での検証であり、実際のマウス・トラックパッドの入力ではまだ確認していない。合成イベントもウィンドウサーバーを通る通常の経路で配送されるため、結果は同じになると見込む。

#### U2：ドラッグ用ペーストボードの読み取り — 確認済み

**事実**
- `NSPasteboard(name: .drag).accessBehavior` は `2`（`.alwaysAllow`）。SDK ヘッダ（`NSPasteboard.h`）にも「General 以外のペーストボードの既定は常に許可」とある。
- ドラッグ中に `changeCount` の増加（例：8→9）を検知でき、`types` を読めた。
- 確認された `types`：`public.file-url`、`NSFilenamesPboardType`、`Apple URL pasteboard type` など。Finder 発の場合はさらに `com.apple.finder.node` が付く。
- 検証の間、`pboard` / `tccd` のログに `ShelfSpike` 向けのアクセス確認の記録はなかった。

**補足**
- このアプリでは `NSPasteboard.general.accessBehavior` も `2` だった。General ペーストボードは本アプリでは使わない。

#### U3：ドロップした URL へのアクセスと取り出し — 確認済み

**事実**
- ドロップ時・5 秒後・60 秒後のいずれでも、ドロップされたファイルを読めた。
- ドロップ直後に `.withSecurityScope` の bookmark を作れた（968 バイト）。その bookmark は 5 秒後・60 秒後も解決でき、`startAccessingSecurityScopedResource()` は `true` を返し、stale ではなかった。
- パネルから Finder（同じボリュームの別フォルダ）へ、ソース操作 `.copy` のみで 2 ファイルを取り出した結果：
  - 宛先に新しい inode のファイルができ、内容（SHA-1）は原本と一致した。
  - 原本のパス・inode・更新日時・サイズ・SHA-1 は変わらなかった。
  - `draggingSession(_:endedAt:operation:)` の操作は `1`（`.copy`）。

**推測**
- プロセスが動いている間はドロップで得たアクセス権が続く。MVP（メモリ保持のみ）なら bookmark は必須ではないが、原本の移動追従（F10）と将来の永続化のため、ドロップ直後に作成する設計を維持する。

#### U4：パネルの表示とドロップ受け付け — 確認済み（`.floating`）

**事実**
- `level = .floating`（`CGWindowLayer` = 3）で、通常の Space でも Finder ウィンドウをフルスクリーンにした Space でも、`isOnActiveSpace = true`、`occlusionState` が visible、ウィンドウサーバーの画面上ウィンドウ一覧にも存在した。
- フルスクリーン Space 上でも、パネルはドロップを受け付けた。
- 他アプリからのドロップ受け付け中、`NSApp.isActive = false`、パネルは非キーのまま。
- パネルをクリックすると `NSApp.isActive = true`・パネルがキーになるが、最前面アプリ（`frontmostApplication`）はドラッグ元のアプリのまま変わらなかった。
- `.statusBar` 以上のレベルは不要だった（試していない）。

**未確認（残り）**
- 画面収録の権限がないため、スクリーンショットでの目視確認はできていない。表示はウィンドウサーバーの情報で判断した。
- 外部ディスプレイ、Stage Manager、Mission Control 中の挙動。

### 2.3 実装に反映すべき知見（事実）

| # | 観察 | 実装方針 |
|---|---|---|
| K1 | `isMovableByWindowBackground = true` だと、項目ビュー上のドラッグでもパネルごと移動し、取り出しのドロップが自パネルに落ちた。`mouseDownCanMoveWindow = false` を返しても防げなかった | 背景ドラッグでの移動は使わない。移動はタイトル領域などの専用ハンドルで行い、必要なら `window.performDrag(with:)` を明示的に呼ぶ |
| K2 | 他アプリが前面のとき、項目ビューは最初のクリックで `mouseDown` / `mouseDragged` を受け取らなかった | 項目ビューで `acceptsFirstMouse(for:)` を `true` にする |
| K3 | 外部ドラッグ中にカーソルがパネルへ入ると、項目ビューに `mouseDragged` が 1 件届き、取り出しのドラッグが意図せず始まった。その結果、自パネルへの 2 回目のドロップ（ソース mask = 0）が発生した | 取り出しは、自ビューで `mouseDown` を受けた後の `mouseDragged` に限って開始する。自アプリ発のドラッグ（`draggingSource` が自分）のドロップは受け付けない |
| K4 | Finder 発のドラッグでパネルに届いたソース操作 mask は `4`（`.generic` のみ）だった。`DragSource` では `23` | `draggingEntered` は、mask に `.copy` があれば `.copy`、なければ `.generic` を返す |
| K5 | `NSApp.isActive` はパネルがキーになると `true` になるが、ドラッグ元アプリは最前面のまま | 「フォーカスを奪わない」の判定は `NSWorkspace.shared.frontmostApplication` で行う |
| K6 | 外部ドラッグ中の座標の大半はグローバルモニタ、自パネル上の 1 件はローカルモニタから届く | `GlobalDragMonitor` は両モニタを統合する |
| K7 | （Phase 4 で確認）`.titled` + 透明タイトルバーのパネルで、タイトルバー領域のビューから取り出しを始めると、パネルもカーソルに付いて動き、ドロップが自パネルに落ちた（operation 0）。そのビューとその下のビューで `mouseDownCanMoveWindow = false` を返しても防げず、`isMovable = false` で止まった。`isMovable = false` でも `performDrag(with:)` による移動はできた | パネルは `isMovable = false` にし、移動はハンドルの `performDrag(with:)` だけで行う |

### 2.4 検証環境への影響

- テストファイルは `spikes/phase0/work/` だけに作成し、検証後に削除した。それ以外の場所にファイルはできていない（ホーム配下を検索して確認）。
- Finder の 1 ウィンドウをリスト表示に切り替え、一時的にフルスクリーンにした（解除済み）。
- 目視確認のため `screencapture` を実行したが、画面収録の権限がなく失敗した。直後に最前面アプリがシステム設定になっており、権限の確認画面が出た可能性がある。権限は付与していない。

## 3. Phase 5 検証結果（2026-10-22）

### 3.1 方法

- コード：[spikes/phase5](../spikes/phase5/README.md)。製品には含めない。
  - `Driver`：Phase 0 のドライバを拡張したもの。振り幅・1 振りの時間・回数・角度・イベントレート・揺らぎを指定してシェイクを再現し、どのアプリのウィンドウが開いたかを `CGWindowListCopyWindowInfo` で判定する。
  - `Harness`：製品の `ShakeDetector.swift` をそのままコンパイルし、閾値だけ差し替えて、合成した軌跡（意図的なシェイクと普通のドラッグ）を流す。軌跡は手の動きに近づけるため、各振りを余弦で加減速させ、振り幅と時間を ±20%、横ぶれを ±15% 揺らす。乱数は固定シードで、1 条件につき 20 本。
- 環境：macOS 27、ディスプレイ 2 台（3440×1440pt と 1920×1080pt）。Shelf は Debug ビルド。入力はすべて合成イベント。

### 3.2 シェイク判定が止まる不具合（事実）

- Phase 1〜4 の `ShakeDetector` は、区間が成立した点にだけ基準点を移していた。振り幅が区間長の 2 倍未満だと、基準点が振れの中央付近に残り、両端とも区間長に届かずに反転を数えなくなった。
- 実ドラッグで、調整中の値（反転 3 回・18pt）の「高」が 30pt の振りに一度も反応せず、区間長の長い「標準」（24pt）のほうが反応するという逆転が起きた。同じ軌跡を `Harness` で再生して再現した。
- 前の区間と同じ向きに進んでいる間は基準点をカーソルに合わせて進め、折り返し点を次の区間の始点にするよう直した。この軌跡を回帰テスト（`swingShorterThanTwoSegmentsStillCounts`）にした。旧実装では失敗し、新実装では通る。
- 直した後は、振り幅が区間長以上あれば反転を数える。検出範囲の境界がはっきりした。

### 3.3 閾値の選定

基準：
- 「標準」は、普通のドラッグで発火しないこと（誤検知 0）を優先する。そのうえで、3 往復前後のはっきりしたシェイクは確実に拾う。
- 段階を上げるほど、少ない回数・小さい振り幅・遅い振りで発火する。
- 照準の動き（行き過ぎ → 戻す → 少し進める）で反転が 2 回起きるため、どの段階も反転 3 回以上を必要とする。旧「最高」（反転 2 回・10pt）は、照準の修正、手ぶれ（±6pt）、画面端での跳ね返りで 60〜100% 誤検知した。

決めた値（反転角はいずれも 120°）：

| 感度 | 反転回数 | 区間の最小長 | 時間窓 | 発火する目安（シミュレーション） |
|---|---|---|---|---|
| 標準 | 4 | 24pt | 0.9 秒 | 30pt 以上を 5 振り以上、1 振り 250ms まで |
| 高 | 3 | 24pt | 0.8 秒 | 30pt 以上を 4 振り以上、1 振り 350ms まで |
| 最高 | 3 | 20pt | 1.1 秒 | 30pt 以上を 4 振り以上、1 振り 500ms まで |

普通のドラッグ 15 種での誤検知率（`Harness`、60・120・250Hz で同じ傾向）：

- 3 段階とも 0%：直線、L 字、円、行き過ぎて戻す、戻して少し進める、小さな修正 2 回・3 回、リスト上での ±15pt の揺れ、手ぶれ ±6pt、行って戻って行く（0.25〜0.4 秒ごと）、フォルダを探す斜めの動き、画面端での跳ね返り。
- 「高」と「最高」で 100%：2 つの目標の間を 100pt で 4 回行き来する（0.35 秒ごと）。ほぼシェイクと同じ動きなので許容する。
- 「最高」だけ 100%：±60pt を 0.5 秒ごとにゆっくり 4 回振る。遅いシェイクを拾うための設定なので許容する。

実ドラッグ（Driver、新ビルド）でも同じ傾向だった。
- 標準：5 振り以上で発火、4 振りでは発火しない。1 振り 250ms は境界で、結果がまちまちだった（Driver の実際の振りは指定より 1 割ほど遅い）。
- 高：4 振り以上・250ms まで発火した。
- 最高：4 振り以上・350ms まで発火した。
- 500ms の振りは、どの段階でも発火しなかった。Driver では、指定より遅くなって時間窓を超えたと推測する。

### 3.4 受け入れ確認（Driver による実ドラッグ）

- `xcodebuild test`：48 テストすべて成功。
- Finder（リスト表示）の項目をドラッグ中に振ると、シェイクした位置を中心にシェルフが出た。Finder のウィンドウをフルスクリーンにした Space 上でも出た（画面上に表示、レイヤー 3）。
- ボタンを押さずに振る、Finder の空き領域での範囲選択、Finder ウィンドウの移動では出なかった。対照として、同じ振り方でファイルをドラッグすると出た。
- 取り出しはすべて operation 1（`.copy`）だった。
  - Finder（同じボリューム）：「すべて」で 2 項目を取り出した。宛先は新しい inode で、原本の inode・サイズ・更新日時・SHA-1 は変わらなかった。シェルフは閉じた。
  - メール：新規メッセージの本文に落とし、添付（`a.txt, 6 バイト`）になった。テスト用の下書きは保存せずに閉じた。送信はしていない。
  - Safari：ページ内のドロップ領域で受けた `File` の名前・サイズ・SHA-1 が原本と一致した。
- Safari からテキスト・URL・画像（Promise）を置くと、`.txt`・`.webloc`・`photo.png` が一時ディレクトリにできた。
  - 3 つとも取り出せた。`.txt` は Safari へ、`.webloc` と画像は Finder へ。いずれも SHA-1 が一時ファイルと一致し、`.webloc` の URL も正しかった。
  - 取り出しで空になって閉じたシェルフの一時ディレクトリは 30 秒後に消えた。閉じるボタンで閉じた場合はすぐに消えた。
- 原本をリネームすると、項目名が新しい名前になり、取り出した先も新しい名前だった。ゴミ箱へ移すと「見つかりません」になり、ドラッグが始まらなかった。元に戻すと再び取り出せた。
- ドロップ、ハンドルでの移動、「すべて」からの取り出しの間、`frontmostApplication` は Finder のままだった。
- 権限：tccd のログに Shelf に関する記録はなかった。コードにも権限を要求する API はない。Entitlements は N2 の 3 つのみ。

### 3.5 未確認（残り）

- 実際のマウス・トラックパッドでの操作感。合成イベントは振りの形が規則的なので、実際の手では境界付近の結果が変わりうる。
- 外部ディスプレイをまたぐ移動、Stage Manager、Mission Control 中の挙動。

### 3.6 検証環境への影響

- テストファイルは `spikes/phase5/work/` に作成した（git 管理外）。ゴミ箱へ移したテストファイル 1 つは元に戻した。
- メールで新規メッセージを 1 通作り、送信せず、保存もせずに閉じた。メールは起動したまま。
- Safari に検証ページのタブ（`127.0.0.1:8765`、サーバーは停止済み）、Finder に `work/src`・`work/dest` のウィンドウが残っている。Finder のウィンドウを一時的にフルスクリーンにした（解除済み）。
- Xcode のデバッガ下で動いていた Shelf に SIGTERM を送った。プロセスはデバッガで一時停止したまま残っている。
- Shelf の感度設定を切り替えながら計測し、最後に元の「高」へ戻した。

## 4. Services による「新規シェルフに置く」の検証（2026-10-24）

F13（選択中のファイルをショートカットで新規シェルフに置く）の前提を確かめた。一度は Services で実装したが、新規シェルフのショートカット（F12）と同じキーにできないため採用せず、§5 の方式にした。

### 4.1 方法

- コード：[spikes/services](../spikes/services/README.md)。いずれも使い捨て。
  - `ServiceSpike`：Sandbox 有効（Entitlements は N2 の 3 つ）、`LSUIElement`。`NSServices` に、ファイルを受け取るサービス（`NSSendFileTypes` = `public.item`）と、何も受け取らないサービスを宣言する。受け取った URL の読み取り可否・bookmark の作成可否・`frontmostApplication` をログに出す。
  - `Driver`：`CGEvent` でキーを押す。
- Finder でフォルダを開いて ⌘A で全選択し、サービスのショートカットを押した。
- 製品のビルド（Debug）でも同じ操作をし、棚から Finder へ取り出した。
- 環境：macOS 27.0.1（26A434）。

### 4.2 結果

**事実**
- Finder で選択中のファイル・フォルダが、サービスのペーストボード（`public.file-url`、`NSFilenamesPboardType` など）でファイル URL として届いた。
- 起動時に読めなかったファイル（対照：`readable=false`）も、サービスで受け取った後は読めた。60 秒後も読めた。`.withSecurityScope` の bookmark も作れた。ドロップ（U3）と同じく、Entitlements を増やさずに扱える。
- `NSKeyEquivalent` の既定値は ⌘ 以外の修飾キーも書ける（`$^~@N` = ⇧⌃⌥⌘N）。サードパーティのアプリでも、その既定値のショートカットでサービスが動いた。
- 同じ組み合わせを `RegisterEventHotKey` でも登録していると、ホットキーが受け取り、サービスは動かなかった。
- 同じショートカットを 2 つのサービスに宣言すると、Finder でファイルを選択していてもいなくても、何も受け取らないほうのサービスが動いた（選択の有無で振り分けられない）。
- サービスを実行するとき、システムは提供側のアプリをアクティブにする（ハンドラの時点で `frontmostApplication` が提供側）。`NSApp.deactivate()` では Finder に戻らなかった。直前にアクティブだったアプリ（`NSWorkspace.didActivateApplicationNotification` で記録）に `activate()` すると、Finder が最前面に戻った。
- 提供側が起動していないときは、システムが起動してからハンドラを呼んだ（`servicesProvider` は `applicationDidFinishLaunching` で設定）。この場合、起動時点ですでに提供側が最前面で、直前のアプリを記録できなかった。
- アプリを `open` で起動すると、`pbs -update` を実行しなくてもサービスが登録された（`pbs -dump` で確認）。
- 製品のビルドで、Finder の 2 項目（ファイルとフォルダ）がサムネイル付きで新規シェルフに並び、操作後も `frontmostApplication` は Finder だった。並んだファイルを Finder へ取り出すとコピーになった（operation 1、宛先は新しい inode）。

**推測**
- ⌃⌥⌘N（新規シェルフ）と同じショートカットで「選択があれば置く、なければ空」を切り替える方法は、Services では見当たらない。
- ショートカットの変更はシステム設定（キーボード → キーボードショートカット → サービス）で行える。Sandbox のアプリからは変更できない。

**未確認（残り）**
- 実際のキー入力での確認（合成イベントのみ）。
- Finder 以外のアプリ（ファイルをサービスに渡せるもの）からの利用。
- Shelf が起動していない状態からサービスで起動したときに、元のアプリへフォーカスが戻らないこと（スパイクでは戻らなかった。製品は通常ログイン時に起動しているため影響は小さい見込み）。

### 4.3 検証環境への影響

- テストファイルは `spikes/services/work/` に作成した（git 管理外）。Finder に開いた検証用のタブは閉じた。
- `/Applications/Shelf.app` を一度終了し、検証後に起動し直した。検証用のビルド（`ServiceSpike.app`、Debug の `Shelf.app`）は LaunchServices から登録を外した。
- 取り出しの試行のうち 1 回は、ドロップ位置が Finder ではなく Claude のウィンドウ上になり、そちらが `a.txt` を受け取った（operation 1）。

## 5. Apple Events による Finder の選択項目の取得（2026-10-24）

F13 を新規シェルフのショートカット（F12）と同じキーで実現する方式を確かめた。ショートカットを押した時点で Finder に選択を問い合わせる。

### 5.1 方法

- コード：[spikes/finder-open](../spikes/finder-open/README.md)。使い捨て。
  - `OpenSpike`：Sandbox 有効、`LSUIElement`。開くよう渡されたファイル（`application(_:open:)`）と、渡されていないファイル（対照）について、読み取り・bookmark の作成・解決をログに出す。
- Finder への問い合わせは製品のビルドで確かめた。Driver（spikes/services）で F1（`fn` 付き）を押し、Phase 0 の `ShelfSpike`（Sandbox 有効）を取り出し先にした。
- 環境：macOS 27.0.1（26A434）。

### 5.2 結果

**事実**
- Finder に「選択項目を Sandbox のアプリで開く」よう頼む方法（`open selection using <app>`）は使えなかった。書類タイプを宣言していないと `kLSAppDoesNotClaimTypeErr`（-10820）。`CFBundleTypeRole` = `None` でも同じ。`Viewer`（`LSHandlerRank` = `None`）にすると、今度は「呼び出し元にその場所への Sandbox アクセスがない」として -54 で拒否された。Sandbox の外から AppleScript を送っても同じだった。`open -a` で同じアプリに渡すと、拡張付きで開けた。
- 失敗したときは CoreServicesUIAgent がエラーを表示した（`frontmostApplication` が `com.apple.coreservices.uiagent` になった）。
- Sandbox のアプリは、渡されていないファイルを読めず、bookmark も作れない（`Could not open() the item`）。
- `temporary-exception.files.absolute-path.read-only`（`/`）を付けると、渡されていないファイルを読めた。security-scoped bookmark は作れなかった（同じエラー）が、通常の bookmark は作れ、リネーム後に新しい場所へ解決できた（stale = true）。通常の bookmark を `.withSecurityScope` 付きで解決すると失敗した。
- 例外を付けたアプリで `~/Desktop` を読もうとすると、tccd に `kTCCServiceSystemPolicyDesktopFolder` の記録ができた。
- 製品（Entitlements に `automation.apple-events`、`temporary-exception.apple-events` = `com.apple.finder`、上の読み取り例外を追加）で：
  - 設定をオンにすると「オートメーション」の確認が出て、許可すると `AEDeterminePermissionToAutomateTarget` は `noErr` を返した。
  - Finder でファイル 2 つとフォルダ 1 つを選択して F1 を押すと、3 項目が並んだ新規シェルフが開いた。Finder は最前面のままだった。選択が 1 項目のときは 1 項目だけが並んだ。
  - そのファイルを `ShelfSpike`（Sandbox 有効）へドラッグすると、受け取り側で読めて security-scoped bookmark も作れた（operation 1）。
  - 原本をリネームしてカーソルを棚に乗せると、項目名が新しい名前になった。

**推測**
- Shelf が拡張を発行できるのは、読み取り例外で読めるため。
- デスクトップ・書類など保護されたフォルダの項目は、フォルダごとに初回だけ macOS がアクセスの許可を確認する。

**未確認（残り）**
- 実際のキー入力での確認（合成イベントのみ）。
- 保護されたフォルダ（デスクトップ・書類・ダウンロード・iCloud Drive）の項目での動作と、確認を拒否したときの表示。
- 外部ボリューム・ネットワークボリュームの項目。

### 5.3 検証環境への影響

- テストファイルは `spikes/finder-open/work/` に作成した（git 管理外）。リネームした原本は元に戻した。
- `OpenSpike` が `~/Desktop` を読もうとしたため、デスクトップフォルダへのアクセスの確認が出た可能性がある（確認中にプロセスを終了した）。
- Finder に開かせる試行で、CoreServicesUIAgent のエラーダイアログが何度か出た可能性がある。
- `/Applications/Shelf.app` を入れ替えた。メニューの「ショートカットで Finder の選択項目を置く」をオンにし、Finder のオートメーションはユーザーが許可した。
- スパイクと検証用のビルドは LaunchServices から登録を外した。
