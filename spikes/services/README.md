# Services スパイク

[docs/verification.md](../../docs/verification.md) §4 の、サービス「新規シェルフに置く」（F13）の前提を検証するための使い捨てコード。製品コードには含めない。

| ディレクトリ | 内容 |
|---|---|
| `ServiceSpike/` | Sandbox 有効・LSUIElement のアプリ。ファイルを受け取るサービス（`placeFiles`）と、何も受け取らないサービス（`openEmpty`）を提供し、受け取った内容をログに出す |
| `Driver/` | `CGEvent` でキーを押す（`key <keyCode> [ctrl] [opt] [cmd] [shift]`）。実行元プロセスに Accessibility 権限が必要 |

## 実行

```sh
# サービスの既定のショートカットを key-binding の書式で渡す（^=⌃ ~=⌥ @=⌘ $=⇧）
KEY_FILES='$^~@N' ./build.sh
mkdir -p work/src && echo alpha > work/src/a.txt && echo beta > work/src/b.txt && echo control > work/control.txt
open -n --env SPIKE_CONTROL_PATH=$PWD/work/control.txt build/ServiceSpike.app
open work/src && build/driver key 0 cmd       # Finder で ⌘A
build/driver key 45 ctrl opt cmd shift        # ⇧⌃⌥⌘N
/usr/bin/log show --last 5m --info --style compact --predicate 'subsystem == "dev.keimvm.ServiceSpike"'
```

環境変数：`SPIKE_RESTORE`（`deactivate`|`previous`：サービス実行後にフォーカスを戻す方法）、`SPIKE_HOTKEY=1`（⌃⌥⌘N を `RegisterEventHotKey` でも登録する）、`KEY_EMPTY`（`openEmpty` の既定のショートカット）。

終わったら登録を外す（残すと製品のショートカットと重なる）：

```sh
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u build/ServiceSpike.app
/System/Library/CoreServices/pbs -update
```
