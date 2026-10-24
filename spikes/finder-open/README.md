# Finder 選択項目のスパイク

[docs/verification.md](../../docs/verification.md) §5 の、Finder の選択項目を Sandbox のアプリで受け取る方法（F13）を検証するための使い捨てコード。製品コードには含めない。

| ディレクトリ | 内容 |
|---|---|
| `OpenSpike/` | Sandbox 有効・LSUIElement のアプリ。`application(_:open:)` で渡されたファイルと、渡されていないファイル（`SPIKE_CONTROL_PATH`）の読み取り・bookmark の作成と解決をログに出す |

## 実行

```sh
# RANK / ROLE は CFBundleDocumentTypes の LSHandlerRank / CFBundleTypeRole。
# ENTITLEMENTS=OpenSpike/ReadOnly.entitlements で読み取り専用の例外（/）を付ける
ENTITLEMENTS=OpenSpike/ReadOnly.entitlements ./build.sh
mkdir -p work/src && echo alpha > work/src/a.txt && echo control > work/control.txt
open -n --env SPIKE_CONTROL_PATH=$PWD/work/control.txt build/OpenSpike.app
# Finder に開かせる（拒否される。verification.md §5）
APP=$PWD/build/OpenSpike.app osascript -e 'tell application "Finder" to open (get selection) using (POSIX file (system attribute "APP") as alias)'
/usr/bin/log show --last 5m --info --style compact --predicate 'subsystem == "dev.keimvm.OpenSpike"'
```

`SPIKE_CONTROL_PATH` に保護されたフォルダ（`~/Desktop` など）を渡すと、macOS がアクセスの許可を確認する。

終わったら登録を外す（書類タイプを宣言しているため）：

```sh
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u build/OpenSpike.app
```
