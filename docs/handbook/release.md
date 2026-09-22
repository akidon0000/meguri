# リリース（TestFlight / 審査提出）

- 読み手: このリポジトリで作業する自分・エージェント
- 目的: Meguri を TestFlight / 審査提出まで進める現在の手順の正本
- 認可: 審査提出（submit for review）までは自動で進めてよい。ストア公開（リリースボタン）はユーザーが手動で行う

fastlane は使わず [asc](https://asccli.sh/)（App Store Connect CLI）を使う。asc の採用理由・
認証の共有範囲（チーム単位で全アプリ共通）は [hq の ADR-0007](https://github.com/akidon0000/hq/blob/main/docs/adr/0007-asc-cli-for-ios-release.md)
と [hq の handbook/ios-release.md](https://github.com/akidon0000/hq/blob/main/docs/handbook/ios-release.md) が正本。
ここには Meguri 固有の値だけを置く。

## このアプリの値

| 項目 | 値 |
|---|---|
| Bundle ID | `com.akidon0000.meguri` |
| Team ID | `XSC9AJPSP3` |
| App Store Connect App ID | `6814714502` |

## 手順

### 0. アプリレコード作成（ユーザーが自分で行う・完了済み）

`asc web apps create` は ASC API キーではなく Apple ID の Web セッション認証（パスワード・2FA）が要る。
エージェントはパスワードを扱えないため、**この 1 回だけはユーザーが自分のターミナルで実行する**：

```bash
asc web apps create --name "Meguri" --bundle-id "com.akidon0000.meguri" \
  --sku "meguri-ios" --primary-locale "ja"
```

Apple ID・2FA はプロンプトで安全に入力される（コマンド引数には含めない）。primary-locale は
リージョン無しの `ja`（`ja-JP` は `ENTITY_ERROR.ATTRIBUTE.INVALID` で失敗する）。

2026-09-22 に実行済み。App Store 上で "Meguri" という名前が既に使われていたため
`--auto-rename`（既定 true）が働き、App 名は `Meguri - meguri` になった。
`asc apps rename --app 6814714502 --locale "ja" --name "Megumemo"` で正式名称
「Megumemo」に変更済み（[Info.plist](../../Meguri/Info.plist) の `CFBundleDisplayName` と
[CollectionView.swift](../../Meguri/Features/Collection/CollectionView.swift) の
`navigationTitle` も揃えた）。Xcode プロジェクト名・Bundle ID・Swift モジュール名は
`Meguri` のまま変えていない。

### 1. 署名の準備（Xcode に Apple ID 未ログインのときだけ必要・完了済み）

自動署名（`signingStyle: automatic`）は Xcode に Apple ID アカウントが登録されている前提だが、
このマシンでは未登録で `error: exportArchive No Accounts` になった。Apple ID ログインは GUI 操作＋
パスワードが要るためエージェントは行えない代わりに、ASC API キーだけで完結する手動署名に切り替えた：

```bash
# 配布証明書の秘密鍵がこのMacのキーチェーンに既にあることを確認
security find-identity -v -p codesigning | grep Distribution

# ASC APIでプロビジョニングプロファイルを新規作成・取得（無ければ --create-missing で作成される）
asc signing fetch --bundle-id com.akidon0000.meguri --profile-type IOS_APP_STORE \
  --create-missing --output ./signing

# Xcodeが参照する標準の場所にインストール（ファイル名は UUID.mobileprovision）
cp signing/IOS_APP_STORE-*.mobileprovision \
  ~/Library/MobileDevice/Provisioning\ Profiles/<UUID>.mobileprovision
```

`scripts/ExportOptions.plist` は `signingStyle: manual` + `provisioningProfiles` にプロファイル名を
指定する形に変更済み。Xcode に Apple ID を追加すれば `automatic` に戻せるが、必須ではない。

### 2. ビルド・アップロード（完了済み）・審査提出（未実施）

asc の認証は済んでいる前提（`asc auth status` で確認。していなければ hq の handbook 参照）。

```bash
scripts/testflight.sh <APP_ID>                          # archive → export → TestFlight upload
scripts/testflight.sh <APP_ID> --group "Internal" --notify
asc publish appstore --app <APP_ID> --ipa build/Meguri.ipa --version 1.0 --submit --confirm   # 審査提出まで
```

`scripts/testflight.sh` は `.xcodeproj` からプロジェクト名・スキーム名を自動検出するので、
アプリ名を変えても編集不要（[ios-project-template](https://github.com/akidon0000/ios-project-template) 由来の共通実装）。
`scripts/ExportOptions.plist` は `manageAppVersionAndBuildNumber: true` にしてあり、ビルド番号は
asc 側で自動採番される。

2026-09-22、Build 1（version 1.0）のアップロードまで完了（`processingState: VALID`）。
内部テスター用に `Internal` グループを作成し `a@art.jp` を追加済み（TestFlightアプリで実機確認可能）。
**審査提出はまだ行っていない** — Foundation Models の説明品質を実機で確認してから、
というのがこのセッションの判断（シミュレータでは Vision/Foundation Models が動かないため未検証）。
