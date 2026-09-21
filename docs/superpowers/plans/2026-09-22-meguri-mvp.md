# Meguri MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 写真を撮る → Vision + Foundation Models で説明カードを生成 → SwiftData のコレクションに保存・閲覧できる iOS アプリを TestFlight に上げられる状態にする。

**Architecture:** SwiftUI + Observation の薄い MVVM。`AnalyzeViewModel` が 4 つの protocol（知覚・生成・位置・画像保存）を注入で受けて 1 本の流れを組み、UI はそれを表示するだけ。プロンプト組み立ては純粋関数 `PromptBuilder` に隔離してテストで固定する。

**Tech Stack:** Swift 6 / SwiftUI / SwiftData / Vision / FoundationModels / CoreLocation / PhotosUI / Swift Testing / XcodeGen

**Spec:** [../specs/2026-09-22-meguri-mvp-design.md](../specs/2026-09-22-meguri-mvp-design.md)

**Execution method:** Native（ユーザー就寝中の自律実行のため。朝に全体レビューを依頼する）

## Global Constraints

- iOS 26.0 以上、Swift 6 strict concurrency、`any` 明示
- 外部ネットワーク API を呼ばない。AI は FoundationModels のみ
- 画像本体は SwiftData に入れない（ファイル保存 + 256px サムネイルのみ DB）
- UI 文字列は String Catalog（`Localizable.xcstrings`）、ja 翻訳あり
- 依存追加なし（SPM 追加禁止）
- テストは `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`

## Review Focus

1. Foundation Models 利用不可（`.unavailable`）でも保存が完了し、詳細画面に理由が出る → Task 5 のテスト
2. Vision がラベルもテキストも返さないとき、プロンプトに「情報が少ない」旨が入り生成は続行する → Task 2 のテスト
3. 位置情報が取れないとき、場所なしで保存される → Task 5 のテスト
4. 生成が throw したとき、画像と知覚結果は保存され、再生成できる → Task 5 のテスト
5. 巨大画像（12MP）でサムネイル生成がメモリを食い潰さない → Task 3 で `preparingThumbnail` を使う

---

### Task 1: Insight モデルと JSON 往復

**Files:**
- Create: `Meguri/Models/Insight.swift`（済: @Generable 構造体）
- Test: `MeguriTests/InsightTests.swift`

**Interfaces:**
- Produces: `struct Insight: Codable, Sendable, Equatable { title, creator, era, summary, funFacts: [String], category: Category }`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import Meguri

@Suite struct InsightTests {
    @Test func roundTripsThroughJSON() throws {
        let original = Insight(title: "睡蓮", creator: "クロード・モネ", era: "1906年頃",
                               summary: "ジヴェルニーの庭の池を描いた連作の一枚。", funFacts: ["連作は250点以上ある"],
                               category: .artwork)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Insight.self, from: data)
        #expect(decoded == original)
    }
}
```

- [ ] **Step 2: Run test to verify it fails** — `Insight` に memberwise init がある（@Generable が生成）ので、この段階では通るはず。通ったら Step 5 へ。
- [ ] **Step 3/4:** 不要
- [ ] **Step 5: Commit** — `git commit -m "Add Insight model with JSON round-trip test"`

### Task 2: PromptBuilder

**Files:**
- Create: `Meguri/Services/PromptBuilder.swift`
- Test: `MeguriTests/PromptBuilderTests.swift`

**Interfaces:**
- Produces: `enum PromptBuilder { static let instructions: String; static func prompt(labels: [String], texts: [String], placeName: String?, locale: Locale) -> String }`

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct PromptBuilderTests {
    @Test func includesRecognizedTextFirst() {
        let p = PromptBuilder.prompt(labels: ["painting", "water lily"], texts: ["Water Lilies, Claude Monet, 1906"], placeName: nil, locale: Locale(identifier: "ja_JP"))
        #expect(p.contains("Water Lilies, Claude Monet, 1906"))
        #expect(p.range(of: "Water Lilies")!.lowerBound < p.range(of: "painting")!.lowerBound)
    }
    @Test func includesPlaceWhenKnown() {
        let p = PromptBuilder.prompt(labels: [], texts: [], placeName: "国立西洋美術館", locale: .current)
        #expect(p.contains("国立西洋美術館"))
    }
    @Test func notesSparseInputWhenNothingPerceived() {
        let p = PromptBuilder.prompt(labels: [], texts: [], placeName: nil, locale: .current)
        #expect(p.contains("little information"))
    }
    @Test func requestsAnswerLanguage() {
        let p = PromptBuilder.prompt(labels: ["x"], texts: [], placeName: nil, locale: Locale(identifier: "ja_JP"))
        #expect(p.contains("Japanese"))
    }
}
```

