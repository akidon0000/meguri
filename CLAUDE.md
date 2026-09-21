# Meguri

写真（絵画・建物・風景）を撮ると Vision + Foundation Models で説明カードを作り、SwiftData に溜める iOS アプリ。
設計は `docs/superpowers/specs/`、実装計画は `docs/superpowers/plans/` が正本。

## 開発ループ

- superpowers（brainstorming → writing-plans → TDD → verification）で進める。spec と plan を先に置いてから書く
- Xcode プロジェクトは XcodeGen 管理。ファイルを足したら `xcodegen generate`（`.xcodeproj` はコミット対象）
- テスト: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
- Swift Testing で `@MainActor` + `container.mainContext` を組み合わせると Xcode 27 beta でデッドロックする。テストでは `ModelContext(container)` を使う
- シミュレータでは Vision の分類器（"espresso context"）と Foundation Models の生成が失敗する。文字認識と UI の流れはシミュレータで確認でき、AI 説明は実機でしか検証できない

## リリース

- fastlane は使わない。App Store Connect CLI（`asc`、`~/.local/bin/asc`）で TestFlight / 審査提出まで行う
- `scripts/testflight.sh APP_ID` でアーカイブ → エクスポート → TestFlight アップロード（`--upload-only` 既定）
- 署名は automatic（Team `XSC9AJPSP3`、Bundle ID `com.akidon0000.meguri`）。`ExportOptions.plist` は `scripts/`
- 審査提出まではエージェントが進めてよい。ストア公開（リリースボタン）はユーザーが手動で行う
