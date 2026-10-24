# Capture スパイク

[docs/verification.md](../../docs/verification.md) §6 の、サービス「Shelf に置く」（F13）の前提を検証するための使い捨てコード。製品コードには含めない。

| ディレクトリ | 内容 |
|---|---|
| `CaptureSpike/` | Sandbox 有効・LSUIElement のアプリ。ファイル（`NSSendFileTypes`）とテキスト・URL（`NSSendTypes`）の両方を宣言した 1 つのサービス（`put`）を提供し、受け取った内容をログに出す |
| `Driver/` | `NSPerformService` でサービスを呼ぶ（合成のキー入力は使わない）。`NSApplication.shared` を初期化しないと、受け取り側のペーストボードが空になる |

## 実行

```sh
KEY='^~@p' ./build.sh
mkdir -p work/src && echo alpha > work/src/a.txt && echo control > work/control.txt
open -n --env SPIKE_CONTROL_PATH=$PWD/work/control.txt build/CaptureSpike.app
build/driver "CaptureSpike: Put" file $PWD/work/src/a.txt
build/driver "CaptureSpike: Put" text "hello shelf"
build/driver "CaptureSpike: Put" url https://example.com/page
/usr/bin/log show --last 5m --info --style compact --predicate 'subsystem == "dev.keimvm.CaptureSpike"'
```

終わったら登録を外す：

```sh
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u build/CaptureSpike.app
/System/Library/CoreServices/pbs -update
```
