# Meguri

美術館の絵画や旅先の風景を撮ると、その場で「それが何か・どんな背景があるか」を Apple 純正 AI が説明し、
撮った記録がコレクションとして溜まっていく iOS アプリ。

- 説明は Vision（文字認識・画像分類）→ Foundation Models（オンデバイス / Private Cloud Compute）で生成。外部 API なし
- 撮影場所（CoreLocation）と日時つきで SwiftData に保存
- iOS 26.0+、Swift 6、SwiftUI

## 開発

```bash
brew install mint xcodegen
xcodegen generate
xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

設計: [docs/superpowers/specs/](docs/superpowers/specs/)、実装計画: [docs/superpowers/plans/](docs/superpowers/plans/)

## TestFlight

[asc](https://asccli.sh/)（App Store Connect CLI）で配信する。

```bash
asc auth login --name akidon0000 --key-id KEY_ID --issuer-id ISSUER_ID --private-key ~/.appstoreconnect/private_keys/AuthKey_KEY_ID.p8
scripts/testflight.sh APP_ID
```