- [ ] **Step 2: Run** — FAIL: `PromptBuilder` not found
- [ ] **Step 3: Implement**

```swift
enum PromptBuilder {
    static let instructions = """
    You are a knowledgeable, friendly museum and travel guide. Given clues extracted from a photo \
    (text seen in the image, visual labels, and the place it was taken), identify what the photo shows \
    and explain its background. Prefer text clues (captions, plaques) over visual labels. \
    Never invent specific names, dates, or facts you are not confident about; hedge instead.
    """
    static func prompt(labels: [String], texts: [String], placeName: String?, locale: Locale) -> String {
        var lines: [String] = []
        if !texts.isEmpty { lines.append("Text seen in the photo:\n" + texts.map { "- \($0)" }.joined(separator: "\n")) }
        if !labels.isEmpty { lines.append("Visual labels: " + labels.joined(separator: ", ")) }
        if let placeName { lines.append("Taken at: \(placeName)") }
        if texts.isEmpty && labels.isEmpty { lines.append("There is little information extracted from the photo; describe what a visitor would likely be looking at, in general terms.") }
        lines.append("Answer in \(languageName(for: locale)).")
        return lines.joined(separator: "\n\n")
    }
    static func languageName(for locale: Locale) -> String {
        Locale(identifier: "en_US").localizedString(forLanguageCode: locale.language.languageCode?.identifier ?? "en") ?? "English"
    }
}
```

- [ ] **Step 4: Run** — PASS
- [ ] **Step 5: Commit** — `git commit -m "Add PromptBuilder"`

### Task 3: FileImageStore

**Files:**
- Create: `Meguri/Services/ImageStore.swift`
- Test: `MeguriTests/FileImageStoreTests.swift`

**Interfaces:**
- Produces: `protocol ImageStoring: Sendable { func save(_ image: UIImage) throws -> StoredImage; func load(fileName: String) -> UIImage?; func delete(fileName: String) }`, `struct StoredImage { fileName: String; thumbnailData: Data }`, `final class FileImageStore: ImageStoring { init(directory: URL) }`

- [ ] **Step 1: Test**

```swift
@Suite struct FileImageStoreTests {
    @Test func savesJPEGAndThumbnail() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = FileImageStore(directory: dir)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1500)).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 2000, height: 1500))
        }
        let stored = try store.save(image)
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent(stored.fileName).path))
        let thumb = try #require(UIImage(data: stored.thumbnailData))
        #expect(max(thumb.size.width, thumb.size.height) <= 256)
        #expect(store.load(fileName: stored.fileName) != nil)
        store.delete(fileName: stored.fileName)
        #expect(store.load(fileName: stored.fileName) == nil)
    }
}
```

- [ ] **Step 2: Run** — FAIL
- [ ] **Step 3: Implement** — JPEG 0.85 で `<uuid>.jpg` 保存、`image.preparingThumbnail(of:)` で 256px サムネイル、`directory` は `Application Support/Images` を既定に
- [ ] **Step 4: Run** — PASS
- [ ] **Step 5: Commit**

### Task 4: Entry (SwiftData)

**Files:**
- Create: `Meguri/Models/Entry.swift`
- Test: `MeguriTests/EntryTests.swift`

