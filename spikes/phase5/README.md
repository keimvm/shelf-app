# Phase 5 検証コード

[docs/verification.md](../../docs/verification.md) §9 の感度調整と受け入れ確認に使ったコード。製品コードには含めない。

| ディレクトリ | 内容 |
|---|---|
| `Driver/` | `CGEvent` でドラッグとシェイクを再現する（`shake` / `shakedrop` / `drag` / `shelves` / `click` / `find`）。実行元プロセスに Accessibility 権限が必要 |
| `Harness/` | 製品の `ShakeDetector.swift` と、閾値を差し替える `Candidates.swift` で、合成した軌跡の発火率を表にする |

## 実行

```sh
mkdir -p build
swiftc -swift-version 5 -O Driver/main.swift -o build/driver
swiftc -swift-version 5 -O ../../Shelf/Drag/ShakeDetector.swift Harness/Candidates.swift Harness/main.swift -o build/harness

# 閾値の比較（名前=反転回数,区間の最小長,時間窓[,反転角]）。HZ でイベントレートを変える
./build/harness --set standard=4,24,0.9 high=3,24,0.8 highest=3,20,1.1
HZ=60 ./build/harness --set standard=4,24,0.9

# 実ドラッグ。ドラッグ元は spikes/phase0 の DragSource（Cocoa 座標 200,300 の 160×160）
open -n ../phase0/build/DragSource.app --args $PWD/work/src/a.txt
./build/driver shake 280 1060 --amp 80 --swings 6 --ms 150
./build/driver shakedrop 280 1060 900 600   # 900,600 で振って、出たシェルフへドロップ
```

座標はグローバル・左上原点（CG）。`shake` は、開始前と終了後に開いている Shelf のシェルフを閉じる（`--keep` で残す）。
