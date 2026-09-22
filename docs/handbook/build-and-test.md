# ビルド・テスト

- 読み手: このリポジトリで作業する自分・エージェント
- 目的: プロジェクト編集・ビルド・テストの現在の手順の正本（構成の経緯: [ADR-0004](../adr/0004-json-project-format-without-xcodegen.md)）
- 前提: **Xcode 27.2 以降**。`Meguri.xcodeproj/project.xcproj` は Xcode 27.2 Beta の JSON5 プロジェクト形式で、
  Xcode 27.1 以前では開けない（`-convert-project` にこの形式が存在しない）

## ファイルを追加・削除するとき

XcodeGen は使わない。`.xcodeproj` を直接編集する。方法は2つ、どちらでも同じ `project.xcproj` が更新される。

**Xcode の GUI（人が作業するとき）**: 通常どおり Project Navigator にドラッグ&ドロップする。

**`xcodeproj` CLI（エージェントが作業するとき、Xcode 27.2 に同梱）**:

```bash
# 1. グループにファイル参照を追加（コンパイルはまだされない）
xcrun xcodeproj group add-file NewFile.swift --group /Meguri/Services

# 2. ターゲットのビルドフェーズに組み込む（phase 番号は target info で確認）
xcrun xcodeproj target info --target Meguri   # phase 一覧: 1=sources, 2=resources 等
xcrun xcodeproj group include NewFile.swift --group /Meguri/Services --target Meguri --phase 1

# 削除するとき
xcrun xcodeproj group remove-file NewFile.swift --group /Meguri/Services --force
```

グループパスは `xcrun xcodeproj group ls /Meguri` 等で確認できる。ターゲット・グループ操作の全体像は
`xcrun xcodeproj --help` / `xcrun xcodeproj help group <subcommand>`。

## ビルド・テスト

```bash
xcodebuild build -project Meguri.xcodeproj -scheme Meguri \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'

xcodebuild test -project Meguri.xcodeproj -scheme Meguri \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

## 既知の制限

### シミュレータでは AI 機能が動かない

Vision の分類器（`ClassifyImageRequest`）と Foundation Models の生成
（`FoundationModelsInsightGenerator`）は iOS シミュレータ上では失敗する。

- 確認できること（シミュレータで可）: 文字認識（`RecognizeTextRequest`）、写真選択・保存・一覧・削除の UI フロー
- 確認できないこと（実機が必要）: 絵画・建物の同定精度、Foundation Models が生成する説明文の質
  （[ADR-0002](../adr/0002-on-device-ai-only.md) 参照）

### Swift Testing で `@MainActor` + `mainContext` がデッドロックする

Xcode 27 beta で、`@Test @MainActor` な関数の中で `ModelContainer.mainContext` を使うとテストが
デッドロックすることを確認している。テストでは `ModelContext(container)` を明示的に作って使うこと
（`@MainActor` を付けない、または付けても `mainContext` を経由しない）。

```swift
// NG: デッドロックする
@Test @MainActor func example() throws {
    let context = container.mainContext
}

// OK
@Test func example() throws {
    let context = ModelContext(container)
}
```

`MeguriTests/EntryTests.swift` ・ `MeguriTests/AnalyzeViewModelTests.swift` が実例。

### CI にビルド・テストが無い

`.github/workflows/` には SwiftLint（Danger）と swift-format の PR チェックしかなく、
`xcodebuild build` / `test` を走らせる CI ワークフローは存在しない。GitHub Actions の macOS
ランナーイメージ（`actions/runner-images` の `xcode-27-arm64`）が 2026-09-22 時点で Xcode 27.0 までしか
収録しておらず、本リポジトリが前提とする Xcode 27.2 Beta が無いため、今は追加もできない
（[ADR-0004](../adr/0004-json-project-format-without-xcodegen.md) 参照）。

push・PR の前に、このページの「ビルド・テスト」節のコマンドをローカルで必ず実行すること。
ランナーイメージが Xcode 27.2 を収録したら、`runs-on: xcode-27-arm64`（または該当ラベル）で
build/test ワークフローを追加できないか再検討する。