**Interfaces:**
- Produces: `@Model final class Entry { id, createdAt, imageFileName, thumbnailData, placeName, latitude, longitude, insightData, perceivedLabels, recognizedTexts, unavailableReason: String? }`、computed `insight: Insight?`（get/set で JSON 変換）

- [ ] **Step 1: Test** — in-memory `ModelContainer` に insert → fetch → `insight` が往復する
- [ ] **Step 2: Run** — FAIL
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run** — PASS
- [ ] **Step 5: Commit**

### Task 5: AnalyzeViewModel と protocol 群

**Files:**
- Create: `Meguri/Services/ImagePerception.swift`（protocol + Vision 実装）
- Create: `Meguri/Services/InsightGenerator.swift`（protocol + FoundationModels 実装）
- Create: `Meguri/Services/LocationService.swift`（protocol + CoreLocation 実装）
- Create: `Meguri/Features/Capture/AnalyzeViewModel.swift`
- Test: `MeguriTests/AnalyzeViewModelTests.swift`（フェイク 3 種を同ファイルに）

**Interfaces:**
- `protocol ImagePerceiving: Sendable { func perceive(_ image: UIImage) async throws -> Perception }`、`struct Perception { labels: [String]; texts: [String] }`
- `protocol InsightGenerating: Sendable { var availability: GeneratorAvailability { get }; func generate(prompt: String) async throws -> Insight }`、`enum GeneratorAvailability: Equatable { case available, unavailable(reason: String) }`
- `protocol LocationProviding: Sendable { func currentPlace() async -> Place? }`、`struct Place { name: String?; latitude: Double; longitude: Double }`
- `@MainActor @Observable final class AnalyzeViewModel { enum Phase { idle, perceiving, generating, done(Entry), failed(String) }; var phase; init(perception:, generator:, location:, imageStore:, modelContext:); func analyze(_ image: UIImage) async; func regenerate(_ entry: Entry) async }`

- [ ] **Step 1: Tests**（4 本: 成功で insight 付き Entry が保存される / generator unavailable で insightData nil + unavailableReason あり / generator throw で Entry 保存 + phase done + unavailableReason にエラー文 / location nil で placeName nil）
- [ ] **Step 2: Run** — FAIL
- [ ] **Step 3: Implement** — `async let` で位置と知覚を並列。生成は `availability` を先に見る
- [ ] **Step 4: Run** — PASS
- [ ] **Step 5: Commit**

### Task 6: UI（Collection / Capture / Detail）と App 配線

**Files:**
- Create: `Meguri/Features/Collection/CollectionView.swift`, `EntryCard.swift`
- Create: `Meguri/Features/Capture/CaptureSheet.swift`（PhotosPicker + CameraPicker）, `CameraPicker.swift`（UIImagePickerController）, `AnalyzingView.swift`
- Create: `Meguri/Features/Detail/EntryDetailView.swift`
- Create: `Meguri/Resources/Localizable.xcstrings`, `Meguri/Resources/Assets.xcassets`（AppIcon, AccentColor）
- Modify: `Meguri/MeguriApp.swift`（`.modelContainer(for: Entry.self)`）、削除: `ContentView.swift`
- Create: `Meguri/AppDependencies.swift`（本番実装を束ねる）

- [ ] **Step 1:** UI はプレビューとシミュレータで確認（単体テストなし）
- [ ] **Step 2:** ビルド → シミュレータ起動 → 空状態 → ライブラリから画像を選ぶ → 詳細が出る → 一覧に戻る、を実機能で確認しスクリーンショットを残す
- [ ] **Step 3: Commit**

### Task 7: リリース準備

**Files:**
- Create: `scripts/archive.sh`（`xcodebuild archive` + export）、`scripts/upload-testflight.sh`（`asc` で upload）
- Create: `CLAUDE.md`（リポジトリ固有の手順）
- Modify: `README.md`

- [ ] **Step 1:** `xcodebuild archive` がシミュレータなし・自動署名で通ることを確認
- [ ] **Step 2:** asc の認証が有効なら `asc publish testflight` まで。無効なら手順だけ残す
- [ ] **Step 3: Commit & push**
