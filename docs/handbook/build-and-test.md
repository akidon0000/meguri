# ビルド・テスト

- 読み手: このリポジトリで作業する自分・エージェント
- 目的: プロジェクト生成・ビルド・テストの現在の手順の正本（構成の経緯: [ADR-0001](../adr/0001-xcodegen-without-build-plugins.md)）

## プロジェクト生成

`Meguri.xcodeproj` は `project.yml` から [XcodeGen](https://github.com/yonaskolb/XcodeGen) で生成する。
`project.yml` を変更したら、またはソースファイルを追加・削除したら実行する。

```bash
xcodegen generate
```

生成された `.xcodeproj` はコミット対象。

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
