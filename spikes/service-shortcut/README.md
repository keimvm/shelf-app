# Service shortcut スパイク

[docs/verification.md](../../docs/verification.md) §7 の、サービス「Shelf に置く」（F13）のショートカットをアプリから変えられるかを検証するための使い捨てコード。製品コードには含めない。

| ディレクトリ | 内容 |
|---|---|
| `PrefsSpike/` | Sandbox 有効（Entitlements は N2 の 3 つ）・LSUIElement のアプリ。サービスのショートカットを保持する `pbs` ドメインを読み、無害なキー（`PrefsSpikeProbe`）を書いて消す。`NSServicesStatus` そのものには書かない。システム設定のキーボードを開く URL を扱うアプリも調べる |

## 実行

```sh
./build.sh
open -W -n build/PrefsSpike.app
/usr/bin/log show --last 1m --info --style compact --predicate 'subsystem == "dev.keimvm.PrefsSpike"'
defaults read pbs PrefsSpikeProbe   # 書き込みが届いていなければ「見つからない」
```

終わったら登録を外す：

```sh
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u build/PrefsSpike.app
```
