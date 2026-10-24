# Phase 0 スパイク

[docs/verification.md](../../docs/verification.md) の U1〜U4 を検証するための使い捨てコード。製品コードには含めない。

| ディレクトリ | 内容 |
|---|---|
| `ShelfSpike/` | Sandbox 有効・LSUIElement のアプリ。グローバル/ローカルモニタでドラッグを観測し、ドロップ受け付けと取り出し（`.copy` のみ）ができる `NSPanel` を持つ |
| `DragSource/` | Sandbox なしの補助アプリ。固定位置（Cocoa 座標 200,300、160×160）からファイルドラッグを開始する |
| `Driver/` | `CGEvent` でドラッグを再現する（`drag` / `find` / `fullscreen`）。実行元プロセスに Accessibility 権限が必要 |

## 実行

```sh
./build.sh
mkdir -p work/src work/dest && echo alpha > work/src/a.txt && echo beta > work/src/b.txt && echo control > work/control.txt
open -n --env SPIKE_CONTROL_PATH=$PWD/work/control.txt build/ShelfSpike.app
open -n build/DragSource.app --args $PWD/work/src/a.txt $PWD/work/src/b.txt
# 座標はグローバル・左上原点（CG）。以下は 1800x1169pt の画面での値
build/driver drag 280 789 1010 789 shake   # DragSource → パネル（シェイクあり）
build/driver drag 1010 789 650 700         # パネル → Finder ウィンドウ（work/dest）
/usr/bin/log show --last 5m --style compact --predicate 'subsystem == "dev.keimvm.ShelfSpike"'
```

環境変数：`SPIKE_LEVEL`（`floating`|`statusBar`|`popUpMenu`）、`SPIKE_MOVABLE_BG=1`（背景ドラッグでのパネル移動を有効化）。
