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
| App Store Connect App ID | 未作成（`asc web apps create` か Web UI でアプリレコードを作ってから控える） |

## 手順

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
